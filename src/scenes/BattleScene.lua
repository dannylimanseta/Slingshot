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
local EnemyController = require("scenes.battle.EnemyController")
local PopupController = require("scenes.battle.PopupController")
local UpdateController = require("scenes.battle.UpdateController")

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
  
  -- Determine if current encounter is elite and compute relic multipliers
  local isEliteEncounter = false
  do
    local ok, EncounterManager = pcall(require, "core.EncounterManager")
    if ok and EncounterManager and EncounterManager.getCurrentEncounter then
      local enc = EncounterManager.getCurrentEncounter()
      isEliteEncounter = enc and enc.elite == true
    end
  end
  local eliteHpMultiplier = 1.0
  if isEliteEncounter then
    local RelicSystem = require("core.RelicSystem")
    if RelicSystem and RelicSystem.getEliteEnemyHpMultiplier then
      eliteHpMultiplier = RelicSystem.getEliteEnemyHpMultiplier() or 1.0
    end
  end
  
  -- Create a modified battle profile copy with reduced HP for elite encounters
  -- This ensures both BattleScene and BattleState use the same modified values
  local modifiedProfile = battleProfile
  if isEliteEncounter and eliteHpMultiplier ~= 1.0 and battleProfile.enemies then
    modifiedProfile = {}
    for k, v in pairs(battleProfile) do
      modifiedProfile[k] = v
    end
    modifiedProfile.enemies = {}
    for i, enemyConfig in ipairs(battleProfile.enemies) do
      local modifiedEnemy = {}
      for k, v in pairs(enemyConfig) do
        modifiedEnemy[k] = v
      end
      if modifiedEnemy.maxHP then
        modifiedEnemy.maxHP = math.max(1, math.floor(modifiedEnemy.maxHP * eliteHpMultiplier + 0.5))
      end
      table.insert(modifiedProfile.enemies, modifiedEnemy)
    end
  end
  
  -- Initialize enemies from battle profile
  self.enemies = {}
  local maxAvailableEnemies = modifiedProfile.enemies and #modifiedProfile.enemies or 0
  
  -- Use enemyCount from battle profile if specified, otherwise randomize (for backward compatibility)
  local enemyCount
  if modifiedProfile.enemyCount and modifiedProfile.enemyCount > 0 then
    -- Use the specified enemy count from the battle profile
    enemyCount = math.min(modifiedProfile.enemyCount, maxAvailableEnemies)
  else
    -- Fallback: Randomize enemy count between 1-3 for old battle profiles
    local randomEnemyCount = love.math.random(1, 3)
    enemyCount = math.min(randomEnemyCount, maxAvailableEnemies)
  end
  
  -- Select enemies sequentially from the battle profile (respects encounter order)
  if modifiedProfile.enemies and maxAvailableEnemies > 0 then
    for i = 1, enemyCount do
      if modifiedProfile.enemies[i] then
        local enemyConfig = modifiedProfile.enemies[i]
        local enemy = createEnemyFromConfig(enemyConfig, i)
        table.insert(self.enemies, enemy)
      end
    end
  end

  self:_ensureBattleState(modifiedProfile)
  
  -- Apply elite HP reduction to BattleState enemies directly
  -- This ensures BattleState has the correct HP values matching our modified profile
  if isEliteEncounter and eliteHpMultiplier ~= 1.0 and self.battleState and self.battleState.enemies and modifiedProfile.enemies then
    for i, stateEnemy in ipairs(self.battleState.enemies) do
      local modifiedEnemyConfig = modifiedProfile.enemies[i]
      if modifiedEnemyConfig and modifiedEnemyConfig.maxHP then
        stateEnemy.maxHP = modifiedEnemyConfig.maxHP
        stateEnemy.hp = math.min(stateEnemy.hp or stateEnemy.maxHP, modifiedEnemyConfig.maxHP)
      end
    end
  end
  
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
  UpdateController.update(self, dt)
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
  -- Slow down animation by 50% (multiply duration by 1.5)
  self._pendingTurnIndicator = { text = "YOUR TURN", t = 1.0 * 1.5, duration = 1.0 * 1.5 }
  self.turnIndicatorDelay = 0.3
end

-- Generic API: show any turn indicator (used by TurnManager)
function BattleScene:showTurnIndicator(text, duration)
  text = text or "TURN"
  duration = duration or 1.0
  -- Slow down animation by 50% (multiply duration by 1.5)
  local slowedDuration = duration * 1.5
  -- Clear any existing pending indicator to avoid conflicts
  self._pendingTurnIndicator = { text = text, t = slowedDuration, duration = slowedDuration }
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
  return EnemyController.getSelectedEnemy(self)
end

function BattleScene:_syncStateFromBridge()
  StateBridge.get(self)
  self:_syncPlayerFromState()
  self:_syncEnemiesFromState()
end

BattleScene._updateEnemyFlashTimers = UpdateController.updateEnemyFlashTimers
BattleScene._updatePlayerHitEffects = UpdateController.updatePlayerHitEffects
BattleScene._tweenHealthBars = UpdateController.tweenHealthBars
BattleScene._startDisintegrationIfReady = PopupController.startDisintegrationIfReady
BattleScene._updateIntentFadeAnimations = UpdateController.updateIntentFadeAnimations

BattleScene._updateEnrageFx = UpdateController.updateEnrageFx
BattleScene._advanceDisintegrationAnimations = UpdateController.advanceDisintegrationAnimations
BattleScene._updateVictoryState = UpdateController.updateVictoryState
BattleScene._updateTurnIndicator = UpdateController.updateTurnIndicator
BattleScene._updatePopups = PopupController.update
BattleScene._triggerPendingDisintegrations = PopupController.triggerPendingDisintegrations

BattleScene._updateArmorEffects = UpdateController.updateArmorEffects
BattleScene._updateEnemyTurnDelay = UpdateController.updateEnemyTurnDelay
BattleScene._updateHealGlowTimers = UpdateController.updateHealGlowTimers

BattleScene._processChargedAttackDamage = UpdateController.processChargedAttackDamage
BattleScene._updateMultiHitAttacks = UpdateController.updateMultiHitAttacks
BattleScene._updateEnemyDarkness = UpdateController.updateEnemyDarkness
BattleScene._updateEnemyAttackDelays = UpdateController.updateEnemyAttackDelays
BattleScene._updatePlayerAttackDelay = UpdateController.updatePlayerAttackDelay

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

function BattleScene:getAllEnemyHitPoints(bounds)
  return EnemyController.getAllEnemyHitPoints(self, bounds)
end

function BattleScene:getEnemyHitPoint(bounds)
  return EnemyController.getEnemyHitPoint(self, bounds)
end

function BattleScene:getEnemyCenterPivot(enemyIndex, bounds)
  return EnemyController.getEnemyCenterPivot(self, enemyIndex, bounds)
end

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
    EnemyController.cycleEnemySelection(self)
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
    EnemyController.selectNextEnemy(self)
  end
end

-- Cycle enemy selection to the next alive enemy
-- Handle mouse clicks for enemy selection
function BattleScene:mousepressed(x, y, button, bounds)
  EnemyController.handleMousePressed(self, x, y, button, bounds)
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



