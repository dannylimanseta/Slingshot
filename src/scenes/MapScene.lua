local theme = require("theme")
local config = require("config")
local MapManager = require("managers.MapManager")
local DaySystem = require("core.DaySystem")

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
    _battleTransitionDelay = 0,
    playerSprite = nil,
    _initialized = false,
    _returnGridX = nil,
    _returnGridY = nil,
  }, MapScene)
end

function MapScene:load()
  -- Initialize day system
  self.daySystem:load(config)
  
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
  
  -- If coming back from battle and we saved a return position, restore it
  if self._returnGridX and self._returnGridY then
    self.mapManager.playerGridX = self._returnGridX
    self.mapManager.playerGridY = self._returnGridY
    self.mapManager.playerTargetGridX = nil
    self.mapManager.playerTargetGridY = nil
    self._returnGridX, self._returnGridY = nil, nil
  end
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
  -- Update camera follow
  local cameraSpeed = config.map.cameraFollowSpeed
  local dx = self.targetCameraX - self.cameraX
  local dy = self.targetCameraY - self.cameraY
  self.cameraX = self.cameraX + dx * cameraSpeed * deltaTime
  self.cameraY = self.cameraY + dy * cameraSpeed * deltaTime
  
  -- Update player movement animation
  if self.isMoving and self.playerTargetX and self.playerTargetY then
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
        
        -- Check if we reached an enemy tile (battle)
        if self.mapManager:completeMovement() then
          -- Save return position to the tile where movement started
          self._returnGridX = self.mapManager.previousGridX or self.mapManager.playerGridX
          self._returnGridY = self.mapManager.previousGridY or self.mapManager.playerGridY
          self._battleTransitionDelay = 0.5 -- 0.5 second delay before battle
        end
      else
        -- Interpolate position
        self.playerWorldX = self.playerWorldX + (self.playerTargetX - self.playerWorldX) * progress
        self.playerWorldY = self.playerWorldY + (self.playerTargetY - self.playerWorldY) * progress
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
  if self._battleTransitionDelay > 0 then
    self._battleTransitionDelay = self._battleTransitionDelay - deltaTime
    if self._battleTransitionDelay <= 0 then
      -- Transition to battle
      return "enter_battle"
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
  
  -- Draw grid tiles
  local gridSize = self.gridSize
  local sprites = self.mapManager.sprites
  local oversize = 1.15 -- 15% larger than tile
  
  -- Calculate visible tile range (with padding for smooth scrolling)
  local padding = gridSize * 2
  local minTileX = math.max(1, math.floor((self.cameraX - vw * 0.5 - padding - self.offsetX) / gridSize) + 1)
  local maxTileX = math.min(self.mapManager.gridWidth, math.ceil((self.cameraX + vw * 0.5 + padding - self.offsetX) / gridSize) + 1)
  local minTileY = math.max(1, math.floor((self.cameraY - vh * 0.5 - padding - self.offsetY) / gridSize) + 1)
  local maxTileY = math.min(self.mapManager.gridHeight, math.ceil((self.cameraY + vh * 0.5 + padding - self.offsetY) / gridSize) + 1)
  
  for y = minTileY, maxTileY do
    for x = minTileX, maxTileX do
      local tile = self.mapManager:getTile(x, y)
      if tile then
        local worldX = self.offsetX + (x - 1) * gridSize
        local worldY = self.offsetY + (y - 1) * gridSize
        
        -- Draw base ground and entities for traversable tiles
        if tile.type == MapManager.TileType.GROUND or tile.type == MapManager.TileType.ENEMY or tile.type == MapManager.TileType.REST then
          -- Draw ground sprite decoration if present (sparingly placed)
          if tile.spriteVariant then
            local sprite = sprites.ground[tile.spriteVariant]
            if sprite then
              love.graphics.setColor(1, 1, 1, 1)
              local sx = (gridSize * oversize) / sprite:getWidth()
              local sy = (gridSize * oversize) / sprite:getHeight()
              local ox = (gridSize * (oversize - 1)) * 0.5
              local oy = (gridSize * (oversize - 1)) * 0.5
              love.graphics.draw(sprite, worldX - ox, worldY - oy, 0, sx, sy)
            end
          end
          
          -- Draw enemy sprite if this is an enemy tile
          if tile.type == MapManager.TileType.ENEMY then
            local sprite = sprites.enemy
            if sprite then
              love.graphics.setColor(1, 1, 1, 1)
              local sx = (gridSize * oversize) / sprite:getWidth()
              local sy = (gridSize * oversize) / sprite:getHeight()
              local ox = (gridSize * (oversize - 1)) * 0.5
              local oy = (gridSize * (oversize - 1)) * 0.5
              love.graphics.draw(sprite, worldX - ox, worldY - oy, 0, sx, sy)
            end
          elseif tile.type == MapManager.TileType.REST then
            local sprite = sprites.rest
            if sprite then
              love.graphics.setColor(1, 1, 1, 1)
              local sx = (gridSize * oversize) / sprite:getWidth()
              local sy = (gridSize * oversize) / sprite:getHeight()
              local ox = (gridSize * (oversize - 1)) * 0.5
              local oy = (gridSize * (oversize - 1)) * 0.5
              love.graphics.draw(sprite, worldX - ox, worldY - oy, 0, sx, sy)
            end
          end
        end
        
        -- Draw obstacle tiles (stones/trees that block movement)
        if tile.type == MapManager.TileType.STONE then
          local sprite = sprites.stone[tile.decorationVariant or 1]
          if sprite then
            love.graphics.setColor(1, 1, 1, 1)
            local sx = (gridSize * oversize) / sprite:getWidth()
            local sy = (gridSize * oversize) / sprite:getHeight()
            local ox = (gridSize * (oversize - 1)) * 0.5
            local oy = (gridSize * (oversize - 1)) * 0.5
            love.graphics.draw(sprite, worldX - ox, worldY - oy, 0, sx, sy)
          else
            -- Fallback rendering
            love.graphics.setColor(0.3, 0.3, 0.3, 1)
            love.graphics.rectangle("fill", worldX, worldY, gridSize, gridSize)
          end
        elseif tile.type == MapManager.TileType.TREE then
          local sprite = sprites.tree[tile.decorationVariant or 1]
          if sprite then
            love.graphics.setColor(1, 1, 1, 1)
            local sx = (gridSize * oversize) / sprite:getWidth()
            local sy = (gridSize * oversize) / sprite:getHeight()
            local ox = (gridSize * (oversize - 1)) * 0.5
            local oy = (gridSize * (oversize - 1)) * 0.5
            love.graphics.draw(sprite, worldX - ox, worldY - oy, 0, sx, sy)
          else
            -- Fallback rendering
            love.graphics.setColor(0.2, 0.4, 0.2, 1)
            love.graphics.rectangle("fill", worldX, worldY, gridSize, gridSize)
          end
        end
        
        -- No hover or available-path highlights
      end
    end
  end
  
  -- Draw player character on top of map objects
  local px, py = self.playerWorldX, self.playerWorldY
  if self.playerSprite then
    local spriteSize = self.gridSize * 0.8 -- Slightly smaller than tile
    local spriteW, spriteH = self.playerSprite:getDimensions()
    local scale = spriteSize / math.max(spriteW, spriteH)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.playerSprite, px, py, 0, scale, scale, spriteW * 0.5, spriteH * 0.5)
  else
    -- Fallback circle if sprite not loaded
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", px, py, 12)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.circle("line", px, py, 12)
  end
  
  love.graphics.pop()
  
  -- Draw UI overlay
  self:drawUI()
