local config = require("config")
local theme = require("theme")
local Bar = require("ui.Bar")
local SpriteAnimation = require("utils.SpriteAnimation")
local DisintegrationShader = require("utils.DisintegrationShader")
local WhiteSilhouetteShader = require("utils.WhiteSilhouetteShader")
local FogShader = require("utils.FogShader")
local ImpactSystem = require("scenes.battle.ImpactSystem")
local Animations = require("scenes.battle.Animations")
local Visuals = require("scenes.battle.Visuals")
local TurnManager = require("core.TurnManager")
local TopBar = require("ui.TopBar")
local PlayerState = require("core.PlayerState")
local battle_profiles = require("data.battle_profiles")
local ParticleManager = require("managers.ParticleManager")

local BattleScene = {}
BattleScene.__index = BattleScene

-- Helper function to create an enemy entry from config
local function createEnemyFromConfig(enemyConfig, index)
  return {
    hp = enemyConfig.maxHP,
    maxHP = enemyConfig.maxHP,
    displayHP = enemyConfig.maxHP, -- Display HP for smooth tweening
    img = nil, -- Loaded in load() function
    flash = 0,
    knockbackTime = 0,
    lungeTime = 0,
    jumpTime = 0, -- Jump animation timer (for shockwave attack)
    rotation = 0, -- Current rotation angle in radians (tweens back to 0)
    pulseTime = love.math.random() * (2 * math.pi), -- Different phase offsets for visual variety
    disintegrating = false,
    disintegrationTime = 0,
    pendingDisintegration = false, -- Set to true when HP reaches 0 but waiting for impact animations
    scaleMul = enemyConfig.scaleMul or 1,
    spriteScale = enemyConfig.spriteScale or config.battle.enemySpriteScale or 4,
    damageMin = enemyConfig.damageMin or 3,
    damageMax = enemyConfig.damageMax or 8,
    spritePath = enemyConfig.sprite, -- Store path for loading
    name = enemyConfig.name, -- Display name (optional)
    index = index, -- Position in array (for reference)
  }
end

function BattleScene.new()
  return setmetatable({
    playerHP = config.battle.playerMaxHP,
    enemies = {}, -- Array of enemy objects (initialized in load() from battle profile)
    displayPlayerHP = config.battle.playerMaxHP, -- Display HP for smooth tweening
    playerArmor = 0,
    prevPlayerArmor = 0,
    playerFlash = 0,
    prevPlayerFlash = 0, -- Track previous flash state to detect new hits
    popups = {},
    log = {},
    state = "idle", -- idle | win | lose (deprecated, use TurnManager state)
    _enemyTurnDelay = nil, -- Delay timer for enemy turn start (after armor popup)
    _pendingEnemyTurnStart = false, -- Flag to track if enemy turn is waiting for player attack to complete
    _enemyAttackDelays = {}, -- Array of delay timers for staggered enemy attacks {index, delay}
    _playerAttackDelayTimer = nil, -- Delay timer for player attack animation (after ball despawn)
    _pendingPlayerAttackDamage = nil, -- { damage, armor, wasJackpot, impactBlockCount, impactIsCrit } - stored when turn ends, applied after delay
    _pendingImpactParams = nil, -- { blockCount, isCrit } - stored by playImpact, merged into pending damage
    _shockwaveSequence = nil, -- Timer for sequencing shockwave animation phases
    playerImg = nil,
    playerScaleMul = 1,
    playerLungeTime = 0,
    shakeTime = 0,
    shakeDuration = 0,
    shakeMagnitude = 0,
    pendingArmor = 0,
    armorPopupShown = false,
    iconArmor = nil,
    iconPotion = nil,
    playerKnockbackTime = 0,
    playerRotation = 0, -- Current rotation angle in radians (tweens back to 0)
    idleT = 0,
    borderFragments = {}, -- For shatter effect
    borderFadeInTime = 0, -- Fade-in animation timer for border
    armorIconFlashTimer = 0, -- Timer for armor icon flash when damage is fully blocked
    borderFadeInDuration = 0.2, -- Fade-in duration in seconds
    _lastBounds = nil,
    -- Turn indicator state
    turnIndicator = nil, -- { text = "PLAYER'S TURN" or "ENEMY'S TURN", t = lifetime }
    turnIndicatorDelay = 0, -- Delay timer before showing turn indicator
    _pendingTurnIndicator = nil, -- Queued turn indicator waiting for delay
    -- Impact animation
    impactAnimation = nil, -- Base animation instance
    impactInstances = {}, -- Array of active impact instances {anim, x, y, rotation, delay, offsetX, offsetY}
    impactEffectsPlayed = false,
    splatterImage = nil, -- Splatter image for hit effects (backwards compatibility)
    splatterImages = {}, -- Array of splatter images for randomization
    splatterInstances = {}, -- Array of active splatter instances {x, y, rotation, scale, alpha, lifetime, maxLifetime, image}
    -- Staggered flash and knockback events
    enemyFlashEvents = {}, -- Array of {delay, duration} for staggered flashes
    enemyKnockbackEvents = {}, -- Array of {delay, startTime} for staggered knockbacks
    disintegrationShader = nil,
    whiteSilhouetteShader = nil,
    -- Lunge speed streaks
    lungeStreaks = {},
    lungeStreakAcc = 0,
    -- Pulse animation timers
    playerPulseTime = love.math.random() * (2 * math.pi),
    -- Fog shader
    fogShader = nil,
    fogTime = 0, -- Time accumulator for fog animation
    topBar = TopBar.new(),
    -- Enemy selection
    selectedEnemyIndex = 1, -- Index of currently selected enemy (1 = leftmost)
    selectedIndicatorImg = nil, -- Image for selection indicator
    -- Particle system
    particles = ParticleManager.new(),
  }, BattleScene)
end

