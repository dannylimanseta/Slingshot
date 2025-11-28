-- SplitScene.lua
-- Main scene that combines GameplayScene (breakout) and BattleScene (RPG combat)
-- Refactored to use extracted modules for better maintainability

local theme = require("theme")
local config = require("config")
local playfield = require("utils.playfield")
local GameplayScene = require("scenes.GameplayScene")
local BattleScene = require("scenes.BattleScene")
local TurnManager = require("core.TurnManager")
local TurnActions = require("systems.TurnActions")
local ProjectileCard = require("ui.ProjectileCard")
local LayoutManager = require("managers.LayoutManager")
local battle_profiles = require("data.battle_profiles")
local TopBar = require("ui.TopBar")
local OrbsUI = require("ui.OrbsUI")
local EncounterManager = require("core.EncounterManager")

-- Extracted modules
local SplitSceneEvents = require("scenes.split.SplitSceneEvents")
local SplitSceneRenderer = require("scenes.split.SplitSceneRenderer")
local SplitSceneInput = require("scenes.split.SplitSceneInput")
local SplitSceneTurnLogic = require("scenes.split.SplitSceneTurnLogic")

local SplitScene = {}
SplitScene.__index = SplitScene

function SplitScene.new()
  -- Create small font for orb name (70% of base font size)
  local nameFont = theme.fonts.base or theme.fonts.medium
  local nameFontSize = (nameFont:getHeight() or 20) * 0.7
  local smallFont = theme.newFont(nameFontSize)
  
  return setmetatable({ 
    left = nil, 
    right = nil, 
    -- Turn management system
    turnManager = nil,
    -- Projectile card UI
    projectileCard = nil,
    currentProjectileId = "strike",
    _prevProjectileId = nil,
    tooltipFadeTimer = 0,
    tooltipFadeDuration = 0.3,
    -- Layout management for dynamic canvas width
    layoutManager = LayoutManager.new(),
    _lastCenterW = nil,
    -- Edge glow effects
    edgeGlowImage = nil,
    edgeGlowLeftTimer = 0,
    edgeGlowRightTimer = 0,
    edgeGlowLeftY = 0,
    edgeGlowRightY = 0,
    edgeGlowDuration = 0.3,
    -- Cached small font for orb name display
    _smallFont = smallFont,
    -- Left boundary damage effect
    boundaryLeftDamageTimer = 0,
    boundaryLeftDamageDuration = 0.5,
    -- Screenshake for full screen
    shakeTime = 0,
    shakeDuration = 0,
    shakeMagnitude = 0,
    -- Victory/defeat detection flags
    _victoryDetected = false,
    _defeatDetected = false,
    _returnToMapTimer = 0,
    topBar = TopBar.new(),
    orbsUI = OrbsUI.new(),
    _orbsUIOpen = false,
    _mouseX = 0,
    _mouseY = 0,
    -- Lightning impact delay timer
    _lightningImpactDelayTimer = 0,
    _lightningImpactDelayDuration = 0.2,
  }, SplitScene)
end

function SplitScene:load()
  -- Ensure layoutManager exists
  if not self.layoutManager then
    self.layoutManager = LayoutManager.new()
  end
  
  -- Use virtual resolution from config
  local w = (config.video and config.video.virtualWidth) or 1280
  local h = (config.video and config.video.virtualHeight) or 720
  local centerRect = self.layoutManager:getCenterRect(w, h)
  
  self.left = GameplayScene.new()
  self.right = BattleScene.new()
  
  -- Get encounter battle profile
  local currentBattleType = self.layoutManager:getBattleType()
  local battleProfile = EncounterManager.getCurrentBattleProfile() or battle_profiles.getProfile(currentBattleType)
  
  self.left:load({ x = 0, y = 0, w = centerRect.w, h = h }, self.currentProjectileId, battleProfile)
  self.right:load({ x = centerRect.w, y = 0, w = w - centerRect.w, h = h }, battleProfile)
  self._lastCenterW = centerRect.w
  
  -- Ensure only SplitScene draws the shared top bar
  if self.left then self.left.disableTopBar = true end
  if self.right then self.right.disableTopBar = true end
  
  -- Grey out orbs and inventory icons during battle
  if self.topBar then
    self.topBar.disableOrbsIcon = true
    self.topBar.disableInventoryIcon = true
  end

  -- Load assets
  self:loadAssets()
  
  -- Set up callbacks
  self:setupCallbacks()

  -- Initialize TurnManager
  self.turnManager = TurnManager.new()
  TurnActions.registerAll(self.turnManager)
  
  -- Give BattleScene access to TurnManager
  if self.right and self.right.setTurnManager then
    self.right:setTurnManager(self.turnManager)
  end
  self.turnManager._sceneRight = self.right
  
  -- Give GameplayScene access to TurnManager
  if self.left and self.left.setTurnManager then
    self.left:setTurnManager(self.turnManager)
  end

  -- Set up event handlers using extracted module
  SplitSceneEvents.setup(self)
  
  -- Initialize projectile card UI
  self.projectileCard = ProjectileCard.new()
  
  -- Start the first player turn
  self.turnManager:startPlayerTurn()
