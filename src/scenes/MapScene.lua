local theme = require("theme")
local config = require("config")
local MapManager = require("managers.MapManager")
local DaySystem = require("core.DaySystem")
local TopBar = require("ui.TopBar")

local MapScene = {}
MapScene.__index = MapScene

function MapScene.new()
  return setmetatable({
    mapManager = MapManager.new(),
    daySystem = DaySystem.new(),
    cameraX = 0,
    cameraY = 0,
    targetCameraX = 0,
    targetCameraY = 0,
    playerWorldX = 0,
    playerWorldY = 0,
    playerTargetX = nil,
    playerTargetY = nil,
    isMoving = false,
    selectedGridX = nil,
    selectedGridY = nil,
    gridSize = 64,
    offsetX = 0,
    offsetY = 0,
    _pendingBattleTransition = false,
    _battleTransitionDelay = nil,
    playerSprite = nil,
    _initialized = false,
    _returnGridX = nil,
    _returnGridY = nil,
    _enemyTileX = nil, -- Enemy tile position (where player moved to for battle)
    _enemyTileY = nil,
    _battleVictory = false, -- Whether the last battle was a victory
    _treeSwayTime = 0, -- accumulated time for tree sway animation
    playerFacingRight = true, -- track player facing direction for sprite flipping
    _movementTime = 0, -- time elapsed during current movement for bobbing animation
    topBar = TopBar.new(),
    -- UI assets for End Day button
    endDayIcon = nil,
    keySpaceIcon = nil,
    endDayBtnRect = nil,
    _endDayFadeAlpha = 0,
    _endDayHoverScale = 1, -- tweened scale for hover effect
    _endDayHovered = false, -- track hover state for text/key alpha
    _endDaySpinAngle = 0, -- rotation angle for spin animation
    _endDaySpinTime = 0, -- time elapsed in spin animation
    _endDaySpinDuration = 0.6, -- duration of spin animation
    _endDayFadeOutAlpha = 1, -- fade out alpha after press
    _endDayFadeOutTime = 0, -- time elapsed in fade out
    _endDayFadeOutDuration = 0.2, -- duration of fade out (faster)
    _endDayPressed = false, -- track if button was pressed
    _mouseX = 0,
    _mouseY = 0,
    -- Hold-to-move state
    _heldMoveKey = nil,
    _heldDirX = 0,
    _heldDirY = 0,
    _holdElapsed = 0,
    _repeatElapsed = 0,
    _hasFiredInitialRepeat = false,
  }, MapScene)
end

function MapScene:load()
  -- Initialize day system
  self.daySystem:load(config)
  -- Expose day system to top bar for rendering day and steps
  if self.topBar then
    self.topBar.daySystem = self.daySystem
  end
  
  -- Load map sprites
  if not self._initialized then
    self.mapManager:loadSprites()
  end
  
  -- Load player sprite
  self.playerSprite = love.graphics.newImage(config.assets.images.player)
  
  -- Load player glow (optional)
  do
    local ok, glow = pcall(love.graphics.newImage, "assets/images/map/player_glow.png")
    if ok then self.playerGlow = glow end
  end
  
  -- Load orange glow for rest sites (optional)
  do
    local ok, glow = pcall(love.graphics.newImage, "assets/images/map/orange_glow.png")
    if ok then self.restGlow = glow end
  end

  -- Load End Day button icons (optional, with linear filtering)
  do
    local imgs = (config.assets and config.assets.images) or {}
    if imgs.end_turn then
      local ok, img = pcall(love.graphics.newImage, imgs.end_turn)
      if ok then pcall(function() img:setFilter('linear', 'linear') end); self.endDayIcon = img end
    end
    if imgs.key_space then
      local ok, img = pcall(love.graphics.newImage, imgs.key_space)
      if ok then pcall(function() img:setFilter('linear', 'linear') end); self.keySpaceIcon = img end
    end
  end
  
  -- Generate map on first load only; preserve state when returning from battle
  local genConfig = config.map.generation
  if not self._initialized then
    self.mapManager:generateMap(genConfig.width, genConfig.height, math.random(1000000))
    self._initialized = true
  end
  
  -- Calculate map offset to center it
  self.gridSize = config.map.gridSize
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  
  local mapWidth = self.mapManager.gridWidth * self.gridSize
  local mapHeight = self.mapManager.gridHeight * self.gridSize
  self.offsetX = (vw - mapWidth) * 0.5
  self.offsetY = (vh - mapHeight) * 0.5
  
  -- Set initial camera and player position
  -- Ensure player position is valid (MapManager should have already placed it correctly)
  if self.mapManager.playerGridX == 0 or self.mapManager.playerGridY == 0 then
    -- Fallback: find first ground tile
    for y = 1, self.mapManager.gridHeight do
      for x = 1, self.mapManager.gridWidth do
        local tile = self.mapManager:getTile(x, y)
        if tile and tile.type == MapManager.TileType.GROUND then
          self.mapManager.playerGridX = x
          self.mapManager.playerGridY = y
          break
        end
      end
      if self.mapManager.playerGridX ~= 0 then break end
    end
  end
  
  -- Handle return from battle
  if self._battleVictory and self._enemyTileX and self._enemyTileY then
    -- Victory: player stays on enemy tile, convert it to ground
    self.mapManager.playerGridX = self._enemyTileX
    self.mapManager.playerGridY = self._enemyTileY
    -- Convert enemy tile to ground
    self.mapManager:setTile(self._enemyTileX, self._enemyTileY, {
      type = MapManager.TileType.GROUND,
      spriteVariant = nil,
      decoration = nil,
    })
    
    -- If we were fighting for a protected treasure, collect it now
    if self._treasureTileX and self._treasureTileY then
      local treasureTile = self.mapManager:getTile(self._treasureTileX, self._treasureTileY)
      if treasureTile and treasureTile.type == MapManager.TileType.TREASURE then
        -- Collect the treasure
        self.mapManager:setTile(self._treasureTileX, self._treasureTileY, {
          type = MapManager.TileType.GROUND,
          spriteVariant = nil,
          decoration = nil,
        })
      end
      self._treasureTileX, self._treasureTileY = nil, nil
    end
    
    -- Clear enemy tile tracking
    self._enemyTileX, self._enemyTileY = nil, nil
    self._battleVictory = false
  elseif self._returnGridX and self._returnGridY then
    -- Defeat: restore player to return position
    self.mapManager.playerGridX = self._returnGridX
    self.mapManager.playerGridY = self._returnGridY
    self._returnGridX, self._returnGridY = nil, nil
    self._enemyTileX, self._enemyTileY = nil, nil
  end
  self.mapManager.playerTargetGridX = nil
  self.mapManager.playerTargetGridY = nil
  local px, py = self.mapManager:getPlayerWorldPosition(self.gridSize, self.offsetX, self.offsetY)
  self.playerWorldX = px
  self.playerWorldY = py
  self.cameraX = px
  self.cameraY = py
  self.targetCameraX = px
  self.targetCameraY = py
  
  -- Clamp camera to map bounds on first frame
  self:_clampCameraToMap()
