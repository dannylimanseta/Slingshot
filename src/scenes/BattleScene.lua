local config = require("config")
local theme = require("theme")
local Bar = require("ui.Bar")
local SpriteAnimation = require("utils.SpriteAnimation")
local DisintegrationShader = require("utils.DisintegrationShader")
local WhiteSilhouetteShader = require("utils.WhiteSilhouetteShader")
local FogShader = require("utils.FogShader")
local ImpactSystem = require("scenes.battle.ImpactSystem")
local Visuals = require("scenes.battle.Visuals")
local EnemySkills = require("scenes.battle.EnemySkills")
local EnemyIntents = require("scenes.battle.EnemyIntents")
local StateBridge = require("scenes.battle.StateBridge")
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
    id = enemyConfig.id, -- Enemy identifier (e.g., "bloodhound")
    hp = enemyConfig.maxHP,
    maxHP = enemyConfig.maxHP,
    displayHP = enemyConfig.maxHP, -- Display HP for smooth tweening
    img = nil, -- Loaded in load() function
    flash = 0,
    knockbackTime = 0,
    lungeTime = 0, -- Jump animation timer (for shockwave attack)
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
    intent = nil, -- Enemy intent for next turn: { type = "attack"|"armor"|"skill", ... }
    -- Enrage FX state (for enemies like Bloodhound)
    enrageLevel = 0,       -- 0 = normal, 1 = first enrage, 2 = second enrage
    enrageFxTime = 0,      -- Timer for enrage FX animation
    enrageFxActive = false,-- Whether enrage FX is currently playing
  }
end

-- Returns true while enemy attacks/sequences are still running
function BattleScene:areEnemyAttacksActive()
  -- Any staggered enemy attacks pending?
  if self._enemyAttackDelays and #self._enemyAttackDelays > 0 then
    return true
  end
  -- Any special sequences active?
  if self._shockwaveSequence or self._calcifySequence or self._healSequence or self._sporeSequence then
    return true
  end
  -- Any enemy lunge/jump/knockback in progress?
  for _, enemy in ipairs(self.enemies or {}) do
    if (enemy.lungeTime and enemy.lungeTime > 0) or (enemy.jumpTime and enemy.jumpTime > 0) or (enemy.knockbackTime and enemy.knockbackTime > 0) or (enemy.chargeLungeTime and enemy.chargeLungeTime > 0) then
      return true
    end
    -- Check for active multi-hit attacks
    if enemy.multiHitState then
      return true
    end
  end
  return false
end

-- Helper: Get hit count for an enemy (for multi-hit attacks like Bloodhound)
function BattleScene:_getEnemyHitCount(enemy, intent)
  -- For Bloodhound, always recalculate from current HP
  if enemy.id == "bloodhound" or enemy.name == "Bloodhound" then
    local hpPercent = enemy.maxHP and enemy.maxHP > 0 and (enemy.hp / enemy.maxHP) or 1
    if hpPercent < 0.25 then
      return 3
    elseif hpPercent < 0.5 then
      return 2
    else
      return 1
    end
  end
  -- Other enemies: use intent.hits if available
  return (intent and intent.hits) or 1
end

-- Helper: Apply multi-hit damage to player with staggered timing
function BattleScene:_applyMultiHitDamage(enemy, damage, hitCount, enemyIndex)
  hitCount = math.max(1, hitCount or 1)
  
  -- For multi-hit attacks, queue each hit with a small delay
  if hitCount > 1 then
    -- Store multi-hit state on enemy
    enemy.multiHitState = {
      damage = damage,
      remainingHits = hitCount,
      currentHit = 0,
      delay = 0.35, -- 0.35 seconds between hits (increased for visibility)
      timer = 0,
      enemyIndex = enemyIndex,
    }
  else
    -- Single hit - apply immediately
    local blocked, net = self:_applyPlayerDamage(damage)
    
    if net <= 0 then
      self.armorIconFlashTimer = 0.5
      table.insert(self.popups, { x = 0, y = 0, kind = "armor_blocked", t = config.battle.popupLifetime, who = "player" })
    else
      self.playerFlash = config.battle.hitFlashDuration
      self.playerKnockbackTime = 1e-6
      table.insert(self.popups, { x = 0, y = 0, text = tostring(net), t = config.battle.popupLifetime, who = "player" })
      if self.particles then
        local px, py = self:getPlayerCenterPivot(self._lastBounds)
        if px and py then
          self.particles:emitHitBurst(px, py)
        end
      end
      if self.onPlayerDamage then
        self.onPlayerDamage()
      end
    end
    
    -- Trigger lunge animation and shake
    enemy.lungeTime = 1e-6
    self:triggerShake((config.battle and config.battle.shakeMagnitude) or 10, (config.battle and config.battle.shakeDuration) or 0.25)
  end
end

-- Calculate enemy intents for the upcoming turn
-- This determines what each enemy will do on their next turn
function BattleScene:calculateEnemyIntents()
  local intents = EnemyIntents.calculate(self)
  EnemyIntents.apply(self, intents)
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
    _attackingEnemyIndex = nil, -- Index of currently attacking enemy (for darkening others)
    _nonAttackingEnemyDarkness = 0.0, -- Tweened darkness value for non-attacking enemies (0 = normal, 1 = fully dark)
    _playerAttackDelayTimer = nil, -- Delay timer for player attack animation (after ball despawn)
    _pendingPlayerAttackDamage = nil, -- { damage, armor, wasJackpot, impactBlockCount, impactIsCrit } - stored when turn ends, applied after delay
    _pendingImpactParams = nil, -- { blockCount, isCrit } - stored by playImpact, merged into pending damage
    _shockwaveSequence = nil, -- Timer for sequencing shockwave animation phases
    _calcifySequence = nil, -- Timer for calcify particle animation sequence
    _healSequence = nil, -- Timer for heal particle animation sequence
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
    -- Enemy armor border tracking (arrays indexed by enemy index)
    prevEnemyArmor = {}, -- Previous armor values for each enemy
    enemyBorderFragments = {}, -- Shatter fragments for each enemy
    enemyBorderFadeInTime = {}, -- Fade-in timers for each enemy
    enemyBarX = {}, -- Bar X positions for each enemy
    enemyBarY = {}, -- Bar Y positions for each enemy
    enemyBarW = {}, -- Bar widths for each enemy
    enemyBarH = {}, -- Bar heights for each enemy
    enemyHealGlowTimer = {}, -- Heal glow timers for each enemy (fades out after heal)
    playerHealGlowTimer = 0, -- Heal glow timer for player (fades out after heal)
    _lastBounds = nil,
    -- Turn indicator state
    turnIndicator = nil, -- { text = "PLAYER'S TURN" or "ENEMY'S TURN", t = lifetime }
    turnIndicatorDelay = 0, -- Delay timer before showing turn indicator
    _pendingTurnIndicator = nil, -- Queued turn indicator waiting for delay
    -- Impact animation
    impactAnimation = nil, -- Base animation instance
    impactInstances = {}, -- Array of active impact instances {anim, x, y, rotation, delay, offsetX, offsetY}
    blackHoleAttacks = {}, -- Array of active black hole attack animations
    impactEffectsPlayed = false,
    splatterImage = nil, -- Splatter image for hit effects (backwards compatibility)
    splatterImages = {}, -- Array of splatter images for randomization
    splatterInstances = {}, -- Array of active splatter instances {x, y, rotation, scale, alpha, lifetime, maxLifetime, image}
    blackHoleImage = nil, -- Black hole image for black hole attacks
    bloodEnrageImage = nil, -- FX image for Bloodhound enrage indicator
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
    glowSelectedImg = nil, -- Image for glow effect behind selected character
    -- Particle system
    particles = ParticleManager.new(),
    -- Charge skill puff images (left/right variants)
    puffImageLeft = nil,
    puffImageRight = nil,
    -- Shockwave smoke effect
    smokeImage = nil,
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

  self:_ensureBattleState(battleProfile)
  self:_syncEnemiesFromState()
  self:_syncPlayerFromState()
  
  -- Initialize BattleScene's HP from PlayerState (preserve HP between battles)
  local playerState = PlayerState.getInstance()
  self.displayPlayerHP = self.playerHP
  -- Ensure max health is set correctly
  playerState:setMaxHealth(config.battle.playerMaxHP)
  playerState:setHealth(self.playerHP)
  
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
  
  -- Load heal icon
  local iconHealPath = (config.assets and config.assets.images and config.assets.images.icon_heal) or nil
  if iconHealPath then
    local ok, img = pcall(love.graphics.newImage, iconHealPath)
    if ok then self.iconPotion = img end
  end
  
  -- Load intent icons
  local iconAttackPath = "assets/images/icon_attack.png"
  local okAttack, attackImg = pcall(love.graphics.newImage, iconAttackPath)
  if okAttack then self.iconIntentAttack = attackImg end
  
  local iconArmorIntentPath = "assets/images/icon_armor.png"
  local okArmorIntent, armorIntentImg = pcall(love.graphics.newImage, iconArmorIntentPath)
  if okArmorIntent then self.iconIntentArmor = armorIntentImg end
  
  local iconSkillPath = "assets/images/icon_skill.png"
  local okSkill, skillImg = pcall(love.graphics.newImage, iconSkillPath)
  if okSkill then self.iconIntentSkill = skillImg end
  
  -- Load impact animation (optional)
  do
    local impactPath = (config.assets and config.assets.images and config.assets.images.impact) or nil
    if impactPath then
      local fps = (config.battle and config.battle.impactFps) or 30
      self.impactAnimation = SpriteAnimation.new(impactPath, 512, 512, 4, 4, fps)
    end
  end
  
  -- Load charge puff images (optional)
  do
    local puffRPath = "assets/images/fx/fx_puff_r.png"
    local puffLPath = "assets/images/fx/fx_puff_l.png"
    local okR, puffRImg = pcall(love.graphics.newImage, puffRPath)
    if okR then self.puffImageRight = puffRImg end
    local okL, puffLImg = pcall(love.graphics.newImage, puffLPath)
    if okL then self.puffImageLeft = puffLImg end
  end
  
  -- Load smoke image for shockwave effect
  local smokePath = "assets/images/fx/fx_smoke.png"
  local okSmoke, smokeImg = pcall(love.graphics.newImage, smokePath)
  if okSmoke then self.smokeImage = smokeImg end
  
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
  
  -- Load Bloodhound enrage FX image
  do
    local bloodFxPath = "assets/images/fx/fx_blood.png"
    local okBlood, bloodImg = pcall(love.graphics.newImage, bloodFxPath)
    if okBlood then
      self.bloodEnrageImage = bloodImg
    else
      self.bloodEnrageImage = nil
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
  
  -- Load glow image for selected character
  local glowPath = "assets/images/fx/glow_selected.png"
  local okGlow, glowImg = pcall(love.graphics.newImage, glowPath)
  if okGlow then
    self.glowSelectedImg = glowImg
  else
    self.glowSelectedImg = nil
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
  
  -- Load black hole image
  local blackHolePath = "assets/images/fx/black_hole.png"
  local okBlackHole, blackHoleImg = pcall(love.graphics.newImage, blackHolePath)
  if okBlackHole then
    self.blackHoleImage = blackHoleImg
  end
  
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