end

--- Load all image assets
function SplitScene:loadAssets()
  -- Background image
  self.bgImage = nil
  local bgPath = (config.assets and config.assets.images and config.assets.images.background) or nil
  if bgPath then
    local ok, img = pcall(love.graphics.newImage, bgPath)
    if ok then self.bgImage = img end
  end

  -- Boundary images
  self.boundaryLeft = nil
  self.boundaryRight = nil
  local boundaryLeftPath = "assets/images/boundary_left.png"
  local boundaryRightPath = "assets/images/boundary_right.png"
  local okLeft, imgLeft = pcall(love.graphics.newImage, boundaryLeftPath)
  if okLeft then self.boundaryLeft = imgLeft end
  local okRight, imgRight = pcall(love.graphics.newImage, boundaryRightPath)
  if okRight then self.boundaryRight = imgRight end

  -- Edge glow image
  self.edgeGlowImage = nil
  local edgeGlowPath = "assets/images/fx/edge_glow.png"
  local okGlow, imgGlow = pcall(love.graphics.newImage, edgeGlowPath)
  if okGlow then self.edgeGlowImage = imgGlow end

  -- Decorative image for turn indicators
  self.decorImage = nil
  local decorPath = "assets/images/decor_1.png"
  local okDecor, imgDecor = pcall(love.graphics.newImage, decorPath)
  if okDecor then self.decorImage = imgDecor end

  -- Black band image for turn indicator overlay
  self.blackBandImage = nil
  local blackBandPath = "assets/images/fx/black_band.png"
  local okBand, imgBand = pcall(love.graphics.newImage, blackBandPath)
  if okBand then self.blackBandImage = imgBand end
end

--- Set up callbacks between scenes
function SplitScene:setupCallbacks()
  -- Player damage callback
  self.right.onPlayerDamage = function()
    self.boundaryLeftDamageTimer = self.boundaryLeftDamageDuration
    self:triggerShake((config.battle and config.battle.shakeMagnitude) or 10, (config.battle and config.battle.shakeDuration) or 0.25)
  end

  -- Edge hit callback for glow effect
  if self.left then
    self.left.onEdgeHit = function(side, y)
      if side == "left" then
        self.edgeGlowLeftTimer = self.edgeGlowDuration
        self.edgeGlowLeftY = y or -200
      elseif side == "right" then
        self.edgeGlowRightTimer = self.edgeGlowDuration
        self.edgeGlowRightY = y or -200
      end
    end
  end
end

function SplitScene:resize(width, height)
  local w = (config.video and config.video.virtualWidth) or 1280
  local h = (config.video and config.video.virtualHeight) or 720
  local centerRect = self.layoutManager:getCenterRect(w, h)
  
  if self.left and self.left.resize then self.left:resize(centerRect.w, h) end
  if self.right and self.right.resize then self.right:resize(w - centerRect.w, h) end
  
  -- Update walls if width changed significantly
  if self._lastCenterW and math.abs(centerRect.w - self._lastCenterW) > 1 then
    if self.left and self.left.updateWalls then
      self.left:updateWalls(centerRect.w, h)
    end
    self._lastCenterW = centerRect.w
  end
end