function BattleScene:load(bounds, battleProfile)
  -- Get battle profile (use provided or default)
  battleProfile = battleProfile or battle_profiles.getProfile(battle_profiles.Types.DEFAULT)
  
  -- Store battle profile for Visuals.lua to access
  self._battleProfile = battleProfile
  
  -- Initialize enemies from battle profile
  self.enemies = {}
  local maxAvailableEnemies = battleProfile.enemies and #battleProfile.enemies or 0
  
  -- Use enemyCount from battle profile if specified, otherwise randomize (for backward compatibility)
  local enemyCount
  if battleProfile.enemyCount and battleProfile.enemyCount > 0 then
    -- Use the specified enemy count from the battle profile
    enemyCount = math.min(battleProfile.enemyCount, maxAvailableEnemies)
  else
    -- Fallback: Randomize enemy count between 1-3 for old battle profiles
    local randomEnemyCount = love.math.random(1, 3)
    enemyCount = math.min(randomEnemyCount, maxAvailableEnemies)
  end
  
  -- Select enemies sequentially from the battle profile (respects encounter order)
  if battleProfile.enemies and maxAvailableEnemies > 0 then
    for i = 1, enemyCount do
      if battleProfile.enemies[i] then
        local enemy = createEnemyFromConfig(battleProfile.enemies[i], i)
        table.insert(self.enemies, enemy)
      end
    end
  end
  
  -- Sync PlayerState with BattleScene's initial HP
  local playerState = PlayerState.getInstance()
  playerState:setHealth(self.playerHP)
  playerState:setMaxHealth(config.battle.playerMaxHP)
  
  -- Load player sprite
  local playerPath = (config.assets and config.assets.images and config.assets.images.player) or nil
  if playerPath then
    local ok, img = pcall(love.graphics.newImage, playerPath)
    if ok then self.playerImg = img end
  end
  
  -- Load enemy sprites from enemy configs
  for i, enemy in ipairs(self.enemies) do
    if enemy.spritePath then
      local fullPath = "assets/images/" .. enemy.spritePath
      local ok, img = pcall(love.graphics.newImage, fullPath)
      if ok then enemy.img = img end
    end
  end
  
  -- Load armor icon
  local iconArmorPath = (config.assets and config.assets.images and config.assets.images.icon_armor) or nil
  if iconArmorPath then
    local ok, img = pcall(love.graphics.newImage, iconArmorPath)
    if ok then self.iconArmor = img end
  end
  
  -- Load potion icon
  local iconPotionPath = (config.assets and config.assets.images and config.assets.images.icon_potion) or nil
  if iconPotionPath then
    local ok, img = pcall(love.graphics.newImage, iconPotionPath)
    if ok then self.iconPotion = img end
  end
  
  -- Load impact animation (optional)
  do
    local impactPath = (config.assets and config.assets.images and config.assets.images.impact) or nil
    if impactPath then
      local fps = (config.battle and config.battle.impactFps) or 30
      self.impactAnimation = SpriteAnimation.new(impactPath, 512, 512, 4, 4, fps)
    end
  end
  
  -- Load disintegration shader
  local ok, shader = pcall(function() return DisintegrationShader.getShader() end)
  if ok and shader then
    self.disintegrationShader = shader
  else
    -- Shader failed to load, disable disintegration effect
    self.disintegrationShader = nil
  end

  -- Load white silhouette shader
  do
    local okWhite, wshader = pcall(function() return WhiteSilhouetteShader.getShader() end)
    if okWhite and wshader then
      self.whiteSilhouetteShader = wshader
    else
      self.whiteSilhouetteShader = nil
    end
  end
  
  -- Load fog shader
  local fogOk, fogShader = pcall(function() return FogShader.getShader() end)
  if fogOk and fogShader then
    self.fogShader = fogShader
  else
    -- Shader failed to load, disable fog effect
    self.fogShader = nil
  end
  
  -- Load selection indicator image
  local indicatorPath = "assets/images/selected_indicator.png"
  local ok, img = pcall(love.graphics.newImage, indicatorPath)
  if ok then
    self.selectedIndicatorImg = img
  else
    self.selectedIndicatorImg = nil
  end
  
  -- Load splatter images for hit effects (pool for randomization)
  self.splatterImages = {}
  local splatterPath1 = "assets/images/fx/splatter_1.png"
  local okSplatter1, splatterImg1 = pcall(love.graphics.newImage, splatterPath1)
  if okSplatter1 then
    table.insert(self.splatterImages, splatterImg1)
  end
  local splatterPath2 = "assets/images/fx/splatter_2.png"
  local okSplatter2, splatterImg2 = pcall(love.graphics.newImage, splatterPath2)
  if okSplatter2 then
    table.insert(self.splatterImages, splatterImg2)
  end
  -- Keep single image reference for backwards compatibility (use first if available)
  self.splatterImage = (#self.splatterImages > 0) and self.splatterImages[1] or nil
  
  -- Initialize selection to leftmost enemy (index 1)
  self.selectedEnemyIndex = 1
  -- Ensure selection is valid
  if #self.enemies > 0 then
    self.selectedEnemyIndex = math.min(self.selectedEnemyIndex, #self.enemies)
  else
    self.selectedEnemyIndex = nil
  end
end

-- Set a new enemy sprite and optional size multiplier at runtime
-- Applies to first enemy (index 1)
function BattleScene:setEnemySprite(path, scaleMultiplier)
  if self.enemies and #self.enemies > 0 then
    local enemy = self.enemies[1]
  if path then
    local ok, img = pcall(love.graphics.newImage, path)
      if ok then enemy.img = img end
  end
  if scaleMultiplier then
      enemy.scaleMul = scaleMultiplier
    end
  end
end

local function pushLog(self, line)
  -- Combat log disabled
end

local function createBorderFragments(x, y, w, h, gap, radius)
  -- Create fragments around the border perimeter that shoot outward
  local fragments = {}
  local fragmentCount = 24
  local barCenterX = x + w * 0.5
  local barCenterY = y + h * 0.5
  local borderW = w + gap * 2
  local borderH = h + gap * 2
  local borderX = x - gap
  local borderY = y - gap
  
  -- Create fragments at various points around the border
  for i = 1, fragmentCount do
    local t = (i - 1) / fragmentCount
    local px, py
    
    -- Calculate position along border perimeter
    if t < 0.25 then
      -- Top edge
      local edgeT = (t / 0.25)
      px = borderX + borderW * edgeT
      py = borderY
    elseif t < 0.5 then
      -- Right edge
      local edgeT = ((t - 0.25) / 0.25)
      px = borderX + borderW
      py = borderY + borderH * edgeT
    elseif t < 0.75 then
      -- Bottom edge
      local edgeT = ((t - 0.5) / 0.25)
      px = borderX + borderW * (1 - edgeT)
      py = borderY + borderH
    else
      -- Left edge
      local edgeT = ((t - 0.75) / 0.25)
      px = borderX
      py = borderY + borderH * (1 - edgeT)
    end
    
    -- Calculate outward direction (away from center)
    local dx = px - barCenterX
    local dy = py - barCenterY
    local dist = math.sqrt(dx * dx + dy * dy)
    -- Normalize and use direction directly for outward movement
    if dist > 0 then
      dx = dx / dist
      dy = dy / dist
    end
    -- Angle points outward (same direction as vector from center to border)
    local angle = math.atan2(dy, dx)
    
    -- Add some randomness to the angle and speed
    -- Reduced by 40% so fragments don't travel as far
    local speed = (120 + love.math.random() * 80) * 0.6
    local angleOffset = (love.math.random() - 0.5) * 0.5
    local vx = math.cos(angle + angleOffset) * speed
    local vy = math.sin(angle + angleOffset) * speed
    
    -- Fragment length varies more and is 40% shorter, then 20% shorter again
    -- Base range is 8-20, reduced by 40% gives ~5-12, then 20% shorter gives ~4-9.6
    local baseLength = 8 + love.math.random() * 12
    local fragLength = baseLength * 0.6 * 0.8
    
    -- Add extra variation: some fragments are much shorter or slightly longer
    local variation = love.math.random()
    if variation < 0.3 then
      -- 30% chance: very short fragments
      fragLength = fragLength * (0.4 + love.math.random() * 0.3)
    elseif variation < 0.7 then
      -- 40% chance: medium fragments (no change)
      fragLength = fragLength * (0.9 + love.math.random() * 0.2)
    else
      -- 30% chance: slightly longer fragments
      fragLength = fragLength * (1.1 + love.math.random() * 0.3)
    end
    
    table.insert(fragments, {
      x = px,
      y = py,
      vx = vx,
      vy = vy,
      rotation = angle + math.pi * 0.5 + (love.math.random() - 0.5) * 0.3,
      rotationSpeed = (love.math.random() - 0.5) * 8,
      lifetime = 0.5,
      maxLifetime = 0.5,
      length = fragLength,
      progress = 1.0, -- Initialize progress
    })
  end
  
  return fragments
end

function BattleScene:onPlayerTurnEnd(turnScore, armor, isAOE)
  -- Check win/lose states via TurnManager
  local tmState = self.turnManager and self.turnManager:getState()
  if tmState == TurnManager.States.VICTORY or tmState == TurnManager.States.DEFEAT then return end
  if turnScore and turnScore > 0 then
    local dmg = math.floor(turnScore)
    
    -- Store damage info to apply after delay (merge with pending impact params if any)
    self._pendingPlayerAttackDamage = {
      damage = dmg,
      armor = armor or 0,
      isAOE = isAOE or false, -- Store AOE flag
      impactBlockCount = (self._pendingImpactParams and self._pendingImpactParams.blockCount) or 1,
      impactIsCrit = (self._pendingImpactParams and self._pendingImpactParams.isCrit) or false
    }
    self._pendingImpactParams = nil -- Clear after merging
    -- Trigger player attack sequence after delay
    self._playerAttackDelayTimer = (config.battle and config.battle.playerAttackDelay) or 1.0
    
    -- Queue incoming armor for TurnManager to handle (this happens immediately, visual effects are delayed)
    self.pendingArmor = armor or 0
    self.armorPopupShown = false
  end
end

function BattleScene:applyHealing(amount)
  if not amount or amount <= 0 then return end
  -- Heal player (clamp to max HP)
  local maxHP = config.battle.playerMaxHP
  self.playerHP = math.min(maxHP, self.playerHP + amount)
  
  -- Show healing popup
  table.insert(self.popups, { x = 0, y = 0, kind = "heal", value = amount, t = config.battle.popupLifetime, who = "player" })
end

function BattleScene:update(dt, bounds)
  -- Cache latest bounds for positioning helper usage from other methods
  self._lastBounds = bounds or self._lastBounds

  -- Update enemy flash timers
  for _, enemy in ipairs(self.enemies or {}) do
    if enemy.flash > 0 then enemy.flash = math.max(0, enemy.flash - dt) end
  end
  
  -- Check if player was just hit (flash transitioned from 0 to positive)
  if self.prevPlayerFlash == 0 and self.playerFlash > 0 then
    -- Player was just hit, create splatter effect
    ImpactSystem.createPlayerSplatter(self, self._lastBounds)
  end
  self.prevPlayerFlash = self.playerFlash
  
  if self.playerFlash > 0 then self.playerFlash = math.max(0, self.playerFlash - dt) end
  
  -- Update impact system (slashes, flashes, knockback)
  ImpactSystem.update(self, dt)
  
  -- Update particle system
  if self.particles then
    self.particles:update(dt)
  end
  
  -- Sync PlayerState with BattleScene's playerHP (for top bar display)
  local playerState = PlayerState.getInstance()
  playerState:setHealth(self.playerHP)
  
  -- Tween HP bars toward actual HP values
  local hpTweenSpeed = (config.battle and config.battle.hpBarTweenSpeed) or 8
  -- Player HP bar tween (exponential interpolation)
  local playerDelta = self.playerHP - (self.displayPlayerHP or self.playerHP)
  if math.abs(playerDelta) > 0.01 then
    local k = math.min(1, hpTweenSpeed * dt) -- Fraction to move this frame
    self.displayPlayerHP = (self.displayPlayerHP or self.playerHP) + playerDelta * k
  else
    self.displayPlayerHP = self.playerHP
  end
  
  -- Enemy HP bar tween (exponential interpolation) - iterate through all enemies
  for _, enemy in ipairs(self.enemies or {}) do
    local enemyDelta = enemy.hp - (enemy.displayHP or enemy.hp)
  if math.abs(enemyDelta) > 0.01 then
    local k = math.min(1, hpTweenSpeed * dt) -- Fraction to move this frame
      enemy.displayHP = (enemy.displayHP or enemy.hp) + enemyDelta * k
  else
      enemy.displayHP = enemy.hp
    end
  end
  
  -- Check if enemies should start disintegrating (safeguard for any code path)
  -- Only auto-start if no impact animations are active and disintegration isn't pending
  -- Also check that disintegration hasn't already completed (to prevent looping)
  for _, enemy in ipairs(self.enemies or {}) do
    if enemy.hp <= 0 and not enemy.disintegrating and not enemy.pendingDisintegration and self.state ~= "win" then
      -- Check if disintegration has already completed (prevent restarting)
      local cfg = config.battle.disintegration or {}
      local duration = cfg.duration or 1.5
      local hasCompletedDisintegration = (enemy.disintegrationTime or 0) >= duration
      
      if not hasCompletedDisintegration then
        local impactsActive = (self.impactInstances and #self.impactInstances > 0)
        if impactsActive then
          -- Wait for impact animations to finish
          enemy.pendingDisintegration = true
        else
          -- No impacts, start disintegration immediately
          enemy.disintegrating = true
          enemy.disintegrationTime = 0
        end
      end
    end
  end
  
  -- Update enemy disintegration effects
  for _, enemy in ipairs(self.enemies or {}) do
    if enemy.disintegrating then
    local cfg = config.battle.disintegration or {}
    local duration = cfg.duration or 1.5
      enemy.disintegrationTime = enemy.disintegrationTime + dt
      if enemy.disintegrationTime >= duration then
        enemy.disintegrating = false
        -- If this was the selected enemy, select next one
        if self.selectedEnemyIndex and self.enemies[self.selectedEnemyIndex] == enemy then
          self:_selectNextEnemy()
        end
      end
    end
  end
  
  -- Check victory condition: all enemies must be defeated
  local allEnemiesDefeated = true
  local anyDisintegrating = false
  local anyPendingDisintegration = false
  for _, enemy in ipairs(self.enemies or {}) do
    if enemy.hp > 0 and not enemy.disintegrating then
      allEnemiesDefeated = false
    end
    if enemy.disintegrating then
      anyDisintegrating = true
    end
    if enemy.pendingDisintegration then
      anyPendingDisintegration = true
    end
  end
  
  if allEnemiesDefeated and self.state ~= "win" then
    -- All enemies defeated, wait for disintegration animations if needed
    -- Also wait for pending disintegrations (enemies waiting for impact animations)
    if not anyDisintegrating and not anyPendingDisintegration then
      self.state = "win"
    end
  end
  
  -- Update turn indicator delay
  if self.turnIndicatorDelay > 0 then
    self.turnIndicatorDelay = self.turnIndicatorDelay - dt
    if self.turnIndicatorDelay <= 0 then
      -- Delay finished, show the pending indicator
      if self._pendingTurnIndicator then
        self.turnIndicator = self._pendingTurnIndicator
        self._pendingTurnIndicator = nil
        -- Notify TurnManager that the indicator is now visible
        if self.turnManager and self.turnManager.emit then
          self.turnManager:emit("turn_indicator_shown", { text = self.turnIndicator.text })
        end
      end
      self.turnIndicatorDelay = 0
    end
  end
  
  -- Update turn indicator
  if self.turnIndicator then
    self.turnIndicator.t = self.turnIndicator.t - dt
    if self.turnIndicator.t <= 0 then
      self.turnIndicator = nil
    end
  end
  
  -- Popups
  local alive = {}
  for _, p in ipairs(self.popups) do
    p.t = p.t - dt
    if p.t > 0 then table.insert(alive, p) end
  end
  self.popups = alive
  
  -- Update armor icon flash timer
  if self.armorIconFlashTimer > 0 then
    self.armorIconFlashTimer = math.max(0, self.armorIconFlashTimer - dt)
  end
  
  -- Update border fragments and detect armor break/gain
  local armorBroken = (self.prevPlayerArmor or 0) > 0 and (self.playerArmor or 0) == 0
  local armorGained = (self.prevPlayerArmor or 0) == 0 and (self.playerArmor or 0) > 0
  
  if armorBroken and self.playerBarX and self.playerBarY and self.playerBarW and self.playerBarH then
    -- Create shatter fragments
    local gap = 3
    self.borderFragments = createBorderFragments(self.playerBarX, self.playerBarY, self.playerBarW, self.playerBarH, gap, 6)
  end
  
  -- Start fade-in animation when armor is gained
  if armorGained then
    self.borderFadeInTime = self.borderFadeInDuration
  end
  
  -- Update border fade-in timer
  if self.borderFadeInTime > 0 then
    self.borderFadeInTime = math.max(0, self.borderFadeInTime - dt)
  end
  
  self.prevPlayerArmor = self.playerArmor or 0
  
  -- Update fragments with easing
  local aliveFragments = {}
  for _, frag in ipairs(self.borderFragments) do
    frag.lifetime = frag.lifetime - dt
    if frag.lifetime > 0 then
      -- Easing: calculate progress (0 to 1, where 1 is just spawned, 0 is about to disappear)
      local progress = frag.lifetime / frag.maxLifetime
      
      -- Ease-out for velocity (fragments slow down over time)
      local easeOut = progress * progress -- Quadratic ease-out
      local velScale = 0.3 + easeOut * 0.7 -- Start at 100% speed, end at 30% speed
      
      frag.x = frag.x + frag.vx * dt * velScale
      frag.y = frag.y + frag.vy * dt * velScale
      frag.rotation = frag.rotation + frag.rotationSpeed * dt * (0.5 + progress * 0.5) -- Rotation also slows
      
      -- Store progress for alpha calculation in draw
      frag.progress = progress
      
      table.insert(aliveFragments, frag)
    end
  end
  self.borderFragments = aliveFragments

  -- Handle enemy turn delay (for armor popup timing and player attack completion)
  if self._enemyTurnDelay and self._enemyTurnDelay > 0 then
    self._enemyTurnDelay = self._enemyTurnDelay - dt
    
    -- Check if player attack animation is still active
    local playerAttackActive = (self.playerLungeTime and self.playerLungeTime > 0) or false
    
    if playerAttackActive and self._pendingEnemyTurnStart then
      -- Player attack still playing, calculate remaining time
      local lungeD = (config.battle and config.battle.lungeDuration) or 0
      local lungeRD = (config.battle and config.battle.lungeReturnDuration) or 0
      local lungePause = (config.battle and config.battle.lungePauseDuration) or 0
      local totalLungeDuration = lungeD + lungePause + lungeRD
      local remainingTime = totalLungeDuration - (self.playerLungeTime or 0)
      
      -- Reset delay to wait for remaining animation time + small buffer
      if remainingTime > 0 then
        self._enemyTurnDelay = remainingTime + 0.1
      end
    end
    
    if self._enemyTurnDelay <= 0 then
      self._enemyTurnDelay = nil
      self._pendingEnemyTurnStart = false
      if self.turnManager then
        self.turnManager:startEnemyTurn()
      end
    end
  end

  -- Update shockwave sequence
  self:_updateShockwaveSequence(dt)

  -- Handle staggered enemy attack delays
  -- Don't process staggered attacks while shockwave sequence is active
  local shockwaveActive = self._shockwaveSequence ~= nil
  local aliveAttackDelays = {}
  for _, delayData in ipairs(self._enemyAttackDelays or {}) do
    if shockwaveActive then
      -- Shockwave is active, don't count down - just keep the delay data
      table.insert(aliveAttackDelays, delayData)
    else
      delayData.delay = delayData.delay - dt
      if delayData.delay <= 0 then
        -- Perform attack for this enemy
        local enemy = self.enemies[delayData.index]
        if enemy and enemy.hp > 0 then
          local dmg = love.math.random(enemy.damageMin, enemy.damageMax)
          local blocked = math.min(self.playerArmor or 0, dmg)
          local net = dmg - blocked
          self.playerArmor = math.max(0, (self.playerArmor or 0) - blocked)
          self.playerHP = math.max(0, self.playerHP - net)
          
          if net <= 0 then
            self.armorIconFlashTimer = 0.5
            table.insert(self.popups, { x = 0, y = 0, kind = "armor_blocked", t = config.battle.popupLifetime, who = "player" })
          else
            self.playerFlash = config.battle.hitFlashDuration
            self.playerKnockbackTime = 1e-6
            table.insert(self.popups, { x = 0, y = 0, text = tostring(net), t = config.battle.popupLifetime, who = "player" })
            pushLog(self, "Enemy " .. delayData.index .. " dealt " .. net)
            -- Emit hit burst particles from player center
            if self.particles then
              local px, py = self:getPlayerCenterPivot(self._lastBounds)
              if px and py then
                self.particles:emitHitBurst(px, py) -- Uses default colors between FFE7B3 and D79752
              end
            end
            if self.onPlayerDamage then
              self.onPlayerDamage()
            end
          end
          enemy.lungeTime = 1e-6
          self:triggerShake((config.battle and config.battle.shakeMagnitude) or 10, (config.battle and config.battle.shakeDuration) or 0.25)
          
          if self.playerHP <= 0 then
            self.state = "lose"
            pushLog(self, "You were defeated!")
            if self.turnManager then
              self.turnManager:transitionTo(TurnManager.States.DEFEAT)
            end
          end
        end
      else
        table.insert(aliveAttackDelays, delayData)
      end
    end
  end
  self._enemyAttackDelays = aliveAttackDelays

  -- Handle player attack delay (between ball despawn and attack animation)
  if self._playerAttackDelayTimer and self._playerAttackDelayTimer > 0 then
    self._playerAttackDelayTimer = self._playerAttackDelayTimer - dt
    if self._playerAttackDelayTimer <= 0 then
      self._playerAttackDelayTimer = nil
      
      -- Apply pending damage and visual effects
      if self._pendingPlayerAttackDamage then
        local dmg = self._pendingPlayerAttackDamage.damage
        local armor = self._pendingPlayerAttackDamage.armor
        local isAOE = self._pendingPlayerAttackDamage.isAOE or false
        local impactBlockCount = self._pendingPlayerAttackDamage.impactBlockCount or 1
        local impactIsCrit = self._pendingPlayerAttackDamage.impactIsCrit or false
        
        -- Create impact sprite animations first (before damage effects)
        -- Pass AOE flag so impacts appear at all enemy positions
        if impactBlockCount and impactBlockCount > 0 then
          self:_createImpactInstances(impactBlockCount, impactIsCrit, isAOE)
        end
        
        -- Apply damage to all enemies if AOE, otherwise just selected enemy
        if isAOE then
          -- AOE attack: damage all enemies
          for i, enemy in ipairs(self.enemies or {}) do
            if enemy and enemy.hp > 0 then
              enemy.hp = math.max(0, enemy.hp - dmg)
              
              -- Trigger enemy hit visual effects (flash, knockback, popup)
              enemy.flash = config.battle.hitFlashDuration
              enemy.knockbackTime = 1e-6
              table.insert(self.popups, { x = 0, y = 0, text = tostring(dmg), t = config.battle.popupLifetime, who = "enemy", enemyIndex = i })
              -- Emit hit burst particles from enemy center
              if self.particles then
                local ex, ey = self:getEnemyCenterPivot(i, self._lastBounds)
                if ex and ey then
                  self.particles:emitHitBurst(ex, ey, nil, impactIsCrit) -- Uses default colors, crit mode if applicable
                end
              end
              
              -- Check if enemy is defeated
              if enemy.hp <= 0 then
                -- Check if disintegration has already completed (prevent restarting)
                local cfg = config.battle.disintegration or {}
                local duration = cfg.duration or 1.5
                local hasCompletedDisintegration = (enemy.disintegrationTime or 0) >= duration
                
                if not hasCompletedDisintegration then
                  -- Check if impact animations are still playing
                  local impactsActive = (self.impactInstances and #self.impactInstances > 0)
                  if impactsActive then
                    -- Wait for impact animations to finish before starting disintegration
                    enemy.pendingDisintegration = true
                    pushLog(self, "Enemy " .. i .. " defeated!")
                  else
                    -- Start disintegration effect immediately if no impacts
                    if not enemy.disintegrating then
                      enemy.disintegrating = true
                      enemy.disintegrationTime = 0
                      pushLog(self, "Enemy " .. i .. " defeated!")
                    end
                  end
                end
              end
            end
          end
          pushLog(self, "You dealt " .. dmg .. " to all enemies!")
        else
          -- Normal attack: damage only selected enemy
        local selectedEnemy = self:getSelectedEnemy()
        if selectedEnemy then
          local i = self.selectedEnemyIndex
          if selectedEnemy.hp > 0 then
            selectedEnemy.hp = math.max(0, selectedEnemy.hp - dmg)
        
            -- Trigger enemy hit visual effects (flash, knockback, popup)
            selectedEnemy.flash = config.battle.hitFlashDuration
            selectedEnemy.knockbackTime = 1e-6
            table.insert(self.popups, { x = 0, y = 0, text = tostring(dmg), t = config.battle.popupLifetime, who = "enemy", enemyIndex = i })
            -- Emit hit burst particles from enemy center
            if self.particles then
              local ex, ey = self:getEnemyCenterPivot(i, self._lastBounds)
              if ex and ey then
                self.particles:emitHitBurst(ex, ey, nil, impactIsCrit) -- Uses default colors, crit mode if applicable
              end
            end
        
            -- Check if enemy is defeated
            if selectedEnemy.hp <= 0 then
              -- Check if disintegration has already completed (prevent restarting)
              local cfg = config.battle.disintegration or {}
              local duration = cfg.duration or 1.5
              local hasCompletedDisintegration = (selectedEnemy.disintegrationTime or 0) >= duration
              
              if not hasCompletedDisintegration then
                -- Check if impact animations are still playing
                local impactsActive = (self.impactInstances and #self.impactInstances > 0)
                if impactsActive then
                  -- Wait for impact animations to finish before starting disintegration
                  selectedEnemy.pendingDisintegration = true
                  pushLog(self, "Enemy " .. i .. " defeated!")
                else
                  -- Start disintegration effect immediately if no impacts
                  if not selectedEnemy.disintegrating then
                    selectedEnemy.disintegrating = true
                    selectedEnemy.disintegrationTime = 0
                    pushLog(self, "Enemy " .. i .. " defeated!")
                  end
                end
              end
              
              -- Auto-select next enemy to the right when selected enemy dies
              self:_selectNextEnemy()
            end
          end
        end
        pushLog(self, "You dealt " .. dmg)
        end
        
        -- Clear pending damage
        self._pendingPlayerAttackDamage = nil
      end
      
      -- Also handle case where impact params exist but no damage (shouldn't happen, but be safe)
      if self._pendingImpactParams then
        self:_createImpactInstances(self._pendingImpactParams.blockCount, self._pendingImpactParams.isCrit)
        self._pendingImpactParams = nil
      end
      
      -- Trigger player lunge animation
      self.playerLungeTime = 1e-6
      -- Trigger screenshake
      self:triggerShake((config.battle and config.battle.shakeMagnitude) or 10, (config.battle and config.battle.shakeDuration) or 0.25)
    end
  end

  -- Delegate animation timers and streaks
  Animations.update(self, dt)

end

function BattleScene:triggerShake(mag, dur)
  self.shakeMagnitude = mag or 10
  self.shakeDuration = dur or 0.25
  self.shakeTime = self.shakeDuration
end

local function drawCenteredText(text, x, y, w)
  theme.printfWithOutline(text, x, y, w, "center", theme.colors.uiText[1], theme.colors.uiText[2], theme.colors.uiText[3], theme.colors.uiText[4], 2)
end

local function drawBarGlow(x, y, w, h, alpha)
  -- Draw white border around bar with 3px gap
  local gap = 3
  local radius = 8
  alpha = alpha or 1.0
  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x - gap, y - gap, w + gap * 2, h + gap * 2, radius, radius)
  love.graphics.setColor(1, 1, 1, 1)
end

local function drawBorderFragments(fragments)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(2)
  for _, frag in ipairs(fragments) do
    -- Use eased alpha fade (ease-out curve for smooth fade)
    local progress = frag.progress or (frag.lifetime / frag.maxLifetime)
    local easeOut = progress * progress -- Quadratic ease-out
    local alpha = easeOut -- Fade out smoothly
    
    if alpha > 0 then
      love.graphics.push()
      love.graphics.translate(frag.x, frag.y)
      love.graphics.rotate(frag.rotation)
      love.graphics.setColor(1, 1, 1, alpha)
      love.graphics.line(0, 0, frag.length, 0)
      love.graphics.pop()
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function BattleScene:draw(bounds)
  Visuals.draw(self, bounds)
  
  -- Draw particles (above sprites but below UI)
  if self.particles then
    self.particles:draw()
  end
  
  -- Draw top bar on top (z-order)
  if self.topBar then
    self.topBar:draw()
  end
end

-- (Jackpot API removed)

-- External API: show player turn indicator
function BattleScene:showPlayerTurn()
  -- Queue "PLAYER'S TURN" indicator with delay
  self._pendingTurnIndicator = { text = "PLAYER'S TURN", t = 1.0 }
  self.turnIndicatorDelay = 0.3
end

-- Generic API: show any turn indicator (used by TurnManager)
function BattleScene:showTurnIndicator(text, duration)
  text = text or "TURN"
  duration = duration or 1.0
  -- Clear any existing pending indicator to avoid conflicts
  self._pendingTurnIndicator = { text = text, t = duration }
  self.turnIndicatorDelay = 0.3
end

-- Perform enemy attack (called by TurnManager)
function BattleScene:performEnemyAttack(minDamage, maxDamage)
  -- Clear any existing attack delays
  self._enemyAttackDelays = {}
  
  -- Schedule attacks for all alive enemies with staggered delays
  local attackDelay = 0.5 -- Delay between consecutive enemy attacks (in seconds)
  for i, enemy in ipairs(self.enemies or {}) do
    if enemy.hp > 0 and enemy.displayHP > 0.1 then
      -- First enemy attacks immediately (handled below), others are delayed by 0.3s intervals
      if i == 1 then
        -- Check if enemy_1 (crawler) should do shockwave (30% chance)
        local isEnemy1 = enemy.spritePath == "enemy_1.png"
        local shouldShockwave = isEnemy1 and (love.math.random() < 0.3)
        
        if shouldShockwave then
          -- Perform shockwave attack
          self:performEnemyShockwave(enemy)
        else
          -- Perform normal attack
          local dmg = love.math.random(enemy.damageMin, enemy.damageMax)
          local blocked = math.min(self.playerArmor or 0, dmg)
          local net = dmg - blocked
          self.playerArmor = math.max(0, (self.playerArmor or 0) - blocked)
          self.playerHP = math.max(0, self.playerHP - net)
          
          -- If damage is fully blocked, show armor icon popup and flash icon
          if net <= 0 then
            self.armorIconFlashTimer = 0.5 -- Flash duration
            table.insert(self.popups, { x = 0, y = 0, kind = "armor_blocked", t = config.battle.popupLifetime, who = "player" })
          else
            self.playerFlash = config.battle.hitFlashDuration
            self.playerKnockbackTime = 1e-6
            table.insert(self.popups, { x = 0, y = 0, text = tostring(net), t = config.battle.popupLifetime, who = "player" })
            -- Emit hit burst particles from player center
            if self.particles then
              local px, py = self:getPlayerCenterPivot(self._lastBounds)
              if px and py then
                self.particles:emitHitBurst(px, py) -- Uses default colors between FFE7B3 and D79752
              end
            end
            pushLog(self, "Enemy " .. i .. " dealt " .. net)
            if self.onPlayerDamage then
              self.onPlayerDamage()
            end
          end
          -- Trigger enemy lunge animation
          enemy.lungeTime = 1e-6
          -- Trigger screenshake
          self:triggerShake((config.battle and config.battle.shakeMagnitude) or 10, (config.battle and config.battle.shakeDuration) or 0.25)
        end
      else
        -- Schedule delayed attack for subsequent enemies (0.3s delay between each enemy)
        table.insert(self._enemyAttackDelays, {
          index = i,
          delay = attackDelay * (i - 1) -- Each enemy attacks 0.3s after the previous one
        })
      end
    end
  end
  
  if self.playerHP <= 0 then
    self.state = "lose"
    pushLog(self, "You were defeated!")
    -- Notify TurnManager of defeat
    if self.turnManager then
      self.turnManager:transitionTo(TurnManager.States.DEFEAT)
    end
  else
    -- Armor is per-turn; cleared by TurnManager state transition
  end
  -- Clear pending armor state for next turn
  self.pendingArmor = 0
  self.armorPopupShown = false
end

-- Perform enemy shockwave attack (enemy_1 special ability)
function BattleScene:performEnemyShockwave(enemy)
  -- Start jump animation
  enemy.jumpTime = 1e-6
  
  -- Initialize shockwave sequence timer
  -- Sequence: jump (0.5s) -> screenshake (0.1s delay) -> damage (0.1s delay) -> blocks (0.1s delay)
  self._shockwaveSequence = {
    timer = 0,
    phase = "jump", -- jump -> screenshake -> damage -> blocks
    enemy = enemy,
  }
end

-- Update shockwave sequence (called from update loop)
function BattleScene:_updateShockwaveSequence(dt)
  if not self._shockwaveSequence then return end
  
  local seq = self._shockwaveSequence
  seq.timer = seq.timer + dt
  
  local jumpDuration = 0.5 -- 0.3s up + 0.2s down
  local screenshakeDelay = 0.1 -- Delay after jump lands
  local damageDelay = 0.1 -- Delay after screenshake
  local blocksDelay = 0.1 -- Delay after damage
  local blocksDropDuration = 0.6 -- Time for blocks to fully drop and fade
  
  if seq.phase == "jump" then
    -- Wait for jump to complete
    if seq.timer >= jumpDuration then
      seq.phase = "screenshake"
      seq.timer = 0
    end
  elseif seq.phase == "screenshake" then
    -- Trigger massive screenshake
    if seq.timer >= screenshakeDelay then
      self:triggerShake(30, 0.5) -- Much stronger shake than normal attack
      seq.phase = "damage"
      seq.timer = 0
    end
  elseif seq.phase == "damage" then
    -- Deal 6 damage to player
    if seq.timer >= damageDelay then
      local dmg = 6
      local blocked = math.min(self.playerArmor or 0, dmg)
      local net = dmg - blocked
      self.playerArmor = math.max(0, (self.playerArmor or 0) - blocked)
      self.playerHP = math.max(0, self.playerHP - net)
      
      -- Show damage popup
      if net <= 0 then
        self.armorIconFlashTimer = 0.5
        table.insert(self.popups, { x = 0, y = 0, kind = "armor_blocked", t = config.battle.popupLifetime, who = "player" })
      else
        self.playerFlash = config.battle.hitFlashDuration
        self.playerKnockbackTime = 1e-6
        table.insert(self.popups, { x = 0, y = 0, text = tostring(net), t = config.battle.popupLifetime, who = "player" })
        -- Emit hit burst particles from player center
        if self.particles then
          local px, py = self:getPlayerCenterPivot(self._lastBounds)
          if px and py then
            self.particles:emitHitBurst(px, py)
          end
        end
        pushLog(self, "Enemy shockwave dealt " .. net)
        if self.onPlayerDamage then
          self.onPlayerDamage()
        end
      end
      
      -- Check for defeat
      if self.playerHP <= 0 then
        self.state = "lose"
        pushLog(self, "You were defeated!")
        if self.turnManager then
          self.turnManager:transitionTo(TurnManager.States.DEFEAT)
        end
      end
      
      seq.phase = "blocks"
      seq.timer = 0
    end
  elseif seq.phase == "blocks" then
    -- Trigger block shake and drop effect
    if seq.timer >= blocksDelay then
      if self.turnManager then
        self.turnManager:emit("enemy_shockwave_blocks")
      end
      seq.phase = "waiting_for_blocks"
      seq.timer = 0
    end
  elseif seq.phase == "waiting_for_blocks" then
    -- Wait for blocks to finish dropping (0.6s total duration)
    if seq.timer >= blocksDropDuration then
      -- Sequence complete - now other enemies can attack
      self._shockwaveSequence = nil
    end
  end
end

-- Set TurnManager reference (called by SplitScene)
function BattleScene:setTurnManager(turnManager)
  self.turnManager = turnManager
  
  -- Subscribe to TurnManager events
  if turnManager then
    -- Show turn indicator event
    turnManager:on("show_turn_indicator", function(data)
      if data and data.text then
        self:showTurnIndicator(data.text, data.duration or 1.0)
      end
    end)
    
    -- Enemy attack event
    turnManager:on("enemy_attack", function(data)
      self:performEnemyAttack(data.min or config.battle.enemyDamageMin, data.max or config.battle.enemyDamageMax)
    end)
    
    -- Start enemy turn event - handle armor popup timing, then let TurnManager continue
    turnManager:on("start_enemy_turn", function()
      -- Don't start enemy turn if all enemies are already defeated
      local anyEnemyAlive = false
      for _, enemy in ipairs(self.enemies or {}) do
        if enemy.hp > 0 and enemy.displayHP > 0.1 then
          anyEnemyAlive = true
          break
        end
      end
      
      if not anyEnemyAlive or (turnManager:getState() == TurnManager.States.VICTORY) then
        return
      end
      
      -- Always wait for player attack animation to complete before starting enemy turn
      -- Calculate total player lunge duration (forward + pause + return)
      local lungeD = (config.battle and config.battle.lungeDuration) or 0
      local lungeRD = (config.battle and config.battle.lungeReturnDuration) or 0
      local lungePause = (config.battle and config.battle.lungePauseDuration) or 0
      local totalLungeDuration = lungeD + lungePause + lungeRD
      
      -- Check if player attack animation is still playing
      local playerAttackActive = (self.playerLungeTime and self.playerLungeTime > 0) or false
      
      if playerAttackActive then
        -- Player attack still playing, calculate remaining time
        local remainingTime = totalLungeDuration - (self.playerLungeTime or 0)
        -- Add a small buffer to ensure animation fully completes
        local buffer = 0.1
        local delay = math.max(0, remainingTime + buffer)
        
        -- Store pending enemy turn start flag
        self._pendingEnemyTurnStart = true
        
        -- Queue enemy turn start after player attack completes
        if (self.pendingArmor or 0) > 0 and not self.armorPopupShown then
          -- Show armor popup first, then wait for player attack + delay
          self.playerArmor = self.pendingArmor
          table.insert(self.popups, { x = 0, y = 0, kind = "armor", value = self.pendingArmor, t = config.battle.popupLifetime, who = "player" })
          self.armorPopupShown = true
          -- Wait for player attack + armor popup duration + post-armor delay
          local armorDelay = (config.battle.popupLifetime or 0.8) + (config.battle.enemyAttackPostArmorDelay or 0.3)
          self._enemyTurnDelay = delay + armorDelay
        else
          -- No armor, just wait for player attack to complete
          self._enemyTurnDelay = delay
        end
      else
        -- Player attack already complete, proceed normally
        if (self.pendingArmor or 0) > 0 and not self.armorPopupShown then
          self.playerArmor = self.pendingArmor
          table.insert(self.popups, { x = 0, y = 0, kind = "armor", value = self.pendingArmor, t = config.battle.popupLifetime, who = "player" })
          self.armorPopupShown = true
          -- Queue enemy turn start after armor popup duration + delay
          local delay = (config.battle.popupLifetime or 0.8) + (config.battle.enemyAttackPostArmorDelay or 0.3)
          self._enemyTurnDelay = delay
        else
          -- No armor, start enemy turn immediately
          turnManager:startEnemyTurn()
        end
      end
    end)
    
    -- State transitions
    turnManager:on("state_enter", function(newState, previousState)
      if newState == TurnManager.States.ENEMY_TURN_RESOLVING then
        -- After enemy turn resolves, reset armor and spawn blocks
        self.playerArmor = 0
        self.pendingArmor = 0
        self.armorPopupShown = false
      end
    end)
  end
end

-- Get currently selected enemy
function BattleScene:getSelectedEnemy()
  if self.selectedEnemyIndex and self.enemies and self.enemies[self.selectedEnemyIndex] then
    return self.enemies[self.selectedEnemyIndex]
  end
  return nil
end

-- Get player sprite center pivot position (for particle effects)
function BattleScene:getPlayerCenterPivot(bounds)
  local w = (bounds and bounds.w) or (self._lastBounds and self._lastBounds.w) or love.graphics.getWidth()
  local h = (bounds and bounds.h) or (self._lastBounds and self._lastBounds.h) or love.graphics.getHeight()
  local center = (bounds and bounds.center) or (self._lastBounds and self._lastBounds.center) or nil
  local centerX = center and center.x or math.floor(w * 0.5) - math.floor((w * 0.5) * 0.5)
  local leftWidth = math.max(0, centerX)
  local r = 24
  local yOffset = (config.battle and config.battle.positionOffsetY) or 0
  local baselineY = h * 0.55 + r + yOffset
  local playerX = (leftWidth > 0) and (leftWidth * 0.5) or (12 + r)
  
  -- Calculate player position with lunge/knockback offsets
  local function lungeOffset(t, pauseActive)
    if not t or t <= 0 then return 0 end
    local d = config.battle.lungeDuration or 0
    local rdur = config.battle.lungeReturnDuration or 0
    local dist = config.battle.lungeDistance or 0
    if t < d then
      return dist * (t / math.max(0.0001, d))
    elseif pauseActive and t < d + rdur then
      return dist
    elseif t < d + rdur then
      local tt = (t - d) / math.max(0.0001, rdur)
      return dist * (1 - tt)
    else
      return 0
    end
  end
  
  local function knockbackOffset(t)
    if not t or t <= 0 then return 0 end
    local d = config.battle.knockbackDuration or 0
    local rdur = config.battle.knockbackReturnDuration or 0
    local dist = config.battle.knockbackDistance or 0
    if t < d then
      return dist * (t / math.max(0.0001, d))
    elseif t < d + rdur then
      local tt = (t - d) / math.max(0.0001, rdur)
      return dist * (1 - tt)
    else
      return 0
    end
  end
  
  local playerLunge = lungeOffset(self.playerLungeTime, (self.impactInstances and #self.impactInstances > 0))
  local playerKB = knockbackOffset(self.playerKnockbackTime)
  local curPlayerX = playerX + playerLunge - playerKB
  
  -- Calculate player sprite visual center
  local playerScaleCfg = (config.battle and (config.battle.playerSpriteScale or config.battle.spriteScale)) or 1
  local playerScale = 1
  if self.playerImg then
    local ih = self.playerImg:getHeight()
    playerScale = ((2 * r) / math.max(1, ih)) * playerScaleCfg * (self.playerScaleMul or 1)
  end
  
  local playerSpriteHeight = self.playerImg and (self.playerImg:getHeight() * playerScale) or (r * 2)
  local playerSpriteCenterX = curPlayerX
  local playerSpriteCenterY = baselineY - playerSpriteHeight * 0.5
  
  return playerSpriteCenterX, playerSpriteCenterY
end

-- Get enemy sprite center pivot position (for particle effects)
function BattleScene:getEnemyCenterPivot(enemyIndex, bounds)
  if not enemyIndex or not self.enemies or not self.enemies[enemyIndex] then
    return nil, nil
  end
  
  local enemy = self.enemies[enemyIndex]
  local w = (bounds and bounds.w) or (self._lastBounds and self._lastBounds.w) or love.graphics.getWidth()
  local h = (bounds and bounds.h) or (self._lastBounds and self._lastBounds.h) or love.graphics.getHeight()
  local center = (bounds and bounds.center) or (self._lastBounds and self._lastBounds.center) or nil
  local centerX = center and center.x or math.floor(w * 0.5) - math.floor((w * 0.5) * 0.5)
  local centerW = center and center.w or math.floor(w * 0.5)
  local rightStart = centerX + centerW
  local rightWidth = math.max(0, w - rightStart)
  local r = 24
  local yOffset = (config.battle and config.battle.positionOffsetY) or 0
  local baselineY = h * 0.55 + r + yOffset
  
  -- Calculate enemy position dynamically (matching Visuals.lua logic)
  local enemyScales = {}
  local enemyWidths = {}
  local totalWidth = 0
  local battleProfile = self._battleProfile or {}
  local gapCfg = battleProfile.enemySpacing
  local enemyCount = #self.enemies
  local gap
  if type(gapCfg) == "table" then
    gap = gapCfg[enemyCount] or gapCfg.default or 0
  else
    gap = gapCfg or -20
  end
  
  for i, e in ipairs(self.enemies) do
    local scaleCfg = e.spriteScale or (config.battle and (config.battle.enemySpriteScale or config.battle.spriteScale)) or 4
    local scale = 1
    if e.img then
      local ih = e.img:getHeight()
      scale = ((2 * r) / math.max(1, ih)) * scaleCfg * (e.scaleMul or 1)
    end
    enemyScales[i] = scale
    enemyWidths[i] = e.img and (e.img:getWidth() * scale) or (r * 2)
    totalWidth = totalWidth + enemyWidths[i]
    if i < #self.enemies then
      totalWidth = totalWidth + gap
    end
  end
  
  local centerXPos = rightStart + rightWidth * 0.5
  local startX = centerXPos - totalWidth * 0.5 - 70 -- Shift enemies left by 70px
  
  -- Calculate X position for this enemy
  local enemyX = startX
  for j = 1, enemyIndex - 1 do
    enemyX = enemyX + enemyWidths[j] + gap
  end
  enemyX = enemyX + enemyWidths[enemyIndex] * 0.5
  
  -- Account for enemy lunge
  local function lungeOffset(enemy, t)
    if not t or t <= 0 then return 0 end
    local d = config.battle.lungeDuration or 0
    local rdur = config.battle.lungeReturnDuration or 0
    local dist = config.battle.lungeDistance or 0
    if t < d then
      return dist * (t / math.max(0.0001, d))
    elseif t < d + rdur then
      local tt = (t - d) / math.max(0.0001, rdur)
      return dist * (1 - tt)
    else
      return 0
    end
  end
  
  local enemyLunge = lungeOffset(enemy, enemy.lungeTime)
  local curEnemyX = enemyX - enemyLunge
  
  -- Calculate enemy sprite visual center
  local enemySpriteHeight = enemy.img and (enemy.img:getHeight() * enemyScales[enemyIndex]) or (r * 2)
  local spriteCenterX = curEnemyX
  local spriteCenterY = baselineY - enemySpriteHeight * 0.5
  
  return spriteCenterX, spriteCenterY
end

-- Select next enemy to the right (or wrap to first if at end)
function BattleScene:_selectNextEnemy()
  if not self.enemies or #self.enemies == 0 then
    self.selectedEnemyIndex = nil
    return
  end
  
  -- Find next alive enemy to the right
  local startIndex = self.selectedEnemyIndex or 1
  for i = 1, #self.enemies do
    local checkIndex = ((startIndex + i - 1) % #self.enemies) + 1
    local enemy = self.enemies[checkIndex]
    if enemy and (enemy.hp > 0 or enemy.disintegrating or enemy.pendingDisintegration) then
      self.selectedEnemyIndex = checkIndex
      return
    end
  end
  
  -- No alive enemies found
  self.selectedEnemyIndex = nil
end

-- Compute hit points for all enemies (screen coordinates), matching draw layout
-- Returns array of {x, y, enemyIndex} for all alive enemies
function BattleScene:getAllEnemyHitPoints(bounds)
  local hitPoints = {}
  local w = (bounds and bounds.w) or love.graphics.getWidth()
  local h = (bounds and bounds.h) or love.graphics.getHeight()
  local center = bounds and bounds.center or nil
  local centerX = center and center.x or math.floor(w * 0.5) - math.floor((w * 0.5) * 0.5)
  local centerW = center and center.w or math.floor(w * 0.5)
  local leftWidth = math.max(0, centerX)
  local rightStart = centerX + centerW
  local rightWidth = math.max(0, w - rightStart)
  local r = 24
  local yOffset = (config.battle and config.battle.positionOffsetY) or 0
  local baselineY = h * 0.55 + r + yOffset
  
  if not self.enemies or #self.enemies == 0 then
    return hitPoints
  end
  
  -- Calculate enemy positions dynamically (matching Visuals.lua logic)
  local enemyScales = {}
  local enemyWidths = {}
  local totalWidth = 0
  local battleProfile = self._battleProfile or {}
  local gapCfg = battleProfile.enemySpacing
  local enemyCount = #self.enemies
  local gap
  if type(gapCfg) == "table" then
    gap = gapCfg[enemyCount] or gapCfg.default or 0
  else
    gap = gapCfg or -20
  end
  
  for i, e in ipairs(self.enemies) do
    local scaleCfg = e.spriteScale or (config.battle and (config.battle.enemySpriteScale or config.battle.spriteScale)) or 4
    local scale = 1
    if e.img then
      local ih = e.img:getHeight()
      scale = ((2 * r) / math.max(1, ih)) * scaleCfg * (e.scaleMul or 1)
    end
    enemyScales[i] = scale
    enemyWidths[i] = e.img and (e.img:getWidth() * scale) or (r * 2)
    totalWidth = totalWidth + enemyWidths[i]
    if i < #self.enemies then
      totalWidth = totalWidth + gap
    end
  end
  
  local centerXPos = rightStart + rightWidth * 0.5
  local startX = centerXPos - totalWidth * 0.5 - 70 -- Shift enemies left by 70px (matching Visuals.lua)
  
  -- Account for current lunge
  local function lungeOffset(enemy, t)
    if not t or t <= 0 then return 0 end
    local d = config.battle.lungeDuration or 0
    local rdur = config.battle.lungeReturnDuration or 0
    local dist = config.battle.lungeDistance or 0
    if t < d then
      return dist * (t / math.max(0.0001, d))
    elseif t < d + rdur then
      local tt = (t - d) / math.max(0.0001, rdur)
      return dist * (1 - tt)
    else
      return 0
    end
  end
  
  -- Get hit points for all alive enemies
  for i, enemy in ipairs(self.enemies) do
    if enemy and (enemy.hp > 0 or enemy.disintegrating or enemy.pendingDisintegration) then
      -- Calculate X position for this enemy
      local enemyX = startX
      for j = 1, i - 1 do
        enemyX = enemyX + enemyWidths[j] + gap
      end
      enemyX = enemyX + enemyWidths[i] * 0.5
      
      local enemyLunge = lungeOffset(enemy, enemy.lungeTime)
      local curEnemyX = enemyX - enemyLunge
      
      -- Aim mid-height of sprite if available; else circle center
      local enemyHalfH = r
      if enemy.img then
        enemyHalfH = (enemy.img:getHeight() * enemyScales[i]) * 0.5
      end
      local hitX = curEnemyX
      local hitY = baselineY - enemyHalfH * 0.7 -- slightly above center
      
      table.insert(hitPoints, { x = hitX, y = hitY, enemyIndex = i })
    end
  end
  
  return hitPoints
end

-- Compute current enemy hit point (screen coordinates), matching draw layout
-- Returns hit point for selected enemy
function BattleScene:getEnemyHitPoint(bounds)
  local w = (bounds and bounds.w) or love.graphics.getWidth()
  local h = (bounds and bounds.h) or love.graphics.getHeight()
  local center = bounds and bounds.center or nil
  local centerX = center and center.x or math.floor(w * 0.5) - math.floor((w * 0.5) * 0.5)
  local centerW = center and center.w or math.floor(w * 0.5)
  local leftWidth = math.max(0, centerX)
  local rightStart = centerX + centerW
  local rightWidth = math.max(0, w - rightStart)
  local r = 24
  local yOffset = (config.battle and config.battle.positionOffsetY) or 0
  local baselineY = h * 0.55 + r + yOffset
  
  -- Get selected enemy position (or first enemy as fallback)
  local selectedEnemy = self:getSelectedEnemy()
  if selectedEnemy and self.enemies and #self.enemies > 0 then
    local enemy = selectedEnemy
    local enemyIndex = self.selectedEnemyIndex
    -- Calculate enemy position dynamically (matching Visuals.lua logic)
    local enemyScales = {}
    local enemyWidths = {}
    local totalWidth = 0
    local battleProfile = self._battleProfile or {}
    local gapCfg = battleProfile.enemySpacing
    local enemyCount = #self.enemies
    local gap
    if type(gapCfg) == "table" then
      gap = gapCfg[enemyCount] or gapCfg.default or 0
    else
      gap = gapCfg or -20
    end
    
    for i, e in ipairs(self.enemies) do
      local scaleCfg = e.spriteScale or (config.battle and (config.battle.enemySpriteScale or config.battle.spriteScale)) or 4
      local scale = 1
      if e.img then
        local ih = e.img:getHeight()
        scale = ((2 * r) / math.max(1, ih)) * scaleCfg * (e.scaleMul or 1)
      end
      enemyScales[i] = scale
      enemyWidths[i] = e.img and (e.img:getWidth() * scale) or (r * 2)
      totalWidth = totalWidth + enemyWidths[i]
      if i < #self.enemies then
        totalWidth = totalWidth + gap
      end
    end
    
    local centerX = rightStart + rightWidth * 0.5
    local startX = centerX - totalWidth * 0.5 - 70 -- Shift enemies left by 70px (matching Visuals.lua)
    
    -- Calculate X position for the selected enemy
    local enemyX = startX
    for i = 1, enemyIndex - 1 do
      enemyX = enemyX + enemyWidths[i] + gap
    end
    enemyX = enemyX + enemyWidths[enemyIndex] * 0.5

  -- Account for current lunge
  local function lungeOffset(t)
    if not t or t <= 0 then return 0 end
    local d = config.battle.lungeDuration or 0
    local rdur = config.battle.lungeReturnDuration or 0
    local dist = config.battle.lungeDistance or 0
    if t < d then
      return dist * (t / math.max(0.0001, d))
    elseif t < d + rdur then
      local tt = (t - d) / math.max(0.0001, rdur)
      return dist * (1 - tt)
    else
      return 0
    end
  end
    local enemyLunge = lungeOffset(enemy.lungeTime)
  local curEnemyX = enemyX - enemyLunge

    -- Aim mid-height of sprite if available; else circle center
    local enemyHalfH = r
    if enemy.img then
      local ih = enemy.img:getHeight()
      enemyHalfH = (enemy.img:getHeight() * enemyScales[enemyIndex]) * 0.5
    end
    local hitX = curEnemyX
    local hitY = baselineY - enemyHalfH * 0.7 -- slightly above center
    return hitX, hitY
  else
    -- Fallback if no enemies
    local enemyX = (rightWidth > 0) and (rightStart + rightWidth * 0.5) or (w - 12 - r)
    return enemyX, baselineY - r * 0.7
  end
end

-- Trigger the impact animation at the current enemy hit point
-- blockCount: number of blocks hit (1-4+, determines how many impact sprites to spawn)
-- isCrit: if true, spawn 5 staggered slashes regardless of block count
function BattleScene:playImpact(blockCount, isCrit)
  if not self.impactAnimation then return end
  blockCount = blockCount or 1
  isCrit = isCrit or false
  
  -- Store impact parameters to be applied after delay
  self._pendingImpactParams = {
    blockCount = blockCount,
    isCrit = isCrit
  }
  
  -- Set delay timer if not already set (onPlayerTurnEnd will also set it, but this ensures it's set even if onPlayerTurnEnd isn't called)
  if not self._playerAttackDelayTimer then
    self._playerAttackDelayTimer = (config.battle and config.battle.playerAttackDelay) or 1.0
  end
  self.impactEffectsPlayed = true
end

-- Internal helper to actually create impact instances (called after delay)
function BattleScene:_createImpactInstances(blockCount, isCrit, isAOE)
  if not self.impactAnimation then return end
  ImpactSystem.create(self, blockCount or 1, isCrit or false, isAOE or false)
end

-- Handle keyboard input for enemy selection
function BattleScene:keypressed(key, scancode, isRepeat)
  if key == "k" and not isRepeat then
    self:_cheatDefeatAllEnemies()
    return
  end
  if key == "tab" then
    -- Cycle to next enemy
    self:_cycleEnemySelection()
  end
end

function BattleScene:_cheatDefeatAllEnemies()
  if self.state == "win" or self.state == "lose" then
    return
  end

  local anyDefeated = false
  local disintegrationCfg = (config.battle and config.battle.disintegration) or {}
  local impactsActive = self.impactInstances and #self.impactInstances > 0

  for index, enemy in ipairs(self.enemies or {}) do
    if enemy and (enemy.hp or 0) > 0 then
      enemy.hp = 0
      enemy.displayHP = 0
      enemy.flash = 0
      enemy.knockbackTime = 0
      enemy.pendingDisintegration = false

      local duration = disintegrationCfg.duration or 1.5
      if enemy.disintegrating then
        enemy.disintegrationTime = enemy.disintegrationTime or 0
      elseif (enemy.disintegrationTime or 0) >= duration then
        enemy.disintegrating = false
      elseif impactsActive then
        enemy.pendingDisintegration = true
      else
        enemy.disintegrating = true
        enemy.disintegrationTime = 0
      end

      pushLog(self, string.format("Cheat: Enemy %d defeated instantly", index))
      anyDefeated = true
    end
  end

  if anyDefeated then
    self:_selectNextEnemy()
  end
end

-- Cycle enemy selection to the next alive enemy
function BattleScene:_cycleEnemySelection()
  if not self.enemies or #self.enemies == 0 then
    self.selectedEnemyIndex = nil
    return
  end
  
  local startIndex = self.selectedEnemyIndex or 1
  -- Find next alive enemy (start from next index, wrapping around)
  for i = 1, #self.enemies do
    local checkIndex = ((startIndex + i - 1) % #self.enemies) + 1
    -- Skip the current enemy
    if checkIndex == startIndex then
      checkIndex = ((startIndex + i) % #self.enemies) + 1
    end
    local enemy = self.enemies[checkIndex]
    if enemy and (enemy.hp > 0 or enemy.disintegrating or enemy.pendingDisintegration) then
      self.selectedEnemyIndex = checkIndex
      return
    end
  end
  
  -- No other alive enemies found, keep current selection or set to nil
  if self.selectedEnemyIndex then
    local currentEnemy = self.enemies[self.selectedEnemyIndex]
    if not currentEnemy or (currentEnemy.hp <= 0 and not currentEnemy.disintegrating and not currentEnemy.pendingDisintegration) then
      self.selectedEnemyIndex = nil
    end
  end
end

-- Handle mouse clicks for enemy selection
function BattleScene:mousepressed(x, y, button, bounds)
  if button ~= 1 then return end -- Only handle left mouse button
  
  -- Get enemy positions to check which one was clicked
  local w = (bounds and bounds.w) or love.graphics.getWidth()
  local h = (bounds and bounds.h) or love.graphics.getHeight()
  local center = bounds and bounds.center or nil
  local centerX = center and center.x or math.floor(w * 0.5) - math.floor((w * 0.5) * 0.5)
  local centerW = center and center.w or math.floor(w * 0.5)
  local rightStart = centerX + centerW
  local rightWidth = math.max(0, w - rightStart)
  local r = 24
  local yOffset = (config.battle and config.battle.positionOffsetY) or 0
  local baselineY = h * 0.55 + r + yOffset
  
  -- Calculate enemy positions (matching Visuals.lua logic)
  local enemyPositions = {}
  local battleProfile = self._battleProfile or {}
  local gapCfg = battleProfile.enemySpacing
  local enemyCount = #self.enemies
  local gap
  if type(gapCfg) == "table" then
    gap = gapCfg[enemyCount] or gapCfg.default or 0
  else
    gap = gapCfg or -20
  end
  local enemyScales = {}
  local enemyWidths = {}
  local totalWidth = 0
  
  for i, enemy in ipairs(self.enemies or {}) do
    local scaleCfg = enemy.spriteScale or (config.battle and (config.battle.enemySpriteScale or config.battle.spriteScale)) or 4
    local scale = 1
    if enemy.img then
      local ih = enemy.img:getHeight()
      scale = ((2 * r) / math.max(1, ih)) * scaleCfg * (enemy.scaleMul or 1)
    end
    enemyScales[i] = scale
    enemyWidths[i] = enemy.img and (enemy.img:getWidth() * scale) or (r * 2)
    totalWidth = totalWidth + enemyWidths[i]
    if i < #self.enemies then
      totalWidth = totalWidth + gap
    end
  end
  
  local centerXPos = rightStart + rightWidth * 0.5
  local startX = centerXPos - totalWidth * 0.5 - 70 -- Shift enemies left by 70px (matching Visuals.lua)
  
  -- Check enemies in reverse order (right to left) so rightmost enemy gets priority when overlapping
  for i = #self.enemies, 1, -1 do
    local enemy = self.enemies[i]
    if not enemy then goto continue end
    
    -- Calculate currentX position for this enemy (matching Visuals.lua logic exactly)
    local currentX = startX
    for j = 1, i - 1 do
      currentX = currentX + enemyWidths[j] + (j < #self.enemies and gap or 0)
    end
    
    -- Calculate enemy X position (matching Visuals.lua logic exactly)
    local enemyX = currentX + enemyWidths[i] * 0.5
    local enemyHalfW = enemyWidths[i] * 0.5
    local enemyHalfH = enemy.img and ((enemy.img:getHeight() * enemyScales[i]) * 0.5) or r
    
    -- Account for enemy lunge animation offset (enemies can move during attacks)
    local enemyLunge = 0
    if enemy.lungeTime and enemy.lungeTime > 0 then
      local lungeD = config.battle.lungeDuration or 0
      local lungeRD = config.battle.lungeReturnDuration or 0
      local lungeDist = config.battle.lungeDistance or 0
      if enemy.lungeTime < lungeD then
        enemyLunge = lungeDist * (enemy.lungeTime / math.max(0.0001, lungeD))
      elseif enemy.lungeTime < lungeD + lungeRD then
        local tt = (enemy.lungeTime - lungeD) / math.max(0.0001, lungeRD)
        enemyLunge = lungeDist * (1 - tt)
      end
    end
    local curEnemyX = enemyX - enemyLunge
    
    -- Check if click is within enemy bounds (with some padding)
    local clickPadding = 30 -- Increased padding for easier clicking
    if x >= curEnemyX - enemyHalfW - clickPadding and 
       x <= curEnemyX + enemyHalfW + clickPadding and
       y >= baselineY - enemyHalfH * 2 - clickPadding and
       y <= baselineY + clickPadding then
      -- Clicked on this enemy, select it if it's alive
      if enemy.hp > 0 or enemy.disintegrating or enemy.pendingDisintegration then
        self.selectedEnemyIndex = i
        return
      end
    end
    
    ::continue::
  end
end

return BattleScene



