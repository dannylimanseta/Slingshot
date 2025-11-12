local theme = require("theme")
local config = require("config")
local MapManager = require("managers.MapManager")
local DaySystem = require("core.DaySystem")
local TopBar = require("ui.TopBar")
local OrbsUI = require("ui.OrbsUI")
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
    _inputSuppressTimer = 0,
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
    _pendingEvent = false,
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
    _darkeningAlpha = 0, -- tweened alpha for darkening overlay when out of turns
    dayIndicator = nil, -- { text = "DAY X", t = lifetime }
    decorImage = nil, -- decorative image for day indicator
    orbsUI = OrbsUI.new(), -- UI for viewing equipped orbs
    _orbsUIOpen = false, -- track if orbs UI is open
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
  
  -- Load player glow 2 (optional)
  do
    local ok, glow = pcall(love.graphics.newImage, "assets/images/map/player_glow_2.png")
    if ok then self.playerGlow2 = glow end
  end
  
  -- Load orange glow for rest sites (optional)
  do
    local ok, glow = pcall(love.graphics.newImage, "assets/images/map/orange_glow.png")
    if ok then self.restGlow = glow end
  end

  -- Load decorative image for day indicator (same as turn indicators)
  do
    local ok, img = pcall(love.graphics.newImage, "assets/images/decor_1.png")
    if ok then self.decorImage = img end
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
  
  -- Reset movement state when returning to map
  self.isMoving = false
  self.playerTargetX = nil
  self.playerTargetY = nil
  self._movementTime = 0
  -- Clear hold-to-move state
  self._heldMoveKey = nil
  self._heldDirX = 0
  self._heldDirY = 0
  self._holdElapsed = 0
  self._repeatElapsed = 0
  self._hasFiredInitialRepeat = false

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
  
  -- Always clear target grid positions when loading
  self.mapManager.playerTargetGridX = nil
  self.mapManager.playerTargetGridY = nil
  
  -- Recalculate world position from grid position (grid position is source of truth)
  -- This ensures player position is correct when returning from events, battles, or rest sites
  -- Always recalculate from grid position to avoid position bugs when returning from scenes
    local px, py = self.mapManager:getPlayerWorldPosition(self.gridSize, self.offsetX, self.offsetY)
    -- Prefer restoring the exact world position saved before leaving the map (avoids visual jumps on transition)
    local restoreX = self._savedWorldX or px
    local restoreY = self._savedWorldY or py
    self.playerWorldX = restoreX
    self.playerWorldY = restoreY
    self.cameraX = restoreX
    self.cameraY = restoreY
    self.targetCameraX = restoreX
    self.targetCameraY = restoreY
    -- Clear saved world position after applying
    self._savedWorldX, self._savedWorldY = nil, nil
  
  -- Clamp camera to map bounds on first frame
  self:_clampCameraToMap()
end

function MapScene:update(deltaTime)
  if self.controller then
    return self.controller:update(deltaTime)
  end
  return nil
end

-- Reset all movement/input state and re-apply saved world position when resuming this scene.
-- Use when returning from other scenes to avoid replaying stale movement steps.
function MapScene:resetMovementOnResume()
  -- Clear movement
  self.isMoving = false
  self.playerTargetX = nil
  self.playerTargetY = nil
  self._movementTime = 0

  -- Clear held input state
  self._heldMoveKey = nil
  self._heldDirX = 0
  self._heldDirY = 0
  self._holdElapsed = 0
  self._repeatElapsed = 0
  self._hasFiredInitialRepeat = false

  -- Clear target grid positions
  if self.mapManager then
    self.mapManager.playerTargetGridX = nil
    self.mapManager.playerTargetGridY = nil
  end

  -- Recompute and restore precise world position
  if self.mapManager then
    local px, py = self.mapManager:getPlayerWorldPosition(self.gridSize, self.offsetX, self.offsetY)
    local restoreX = self._savedWorldX or px
    local restoreY = self._savedWorldY or py
    self.playerWorldX = restoreX
    self.playerWorldY = restoreY
    self.cameraX = restoreX
    self.cameraY = restoreY
    self.targetCameraX = restoreX
    self.targetCameraY = restoreY
    -- Clear saved world position after applying
    self._savedWorldX, self._savedWorldY = nil, nil
  end

  -- Clamp camera immediately
  if self._clampCameraToMap then
    self:_clampCameraToMap(true)
    self:_clampCameraToMap(false)
  end
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
  -- Draw orbs UI overlay if open
  if self.orbsUI and self._orbsUIOpen then
    self.orbsUI:draw()
    end
end

function MapScene:mousepressed(x, y, button)
  if self.controller then self.controller:mousepressed(x, y, button) end
end

function MapScene:mousereleased(x, y, button)
  if self.controller then self.controller:mousereleased(x, y, button) end
end

function MapScene:mousemoved(x, y, dx, dy)
  if self.controller then self.controller:mousemoved(x, y, dx, dy) end
end

function MapScene:wheelmoved(dx, dy)
  if self.controller then self.controller:wheelmoved(dx, dy) end
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
