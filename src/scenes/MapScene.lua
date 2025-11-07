local theme = require("theme")
local config = require("config")
local MapManager = require("managers.MapManager")
local DaySystem = require("core.DaySystem")
local TopBar = require("ui.TopBar")
local MapController = require("scenes.map.MapController")
local MapRenderer = require("scenes.map.MapRenderer")

local MapScene = {}
MapScene.__index = MapScene

function MapScene.new()
  local scene = setmetatable({
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
  scene.controller = MapController.new(scene)
  scene.renderer = MapRenderer.new()
  return scene
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
    if self.mapManager.calculateRecommendedDailyMoves and self.daySystem then
      local recommendedMoves = self.mapManager:calculateRecommendedDailyMoves(self.daySystem:getTotalDays())
      if recommendedMoves then
        self.daySystem:setMaxMovesPerDay(recommendedMoves)
      end
    end
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
  if self.controller then
    return self.controller:update(deltaTime)
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
  if self.renderer then self.renderer:draw(self) end
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
  if self.controller then self.controller:mousepressed(x, y, button) end
end

function MapScene:mousemoved(x, y, dx, dy)
  if self.controller then self.controller:mousemoved(x, y, dx, dy) end
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
  if self.controller then self.controller:keyreleased(key) end
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
  if self.controller then 
    local result = self.controller:keypressed(key, scancode, isRepeat)
    if result then return result end
  end
end

function MapScene:resize(width, height)
  if self.controller then self.controller:resize(width, height) end
end

return MapScene