end

function MapScene:update(deltaTime)
  -- Update tree sway animation time
  self._treeSwayTime = self._treeSwayTime + deltaTime
  
  -- Update camera follow
  local cameraSpeed = config.map.cameraFollowSpeed
  local dx = self.targetCameraX - self.cameraX
  local dy = self.targetCameraY - self.cameraY
  self.cameraX = self.cameraX + dx * cameraSpeed * deltaTime
  self.cameraY = self.cameraY + dy * cameraSpeed * deltaTime
  
  -- Update player movement animation
  if self.isMoving and self.playerTargetX and self.playerTargetY then
    -- Track movement time for bobbing animation
    self._movementTime = self._movementTime + deltaTime
    
    local moveSpeed = config.map.playerMoveSpeed
    local totalDistance = math.sqrt(
      (self.playerTargetX - self.playerWorldX) ^ 2 +
      (self.playerTargetY - self.playerWorldY) ^ 2
    )
    
    if totalDistance > 0 then
      local moveDistance = moveSpeed * deltaTime
      local progress = moveDistance / totalDistance
      
      if progress >= 1 then
        -- Movement complete
        self.playerWorldX = self.playerTargetX
        self.playerWorldY = self.playerTargetY
        self.playerTargetX = nil
        self.playerTargetY = nil
        self.isMoving = false
        self._movementTime = 0 -- Reset movement time
        
        -- Check what we reached (enemy, protected treasure, or regular treasure)
        local battleTriggered, battleType, treasureX, treasureY = self.mapManager:completeMovement()
        if battleTriggered then
          -- Save return position to the tile where movement started
          self._returnGridX = self.mapManager.previousGridX or self.mapManager.playerGridX
          self._returnGridY = self.mapManager.previousGridY or self.mapManager.playerGridY
          -- Store enemy tile position (where player is now, which is the enemy tile)
          self._enemyTileX = self.mapManager.playerGridX
          self._enemyTileY = self.mapManager.playerGridY
          -- If this was a protected treasure, store the treasure position
          if battleType == "protected_treasure" and treasureX and treasureY then
            self._treasureTileX = treasureX
            self._treasureTileY = treasureY
          end
          self._battleTransitionDelay = 0 -- No delay, transition immediately
        elseif battleType == "treasure_collected" then
          -- Treasure was collected, update player visual position
          local px, py = self.mapManager:getPlayerWorldPosition(self.gridSize, self.offsetX, self.offsetY)
          self.playerWorldX = px
          self.playerWorldY = py
        elseif battleType == "event_collected" then
          -- Event was collected, update player visual position
          local px, py = self.mapManager:getPlayerWorldPosition(self.gridSize, self.offsetX, self.offsetY)
          self.playerWorldX = px
          self.playerWorldY = py
        end
      else
        -- Interpolate position
        local oldX = self.playerWorldX
        self.playerWorldX = self.playerWorldX + (self.playerTargetX - self.playerWorldX) * progress
        self.playerWorldY = self.playerWorldY + (self.playerTargetY - self.playerWorldY) * progress
        
        -- Update facing direction based on horizontal movement
        if self.playerTargetX > oldX then
          self.playerFacingRight = true
        elseif self.playerTargetX < oldX then
          self.playerFacingRight = false
        end
      end
    end
  end
  
  -- Update camera target to follow player
  self.targetCameraX = self.playerWorldX
  self.targetCameraY = self.playerWorldY
  
  -- Clamp target to map bounds so we never see beyond edges
  self:_clampCameraToMap(true)
  
  -- After moving, also clamp actual camera (covers small numerical drift)
  self:_clampCameraToMap(false)
  
  -- Handle battle transition delay
  if self._battleTransitionDelay ~= nil then
  if self._battleTransitionDelay > 0 then
    self._battleTransitionDelay = self._battleTransitionDelay - deltaTime
    if self._battleTransitionDelay <= 0 then
      -- Transition to battle
        self._battleTransitionDelay = nil
        return "enter_battle"
      end
    else
      -- No delay (0), transition immediately
      self._battleTransitionDelay = nil
      return "enter_battle"
    end
  end

  -- Handle hold-to-move repeat for WASD
  if self._heldMoveKey then
    -- Accumulate timers regardless of moving, so repeats can chain smoothly
    self._holdElapsed = (self._holdElapsed or 0) + deltaTime
    self._repeatElapsed = (self._repeatElapsed or 0) + deltaTime
    local repeatCfg = (config.map and config.map.movementRepeat) or { initialDelay = 0.35, interval = 0.12 }
    local canConsiderMove = (self._battleTransitionDelay == nil)
    if canConsiderMove and not self.isMoving and self.daySystem:canMove() then
      if not self._hasFiredInitialRepeat then
        if self._holdElapsed >= repeatCfg.initialDelay then
          local moved = self:_attemptMoveBy(self._heldDirX, self._heldDirY)
          self._hasFiredInitialRepeat = true
          self._repeatElapsed = 0
          if not moved then
            -- If blocked, wait for next interval before trying again
            self._repeatElapsed = 0
          end
        end
      else
        if self._repeatElapsed >= repeatCfg.interval then
          local moved = self:_attemptMoveBy(self._heldDirX, self._heldDirY)
          self._repeatElapsed = 0
          if not moved then
            -- If blocked, still throttle attempts by interval
            self._repeatElapsed = 0
          end
        end
      end
    end
  end

  -- Update End Day button fade-in (shows only when out of moves)
  do
    local target = self.daySystem and (self.daySystem:canMove() and 0 or 1) or 0
    local speed = 6 -- fade speed
    if target > self._endDayFadeAlpha then
      self._endDayFadeAlpha = math.min(1, self._endDayFadeAlpha + deltaTime * speed)
    else
      -- snap back to 0 when moves are available (fade-in only is required)
      self._endDayFadeAlpha = target
      -- Only reset pressed/animation state AFTER animations have finished
      if target == 0 then
        local animating = self._endDayPressed and ((self._endDaySpinTime < self._endDaySpinDuration) or (self._endDayFadeOutTime < self._endDayFadeOutDuration))
        if not animating then
          self._endDayPressed = false
          self._endDaySpinTime = 0
          self._endDaySpinAngle = 0
          self._endDayFadeOutTime = 0
          self._endDayFadeOutAlpha = 1
        end
      end
    end
  end
  
  -- Update End Day button hover scale tween
  local isAnimating = self._endDayPressed and ((self._endDaySpinTime < self._endDaySpinDuration) or (self._endDayFadeOutTime < self._endDayFadeOutDuration))
  if (not self.daySystem:canMove()) or isAnimating then
    if isAnimating then
      -- Disable hover interaction during animation to avoid visual conflicts
      self._endDayHovered = false
      self._endDayHoverScale = 1
    else
    -- Compute button rect for hover detection (same logic as drawUI)
    local vw = config.video.virtualWidth
    local vh = config.video.virtualHeight
    local btnH = 42
    local gap = 12
    
    local font = theme.fonts.base or love.graphics.getFont()
    local textW = font:getWidth("END DAY")
    local contentH = btnH - 16
    
    local leftIconW = 0
    if self.endDayIcon then
      local iw, ih = self.endDayIcon:getDimensions()
      local baseScale = (contentH * 1.69) / math.max(iw, ih)
      leftIconW = iw * baseScale
    end
    
    local keyIconW = 0
    if self.keySpaceIcon then
      local iw, ih = self.keySpaceIcon:getDimensions()
      local keyScale = contentH * 0.68 / math.max(iw, ih)
      keyIconW = iw * keyScale
    end
    
    local btnMargin = 32 -- Match tooltip padding from battle scene
    local gap = 9 -- Match reduced gap from drawUI
    -- Calculate content width and reduce by 20%
    local contentWidth = leftIconW + (self.endDayIcon and gap or 0) + textW + (self.keySpaceIcon and (gap + keyIconW) or 0)
    local btnW = math.floor(btnMargin + contentWidth * 0.8 + btnMargin + 0.5) -- Reduce content width by 20%
    local btnX = btnMargin
    local btnY = vh - btnH - btnMargin
    
    local hovered = self._mouseX >= btnX and self._mouseX <= btnX + btnW and 
                    self._mouseY >= btnY and self._mouseY <= btnY + btnH
    self._endDayHovered = hovered -- track hover state for text/key alpha
    local targetScale = hovered and 1.5 or 1 -- 50% larger on hover
    local tweenSpeed = 12 -- tween speed
    local diff = targetScale - self._endDayHoverScale
    self._endDayHoverScale = self._endDayHoverScale + diff * math.min(1, tweenSpeed * deltaTime)
    end
  else
    self._endDayHoverScale = 1 -- reset when button not visible
    self._endDayHovered = false
  end
  
  -- Update spin animation after button press
  if self._endDayPressed and self._endDaySpinTime < self._endDaySpinDuration then
    self._endDaySpinTime = self._endDaySpinTime + deltaTime
    local progress = math.min(1, self._endDaySpinTime / self._endDaySpinDuration)
    -- Ease out cubic for smooth spin
    local eased = 1 - math.pow(1 - progress, 3)
    self._endDaySpinAngle = eased * math.pi -- 180 degrees
  end
  
  -- Update fade out animation after spin completes
  if self._endDayPressed and self._endDaySpinTime >= self._endDaySpinDuration then
    if self._endDayFadeOutTime < self._endDayFadeOutDuration then
      self._endDayFadeOutTime = self._endDayFadeOutTime + deltaTime
      local progress = math.min(1, self._endDayFadeOutTime / self._endDayFadeOutDuration)
      self._endDayFadeOutAlpha = 1 - progress -- fade from 1 to 0
    end
  end
  
  return nil