function SplitScene:draw()
  local w = (config.video and config.video.virtualWidth) or 1280
  local h = (config.video and config.video.virtualHeight) or 720
  local centerRect = self.layoutManager:getCenterRect(w, h)
  local centerW = centerRect.w
  local centerX = centerRect.x - 100
  
  -- Calculate grid bounds
  local gridStartX, gridEndX = playfield.calculateGridBounds(centerW, h)
  local gridStartXAbsolute = centerX + gridStartX
  local gridEndXAbsolute = centerX + gridEndX

  -- Apply screenshake
  love.graphics.push()
  if self.shakeTime > 0 and self.shakeDuration > 0 then
    local t = self.shakeTime / self.shakeDuration
    local ease = t * t
    local mag = self.shakeMagnitude * ease
    local ox = (love.math.random() * 2 - 1) * mag
    local oy = (love.math.random() * 2 - 1) * mag
    love.graphics.translate(ox, oy)
  end

  -- Draw background
  SplitSceneRenderer.drawBackground(self, w, h)

  -- Draw battle scene (full screen, behind gameplay)
  local battleBounds = { x = 0, y = 0, w = w, h = h, center = { x = centerX, w = centerW, h = h } }
  if self.right and self.right.draw then
    self.right:draw(battleBounds)
  end

  -- Draw boundaries
  love.graphics.push("all")
  love.graphics.setBlendMode("add")
  SplitSceneRenderer.drawLeftBoundary(self, gridStartXAbsolute, h)
  SplitSceneRenderer.drawRightBoundary(self, gridEndXAbsolute, h)
  love.graphics.pop()

  -- Draw gameplay centered
  love.graphics.push()
  love.graphics.translate(centerX, 0)
  if self.left and self.left.draw then 
    self.left:draw({ x = 0, y = 0, w = centerW, h = h }) 
  end
  love.graphics.pop()
  
  -- Draw battle overlays
  if self.right and self.right.drawAttackOverlay then
    self.right:drawAttackOverlay(battleBounds)
  end
  if self.right and self.right.drawSkillParticles then
    self.right:drawSkillParticles()
  end

  -- Draw edge glows
  SplitSceneRenderer.drawEdgeGlows(self, gridStartXAbsolute, gridEndXAbsolute, h)

  -- Draw guide lines (debug)
  SplitSceneRenderer.drawGuideLines(centerX, centerW, h)

  -- Draw turn indicator overlay
  SplitSceneRenderer.drawTurnIndicator(self, w, h, centerRect)
  
  love.graphics.pop() -- Pop screenshake transform
  
  -- Draw projectile card
  SplitSceneRenderer.drawProjectileCard(self, w, h)
  
  -- Draw top bar
  if self.topBar then
    self.topBar:draw()
  end
  
  -- Draw orbs UI overlay if open
  if self.orbsUI and self._orbsUIOpen then
    self.orbsUI:draw()
  end
end

function SplitScene:mousepressed(x, y, button)
  return SplitSceneInput.mousepressed(self, x, y, button)
end

function SplitScene:mousereleased(x, y, button)
  return SplitSceneInput.mousereleased(self, x, y, button)
end

function SplitScene:mousemoved(x, y, dx, dy)
  return SplitSceneInput.mousemoved(self, x, y, dx, dy)
end

function SplitScene:wheelmoved(x, y)
  return SplitSceneInput.wheelmoved(self, x, y)
end

function SplitScene:keypressed(key, scancode, isRepeat)
  return SplitSceneInput.keypressed(self, key, scancode, isRepeat)
end

function SplitScene:update(dt)
  -- Update layout manager
  if self.layoutManager then
    self.layoutManager:update(dt)
  end

  -- Update timers
  self:updateTimers(dt)
  
  local w = (config.video and config.video.virtualWidth) or 1280
  local h = (config.video and config.video.virtualHeight) or 720
  local centerRect = self.layoutManager:getCenterRect(w, h)
  
  -- Update walls if width changed
  if self._lastCenterW and math.abs(centerRect.w - self._lastCenterW) > 1 then
    if self.left and self.left.updateWalls then
      self.left:updateWalls(centerRect.w, h)
    end
    self._lastCenterW = centerRect.w
  elseif not self._lastCenterW then
    self._lastCenterW = centerRect.w
  end

  -- Update sub-scenes
  if self.left and self.left.update then 
    self.left:update(dt, { x = 0, y = 0, w = centerRect.w, h = h }) 
  end
  if self.right and self.right.update then 
    self.right:update(dt, { x = 0, y = 0, w = w, h = h, center = centerRect.center }) 
  end
  
  -- Update OrbsUI
  if self.orbsUI then
    self.orbsUI:update(dt, self._mouseX, self._mouseY)
  end

  -- Controller/gamepad support
  SplitSceneInput.updateController(self, centerRect, h)

  -- Detect turn end and trigger impact VFX
  if SplitSceneTurnLogic.detectTurnEnd(self, dt) then
    -- Trigger impact VFX
    if self.right and self.right.playImpact then
      local blockCount = (self.left and self.left.blocksHitThisTurn) or 1
      local isCrit = (self.left and self.left.critThisTurn and self.left.critThisTurn > 0) or false
      self.right:playImpact(blockCount, isCrit)
    end
    -- End the turn
    SplitSceneTurnLogic.endPlayerTurn(self)
    -- Reset lightning delay timer
    self._lightningImpactDelayTimer = 0
  end

  -- Update TurnManager
  if self.turnManager and self.turnManager.update then
    self.turnManager:update(dt)
  end
  
  -- Update projectile fade animation
  self:updateProjectileFade(dt)
  
  -- Victory/defeat handling
  local victoryDefeatResult = SplitSceneTurnLogic.updateVictoryDefeat(self, dt)
  if victoryDefeatResult then
    return victoryDefeatResult
  end
  
  return nil