-- Helper function to build animated damage sequence
-- Returns array of {text, duration} for the animation sequence
-- Simplified to show only final damage number (no incrementing animation)
local function buildDamageAnimationSequence(blockHitSequence, baseDamage, orbBaseDamage, critCount, multiplierCount, finalDamage)
  local sequence = {}
  local config = require("config")
  
  -- Track if we have any multipliers
  local hasMultiplier = (critCount > 0) or (multiplierCount > 0)
  
  -- Just show the final damage number directly (no incrementing animation)
  local finalText = tostring(finalDamage)
  if hasMultiplier then
    finalText = finalText .. "!"
  end
  table.insert(sequence, { text = finalText, duration = 0.3, isMultiplier = hasMultiplier })
  return sequence
end

function BattleScene:onPlayerTurnEnd(turnData)
  -- Support both old parameter style (for backward compatibility) and new object style
  if type(turnData) ~= "table" or turnData.damage == nil then
    -- Old style: convert positional parameters to object
    local turnScore, armor, isAOE, blockHitSequence, baseDamage, orbBaseDamage, critCount, multiplierCount, isPierce, isBlackHole, isLightning = turnData, armor, isAOE, blockHitSequence, baseDamage, orbBaseDamage, critCount, multiplierCount, isPierce, isBlackHole, isLightning
    turnData = {
      damage = turnScore,
      armor = armor,
      isAOE = isAOE,
      blockHitSequence = blockHitSequence,
      baseDamage = baseDamage,
      orbBaseDamage = orbBaseDamage,
      critCount = critCount,
      multiplierCount = multiplierCount,
      projectileId = (isLightning and "lightning") or (isBlackHole and "black_hole") or (isPierce and "pierce") or "strike",
    }
  end
  
  -- Check win/lose states via TurnManager
  local tmState = self.turnManager and self.turnManager:getState()
  if tmState == TurnManager.States.VICTORY or tmState == TurnManager.States.DEFEAT then return end
  if turnData.damage and turnData.damage > 0 then
    local dmg = math.floor(turnData.damage)
    
    -- Load impact behavior config
    local impactConfigs = require("data.impact_configs")
    local projectileId = turnData.projectileId or "strike"
    local behavior = impactConfigs.getBehavior(projectileId)
    
    -- Store damage info to apply after delay (merge with pending impact params if any)
    self._pendingPlayerAttackDamage = {
      damage = dmg,
      armor = turnData.armor or 0,
      isAOE = turnData.isAOE or false,
      projectileId = projectileId,
      impactBlockCount = turnData.impactBlockCount or (self._pendingImpactParams and self._pendingImpactParams.blockCount) or 1,
      impactIsCrit = turnData.impactIsCrit or (self._pendingImpactParams and self._pendingImpactParams.isCrit) or false,
      blockHitSequence = turnData.blockHitSequence or {},
      baseDamage = turnData.baseDamage or 0, -- Use calculated baseDamage, don't fall back to final damage
      orbBaseDamage = turnData.orbBaseDamage or 0,
      critCount = turnData.critCount or 0,
      multiplierCount = turnData.multiplierCount or 0,
      behavior = behavior, -- Store behavior config
    }
    self._pendingImpactParams = nil -- Clear after merging
    
    -- Use behavior-driven attack delay
    self._playerAttackDelayTimer = behavior.attackDelay
    
    -- Queue incoming armor for TurnManager to handle (this happens immediately, visual effects are delayed)
    self.pendingArmor = turnData.armor or 0
    self.armorPopupShown = false
  end
end

function BattleScene:applyHealing(amount)
  if not amount or amount <= 0 then return end
  self:_applyPlayerHeal(amount)
  table.insert(self.popups, { x = 0, y = 0, kind = "heal", value = amount, t = config.battle.popupLifetime, who = "player" })
end

function BattleScene:update(dt, bounds)
  self._lastBounds = bounds or self._lastBounds
  self:_syncStateFromBridge()

  self:_updateEnemyFlashTimers(dt)
  
  -- Check if player was just hit (flash transitioned from 0 to positive)
  self:_updatePlayerHitEffects(dt)
  
  self:_tweenHealthBars(dt)
  
  self:_startDisintegrationIfReady()
  
  self:_updateIntentFadeAnimations(dt)
  
  self:_updateEnrageFx(dt)
  
  self:_advanceDisintegrationAnimations(dt)
  
  self:_updateVictoryState()
  
  self:_updateTurnIndicator(dt)
  
  self:_updatePopups(dt)
  
  self:_triggerPendingDisintegrations()
  
  self:_updateArmorEffects(dt)

  self:_updateEnemyTurnDelay(dt)

  -- Update enemy skill sequences
  EnemySkills.update(self, dt)
  
  self:_updateHealGlowTimers(dt)
  
  self:_processChargedAttackDamage(dt)

  self:_updateMultiHitAttacks(dt)
  
  self:_updateEnemyDarkness(dt)
  
  self:_updateEnemyAttackDelays(dt)

  self:_updatePlayerAttackDelay(dt)

  -- Delegate animation timers and streaks
  Visuals.update(self, dt)

end

function BattleScene:triggerShake(mag, dur)
  self.shakeMagnitude = mag or 10
  self.shakeDuration = dur or 0.25
  self.shakeTime = self.shakeDuration
end

function BattleScene:draw(bounds)
  Visuals.draw(self, bounds)
  
  -- Draw particles (above sprites but below UI)
  if self.particles then
    self.particles:draw()
  end
  
  -- Draw top bar on top (z-order)
  if self.topBar and not self.disableTopBar then
    self.topBar:draw()
  end
  
  -- Note: Calcify particles are drawn in SplitScene after blocks for proper z-ordering
end

-- (Jackpot API removed)