end

-- Keep camera inside the map so edges are never visible.
-- If clampTarget is true, clamp targetCameraX/Y; otherwise clamp current cameraX/Y.
function MapScene:_clampCameraToMap(clampTarget)
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  local mapWidth = self.mapManager.gridWidth * self.gridSize
  local mapHeight = self.mapManager.gridHeight * self.gridSize
  
  -- If viewport is larger than map, fix camera at map center along that axis
  local mapCenterX = self.offsetX + mapWidth * 0.5
  local mapCenterY = self.offsetY + mapHeight * 0.5
  
  local minCamX = self.offsetX + math.min(vw * 0.5, mapWidth * 0.5)
  local maxCamX = self.offsetX + mapWidth - math.min(vw * 0.5, mapWidth * 0.5)
  local minCamY = self.offsetY + math.min(vh * 0.5, mapHeight * 0.5)
  local maxCamY = self.offsetY + mapHeight - math.min(vh * 0.5, mapHeight * 0.5)
  
  if clampTarget then
    if vw >= mapWidth then
      self.targetCameraX = mapCenterX
    else
      self.targetCameraX = math.max(minCamX, math.min(maxCamX, self.targetCameraX))
    end
    if vh >= mapHeight then
      self.targetCameraY = mapCenterY
    else
      self.targetCameraY = math.max(minCamY, math.min(maxCamY, self.targetCameraY))
    end
  else
    if vw >= mapWidth then
      self.cameraX = mapCenterX
    else
      self.cameraX = math.max(minCamX, math.min(maxCamX, self.cameraX))
    end
    if vh >= mapHeight then
      self.cameraY = mapCenterY
    else
      self.cameraY = math.max(minCamY, math.min(maxCamY, self.cameraY))
    end
  end
end