end

function MapScene:drawUI()
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  
  -- Draw day and moves remaining
  love.graphics.setFont(theme.fonts.base)
  local dayText = string.format("Day %d", self.daySystem:getCurrentDay())
  local movesText = string.format("Moves: %d/%d", 
    self.daySystem:getMovesRemaining(), 
    self.daySystem:getMaxMoves())
  
  theme.drawTextWithOutline(dayText, 20, 20, 1, 1, 1, 1, 2)
  theme.drawTextWithOutline(movesText, 20, 50, 1, 1, 1, 1, 2)
  
  -- Draw instructions
  if self._battleTransitionDelay > 0 then
    -- Show battle starting message
    local battleText = "BATTLE STARTING..."
    local alpha = math.min(1.0, self._battleTransitionDelay * 2)
    theme.drawTextWithOutline(battleText, vw * 0.5, vh * 0.5, 1, 0.2, 0.2, alpha, 3)
  elseif not self.isMoving and self.daySystem:canMove() then
    local instructionText = "WASD or Click to move"
    theme.drawTextWithOutline(instructionText, 20, vh - 40, 0.7, 0.7, 0.7, 1, 2)
  elseif not self.daySystem:canMove() then
    local instructionText = "No moves remaining. Press SPACE to advance to next day."
    theme.drawTextWithOutline(instructionText, 20, vh - 40, 0.9, 0.7, 0.2, 1, 2)
  end
  
  -- Hover tooltip removed
end

function MapScene:mousepressed(x, y, button)
  if button ~= 1 or self.isMoving or not self.daySystem:canMove() then
    return
  end
  
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
      self.mapManager:movePlayerTo(gridX, gridY)
    end
  end
end

function MapScene:mousemoved(x, y, dx, dy)
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

function MapScene:keypressed(key, scancode, isRepeat)
  -- Advance to next day when out of moves
  if key == "space" and not self.daySystem:canMove() and not self.isMoving then
    self.daySystem:advanceDay()
    return
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
  elseif key == "d" or key == "right" then
    targetGridX = currentGridX + 1
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