-- External API: show player turn indicator
function BattleScene:showPlayerTurn()
  -- Queue "YOUR TURN" indicator with delay
  self._pendingTurnIndicator = { text = "YOUR TURN", t = 1.0 }
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
  -- Set first enemy as attacking (will be updated as attacks progress)
  self._attackingEnemyIndex = 1
  
  -- Schedule attacks for all alive enemies with staggered delays
  local attackDelay = 0.5 -- Delay between consecutive enemy attacks (in seconds)
  for i, enemy in ipairs(self.enemies or {}) do
    if enemy.hp > 0 and enemy.displayHP > 0.1 then
      -- First enemy attacks immediately (handled below), others are delayed by 0.3s intervals
      if i == 1 then
        -- Set first enemy as attacking
        self._attackingEnemyIndex = 1
        -- Use stored intent if available, otherwise fall back to old logic
        local intent = enemy.intent
        local shouldShockwave = false
        local shouldCalcify = false
        local shouldCharge = false
        local shouldGainArmor = false
        local shouldSpawnSpores = false
        
        if intent and intent.type == "armor" then
          shouldGainArmor = true
        elseif intent and intent.type == "skill" and intent.skillType == "calcify" then
          shouldCalcify = true
        elseif intent and intent.type == "skill" and intent.skillType == "charge" then
          shouldCharge = true
        elseif intent and intent.type == "skill" and intent.skillType == "spore" then
          shouldSpawnSpores = true
        elseif (intent and intent.type == "skill" and intent.skillType == "shockwave") or
               (intent and intent.type == "attack" and intent.attackType == "shockwave") then
          shouldShockwave = true
        elseif not intent then
          -- Fallback: Only check for shockwave if no intent was set (shouldn't happen normally)
          local isEnemy1 = enemy.spritePath == "enemy_1.png"
          shouldShockwave = isEnemy1 and (love.math.random() < 0.3)
        end
        
        local shouldHeal = intent and intent.type == "skill" and intent.skillType == "heal"
        
        if shouldGainArmor then
          EnemySkills.performArmorGain(self, enemy, i, intent.amount or 5)
        elseif shouldHeal then
          EnemySkills.performHeal(self, enemy, intent.targetIndex, intent.amount or 18)
        elseif shouldCalcify then
          EnemySkills.performCalcify(self, enemy, intent.blockCount or 3)
        elseif shouldCharge then
          EnemySkills.performCharge(self, enemy, (intent and intent.armorBlockCount) or 3)
        elseif shouldSpawnSpores then
          EnemySkills.performSpore(self, enemy, (intent and intent.sporeCount) or 2)
        elseif shouldShockwave then
          EnemySkills.performShockwave(self, enemy)
        else
          -- Normal or charged attack
          local isChargedAttack = intent and intent.type == "attack" and intent.attackType == "charged"
          local hitCount = self:_getEnemyHitCount(enemy, intent)
          
          local dmg
          if intent and intent.type == "attack" and intent.damageMin and intent.damageMax then
            dmg = love.math.random(intent.damageMin, intent.damageMax)
          else
            dmg = love.math.random(enemy.damageMin, enemy.damageMax)
          end
          
          if isChargedAttack then
            -- Store damage (scaled by hit count) to apply later when forward charge phase starts
            enemy.pendingChargedDamage = dmg * hitCount
            enemy.chargedDamageApplied = nil
            enemy.chargeLungeTime = 1e-6
            enemy.chargeLunge = {
              windupDuration = 0.55,
              forwardDuration = 0.22,
              returnDuration = 0.24,
              backDistance = ((config.battle and config.battle.lungeDistance) or 80) * 0.6,
              forwardDistance = ((config.battle and config.battle.lungeDistance) or 80) * 2.8,
            }
          else
            -- Apply multi-hit damage immediately
            self:_applyMultiHitDamage(enemy, dmg, hitCount, i)
          end
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

-- Perform enemy calcify skill (Stagmaw special ability)
function BattleScene:startCalcifyAnimation(enemyX, enemyY, blockPositions)
  EnemySkills.startCalcifyAnimation(self, enemyX, enemyY, blockPositions)
end

function BattleScene:startSporeAnimation(enemyX, enemyY, targetPositions)
  EnemySkills.startSporeAnimation(self, enemyX, enemyY, targetPositions)
end

function BattleScene:drawSkillParticles()
  EnemySkills.draw(self)
end

-- Set TurnManager reference (called by SplitScene)
function BattleScene:setTurnManager(turnManager)
  self.turnManager = turnManager
  
  -- Subscribe to TurnManager events
  if turnManager then
    -- Provide a hook for TurnManager to test if enemy attacks are still running
    function turnManager:isEnemyTurnBusy()
      if not self or not self._sceneRight then return false end
      local scene = self._sceneRight
      if scene.areEnemyAttacksActive then
        return scene:areEnemyAttacksActive()
      end
      return false
    end
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
      
      -- Check if player attack animation is still playing (lunge or black hole)
      local playerAttackActive = (self.playerLungeTime and self.playerLungeTime > 0) or false
      local blackHoleActive = (self.blackHoleAttacks and #self.blackHoleAttacks > 0) or false
      
      if playerAttackActive or blackHoleActive then
        -- Player attack or black hole still playing, calculate remaining time
        local remainingTime = 0
      
      if playerAttackActive then
          remainingTime = math.max(remainingTime, totalLungeDuration - (self.playerLungeTime or 0))
        end
        
        if blackHoleActive then
          -- Calculate remaining black hole animation time
          for _, attack in ipairs(self.blackHoleAttacks or {}) do
            local attackRemaining = attack.duration - attack.t
            remainingTime = math.max(remainingTime, attackRemaining)
          end
        end
        
        -- Add a small buffer to ensure animation fully completes
        local buffer = 0.1
        local delay = math.max(0, remainingTime + buffer)
        
        -- Store pending enemy turn start flag
        self._pendingEnemyTurnStart = true
        
        -- Queue enemy turn start after player attack completes
        if (self.pendingArmor or 0) > 0 and not self.armorPopupShown then
          -- Show armor popup first, then wait for player attack + delay
          self:_addPlayerArmor(self.pendingArmor)
          table.insert(self.popups, { x = 0, y = 0, kind = "armor", value = self.pendingArmor, t = config.battle.popupLifetime, who = "player" })
          self.armorPopupShown = true
          -- Wait for player attack + armor popup duration + post-armor delay
          local armorDelay = (config.battle.popupLifetime or 0.8) + (config.battle.enemyAttackPostArmorDelay or 0.3)
          local extra = (config.battle and config.battle.enemyTurnStartExtraDelay) or 0.25
          self._enemyTurnDelay = delay + armorDelay + extra
        else
          -- No armor, just wait for player attack to complete
          local extra = (config.battle and config.battle.enemyTurnStartExtraDelay) or 0.25
          self._enemyTurnDelay = delay + extra
        end
      else
        -- Player attack already complete, proceed normally
        if (self.pendingArmor or 0) > 0 and not self.armorPopupShown then
          self:_addPlayerArmor(self.pendingArmor)
          table.insert(self.popups, { x = 0, y = 0, kind = "armor", value = self.pendingArmor, t = config.battle.popupLifetime, who = "player" })
          self.armorPopupShown = true
          -- Queue enemy turn start after armor popup duration + delay
          local delay = (config.battle.popupLifetime or 0.8) + (config.battle.enemyAttackPostArmorDelay or 0.3)
          local extra = (config.battle and config.battle.enemyTurnStartExtraDelay) or 0.25
          self._enemyTurnDelay = delay + extra
        else
          -- No armor, start enemy turn immediately
          local extra = (config.battle and config.battle.enemyTurnStartExtraDelay) or 0.25
          self._enemyTurnDelay = extra
        end
      end
    end)
    
    -- State transitions
    turnManager:on("state_enter", function(newState, previousState)
      if newState == TurnManager.States.ENEMY_TURN_RESOLVING then
        -- After enemy turn resolves, reset armor and spawn blocks
        self:_setPlayerArmor(0)
        self.pendingArmor = 0
        self.armorPopupShown = false
      elseif newState == TurnManager.States.PLAYER_TURN_START then
        -- Calculate enemy intents at the start of player turn
        -- This shows what enemies will do on their next turn
        self:calculateEnemyIntents()
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

function BattleScene:_getEnemyLungeOffset(enemy)
  if not enemy or not enemy.lungeTime or enemy.lungeTime <= 0 then
    return 0
  end

  local lungeDuration = config.battle.lungeDuration or 0
  local returnDuration = config.battle.lungeReturnDuration or 0
  local distance = config.battle.lungeDistance or 0

  if enemy.lungeTime < lungeDuration then
    return distance * (enemy.lungeTime / math.max(0.0001, lungeDuration))
  elseif enemy.lungeTime < lungeDuration + returnDuration then
    local t = (enemy.lungeTime - lungeDuration) / math.max(0.0001, returnDuration)
    return distance * (1 - t)
  else
    return 0
  end
end

function BattleScene:_computeEnemyLayout(bounds)
  local fallbackBounds = self._lastBounds
  local w = (bounds and bounds.w) or (fallbackBounds and fallbackBounds.w) or love.graphics.getWidth()
  local h = (bounds and bounds.h) or (fallbackBounds and fallbackBounds.h) or love.graphics.getHeight()
  local center = (bounds and bounds.center) or (fallbackBounds and fallbackBounds.center) or nil

  local centerX = center and center.x or math.floor(w * 0.5) - math.floor((w * 0.5) * 0.5)
  local centerW = center and center.w or math.floor(w * 0.5)
  local rightStart = centerX + centerW
  local rightWidth = math.max(0, w - rightStart)

  local r = 24
  local yOffset = (config.battle and config.battle.positionOffsetY) or 0
  local baselineY = h * 0.55 + r + yOffset

  local layout = {
    w = w,
    baselineY = baselineY,
    rightStart = rightStart,
    rightWidth = rightWidth,
    radius = r,
    entries = {},
  }

  if not self.enemies or #self.enemies == 0 then
    return layout
  end

  local battleProfile = self._battleProfile or {}
  local gapCfg = battleProfile.enemySpacing
  local enemyCount = #self.enemies
  local gap
  if type(gapCfg) == "table" then
    gap = gapCfg[enemyCount] or gapCfg.default or 0
  else
    gap = gapCfg or -20
  end

  local enemyWidths = {}
  local enemyScales = {}
  local totalWidth = 0

  for i, enemy in ipairs(self.enemies) do
    local scaleCfg = enemy.spriteScale or (config.battle and (config.battle.enemySpriteScale or config.battle.spriteScale)) or 4
    local scale = 1
    if enemy.img then
      local ih = enemy.img:getHeight()
      scale = ((2 * r) / math.max(1, ih)) * scaleCfg * (enemy.scaleMul or 1)
    end
    enemyScales[i] = scale

    local width = enemy.img and (enemy.img:getWidth() * scale) or (r * 2)
    enemyWidths[i] = width

    totalWidth = totalWidth + width
    if i < enemyCount then
      totalWidth = totalWidth + gap
    end
  end

  local centerXPos = rightStart + rightWidth * 0.5
  local startX = centerXPos - totalWidth * 0.5 - 70

  for i, enemy in ipairs(self.enemies) do
    local enemyX = startX
    for j = 1, i - 1 do
      enemyX = enemyX + enemyWidths[j] + gap
    end
    enemyX = enemyX + enemyWidths[i] * 0.5

    local centerXPosEnemy = enemyX - self:_getEnemyLungeOffset(enemy)
    local spriteHeight = enemy.img and (enemy.img:getHeight() * enemyScales[i]) or (r * 2)
    local halfHeight = spriteHeight * 0.5
    local halfWidth = enemyWidths[i] * 0.5

    layout.entries[i] = {
      centerX = centerXPosEnemy,
      centerY = baselineY - halfHeight,
      halfWidth = halfWidth,
      halfHeight = halfHeight,
      hitY = baselineY - halfHeight * 0.7,
      boundingTop = baselineY - spriteHeight,
    }
  end

  return layout
end

function BattleScene:_syncStateFromBridge()
  StateBridge.get(self)
  self:_syncPlayerFromState()
  self:_syncEnemiesFromState()
end

function BattleScene:_updateEnemyFlashTimers(dt)
  for _, enemy in ipairs(self.enemies or {}) do
    if enemy.flash and enemy.flash > 0 then
      enemy.flash = math.max(0, enemy.flash - dt * 0.85)
    end
  end
end

function BattleScene:_updatePlayerHitEffects(dt)
  if self.prevPlayerFlash == 0 and self.playerFlash > 0 then
    ImpactSystem.createPlayerSplatter(self, self._lastBounds)
  end
  self.prevPlayerFlash = self.playerFlash

  if self.playerFlash and self.playerFlash > 0 then
    self.playerFlash = math.max(0, self.playerFlash - dt)
  end

  ImpactSystem.update(self, dt)

  if self.particles then
    self.particles:update(dt)
  end

  local playerState = PlayerState.getInstance()
  playerState:setHealth(self.playerHP)
end

function BattleScene:_tweenHealthBars(dt)
  local hpTweenSpeed = (config.battle and config.battle.hpBarTweenSpeed) or 8

  local playerDelta = self.playerHP - (self.displayPlayerHP or self.playerHP)
  if math.abs(playerDelta) > 0.01 then
    local k = math.min(1, hpTweenSpeed * dt)
    self.displayPlayerHP = (self.displayPlayerHP or self.playerHP) + playerDelta * k
  else
    self.displayPlayerHP = self.playerHP
  end

  for _, enemy in ipairs(self.enemies or {}) do
    local enemyDelta = enemy.hp - (enemy.displayHP or enemy.hp)
    if math.abs(enemyDelta) > 0.01 then
      local k = math.min(1, hpTweenSpeed * dt)
      enemy.displayHP = (enemy.displayHP or enemy.hp) + enemyDelta * k
    else
      enemy.displayHP = enemy.hp
    end
  end
end

function BattleScene:_startDisintegrationIfReady()
  if self.state == "win" then
    return
  end

  local disintegrationCfg = config.battle.disintegration or {}
  local duration = disintegrationCfg.duration or 1.5
  local impactsActive = (self.impactInstances and #self.impactInstances > 0) or (self.blackHoleAttacks and #self.blackHoleAttacks > 0)

  for index, enemy in ipairs(self.enemies or {}) do
    if enemy.hp <= 0 and not enemy.disintegrating and not enemy.pendingDisintegration then
      local hasCompleted = (enemy.disintegrationTime or 0) >= duration
      if not hasCompleted then
        local damagePopupActive = self:_enemyHasActiveDamagePopup(index)
        if impactsActive or damagePopupActive then
          enemy.pendingDisintegration = true
        else
          enemy.disintegrating = true
          enemy.disintegrationTime = 0
        end
      end
    end
  end
end

function BattleScene:_updateIntentFadeAnimations(dt)
  local turnManager = self.turnManager
  local isPlayerTurn = turnManager and (
    turnManager:getState() == TurnManager.States.PLAYER_TURN_START or
    turnManager:getState() == TurnManager.States.PLAYER_TURN_ACTIVE
  )

  local fadeInDuration = 0.3
  local fadeOutDuration = 0.2
  local fadeOutRate = fadeOutDuration > 0 and (fadeInDuration / fadeOutDuration) or 0

  for _, enemy in ipairs(self.enemies or {}) do
    if enemy.intentFadeTime ~= nil then
      if isPlayerTurn then
        if enemy.intentFadeTime < fadeInDuration then
          enemy.intentFadeTime = math.min(fadeInDuration, enemy.intentFadeTime + dt)
        else
          enemy.intentFadeTime = fadeInDuration
        end
      else
        if fadeOutRate > 0 then
          enemy.intentFadeTime = math.max(0, enemy.intentFadeTime - dt * fadeOutRate)
        else
          enemy.intentFadeTime = 0
        end
        if enemy.intentFadeTime <= 0 then
          enemy.intentFadeTime = nil
        end
      end
    end
  end
end

function BattleScene:_updateEnrageFx(dt)
  local fxDuration = 0.8
  for _, enemy in ipairs(self.enemies or {}) do
    if enemy.enrageFxActive and enemy.enrageFxTime ~= nil then
      enemy.enrageFxTime = enemy.enrageFxTime + dt
      if enemy.enrageFxTime >= fxDuration or enemy.hp <= 0 then
        enemy.enrageFxActive = false
      end
    end
  end
end

function BattleScene:_advanceDisintegrationAnimations(dt)
  local cfg = config.battle.disintegration or {}
  local duration = cfg.duration or 1.5

  for index, enemy in ipairs(self.enemies or {}) do
    if enemy.disintegrating then
      enemy.disintegrationTime = (enemy.disintegrationTime or 0) + dt * 0.5
      if enemy.disintegrationTime >= duration then
        enemy.disintegrating = false
        if self.selectedEnemyIndex == index then
          self:_selectNextEnemy()
        end
      end
    end
  end
end

function BattleScene:_updateVictoryState()
  if self.state == "win" then
    return
  end

  local allEnemiesDefeated = true
  local anyDisintegrating = false
  local anyPending = false

  for _, enemy in ipairs(self.enemies or {}) do
    if enemy.hp > 0 and not enemy.disintegrating then
      allEnemiesDefeated = false
    end
    if enemy.disintegrating then
      anyDisintegrating = true
    end
    if enemy.pendingDisintegration then
      anyPending = true
    end
  end

  if allEnemiesDefeated and not anyDisintegrating and not anyPending then
    self.state = "win"
  end
end

function BattleScene:_updateTurnIndicator(dt)
  if self.turnIndicatorDelay and self.turnIndicatorDelay > 0 then
    self.turnIndicatorDelay = self.turnIndicatorDelay - dt
    if self.turnIndicatorDelay <= 0 then
      if self._pendingTurnIndicator then
        self.turnIndicator = self._pendingTurnIndicator
        self._pendingTurnIndicator = nil
        if self.turnManager and self.turnManager.emit then
          self.turnManager:emit("turn_indicator_shown", { text = self.turnIndicator.text })
        end
      end
      self.turnIndicatorDelay = 0
    end
  end

  if self.turnIndicator then
    self.turnIndicator.t = self.turnIndicator.t - dt
    if self.turnIndicator.t <= 0 then
      self.turnIndicator = nil
    end
  end
end

function BattleScene:_updatePopups(dt)
  local alive = {}

  for _, p in ipairs(self.popups or {}) do
    if p.startDelay and p.startDelay > 0 then
      p.startDelay = p.startDelay - dt
      if p.startDelay > 0 then
        table.insert(alive, p)
        goto continue
      else
        p.startDelay = nil
      end
    end

    local sequenceCompleted = false
    if p.kind == "animated_damage" and p.sequence and #p.sequence > 0 then
      if not p.sequenceIndex then
        p.sequenceIndex = 1
        p.sequenceTimer = 0
      end

      p.sequenceTimer = (p.sequenceTimer or 0) + dt
      local currentStep = p.sequence[p.sequenceIndex]

      if currentStep and p.sequenceTimer >= currentStep.duration then
        if p.sequenceIndex < #p.sequence then
          p.sequenceTimer = 0
          p.sequenceIndex = p.sequenceIndex + 1
          p.bounceTimer = 0
        end
      end

      if p.sequenceIndex == #p.sequence then
        local finalStep = p.sequence[p.sequenceIndex]
        if finalStep and p.sequenceTimer >= finalStep.duration then
          sequenceCompleted = true
          if not p.sequenceFinished then
            p.sequenceFinished = true

            if p.who == "enemy" and p.enemyIndex then
              local enemy = self.enemies and self.enemies[p.enemyIndex]
              if enemy and enemy.pendingDamage and enemy.pendingDamage > 0 then
                self:_applyEnemyDamage(p.enemyIndex, enemy.pendingDamage)
                enemy.pendingDamage = 0
              end
            end

            local lastStep = p.sequence[#p.sequence]
            local hasExclamation = lastStep and lastStep.text and string.find(lastStep.text, "!") ~= nil
            local lingerTime = hasExclamation and 0.9 or 0.45
            local disintegrationDisplayTime = 0.25
            p.t = lingerTime + disintegrationDisplayTime
            p.originalLifetime = p.t
          end
        end
      else
        sequenceCompleted = false
      end

      if p.bounceTimer == nil then
        p.bounceTimer = 0
      end
      p.bounceTimer = p.bounceTimer + dt

      local currentStep = p.sequence[p.sequenceIndex]
      if currentStep and currentStep.isMultiplier then
        if not p.charBounceTimers then
          p.charBounceTimers = { 0, 0, 0 }
          p.multiplierTarget = nil
        end

        local charBounceDelay = 0.08
        if not p.multiplierStartTime then
          p.multiplierStartTime = p.sequenceTimer or 0
        end
        local multiplierElapsed = (p.sequenceTimer or 0) - p.multiplierStartTime

        for i = 1, #p.charBounceTimers do
          if multiplierElapsed >= (i - 1) * charBounceDelay then
            p.charBounceTimers[i] = (p.charBounceTimers[i] or 0) + dt
          end
        end
      end

      local isFinalStep = (p.sequenceIndex == #p.sequence)
      local finalStep = p.sequence[#p.sequence]
      local hasExclamation = finalStep and finalStep.text and string.find(finalStep.text, "!") ~= nil

      if isFinalStep and hasExclamation then
        if not p.shakeTime then
          local finalStepDuration = finalStep.duration or 0.1
          p.shakeTime = finalStepDuration * 2.5
          p.shakeRotation = 0
          p.shakeUpdateTimer = 0
        end

        if p.shakeTime > 0 then
          p.shakeTime = p.shakeTime - dt
          p.shakeUpdateTimer = (p.shakeUpdateTimer or 0) + dt

          local shakeDuration = (finalStep.duration or 0.1) * 2.5
          local progress = shakeDuration > 0 and (p.shakeTime / shakeDuration) or 0
          local shakeMagnitude = 4 * progress

          local shakeUpdateInterval = 0.05
          if p.shakeUpdateTimer >= shakeUpdateInterval then
            p.shakeUpdateTimer = 0
            p.shakeOffsetX = (love.math.random() * 2 - 1) * shakeMagnitude
            p.shakeOffsetY = (love.math.random() * 2 - 1) * shakeMagnitude
          end

          local rotationSpeed = 15
          local elapsedTime = shakeDuration - p.shakeTime
          p.shakeRotation = math.sin(elapsedTime * rotationSpeed * 2 * math.pi) * 0.15 * progress
        else
          p.shakeOffsetX = 0
          p.shakeOffsetY = 0
          p.shakeRotation = 0
          p.shakeUpdateTimer = nil
        end
      else
        p.shakeOffsetX = 0
        p.shakeOffsetY = 0
        p.shakeRotation = 0
        p.shakeTime = nil
      end
    end

    local isAnimatedDamage = (p.kind == "animated_damage" and p.sequence)
    if not isAnimatedDamage then
      p.t = (p.t or 0) - dt
    elseif sequenceCompleted or (p.sequenceFinished == true) then
      p.t = (p.t or 0) - dt
    end

    if p.t and p.t > 0 then
      table.insert(alive, p)
    end

    ::continue::
  end

  self.popups = alive
end

function BattleScene:_triggerPendingDisintegrations()
  local impactsActive = (self.impactInstances and #self.impactInstances > 0) or (self.blackHoleAttacks and #self.blackHoleAttacks > 0)

  for index, enemy in ipairs(self.enemies or {}) do
    if enemy.pendingDisintegration and enemy.hp <= 0 then
      local damagePopupActive = self:_enemyHasActiveDamagePopup(index)
      if not impactsActive and not damagePopupActive then
        enemy.pendingDisintegration = false
        if not enemy.disintegrating then
          enemy.disintegrating = true
          enemy.disintegrationTime = 0
        end
      end
    end
  end
end

function BattleScene:_updateArmorEffects(dt)
  if self.armorIconFlashTimer and self.armorIconFlashTimer > 0 then
    self.armorIconFlashTimer = math.max(0, self.armorIconFlashTimer - dt)
  end

  local prevPlayerArmor = self.prevPlayerArmor or 0
  local playerArmor = self.playerArmor or 0
  local armorBroken = prevPlayerArmor > 0 and playerArmor == 0
  local armorGained = prevPlayerArmor == 0 and playerArmor > 0

  if armorBroken and self.playerBarX and self.playerBarY and self.playerBarW and self.playerBarH then
    local gap = 3
    self.borderFragments = EnemySkills.createBorderFragments(self.playerBarX, self.playerBarY, self.playerBarW, self.playerBarH, gap, 6)
  end

  if armorGained then
    self.borderFadeInTime = self.borderFadeInDuration
  end

  if self.borderFadeInTime and self.borderFadeInTime > 0 then
    self.borderFadeInTime = math.max(0, self.borderFadeInTime - dt)
  end

  self.prevPlayerArmor = playerArmor

  local aliveFragments = {}
  for _, frag in ipairs(self.borderFragments or {}) do
    frag.lifetime = (frag.lifetime or 0) - dt
    if frag.lifetime > 0 then
      local progress = frag.maxLifetime and (frag.lifetime / frag.maxLifetime) or 0
      local easeOut = progress * progress
      local velScale = 0.3 + easeOut * 0.7
      frag.x = frag.x + frag.vx * dt * velScale
      frag.y = frag.y + frag.vy * dt * velScale
      frag.rotation = frag.rotation + frag.rotationSpeed * dt * (0.5 + progress * 0.5)
      frag.progress = progress
      table.insert(aliveFragments, frag)
    end
  end
  self.borderFragments = aliveFragments

  for i, enemy in ipairs(self.enemies or {}) do
    local prevArmor = self.prevEnemyArmor[i] or 0
    local currentArmor = enemy.armor or 0
    local enemyArmorBroken = prevArmor > 0 and currentArmor == 0
    local enemyArmorGained = prevArmor == 0 and currentArmor > 0

    if enemyArmorBroken and self.enemyBarX[i] and self.enemyBarY[i] and self.enemyBarW[i] and self.enemyBarH[i] then
      local gap = 3
      self.enemyBorderFragments[i] = EnemySkills.createBorderFragments(self.enemyBarX[i], self.enemyBarY[i], self.enemyBarW[i], self.enemyBarH[i], gap, 6)
    end

    if enemyArmorGained then
      self.enemyBorderFadeInTime[i] = self.borderFadeInDuration
    end

    if self.enemyBorderFadeInTime[i] and self.enemyBorderFadeInTime[i] > 0 then
      self.enemyBorderFadeInTime[i] = math.max(0, self.enemyBorderFadeInTime[i] - dt)
    end

    self.prevEnemyArmor[i] = currentArmor

    if self.enemyBorderFragments[i] then
      local aliveEnemyFragments = {}
      for _, frag in ipairs(self.enemyBorderFragments[i]) do
        frag.lifetime = (frag.lifetime or 0) - dt
        if frag.lifetime > 0 then
          local progress = frag.maxLifetime and (frag.lifetime / frag.maxLifetime) or 0
          local easeOut = progress * progress
          local velScale = 0.3 + easeOut * 0.7
          frag.x = frag.x + frag.vx * dt * velScale
          frag.y = frag.y + frag.vy * dt * velScale
          frag.rotation = frag.rotation + frag.rotationSpeed * dt * (0.5 + progress * 0.5)
          frag.progress = progress
          table.insert(aliveEnemyFragments, frag)
        end
      end
      self.enemyBorderFragments[i] = aliveEnemyFragments
    end
  end
end

function BattleScene:_updateEnemyTurnDelay(dt)
  if not (self._enemyTurnDelay and self._enemyTurnDelay > 0) then
    return
  end

  self._enemyTurnDelay = self._enemyTurnDelay - dt

  local playerAttackActive = (self.playerLungeTime and self.playerLungeTime > 0) or false
  local blackHoleActive = (self.blackHoleAttacks and #self.blackHoleAttacks > 0) or false

  if (playerAttackActive or blackHoleActive) and self._pendingEnemyTurnStart then
    local remainingTime = 0

    if playerAttackActive then
      local lungeD = (config.battle and config.battle.lungeDuration) or 0
      local lungeRD = (config.battle and config.battle.lungeReturnDuration) or 0
      local lungePause = (config.battle and config.battle.lungePauseDuration) or 0
      local totalLungeDuration = lungeD + lungePause + lungeRD
      remainingTime = math.max(remainingTime, totalLungeDuration - (self.playerLungeTime or 0))
    end

    if blackHoleActive then
      for _, attack in ipairs(self.blackHoleAttacks or {}) do
        local attackRemaining = (attack.duration or 0) - (attack.t or 0)
        remainingTime = math.max(remainingTime, attackRemaining)
      end
    end

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

function BattleScene:_updateHealGlowTimers(dt)
  if self.playerHealGlowTimer and self.playerHealGlowTimer > 0 then
    self.playerHealGlowTimer = math.max(0, self.playerHealGlowTimer - dt)
  end

  for i in ipairs(self.enemies or {}) do
    if self.enemyHealGlowTimer[i] and self.enemyHealGlowTimer[i] > 0 then
      self.enemyHealGlowTimer[i] = math.max(0, self.enemyHealGlowTimer[i] - dt)
    end
  end
end

function BattleScene:_processChargedAttackDamage(dt)
  for _, enemy in ipairs(self.enemies or {}) do
    if enemy.pendingChargedDamage and enemy.chargeLungeTime and enemy.chargeLungeTime > 0 and enemy.chargeLunge then
      local t = enemy.chargeLungeTime
      local windup = enemy.chargeLunge.windupDuration or 0.55
      local forward = enemy.chargeLunge.forwardDuration or 0.2
      local returnDuration = enemy.chargeLunge.returnDuration or 0.2

      if t >= windup and not enemy.chargedDamageApplied then
        enemy.chargedDamageApplied = true

        local dmg = enemy.pendingChargedDamage
        local blocked, net = self:_applyPlayerDamage(dmg)

        if net <= 0 then
          self.armorIconFlashTimer = 0.5
          table.insert(self.popups, { x = 0, y = 0, kind = "armor_blocked", t = config.battle.popupLifetime, who = "player" })
        else
          self.playerFlash = config.battle.hitFlashDuration
          self.playerKnockbackTime = 1e-6
          table.insert(self.popups, { x = 0, y = 0, text = tostring(net), t = config.battle.popupLifetime, who = "player" })
          if self.particles then
            local px, py = self:getPlayerCenterPivot(self._lastBounds)
            if px and py then
              self.particles:emitHitBurst(px, py)
            end
          end
          pushLog(self, (enemy.name or "Enemy") .. " dealt " .. net)
          if self.onPlayerDamage then
            self.onPlayerDamage()
          end
        end

        self:triggerShake((config.battle and config.battle.shakeMagnitude) or 10, (config.battle and config.battle.shakeDuration) or 0.25)
        enemy.pendingChargedDamage = nil
      end

      if t >= windup + forward + returnDuration then
        enemy.chargedDamageApplied = nil
      end
    end
  end
end

function BattleScene:_updateMultiHitAttacks(dt)
  for _, enemy in ipairs(self.enemies or {}) do
    local state = enemy.multiHitState
    if state then
      state.timer = state.timer + dt

      if state.timer >= state.delay then
        state.timer = 0
        state.currentHit = state.currentHit + 1

        if state.currentHit <= state.remainingHits then
          local blocked, net = self:_applyPlayerDamage(state.damage)

          if net <= 0 then
            self.armorIconFlashTimer = 0.5
            table.insert(self.popups, { x = 0, y = 0, kind = "armor_blocked", t = config.battle.popupLifetime, who = "player" })
          else
            self.playerFlash = config.battle.hitFlashDuration
            self.playerKnockbackTime = 1e-6
            table.insert(self.popups, { x = 0, y = 0, text = tostring(net), t = config.battle.popupLifetime, who = "player" })
            if self.particles then
              local px, py = self:getPlayerCenterPivot(self._lastBounds)
              if px and py then
                self.particles:emitHitBurst(px, py)
              end
            end
            if self.onPlayerDamage then
              self.onPlayerDamage()
            end
          end

          enemy.lungeTime = 1e-6
          self:triggerShake((config.battle and config.battle.shakeMagnitude) or 8, (config.battle and config.battle.shakeDuration) or 0.2)

          if state.currentHit >= state.remainingHits then
            enemy.multiHitState = nil
            if self.playerHP <= 0 then
              self.state = "lose"
              if self.turnManager then
                self.turnManager:transitionTo(TurnManager.States.DEFEAT)
              end
            end
          end
        end
      end
    end
  end
end

function BattleScene:_updateEnemyDarkness(dt)
  local targetDarkness = (self._attackingEnemyIndex ~= nil) and 1.0 or 0.0
  local darknessSpeed = 4.0
  local darknessDelta = targetDarkness - (self._nonAttackingEnemyDarkness or 0)
  self._nonAttackingEnemyDarkness = (self._nonAttackingEnemyDarkness or 0) + darknessDelta * math.min(1, darknessSpeed * dt)
end

function BattleScene:_updateEnemyAttackDelays(dt)
  local shockwaveActive = self._shockwaveSequence ~= nil
  local calcifyActive = self._calcifySequence ~= nil
  local chargedAttackActive = false

  for _, enemy in ipairs(self.enemies or {}) do
    if enemy.chargeLungeTime and enemy.chargeLungeTime > 0 then
      chargedAttackActive = true
      break
    end
  end

  local aliveAttackDelays = {}
  for _, delayData in ipairs(self._enemyAttackDelays or {}) do
    if shockwaveActive or calcifyActive or chargedAttackActive then
      table.insert(aliveAttackDelays, delayData)
    else
      delayData.delay = delayData.delay - dt
      if delayData.delay <= 0 then
        self._attackingEnemyIndex = delayData.index

        local enemy = self.enemies[delayData.index]
        if enemy and enemy.hp > 0 then
          local intent = enemy.intent
          if intent and intent.type == "armor" then
            EnemySkills.performArmorGain(self, enemy, delayData.index, intent.amount or 5)
          elseif intent and intent.type == "skill" and intent.skillType == "heal" then
            EnemySkills.performHeal(self, enemy, intent.targetIndex, intent.amount or 18)
          elseif intent and intent.type == "skill" and intent.skillType == "calcify" then
            EnemySkills.performCalcify(self, enemy, intent.blockCount or 3)
          elseif intent and intent.type == "skill" and intent.skillType == "charge" then
            EnemySkills.performCharge(self, enemy, (intent and intent.armorBlockCount) or 3)
          elseif intent and intent.type == "skill" and intent.skillType == "spore" then
            EnemySkills.performSpore(self, enemy, (intent and intent.sporeCount) or 2)
          elseif (intent and intent.type == "skill" and intent.skillType == "shockwave") or
                 (intent and intent.type == "attack" and intent.attackType == "shockwave") then
            EnemySkills.performShockwave(self, enemy)
          else
            local isChargedAttack = intent and intent.type == "attack" and intent.attackType == "charged"
            local hitCount = self:_getEnemyHitCount(enemy, intent)

            local dmg
            if intent and intent.type == "attack" and intent.damageMin and intent.damageMax then
              dmg = love.math.random(intent.damageMin, intent.damageMax)
            else
              dmg = love.math.random(enemy.damageMin, enemy.damageMax)
            end

            if isChargedAttack then
              enemy.pendingChargedDamage = dmg * hitCount
              enemy.chargedDamageApplied = nil
              enemy.chargeLungeTime = 1e-6
              enemy.chargeLunge = {
                windupDuration = 0.55,
                forwardDuration = 0.22,
                returnDuration = 0.24,
                backDistance = ((config.battle and config.battle.lungeDistance) or 80) * 0.6,
                forwardDistance = ((config.battle and config.battle.lungeDistance) or 80) * 2.8,
              }
            else
              self:_applyMultiHitDamage(enemy, dmg, hitCount, delayData.index)
            end

            if self.playerHP <= 0 then
              self.state = "lose"
              pushLog(self, "You were defeated!")
              if self.turnManager then
                self.turnManager:transitionTo(TurnManager.States.DEFEAT)
              end
            end
          end
        end
      else
        table.insert(aliveAttackDelays, delayData)
      end
    end
  end
  self._enemyAttackDelays = aliveAttackDelays

  if (#self._enemyAttackDelays == 0) and not shockwaveActive and not calcifyActive then
    if not self._attackingEnemyClearDelay then
      self._attackingEnemyClearDelay = 0.3
    else
      self._attackingEnemyClearDelay = self._attackingEnemyClearDelay - dt
      if self._attackingEnemyClearDelay <= 0 then
        self._attackingEnemyIndex = nil
        self._attackingEnemyClearDelay = nil
      end
    end
  else
    self._attackingEnemyClearDelay = nil
  end
end

function BattleScene:_updatePlayerAttackDelay(dt)
  if not (self._playerAttackDelayTimer and self._playerAttackDelayTimer > 0) then
    return
  end

  self._playerAttackDelayTimer = self._playerAttackDelayTimer - dt
  if self._playerAttackDelayTimer > 0 then
    return
  end

  self._playerAttackDelayTimer = nil

  if self._pendingPlayerAttackDamage then
    local pending = self._pendingPlayerAttackDamage
    local dmg = pending.damage
    local isAOE = pending.isAOE or false
    local projectileId = pending.projectileId or "strike"
    local behavior = pending.behavior
    local impactBlockCount = pending.impactBlockCount or 1
    local impactIsCrit = pending.impactIsCrit or false

    if impactBlockCount and impactBlockCount > 0 then
      self:_createImpactInstances({
        blockCount = impactBlockCount,
        isCrit = impactIsCrit,
        isAOE = isAOE,
        projectileId = projectileId,
        behavior = behavior,
      })
    end

    local blockHitSequence = pending.blockHitSequence or {}
    local orbBaseDamage = pending.orbBaseDamage or 0
    local baseDamage = pending.baseDamage

    if not baseDamage or baseDamage == 0 then
      baseDamage = orbBaseDamage
      for _, hit in ipairs(blockHitSequence) do
        local kind = (type(hit) == "table" and hit.kind) or "damage"
        local amount = (type(hit) == "table" and (hit.damage or hit.amount)) or 0
        if kind ~= "crit" and kind ~= "multiplier" and kind ~= "armor" and kind ~= "heal" and kind ~= "potion" then
          baseDamage = baseDamage + amount
        end
      end
    end

    local damageSequence = buildDamageAnimationSequence(
      blockHitSequence,
      baseDamage,
      orbBaseDamage,
      pending.critCount or 0,
      pending.multiplierCount or 0,
      dmg
    )

    if isAOE then
      for i, enemy in ipairs(self.enemies or {}) do
        if enemy and enemy.hp > 0 then
          if behavior.delayHPReduction then
            enemy.pendingDamage = (enemy.pendingDamage or 0) + dmg
          else
            self:_applyEnemyDamage(i, dmg)
          end

          self:_enqueueDamagePopup(i, damageSequence, behavior, impactIsCrit, {
            linger = { default = 0.05, exclamation = 0.2 },
            disintegrationTime = 0,
            disintegrationDisplayTime = 0.2,
          })
          self:_handleEnemyDefeatPostHit(i)
        end
      end
      pushLog(self, "You dealt " .. dmg .. " to all enemies!")
    else
      local selectedEnemy = self:getSelectedEnemy()
      if selectedEnemy then
        local index = self.selectedEnemyIndex
        if selectedEnemy.hp > 0 then
          if behavior.delayHPReduction then
            selectedEnemy.pendingDamage = (selectedEnemy.pendingDamage or 0) + dmg
          else
            self:_applyEnemyDamage(index, dmg)
          end

          self:_enqueueDamagePopup(index, damageSequence, behavior, impactIsCrit, {
            linger = { default = 0.3 },
            finalStepDisplayTimeMultiplier = 0.5,
          })
          self:_handleEnemyDefeatPostHit(index)

          if selectedEnemy.hp <= 0 then
            self:_selectNextEnemy()
          end
        end
      end
      pushLog(self, "You dealt " .. dmg)
    end

    self._pendingPlayerAttackDamage = nil
  end

  if self._pendingImpactParams then
    self:_createImpactInstances(self._pendingImpactParams.blockCount, self._pendingImpactParams.isCrit)
    self._pendingImpactParams = nil
  end

  self.playerLungeTime = 1e-6
  self:triggerShake((config.battle and config.battle.shakeMagnitude) or 10, (config.battle and config.battle.shakeDuration) or 0.25)
end

function BattleScene:_calculateDamageSequenceDuration(sequence)
  local total = 0
  if not sequence then return total end
  for _, step in ipairs(sequence) do
    total = total + (step.duration or 0.1)
  end
  return total
end

function BattleScene:_resolvePopupLingerTime(sequence, options)
  options = options or {}
  local defaultLinger = options.default or 0.3
  local exclamationLinger = options.exclamation or defaultLinger

  local lastStep = sequence and sequence[#sequence]
  local hasExclamation = lastStep and lastStep.text and string.find(lastStep.text, "!", 1, true)

  if hasExclamation then
    return exclamationLinger, true
  end
  return defaultLinger, false
end

function BattleScene:_enemyHasActiveDamagePopup(enemyIndex)
  if not enemyIndex then return false end
  for _, popup in ipairs(self.popups or {}) do
    if popup.who == "enemy" and popup.enemyIndex == enemyIndex and popup.t and popup.t > 0 then
      if popup.kind == "animated_damage" and popup.sequence then
        local sequenceIndex = popup.sequenceIndex or 1
        local lastIndex = #popup.sequence
        if sequenceIndex < lastIndex then
          return true
        elseif sequenceIndex == lastIndex then
          local requiredTime = popup.finalStepDisplayTime
          if not requiredTime then
            local lastStep = popup.sequence[sequenceIndex]
            local lastDuration = (lastStep and lastStep.duration) or 0.15
            local linger = popup.lingerTime or 0
            requiredTime = lastDuration + linger
          end
          local sequenceTimer = popup.sequenceTimer or 0
          if sequenceTimer < requiredTime then
            return true
          end
        end
      else
        return true
      end
    end
  end
  return false
end

function BattleScene:_enqueueDamagePopup(enemyIndex, damageSequence, behavior, impactIsCrit, opts)
  local enemy = self.enemies and self.enemies[enemyIndex]
  if not enemy or not damageSequence or #damageSequence == 0 then
    return
  end

  opts = opts or {}
  behavior = behavior or {}

  if not behavior.suppressInitialFlash then
    enemy.flash = config.battle.hitFlashDuration
  end

  if not behavior.suppressInitialKnockback then
    enemy.knockbackTime = 1e-6
  end

  local sequenceDuration = self:_calculateDamageSequenceDuration(damageSequence)
  local lingerOptions = opts.linger or {}
  local lingerTime, hasExclamation = self:_resolvePopupLingerTime(damageSequence, lingerOptions)

  local lastStep = damageSequence[#damageSequence]
  local lastStepDuration = (lastStep and lastStep.duration) or 0.15

  local disintegrationDisplayTime = opts.disintegrationDisplayTime or 0
  local safetyBuffer = opts.safetyBuffer or 0.5
  local disintegrationTime = opts.disintegrationTime
  if disintegrationTime == nil then
    local disintegrationCfg = config.battle.disintegration or {}
    disintegrationTime = disintegrationCfg.duration or 1.5
  end

  local finalStepDisplayTime
  if opts.finalStepDisplayTimeMultiplier then
    finalStepDisplayTime = lastStepDuration * opts.finalStepDisplayTimeMultiplier
  else
    local extra = opts.finalStepDisplayTimeExtra or 0
    finalStepDisplayTime = lastStepDuration + lingerTime + extra
  end

  local totalPopupLifetime = sequenceDuration + lingerTime + disintegrationDisplayTime + disintegrationTime + safetyBuffer
  local popupStartDelay = opts.popupStartDelay
  if popupStartDelay == nil then
    popupStartDelay = behavior.popupDelay or 0
  end

  table.insert(self.popups, {
    x = 0,
    y = 0,
    kind = "animated_damage",
    sequence = damageSequence,
    sequenceIndex = 1,
    sequenceTimer = 0,
    bounceTimer = 0,
    t = totalPopupLifetime,
    originalLifetime = totalPopupLifetime,
    who = "enemy",
    enemyIndex = enemyIndex,
    startDelay = popupStartDelay,
    lingerTime = lingerTime,
    disintegrationDisplayTime = disintegrationDisplayTime,
    safetyBuffer = safetyBuffer,
    sequenceDuration = sequenceDuration,
    hasExclamation = hasExclamation,
    finalStepDisplayTime = finalStepDisplayTime,
  })

  if self.particles and not behavior.suppressInitialParticles then
    local ex, ey = self:getEnemyCenterPivot(enemyIndex, self._lastBounds)
    if ex and ey then
      self.particles:emitHitBurst(ex, ey, nil, impactIsCrit)
    end
  end
end

function BattleScene:_handleEnemyDefeatPostHit(enemyIndex)
  local enemy = self.enemies and self.enemies[enemyIndex]
  if not enemy or enemy.hp > 0 then
    return
  end

  local disintegrationCfg = config.battle.disintegration or {}
  local duration = disintegrationCfg.duration or 1.5
  local hasCompleted = (enemy.disintegrationTime or 0) >= duration
  if hasCompleted then
    return
  end

  local impactsActive = (self.impactInstances and #self.impactInstances > 0) or (self.blackHoleAttacks and #self.blackHoleAttacks > 0)
  local damagePopupActive = self:_enemyHasActiveDamagePopup(enemyIndex)

  if impactsActive or damagePopupActive then
    if not enemy.pendingDisintegration then
      enemy.pendingDisintegration = true
      pushLog(self, "Enemy " .. enemyIndex .. " defeated!")
    end
    return
  end

  if not enemy.disintegrating then
    enemy.disintegrating = true
    enemy.disintegrationTime = 0
    pushLog(self, "Enemy " .. enemyIndex .. " defeated!")
  end
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
  
  local playerLunge = lungeOffset(self.playerLungeTime, (self.impactInstances and #self.impactInstances > 0) or (self.blackHoleAttacks and #self.blackHoleAttacks > 0))
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
  if not enemyIndex then
    return nil, nil
  end
  
  local layout = self:_computeEnemyLayout(bounds)
  local entry = layout.entries[enemyIndex]
  if not entry then
    return nil, nil
  end

  return entry.centerX, entry.centerY
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
  local layout = self:_computeEnemyLayout(bounds)
  
  if not self.enemies or #self.enemies == 0 then
    return hitPoints
  end
  
  for i, enemy in ipairs(self.enemies) do
    if enemy and (enemy.hp > 0 or enemy.disintegrating or enemy.pendingDisintegration) then
      local entry = layout.entries[i]
      if entry then
        table.insert(hitPoints, { x = entry.centerX, y = entry.hitY, enemyIndex = i })
      end
    end
  end
  
  return hitPoints
end

-- Compute current enemy hit point (screen coordinates), matching draw layout
-- Returns hit point for selected enemy
function BattleScene:getEnemyHitPoint(bounds)
  local layout = self:_computeEnemyLayout(bounds)
  local selectedEnemy = self:getSelectedEnemy()
  if selectedEnemy and self.enemies and #self.enemies > 0 then
    local enemy = selectedEnemy
    local enemyIndex = self.selectedEnemyIndex
    local entry = layout.entries[enemyIndex]
    if entry then
      return entry.centerX, entry.hitY
    end
  else
    -- Fallback if no enemies
    local fallbackX
    if layout.rightWidth > 0 then
      fallbackX = layout.rightStart + layout.rightWidth * 0.5
    else
      fallbackX = layout.w - 12 - layout.radius
    end
    return fallbackX, layout.baselineY - layout.radius * 0.7
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
    self._playerAttackDelayTimer = (config.battle and config.battle.playerAttackDelay) or 0.5
  end
  self.impactEffectsPlayed = true
end

-- Internal helper to actually create impact instances (called after delay)
function BattleScene:_createImpactInstances(impactData)
  if not self.impactAnimation then return end
  
  -- Support both old style (positional params) and new style (object)
  if type(impactData) ~= "table" or impactData.blockCount == nil then
    -- Old style: convert to object
    local blockCount, isCrit, isAOE, isPierce, isBlackHole, isLightning = impactData, isCrit, isAOE, isPierce, isBlackHole, isLightning
    impactData = {
      blockCount = blockCount or 1,
      isCrit = isCrit or false,
      isAOE = isAOE or false,
      projectileId = (isLightning and "lightning") or (isBlackHole and "black_hole") or (isPierce and "pierce") or "strike",
    }
  end
  
  ImpactSystem.create(self, impactData)
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
  local impactsActive = (self.impactInstances and #self.impactInstances > 0) or (self.blackHoleAttacks and #self.blackHoleAttacks > 0)

  for index, enemy in ipairs(self.enemies or {}) do
    if enemy and (enemy.hp or 0) > 0 then
      self:_applyEnemyDamage(index, enemy.hp or 0)
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
  
  local layout = self:_computeEnemyLayout(bounds)
  if not self.enemies or #self.enemies == 0 then
    return
  end

  local clickPadding = 30 -- Increased padding for easier clicking
  
  -- Check enemies in reverse order (right to left) so rightmost enemy gets priority when overlapping
  for i = #self.enemies, 1, -1 do
    local enemy = self.enemies[i]
    local entry = layout.entries[i]
    if enemy and entry then
      local left = entry.centerX - entry.halfWidth - clickPadding
      local right = entry.centerX + entry.halfWidth + clickPadding
      local top = entry.boundingTop - clickPadding
      local bottom = layout.baselineY + clickPadding

      if x >= left and x <= right and y >= top and y <= bottom then
      if enemy.hp > 0 or enemy.disintegrating or enemy.pendingDisintegration then
        self.selectedEnemyIndex = i
        return
      end
    end
    end
  end
end

BattleScene._ensureBattleState = StateBridge.ensure
BattleScene._syncPlayerFromState = StateBridge.syncPlayer
BattleScene._syncEnemiesFromState = StateBridge.syncEnemies
BattleScene._applyPlayerDamage = StateBridge.applyPlayerDamage
BattleScene._applyPlayerHeal = StateBridge.applyPlayerHeal
BattleScene._setPlayerArmor = StateBridge.setPlayerArmor
BattleScene._addPlayerArmor = StateBridge.addPlayerArmor
BattleScene._applyEnemyDamage = StateBridge.applyEnemyDamage
BattleScene._registerEnemyIntent = StateBridge.registerEnemyIntent

return BattleScene