function MapScene:draw()
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  
  -- Clear background using theme color
  love.graphics.clear(theme.colors.background)
  
  -- Apply camera transform
  love.graphics.push()
  love.graphics.translate(-self.cameraX + vw * 0.5, -self.cameraY + vh * 0.5)
  
  -- Draw player glow beneath all map objects (z-order below tiles/obstacles)
  do
    local px, py = self.playerWorldX, self.playerWorldY
    if self.playerGlow and px and py then
      local gw, gh = self.playerGlow:getDimensions()
      local glowTiles = (config.map and config.map.playerGlow and config.map.playerGlow.tileScale) or 11.2
      local glowSize = self.gridSize * glowTiles
      local glowScale = glowSize / math.max(gw, gh)
      love.graphics.setColor(1, 1, 1, 0.9)
      love.graphics.draw(self.playerGlow, px, py, 0, glowScale, glowScale, gw * 0.5, gh * 0.5)
    end
  end
  
  -- Draw grid tiles with depth sorting
  local gridSize = self.gridSize
  local sprites = self.mapManager.sprites
  local oversize = 1.3 -- 25% larger than tile
  
  -- Calculate visible tile range (with padding for smooth scrolling)
  local padding = gridSize * 2
  local minTileX = math.max(1, math.floor((self.cameraX - vw * 0.5 - padding - self.offsetX) / gridSize) + 1)
  local maxTileX = math.min(self.mapManager.gridWidth, math.ceil((self.cameraX + vw * 0.5 + padding - self.offsetX) / gridSize) + 1)
  local minTileY = math.max(1, math.floor((self.cameraY - vh * 0.5 - padding - self.offsetY) / gridSize) + 1)
  local maxTileY = math.min(self.mapManager.gridHeight, math.ceil((self.cameraY + vh * 0.5 + padding - self.offsetY) / gridSize) + 1)
  
  -- Collect all drawable objects for depth sorting
  local drawQueue = {}
  local px, py = self.playerWorldX, self.playerWorldY
  
  -- Collect rest site positions for lighting calculation
  local restSites = {}
  for y = minTileY, maxTileY do
    for x = minTileX, maxTileX do
      local tile = self.mapManager:getTile(x, y)
      if tile and tile.type == MapManager.TileType.REST then
        local worldX = self.offsetX + (x - 1) * gridSize
        local worldY = self.offsetY + (y - 1) * gridSize
        table.insert(restSites, {x = worldX, y = worldY})
      end
    end
  end
  
  -- Calculate distance-based alpha for fog effect with rest site lighting
  local fogConfig = config.map.distanceFog
  local lightingConfig = config.map.restLighting
  local function calculateAlpha(worldX, worldY)
    local baseAlpha = 1.0
    
    -- Apply fog effect
    if fogConfig.enabled then
      local dx = worldX - px
      local dy = worldY - py
      local distance = math.sqrt(dx * dx + dy * dy)
      
      if distance <= fogConfig.fadeStartRadius then
        baseAlpha = 1.0 -- Fully visible within start radius
      elseif distance >= fogConfig.fadeEndRadius then
        baseAlpha = fogConfig.minAlpha -- Minimum alpha at max distance
      else
        -- Linear interpolation between fadeStartRadius and fadeEndRadius
        local fadeRange = fogConfig.fadeEndRadius - fogConfig.fadeStartRadius
        local fadeProgress = (distance - fogConfig.fadeStartRadius) / fadeRange
        baseAlpha = 1.0 - fadeProgress * (1.0 - fogConfig.minAlpha)
      end
    end
    
    -- Apply rest site lighting boost
    if lightingConfig.enabled then
      local maxLightBoost = 0
      for _, restSite in ipairs(restSites) do
        local dx = worldX - restSite.x
        local dy = worldY - restSite.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance <= lightingConfig.glowRadius then
          -- Calculate light intensity based on distance (fade from center)
          local lightStrength = 1.0 - (distance / lightingConfig.glowRadius)
          local lightBoost = lightStrength * lightingConfig.lightIntensity
          maxLightBoost = math.max(maxLightBoost, lightBoost)
        end
      end
      -- Add lighting boost to alpha (clamp to 1.0)
      baseAlpha = math.min(1.0, baseAlpha + maxLightBoost)
    end
    
    return baseAlpha
  end
  
  -- Helper function to add drawable objects to queue with fog support
  local function addToQueue(worldY, worldX, drawFunc, isPlayer)
    local alpha = isPlayer and 1.0 or calculateAlpha(worldX, worldY)
    table.insert(drawQueue, { 
      y = worldY, 
      draw = function()
        -- Store original setColor function
        local originalSetColor = love.graphics.setColor
        -- Override setColor to multiply alpha
        love.graphics.setColor = function(r, g, b, a)
          a = a or 1.0
          originalSetColor(r, g, b, a * alpha)
        end
        -- Call drawFunc with modified setColor
        drawFunc()
        -- Restore original setColor
        love.graphics.setColor = originalSetColor
      end
    })
  end
  
  -- Collect tile objects
  for y = minTileY, maxTileY do
    for x = minTileX, maxTileX do
      local tile = self.mapManager:getTile(x, y)
      if tile then
        local worldX = self.offsetX + (x - 1) * gridSize
        local worldY = self.offsetY + (y - 1) * gridSize
        
        -- Draw base ground and entities for traversable tiles
        if tile.type == MapManager.TileType.GROUND or tile.type == MapManager.TileType.ENEMY or tile.type == MapManager.TileType.REST or tile.type == MapManager.TileType.TREASURE or tile.type == MapManager.TileType.EVENT then
          -- Draw ground sprite decoration if present (sparingly placed)
          if tile.spriteVariant then
            local sprite = sprites.ground[tile.spriteVariant]
            if sprite then
              addToQueue(worldY, worldX, function()
              love.graphics.setColor(1, 1, 1, 1)
              local sx = (gridSize * oversize) / sprite:getWidth()
              local sy = (gridSize * oversize) / sprite:getHeight()
              local ox = (gridSize * (oversize - 1)) * 0.5
              local oy = (gridSize * (oversize - 1)) * 0.5
              love.graphics.draw(sprite, worldX - ox, worldY - oy, 0, sx, sy)
              end, false)
            end
          end
          
          -- Draw enemy sprite if this is an enemy tile
          if tile.type == MapManager.TileType.ENEMY then
            local sprite = sprites.enemy
            if sprite then
              addToQueue(worldY, worldX, function()
              love.graphics.setColor(1, 1, 1, 1)
                local baseSx = (gridSize * oversize) / sprite:getWidth()
                local baseSy = (gridSize * oversize) / sprite:getHeight()
                
                -- Calculate bobbing animation for this enemy
                local bobConfig = config.map.enemyBob
                local phaseOffset = (x + y * 100) * bobConfig.phaseVariation
                local heightScale = 1 + math.sin(self._treeSwayTime * bobConfig.speed * 2 * math.pi + phaseOffset) * bobConfig.heightVariation
                
                local sx = baseSx
                local sy = baseSy * heightScale
              local ox = (gridSize * (oversize - 1)) * 0.5
              local oy = (gridSize * (oversize - 1)) * 0.5
                
                local spriteW, spriteH = sprite:getDimensions()
                local pivotX = spriteW * 0.5
                local pivotY = spriteH
                local pivotWorldX = worldX - ox + spriteW * 0.5 * baseSx
                local pivotWorldY = worldY - oy + spriteH * baseSy
                love.graphics.draw(sprite, pivotWorldX, pivotWorldY, 0, sx, sy, pivotX, pivotY)
              end, false)
            end
          elseif tile.type == MapManager.TileType.REST then
            local sprite = sprites.rest
            if sprite then
              -- Calculate rest sprite center position for alignment
              local baseSx = (gridSize * oversize) / sprite:getWidth()
              local baseSy = (gridSize * oversize) / sprite:getHeight()
              local ox = (gridSize * (oversize - 1)) * 0.5
              local oy = (gridSize * (oversize - 1)) * 0.5
              local spriteW, spriteH = sprite:getDimensions()
              local pivotX = spriteW * 0.5
              local pivotY = spriteH
              -- Center position aligns with rest sprite's bottom center pivot
              local centerWorldX = worldX - ox + spriteW * 0.5 * baseSx
              local centerWorldY = worldY - oy + spriteH * baseSy
              
              -- Calculate vertical center of rest sprite (centered with the sprite's visual center)
              local spriteCenterY = worldY + gridSize * 0.5 -- Center of tile vertically
              
              -- Draw orange glow beneath rest site (drawn after ground tiles, but before other objects)
              if self.restGlow then
                local lightingConfig = config.map.restLighting
                local phaseOffset = (x + y * 100) * 0.5 -- unique phase per rest site
                local pulsateTime = self._treeSwayTime * lightingConfig.pulsateSpeed * 2 * math.pi + phaseOffset
                
                -- Pulsation: size and alpha vary with sine wave
                local sizeMultiplier = 1.0 + math.sin(pulsateTime) * lightingConfig.pulsateSizeVariation
                local baseAlpha = 0.4 -- reduced opacity for subtler glow
                local alphaVariation = math.sin(pulsateTime * 0.7) * lightingConfig.pulsateAlphaVariation -- slightly different frequency for more organic feel
                local glowAlpha = math.max(0.2, math.min(0.6, baseAlpha + alphaVariation)) -- adjusted min/max to match reduced base
                
                -- Draw glow after ground tiles but before trees and rest sprite
                -- Use worldY - 0.01 to ensure it draws after ground (same Y, added later) but before trees/rest (same Y, added later)
                -- Trees and rest sprite are at worldY, so glow needs to be slightly lower to draw before them
                addToQueue(worldY - 0.01, centerWorldX, function()
                  -- Set additive blend mode for glow effect
                  local prevBlendMode = love.graphics.getBlendMode()
                  love.graphics.setBlendMode("add")
                  love.graphics.setColor(1, 1, 1, glowAlpha)
                  local baseGlowSize = lightingConfig.glowRadius * 2
                  local glowSize = baseGlowSize * sizeMultiplier
                  local glowW, glowH = self.restGlow:getDimensions()
                  local glowScale = glowSize / math.max(glowW, glowH)
                  -- Draw at sprite center vertically (centered with rest sprite)
                  love.graphics.draw(self.restGlow, centerWorldX, spriteCenterY, 0, glowScale, glowScale, glowW * 0.5, glowH * 0.5)
                  -- Restore previous blend mode
                  love.graphics.setBlendMode(prevBlendMode)
                end, false)
              end
              
              -- Draw rest site sprite
              addToQueue(worldY, worldX, function()
                love.graphics.setColor(1, 1, 1, 1)
                
                local bobConfig = config.map.restBob
                local phaseOffset = (x + y * 100) * bobConfig.phaseVariation
                local time = self._treeSwayTime * bobConfig.speed * 2 * math.pi + phaseOffset
                local heightScale = 1 + math.sin(time) * bobConfig.heightVariation
                local skewX = math.sin(time) * bobConfig.maxShear
                
                local sx = baseSx
                local sy = baseSy * heightScale
                
                love.graphics.push()
                love.graphics.translate(centerWorldX, centerWorldY)
                love.graphics.shear(skewX, 0)
                love.graphics.translate(-pivotX * sx, -pivotY * sy)
                love.graphics.draw(sprite, 0, 0, 0, sx, sy)
                love.graphics.pop()
              end, false)
            end
          elseif tile.type == MapManager.TileType.TREASURE then
            local sprite = sprites.treasure
            if sprite then
              addToQueue(worldY, worldX, function()
                love.graphics.setColor(1, 1, 1, 1)
                local baseSx = (gridSize * oversize) / sprite:getWidth()
                local baseSy = (gridSize * oversize) / sprite:getHeight()
                
                -- Calculate bobbing animation for treasure (similar to rest sites)
                local bobConfig = config.map.restBob
                local phaseOffset = (x + y * 100) * bobConfig.phaseVariation
                local time = self._treeSwayTime * bobConfig.speed * 2 * math.pi + phaseOffset
                local heightScale = 1 + math.sin(time) * bobConfig.heightVariation
                
                local sx = baseSx
                local sy = baseSy * heightScale
                local ox = (gridSize * (oversize - 1)) * 0.5
                local oy = (gridSize * (oversize - 1)) * 0.5
                
                local spriteW, spriteH = sprite:getDimensions()
                local pivotX = spriteW * 0.5
                local pivotY = spriteH
                local centerWorldX = worldX - ox + spriteW * 0.5 * baseSx
                local centerWorldY = worldY - oy + spriteH * baseSy
                
                love.graphics.push()
                love.graphics.translate(centerWorldX, centerWorldY)
                love.graphics.translate(-pivotX * sx, -pivotY * sy)
                love.graphics.draw(sprite, 0, 0, 0, sx, sy)
                love.graphics.pop()
              end, false)
            end
          elseif tile.type == MapManager.TileType.EVENT then
            local sprite = sprites.event
            if sprite then
              addToQueue(worldY, worldX, function()
                love.graphics.setColor(1, 1, 1, 1)
                local baseSx = (gridSize * oversize) / sprite:getWidth()
                local baseSy = (gridSize * oversize) / sprite:getHeight()
                
                -- Calculate bobbing animation for event (slower than rest sites)
                local bobConfig = config.map.restBob
                local phaseOffset = (x + y * 100) * bobConfig.phaseVariation
                local eventSpeed = bobConfig.speed * 0.7 -- 30% slower than rest sites
                local time = self._treeSwayTime * eventSpeed * 2 * math.pi + phaseOffset
                local heightScale = 1 + math.sin(time) * bobConfig.heightVariation
                local skewX = math.sin(time) * bobConfig.maxShear
                
                local sx = baseSx
                local sy = baseSy * heightScale
                local ox = (gridSize * (oversize - 1)) * 0.5
                local oy = (gridSize * (oversize - 1)) * 0.5
                
                local spriteW, spriteH = sprite:getDimensions()
                local pivotX = spriteW * 0.5
                local pivotY = spriteH
                local centerWorldX = worldX - ox + spriteW * 0.5 * baseSx
                local centerWorldY = worldY - oy + spriteH * baseSy
                
                love.graphics.push()
                love.graphics.translate(centerWorldX, centerWorldY)
                love.graphics.shear(skewX, 0)
                love.graphics.translate(-pivotX * sx, -pivotY * sy)
                love.graphics.draw(sprite, 0, 0, 0, sx, sy)
                love.graphics.pop()
              end, false)
            end
          end
        end
        
        -- Draw obstacle tiles (stones/trees that block movement)
        if tile.type == MapManager.TileType.STONE then
          local sprite = sprites.stone[tile.decorationVariant or 1]
          if sprite then
            addToQueue(worldY, worldX, function()
            love.graphics.setColor(1, 1, 1, 1)
            local sx = (gridSize * oversize) / sprite:getWidth()
            local sy = (gridSize * oversize) / sprite:getHeight()
            local ox = (gridSize * (oversize - 1)) * 0.5
            local oy = (gridSize * (oversize - 1)) * 0.5
            love.graphics.draw(sprite, worldX - ox, worldY - oy, 0, sx, sy)
            end, false)
          else
            addToQueue(worldY, worldX, function()
            love.graphics.setColor(0.3, 0.3, 0.3, 1)
            love.graphics.rectangle("fill", worldX, worldY, gridSize, gridSize)
            end, false)
          end
        elseif tile.type == MapManager.TileType.TREE then
          local sprite = sprites.tree[tile.decorationVariant or 1]
          if sprite then
            addToQueue(worldY, worldX, function()
            love.graphics.setColor(1, 1, 1, 1)
            local sx = (gridSize * oversize) / sprite:getWidth()
            local sy = (gridSize * oversize) / sprite:getHeight()
            local ox = (gridSize * (oversize - 1)) * 0.5
            local oy = (gridSize * (oversize - 1)) * 0.5
              
              local swayConfig = config.map.treeSway
              local phaseOffset = (x + y * 100) * swayConfig.phaseVariation
              local time = self._treeSwayTime * swayConfig.speed * 2 * math.pi + phaseOffset
              local swayAngle = math.sin(time) * swayConfig.maxAngle
              local skewX = math.sin(time) * swayConfig.maxShear
              
              local spriteW, spriteH = sprite:getDimensions()
              local pivotX = spriteW * 0.5
              local pivotY = spriteH
              
              love.graphics.push()
              love.graphics.translate(worldX - ox + pivotX * sx, worldY - oy + pivotY * sy)
              love.graphics.shear(skewX, 0)
              love.graphics.rotate(swayAngle)
              love.graphics.translate(-pivotX * sx, -pivotY * sy)
              love.graphics.draw(sprite, 0, 0, 0, sx, sy)
              love.graphics.pop()
            end, false)
          else
            addToQueue(worldY, worldX, function()
            love.graphics.setColor(0.2, 0.4, 0.2, 1)
            love.graphics.rectangle("fill", worldX, worldY, gridSize, gridSize)
            end, false)
          end
        end
      end
    end
  end
  
  -- Add player to draw queue (always fully visible, no fog)
  addToQueue(py, px, function()
  if self.playerSprite then
      local spriteSize = self.gridSize * 0.8 * 1.5
    local spriteW, spriteH = self.playerSprite:getDimensions()
    local scale = spriteSize / math.max(spriteW, spriteH)
    
    -- Calculate bobbing offset during movement
    local bobOffset = 0
    if self.isMoving then
      local bobConfig = config.map.playerBob
      bobOffset = -math.sin(self._movementTime * bobConfig.speed * 2 * math.pi) * bobConfig.amplitude
    end
    
    -- Apply vertical offset to lower player on tile
    local verticalOffset = config.map.playerVerticalOffset or 0
    
    love.graphics.setColor(1, 1, 1, 1)
      local scaleX = self.playerFacingRight and scale or -scale
      -- Draw with bottom pivot: pivotX = spriteW * 0.5 (center horizontally), pivotY = spriteH (bottom)
      love.graphics.draw(self.playerSprite, px, py + verticalOffset + bobOffset, 0, scaleX, scale, spriteW * 0.5, spriteH)
  else
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", px, py, 12)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.circle("line", px, py, 12)
    end
  end, true)
  
  -- Sort draw queue by y position (lower y = drawn first, higher y = drawn last/on top)
  table.sort(drawQueue, function(a, b) return a.y < b.y end)
  
  -- Draw all objects in sorted order
  for _, item in ipairs(drawQueue) do
    item.draw()
  end
  
  love.graphics.pop()
  
  -- Draw UI overlay
  self:drawUI()
  
  -- Draw top bar on top (z-order)
  if self.topBar then
    self.topBar:draw()
  end
end

function MapScene:drawUI()
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  
  -- Day and steps are now rendered by the TopBar
  
  -- End Day button (bottom-left) when no moves remain OR while animating after press
  self.endDayBtnRect = nil
  local isAnimating = self._endDayPressed and ((self._endDaySpinTime < self._endDaySpinDuration) or (self._endDayFadeOutTime < self._endDayFadeOutDuration))
  if (not self.daySystem:canMove()) or isAnimating then
    local paddingX = 20
    local paddingY = 16
    local btnH = 42 -- reduced by 20% (52 * 0.8)
    local cornerR = 6 -- reduced corner radius
    local gap = 9 -- reduced by 25% to decrease button width by ~20%

    -- Text using theme font
    local label = "END DAY"
    local font = theme.fonts.base or love.graphics.getFont()
    love.graphics.setFont(font)
    local textW = font:getWidth(label)
    local textH = font:getHeight()

    -- Icon sizes (fit inside button height with vertical padding)
    local contentH = btnH - 16
    local leftIconW, leftIconH = 0, 0
    local keyIconW, keyIconH = 0, 0
    local leftScale, keyScale = 1, 1

    local baseLeftScale = 1
    if self.endDayIcon then
      local iw, ih = self.endDayIcon:getDimensions()
      -- Base size increased by 30% (1.3 * 1.3 = 1.69)
      baseLeftScale = (contentH * 1.69) / math.max(iw, ih) -- +69% total (30% on top of existing 30%)
      -- Apply hover scale for visual effect only (not for layout)
      leftScale = baseLeftScale * (self._endDayHoverScale or 1)
      -- Use base scale for width calculation to prevent button from growing
      leftIconW = iw * baseLeftScale
      leftIconH = ih * baseLeftScale
    end
    if self.keySpaceIcon then
      local iw, ih = self.keySpaceIcon:getDimensions()
      keyScale = contentH * 0.68 / math.max(iw, ih)
      keyIconW = iw * keyScale
      keyIconH = ih * keyScale
    end

    local btnMargin = 32 -- Match tooltip padding from battle scene
    local btnInternalPad = 12 -- Reduced internal padding to decrease button width
    -- Calculate content width and reduce by 20%
    local contentWidth = leftIconW + (self.endDayIcon and gap or 0) + textW + (self.keySpaceIcon and (gap + keyIconW) or 0)
    local btnW = math.floor(btnMargin + contentWidth * 0.8 + btnMargin + 0.5) -- Reduce content width by 20%
    local btnX = btnMargin
    local btnY = vh - btnH - btnMargin

    -- During animation, show at full base alpha (ignore fade-in), then apply fade-out
    local baseAlpha = isAnimating and 1.0 or (self._endDayFadeAlpha or 1)
    local a = baseAlpha * (self._endDayFadeOutAlpha or 1) -- Apply fade out
    -- Background
    love.graphics.setColor(0.06, 0.07, 0.10, 0.92 * a)
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, cornerR, cornerR)
    -- Subtle border
    love.graphics.setColor(1, 1, 1, 0.06 * a)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH, cornerR, cornerR)

    -- Layout content
    local cx = btnX + btnInternalPad
    local cy = btnY + btnH * 0.5

    if self.endDayIcon then
      love.graphics.setColor(1, 1, 1, 0.95 * a)
      local iconW, iconH = self.endDayIcon:getDimensions()
      -- Shift icon to the right by 10px
      local iconX = cx + 20
      -- Apply spin rotation and scale from center pivot
      love.graphics.push()
      love.graphics.translate(iconX, cy)
      love.graphics.rotate(self._endDaySpinAngle or 0)
      love.graphics.draw(self.endDayIcon, 0, 0, 0, leftScale, leftScale, iconW * 0.5, iconH * 0.5)
      love.graphics.pop()
      -- Use base scale for spacing calculation to prevent layout jump
      cx = cx + (iconW * baseLeftScale) + gap
    end

    -- Label - use hover alpha (0.7 normally, 1.0 on hover)
    local textAlpha = (self._endDayHovered and 1.0 or 0.7) * a
    love.graphics.setColor(1, 1, 1, textAlpha)
    local textY = cy - textH * 0.5
    love.graphics.print(label, cx, textY)
    cx = cx + textW

    if self.keySpaceIcon then
      cx = cx + gap
      -- Use hover alpha (0.7 normally, 1.0 on hover)
      local keyAlpha = (self._endDayHovered and 1.0 or 0.7) * a
      love.graphics.setColor(1, 1, 1, keyAlpha)
      love.graphics.draw(self.keySpaceIcon, cx, cy, 0, keyScale, keyScale, 0, (self.keySpaceIcon:getHeight() * 0.5))
    end

    -- Save button rect for clicks
    self.endDayBtnRect = { x = btnX, y = btnY, w = btnW, h = btnH }
  end
  
  -- Hover tooltip removed