end

--- Update all timers
function SplitScene:updateTimers(dt)
  -- Edge glow timers
  if self.edgeGlowLeftTimer > 0 then
    self.edgeGlowLeftTimer = math.max(0, self.edgeGlowLeftTimer - dt)
  end
  if self.edgeGlowRightTimer > 0 then
    self.edgeGlowRightTimer = math.max(0, self.edgeGlowRightTimer - dt)
  end
  
  -- Left boundary damage effect timer
  if self.boundaryLeftDamageTimer > 0 then
    self.boundaryLeftDamageTimer = math.max(0, self.boundaryLeftDamageTimer - dt)
  end
  
  -- Screenshake timer
  if self.shakeTime > 0 then
    self.shakeTime = math.max(0, self.shakeTime - dt)
    if self.shakeTime <= 0 then
      self.shakeTime = 0
      self.shakeDuration = 0
      self.shakeMagnitude = 0
    end
  end
end

--- Update projectile card fade animation
function SplitScene:updateProjectileFade(dt)
  local projectileIdToShow = "strike"
  if self.left and self.left.shooter and self.left.shooter.getCurrentProjectileId then
    projectileIdToShow = self.left.shooter:getCurrentProjectileId()
  else
    projectileIdToShow = self.currentProjectileId or "strike"
  end
  
  -- Check if projectile changed
  if projectileIdToShow ~= self._prevProjectileId then
    if self._prevProjectileId ~= nil then
      self.tooltipFadeTimer = self.tooltipFadeDuration
    end
    self._prevProjectileId = projectileIdToShow
  end
  
  -- Update fade timer
  if self.tooltipFadeTimer > 0 then
    self.tooltipFadeTimer = math.max(0, self.tooltipFadeTimer - dt)
  end
end

--- Set the current projectile
function SplitScene:setProjectile(projectileId)
  self.currentProjectileId = projectileId or "strike"
  if self.left and self.left.setProjectile then
    self.left:setProjectile(projectileId)
  end
end

--- Set battle type (triggers tween to new canvas width)
function SplitScene:setBattleType(battleType, duration)
  if self.layoutManager then
    self.layoutManager:setBattleType(battleType, duration)
  end
end

--- Set canvas width factor directly
function SplitScene:setCanvasWidthFactor(factor, duration)
  if self.layoutManager then
    return self.layoutManager:setTargetFactor(factor, duration)
  end
  return false
end

--- Get current battle type
function SplitScene:getBattleType()
  if self.layoutManager then
    return self.layoutManager:getBattleType()
  end
  return nil
end

--- Trigger screenshake
function SplitScene:triggerShake(magnitude, duration)
  self.shakeMagnitude = magnitude or 10
  self.shakeDuration = duration or 0.25
  self.shakeTime = self.shakeDuration
end

--- Reload blocks from battle profile
function SplitScene:reloadBlocks()
  if not self.left then return end
  
  if not self.layoutManager then
    self.layoutManager = LayoutManager.new()
  end
  
  -- Reload datasets
  if EncounterManager and EncounterManager.reloadDatasets then
    EncounterManager.reloadDatasets()
    if EncounterManager.getCurrentEncounterId and EncounterManager.setEncounterById then
      local currentEncounterId = EncounterManager.getCurrentEncounterId()
      if currentEncounterId then
        EncounterManager.setEncounterById(currentEncounterId)
      end
    end
  end
  package.loaded["data.battle_profiles"] = nil
  battle_profiles = require("data.battle_profiles")
  
  local currentBattleType = self.layoutManager:getBattleType()
  local battleProfile = (EncounterManager and EncounterManager.getCurrentBattleProfile and EncounterManager.getCurrentBattleProfile()) or battle_profiles.getProfile(currentBattleType)
  
  local w, h = love.graphics.getDimensions()
  local centerRect = self.layoutManager:getCenterRect(w, h)
  local bounds = { x = 0, y = 0, w = centerRect.w, h = h }
  
  if self.left and self.left.reloadBlocks then
    self.left:reloadBlocks(battleProfile, bounds)
  end
end

--- Cleanup
function SplitScene:unload()
  if self.left and self.left.unload then
    self.left:unload()
  end
  if self.right and self.right.unload then
    self.right:unload()
  end
  
  self.left = nil
  self.right = nil
  self.turnManager = nil
  self.projectileCard = nil
  self.layoutManager = nil
end

return SplitScene