end

function MapScene:mousepressed(x, y, button)
  if button ~= 1 then return end

  -- Handle End Day button click when out of moves
  if not self.daySystem:canMove() then
    if self.endDayBtnRect then
      local r = self.endDayBtnRect
      if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
        -- Start spin and fade out animations
        self._endDayPressed = true
        self._endDaySpinTime = 0
        self._endDayFadeOutTime = 0
        self._endDayFadeOutAlpha = 1
        -- Advance day immediately (animations will play while transitioning)
        self.daySystem:advanceDay()
        return
      end
    end
    -- When out of moves and not clicking the button, ignore map movement
    return
  end

  if self.isMoving then return end
  
  -- Convert screen coordinates to world coordinates
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  local worldX = x + self.cameraX - vw * 0.5
  local worldY = y + self.cameraY - vh * 0.5
  
  -- Convert to grid coordinates
  local gridX, gridY = self.mapManager:worldToGrid(worldX, worldY, self.gridSize, self.offsetX, self.offsetY)
  
  -- Try to move to this tile
  if self.mapManager:canMoveTo(gridX, gridY) then
    if self.daySystem:useMove() then
      local targetWorldX, targetWorldY = self.mapManager:gridToWorld(
        gridX, 
        gridY, 
        self.gridSize, 
        self.offsetX, 
        self.offsetY
      )
      self.playerTargetX = targetWorldX
      self.playerTargetY = targetWorldY
      self.isMoving = true
      self._movementTime = 0 -- Reset movement time for new movement
      -- Update facing direction based on movement direction
      if targetWorldX > self.playerWorldX then
        self.playerFacingRight = true
      elseif targetWorldX < self.playerWorldX then
        self.playerFacingRight = false
      end
      self.mapManager:movePlayerTo(gridX, gridY)
    end
  end
end

function MapScene:mousemoved(x, y, dx, dy)
  -- Store mouse position for UI hover detection
  self._mouseX = x
  self._mouseY = y
  
  -- Convert screen coordinates to world coordinates
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  local worldX = x + self.cameraX - vw * 0.5
  local worldY = y + self.cameraY - vh * 0.5
  
  -- Convert to grid coordinates
  local gridX, gridY = self.mapManager:worldToGrid(worldX, worldY, self.gridSize, self.offsetX, self.offsetY)
  
  -- Update selected tile
  if self.mapManager:isValidGrid(gridX, gridY) then
    self.selectedGridX = gridX
    self.selectedGridY = gridY
  else
    self.selectedGridX = nil
    self.selectedGridY = nil
  end
end

-- Map WASD key to a direction vector (dx, dy). Returns nil if not a WASD key.
function MapScene:_dirFromKey(key)
  if key == "w" then return 0, -1 end
  if key == "s" then return 0, 1 end
  if key == "a" then return -1, 0 end
  if key == "d" then return 1, 0 end
  return nil
end

-- Start tracking a held move key (WASD)
function MapScene:_setHeldMove(key)
  local dx, dy = self:_dirFromKey(key)
  if dx then
    self._heldMoveKey = key
    self._heldDirX, self._heldDirY = dx, dy
    self._holdElapsed = 0
    self._repeatElapsed = 0
    self._hasFiredInitialRepeat = false
  end
end

-- Clear held move state if releasing the active key
function MapScene:keyreleased(key)
  if self._heldMoveKey and key == self._heldMoveKey then
    self._heldMoveKey = nil
    self._heldDirX, self._heldDirY = 0, 0
    self._holdElapsed = 0
    self._repeatElapsed = 0
    self._hasFiredInitialRepeat = false
  end
end

-- Attempt to move by a grid offset if possible and allowed
function MapScene:_attemptMoveBy(dx, dy)
  if self.isMoving then return false end
  if not self.daySystem:canMove() then return false end
  local currentGridX = self.mapManager.playerGridX
  local currentGridY = self.mapManager.playerGridY
  if currentGridX == 0 or currentGridY == 0 then return false end
  local targetGridX = currentGridX + dx
  local targetGridY = currentGridY + dy
  if not self.mapManager:canMoveTo(targetGridX, targetGridY) then return false end
  if not self.daySystem:useMove() then return false end
  local targetWorldX, targetWorldY = self.mapManager:gridToWorld(
    targetGridX,
    targetGridY,
    self.gridSize,
    self.offsetX,
    self.offsetY
  )
  self.playerTargetX = targetWorldX
  self.playerTargetY = targetWorldY
  self.isMoving = true
  self._movementTime = 0
  if targetWorldX > self.playerWorldX then
    self.playerFacingRight = true
  elseif targetWorldX < self.playerWorldX then
    self.playerFacingRight = false
  end
  self.mapManager:movePlayerTo(targetGridX, targetGridY)
  return true
end

function MapScene:keypressed(key, scancode, isRepeat)
  -- Advance to next day when out of moves
  if key == "space" and not self.daySystem:canMove() and not self.isMoving then
    -- Start spin and fade out animations
    self._endDayPressed = true
    self._endDaySpinTime = 0
    self._endDayFadeOutTime = 0
    self._endDayFadeOutAlpha = 1
    -- Advance day immediately (animations will play while transitioning)
    self.daySystem:advanceDay()
    return
  end
  
  -- Track hold state for WASD keys, even if currently moving
  if not isRepeat then
    self:_setHeldMove(key)
  end

  -- WASD movement (only if not already moving and have moves remaining)
  if self.isMoving or not self.daySystem:canMove() then
    return
  end
  
  local currentGridX = self.mapManager.playerGridX
  local currentGridY = self.mapManager.playerGridY
  
  if currentGridX == 0 or currentGridY == 0 then
    return
  end
  
  local targetGridX, targetGridY = currentGridX, currentGridY
  
  -- Determine target direction based on key
  if key == "w" or key == "up" then
    targetGridY = currentGridY - 1
  elseif key == "s" or key == "down" then
    targetGridY = currentGridY + 1
  elseif key == "a" or key == "left" then
    targetGridX = currentGridX - 1
    self.playerFacingRight = false -- Face left
  elseif key == "d" or key == "right" then
    targetGridX = currentGridX + 1
    self.playerFacingRight = true -- Face right
  else
    return -- Not a movement key
  end
  
  -- Try to move to the target tile
  if self.mapManager:canMoveTo(targetGridX, targetGridY) then
    if self.daySystem:useMove() then
      local targetWorldX, targetWorldY = self.mapManager:gridToWorld(
        targetGridX, 
        targetGridY, 
        self.gridSize, 
        self.offsetX, 
        self.offsetY
      )
      self.playerTargetX = targetWorldX
      self.playerTargetY = targetWorldY
      self.isMoving = true
      self._movementTime = 0 -- Reset movement time for new movement
      -- Update facing direction based on movement direction (for mouse clicks)
      if targetWorldX > self.playerWorldX then
        self.playerFacingRight = true
      elseif targetWorldX < self.playerWorldX then
        self.playerFacingRight = false
      end
      self.mapManager:movePlayerTo(targetGridX, targetGridY)
    end
  end
end

function MapScene:resize(width, height)
  -- Recalculate map offset to center it
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  
  local mapWidth = self.mapManager.gridWidth * self.gridSize
  local mapHeight = self.mapManager.gridHeight * self.gridSize
  self.offsetX = (vw - mapWidth) * 0.5
  self.offsetY = (vh - mapHeight) * 0.5
  
  -- Update player position
  local px, py = self.mapManager:getPlayerWorldPosition(self.gridSize, self.offsetX, self.offsetY)
  self.playerWorldX = px
  self.playerWorldY = py
  
  -- Re-clamp camera after resize
  self:_clampCameraToMap()
end

return MapScene
