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
  StateBridge.get(self)
  self:_syncPlayerFromState()
  self:_syncEnemiesFromState()

  -- Update enemy flash timers
  for _, enemy in ipairs(self.enemies or {}) do
    if enemy.flash > 0 then enemy.flash = math.max(0, enemy.flash - dt * 0.85) end
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
  
  -- Helper function to check if there are active damage popups for an enemy
  local function hasActiveDamagePopup(enemyIndex)
    if not enemyIndex then return false end
    for _, popup in ipairs(self.popups or {}) do
      if popup.who == "enemy" and popup.enemyIndex == enemyIndex and popup.t > 0 then
        -- Check if it's an animated damage popup that hasn't finished its sequence
        if popup.kind == "animated_damage" and popup.sequence then
          local sequenceIndex = popup.sequenceIndex or 1
          -- If we haven't reached the last step, still animating
          if sequenceIndex < #popup.sequence then
            return true -- Still animating through sequence
          elseif sequenceIndex == #popup.sequence then
            -- On last step, wait for full duration plus a small linger time
            local lastStep = popup.sequence[sequenceIndex]
            -- Longer linger time if it has exclamation mark
            local hasExclamation = lastStep.text and string.find(lastStep.text, "!") ~= nil
            local lingerTime = hasExclamation and 0.2 or 0.05 -- Longer linger for final "XX!" number
            local totalDisplayTime = (lastStep.duration or 0.1) + lingerTime
            if lastStep and popup.sequenceTimer and popup.sequenceTimer < totalDisplayTime then
              return true -- Last step hasn't been shown long enough (wait for full duration + linger)
            end
          end
        elseif popup.kind ~= "animated_damage" then
          -- Regular popup, just check if it's still active
          return true
        end
      end
    end
    return false
  end
  
  -- Check if enemies should start disintegrating (safeguard for any code path)
  -- Only auto-start if no impact animations are active and disintegration isn't pending
  -- Also check that disintegration hasn't already completed (to prevent looping)
  for i, enemy in ipairs(self.enemies or {}) do
    if enemy.hp <= 0 and not enemy.disintegrating and not enemy.pendingDisintegration and self.state ~= "win" then
      -- Check if disintegration has already completed (prevent restarting)
      local cfg = config.battle.disintegration or {}
      local duration = cfg.duration or 1.5
      local hasCompletedDisintegration = (enemy.disintegrationTime or 0) >= duration
      
      if not hasCompletedDisintegration then
        local impactsActive = (self.impactInstances and #self.impactInstances > 0) or (self.blackHoleAttacks and #self.blackHoleAttacks > 0)
        local damagePopupActive = hasActiveDamagePopup(i)
        if impactsActive or damagePopupActive then
          -- Wait for impact animations or damage popup to finish
          enemy.pendingDisintegration = true
        else
          -- No impacts or popups, start disintegration immediately
          enemy.disintegrating = true
          enemy.disintegrationTime = 0
        end
      end
    end
  end
  
  -- Update intent fade animations
  local turnManager = self.turnManager
  local isPlayerTurn = turnManager and (
    turnManager:getState() == TurnManager.States.PLAYER_TURN_START or
    turnManager:getState() == TurnManager.States.PLAYER_TURN_ACTIVE
  )
  
  local fadeInDuration = 0.3 -- 0.3 seconds to fade in
  local fadeOutDuration = 0.2 -- 0.2 seconds to fade out
  
  for _, enemy in ipairs(self.enemies or {}) do
    if enemy.intentFadeTime ~= nil then
      if isPlayerTurn then
        -- Fade in during player turn
        if enemy.intentFadeTime < fadeInDuration then
          enemy.intentFadeTime = math.min(fadeInDuration, enemy.intentFadeTime + dt)
        else
          enemy.intentFadeTime = fadeInDuration -- Keep at max during player turn
        end
      else
        -- Fade out when not in player turn
        enemy.intentFadeTime = math.max(0, enemy.intentFadeTime - dt * (fadeInDuration / fadeOutDuration))
        if enemy.intentFadeTime <= 0 then
          enemy.intentFadeTime = nil
        end
      end
    end
  end
  
  -- Update Bloodhound enrage FX timers
  do
    local fxDuration = 0.8 -- seconds
    for _, enemy in ipairs(self.enemies or {}) do
      if enemy.enrageFxActive and enemy.enrageFxTime ~= nil then
        enemy.enrageFxTime = enemy.enrageFxTime + dt
        if enemy.enrageFxTime >= fxDuration or enemy.hp <= 0 then
          enemy.enrageFxActive = false
        end
      end
    end
  end
  
  -- Update enemy disintegration effects
  for _, enemy in ipairs(self.enemies or {}) do
    if enemy.disintegrating then
    local cfg = config.battle.disintegration or {}
    local duration = cfg.duration or 1.5
      enemy.disintegrationTime = enemy.disintegrationTime + dt * 0.5
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
    -- Handle start delay (for black hole attacks)
    if p.startDelay and p.startDelay > 0 then
      p.startDelay = p.startDelay - dt
      if p.startDelay > 0 then
        -- Still in delay, keep popup but don't update it yet
        table.insert(alive, p)
        goto continue
      else
        -- Delay finished, popup can now start showing
        p.startDelay = nil
      end
    end
    
    -- Update animated damage sequence first
    local sequenceCompleted = false
    if p.kind == "animated_damage" and p.sequence and #p.sequence > 0 then
      -- Initialize sequence index if not set
      if not p.sequenceIndex then
        p.sequenceIndex = 1
        p.sequenceTimer = 0
      end
      
      local prevSequenceIndex = p.sequenceIndex
      p.sequenceTimer = (p.sequenceTimer or 0) + dt
      local currentStep = p.sequence[p.sequenceIndex]
      
      -- Ensure we wait for the full duration of each step before advancing
      if currentStep and p.sequenceTimer >= currentStep.duration then
        -- Move to next step in sequence (only reset timer when advancing)
        if p.sequenceIndex < #p.sequence then
          p.sequenceTimer = 0
          p.sequenceIndex = p.sequenceIndex + 1
          -- Reset bounce timer when step changes
          p.bounceTimer = 0
        end
        -- If on final step, do not reset timer here; let completion check handle finish
      end
      
      -- Check if sequence has completed (on final step and its duration has elapsed)
      -- IMPORTANT: Only mark as completed when we're on the final step AND its full duration has elapsed
      if p.sequenceIndex == #p.sequence then
        local finalStep = p.sequence[p.sequenceIndex]
        -- Force wait for the full duration of the final step before marking complete
        if finalStep and p.sequenceTimer >= finalStep.duration then
          sequenceCompleted = true
          -- Mark sequence as completed (only once)
          if not p.sequenceFinished then
            p.sequenceFinished = true
            
            -- Apply pending damage now that animation is complete
            if p.who == "enemy" and p.enemyIndex then
              local enemy = self.enemies and self.enemies[p.enemyIndex]
              if enemy and enemy.pendingDamage and enemy.pendingDamage > 0 then
                self:_applyEnemyDamage(p.enemyIndex, enemy.pendingDamage)
                enemy.pendingDamage = 0
              end
            end
            
            -- Longer linger for the final value
            local lastStep = p.sequence[#p.sequence]
            local hasExclamation = lastStep and lastStep.text and string.find(lastStep.text, "!") ~= nil
            local lingerTime = hasExclamation and 0.9 or 0.45
            local disintegrationDisplayTime = 0.25
            -- Set popup timer to linger window and capture originalLifetime so fade uses this window
            p.t = lingerTime + disintegrationDisplayTime
            p.originalLifetime = p.t
          end
        end
      else
        -- If not on final step yet, ensure sequence is not marked as finished
        -- This prevents premature display of final number
        sequenceCompleted = false
      end
      
      -- Update bounce timer (for bounce animation on step changes)
      -- Initialize bounce timer if not set (for first step)
      if p.bounceTimer == nil then
        p.bounceTimer = 0
      end
      p.bounceTimer = p.bounceTimer + dt
        
      -- Initialize and update character bounce timers for multiplier steps
      if currentStep and currentStep.isMultiplier then
        -- Initialize character bounce timers when multiplier step first appears
        if not p.charBounceTimers then
          p.charBounceTimers = { 0, 0, 0 } -- Initialize timers for each character part
          p.multiplierTarget = nil -- Will be set when parsing multiplier text
        end
        
        -- Update character bounce timers with sequential delays
        local charBounceDelay = 0.08 -- Delay between each character bounce
        -- Use a separate timer for multiplier animation that doesn't reset
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
      
      -- Check if we're on the final step with exclamation mark - add shake effect
      local isFinalStep = (p.sequenceIndex == #p.sequence)
      local finalStep = p.sequence[#p.sequence]
      local hasExclamation = finalStep and finalStep.text and string.find(finalStep.text, "!") ~= nil
      
      if isFinalStep and hasExclamation then
        -- Initialize shake/rotation if not already set
        if not p.shakeTime then
          local finalStepDuration = finalStep.duration or 0.1
          p.shakeTime = finalStepDuration * 2.5 -- Shake for 2.5x the final step duration
          p.shakeRotation = 0
          p.shakeUpdateTimer = 0 -- Timer for updating shake values
        end
        
        -- Update shake and rotation
        if p.shakeTime > 0 then
          p.shakeTime = p.shakeTime - dt
          p.shakeUpdateTimer = (p.shakeUpdateTimer or 0) + dt
          
          -- Shake offset: random jitter that decreases over time
          local shakeDuration = (finalStep.duration or 0.1) * 2.5 -- Match the initialized duration
          local progress = p.shakeTime / shakeDuration
          local shakeMagnitude = 4 * progress -- Shake decreases over time
          
          -- Update shake values less frequently (every 0.05 seconds instead of every frame)
          local shakeUpdateInterval = 0.05
          if p.shakeUpdateTimer >= shakeUpdateInterval then
            p.shakeUpdateTimer = 0
            p.shakeOffsetX = (love.math.random() * 2 - 1) * shakeMagnitude
            p.shakeOffsetY = (love.math.random() * 2 - 1) * shakeMagnitude
          end
          
          -- Rotation: oscillate with decreasing amplitude (more noticeable rotation)
          local rotationSpeed = 15 -- oscillations per second
          local elapsedTime = shakeDuration - p.shakeTime
          p.shakeRotation = math.sin(elapsedTime * rotationSpeed * 2 * math.pi) * 0.15 * progress -- Up to 0.15 radians (~8.6 degrees)
        else
          -- Reset shake when done
          p.shakeOffsetX = 0
          p.shakeOffsetY = 0
          p.shakeRotation = 0
          p.shakeUpdateTimer = nil
        end
      else
        -- Reset shake if not on final step
        p.shakeOffsetX = 0
        p.shakeOffsetY = 0
        p.shakeRotation = 0
        p.shakeTime = nil
      end
    end
    
    -- Only decrement popup timer if sequence has completed (or if not an animated damage popup)
    -- CRITICAL: For animated damage, NEVER decrement timer until sequence is fully complete
    local isAnimatedDamage = (p.kind == "animated_damage" and p.sequence)
    if not isAnimatedDamage then
      -- Non-animated popups: decrement normally
      p.t = p.t - dt
    elseif sequenceCompleted or (p.sequenceFinished == true) then
      -- Animated damage: only decrement after sequence has fully completed
      -- This ensures the final number stays visible until all steps have finished
      p.t = p.t - dt
    else
      -- Sequence still in progress: keep popup alive indefinitely until it completes
      -- Don't decrement timer - this forces the sequence to finish before fade starts
    end
    
    -- Keep popup alive if it has time left
    if p.t > 0 then 
      table.insert(alive, p) 
    end
    
    ::continue::
  end
  self.popups = alive
  
  -- Check if pending disintegration enemies can now start disintegrating (popups finished)
  for i, enemy in ipairs(self.enemies or {}) do
    if enemy.pendingDisintegration and enemy.hp <= 0 then
      local impactsActive = (self.impactInstances and #self.impactInstances > 0) or (self.blackHoleAttacks and #self.blackHoleAttacks > 0)
      local damagePopupActive = hasActiveDamagePopup(i)
      if not impactsActive and not damagePopupActive then
        -- Popups and impacts finished, start disintegration
        enemy.pendingDisintegration = false
        if not enemy.disintegrating then
          enemy.disintegrating = true
          enemy.disintegrationTime = 0
        end
      end
    end
  end
  
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
    self.borderFragments = EnemySkills.createBorderFragments(self.playerBarX, self.playerBarY, self.playerBarW, self.playerBarH, gap, 6)
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
  
  -- Update enemy armor borders and detect armor break/gain for each enemy
  for i, enemy in ipairs(self.enemies or {}) do
    if enemy then
      local prevArmor = self.prevEnemyArmor[i] or 0
      local currentArmor = enemy.armor or 0
      local enemyArmorBroken = prevArmor > 0 and currentArmor == 0
      local enemyArmorGained = prevArmor == 0 and currentArmor > 0
      
      if enemyArmorBroken and self.enemyBarX[i] and self.enemyBarY[i] and self.enemyBarW[i] and self.enemyBarH[i] then
        -- Create shatter fragments for this enemy
        local gap = 3
        self.enemyBorderFragments[i] = EnemySkills.createBorderFragments(self.enemyBarX[i], self.enemyBarY[i], self.enemyBarW[i], self.enemyBarH[i], gap, 6)
      end
      
      -- Start fade-in animation when armor is gained
      if enemyArmorGained then
        self.enemyBorderFadeInTime[i] = self.borderFadeInDuration
      end
      
      -- Update border fade-in timer
      if self.enemyBorderFadeInTime[i] and self.enemyBorderFadeInTime[i] > 0 then
        self.enemyBorderFadeInTime[i] = math.max(0, self.enemyBorderFadeInTime[i] - dt)
      end
      
      -- Store previous armor value
      self.prevEnemyArmor[i] = currentArmor
      
      -- Update fragments with easing
      if self.enemyBorderFragments[i] then
        local aliveEnemyFragments = {}
        for _, frag in ipairs(self.enemyBorderFragments[i]) do
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
            
            table.insert(aliveEnemyFragments, frag)
          end
        end
        self.enemyBorderFragments[i] = aliveEnemyFragments
      end
    end
  end

  -- Handle enemy turn delay (for armor popup timing and player attack completion)
  if self._enemyTurnDelay and self._enemyTurnDelay > 0 then
    self._enemyTurnDelay = self._enemyTurnDelay - dt
    
    -- Check if player attack animation is still active (lunge or black hole)
    local playerAttackActive = (self.playerLungeTime and self.playerLungeTime > 0) or false
    local blackHoleActive = (self.blackHoleAttacks and #self.blackHoleAttacks > 0) or false
    
    if (playerAttackActive or blackHoleActive) and self._pendingEnemyTurnStart then
      -- Player attack or black hole still playing, calculate remaining time
      local remainingTime = 0
      
      if playerAttackActive then
      local lungeD = (config.battle and config.battle.lungeDuration) or 0
      local lungeRD = (config.battle and config.battle.lungeReturnDuration) or 0
      local lungePause = (config.battle and config.battle.lungePauseDuration) or 0
      local totalLungeDuration = lungeD + lungePause + lungeRD
        remainingTime = math.max(remainingTime, totalLungeDuration - (self.playerLungeTime or 0))
      end
      
      if blackHoleActive then
        -- Calculate remaining black hole animation time
        for _, attack in ipairs(self.blackHoleAttacks or {}) do
          local attackRemaining = attack.duration - attack.t
          remainingTime = math.max(remainingTime, attackRemaining)
        end
      end
      
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

  -- Update enemy skill sequences
  EnemySkills.update(self, dt)
  
  -- Update heal glow timers (fade out over time)
  if self.playerHealGlowTimer > 0 then
    self.playerHealGlowTimer = math.max(0, self.playerHealGlowTimer - dt)
  end
  for i, enemy in ipairs(self.enemies or {}) do
    if self.enemyHealGlowTimer[i] and self.enemyHealGlowTimer[i] > 0 then
      self.enemyHealGlowTimer[i] = math.max(0, self.enemyHealGlowTimer[i] - dt)
    end
  end
  
  -- Check for charged attacks entering forward phase and apply damage
  for _, enemy in ipairs(self.enemies or {}) do
    if enemy.pendingChargedDamage and enemy.chargeLungeTime and enemy.chargeLungeTime > 0 and enemy.chargeLunge then
      local t = enemy.chargeLungeTime
      local w = enemy.chargeLunge.windupDuration or 0.55
      local f = enemy.chargeLunge.forwardDuration or 0.2
      
      -- Check if we just entered the forward phase (windup just finished)
      -- Apply damage once when forward phase starts (not during windup)
      -- Apply when we cross the threshold from windup to forward phase
      if t >= w and not enemy.chargedDamageApplied then
        enemy.chargedDamageApplied = true -- Mark as applied to prevent multiple applications
        
        local dmg = enemy.pendingChargedDamage
        local blocked, net = self:_applyPlayerDamage(dmg)
        
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
          pushLog(self, (enemy.name or "Enemy") .. " dealt " .. net)
          if self.onPlayerDamage then
            self.onPlayerDamage()
          end
        end
        
        -- Trigger screenshake when damage is applied
        self:triggerShake((config.battle and config.battle.shakeMagnitude) or 10, (config.battle and config.battle.shakeDuration) or 0.25)
        
        -- Clear pending damage
        enemy.pendingChargedDamage = nil
      end
      
      -- Reset flag when animation completes
      if t >= w + f + (enemy.chargeLunge.returnDuration or 0.2) then
        enemy.chargedDamageApplied = nil
      end
    end
  end

  -- Update multi-hit attack timers
  for i, enemy in ipairs(self.enemies or {}) do
    if enemy.multiHitState then
      local state = enemy.multiHitState
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
            -- Flash and knockback on EVERY hit for better visual feedback
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
          
          -- Trigger lunge on EVERY hit for better visual feedback
          enemy.lungeTime = 1e-6
          -- Trigger shake on EVERY hit for better feedback
          self:triggerShake((config.battle and config.battle.shakeMagnitude) or 8, (config.battle and config.battle.shakeDuration) or 0.2)
          
          -- On last hit, clean up
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
  
  -- Update tweened darkness for non-attacking enemies
  local targetDarkness = (self._attackingEnemyIndex ~= nil) and 1.0 or 0.0 -- Darken fully (to 0% brightness) when enemy is attacking
  local darknessSpeed = 4.0 -- Speed of darkness tween
  local darknessDelta = targetDarkness - self._nonAttackingEnemyDarkness
  self._nonAttackingEnemyDarkness = self._nonAttackingEnemyDarkness + darknessDelta * math.min(1, darknessSpeed * dt)
  
  -- Handle staggered enemy attack delays
  -- Don't process staggered attacks while shockwave, calcify, or charged attack is active
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
      -- Shockwave, calcify, or charged attack is active, don't count down - just keep the delay data
      table.insert(aliveAttackDelays, delayData)
    else
      delayData.delay = delayData.delay - dt
      if delayData.delay <= 0 then
        -- Set this enemy as the attacking enemy (before performing action)
        self._attackingEnemyIndex = delayData.index
        
        -- Perform action for this enemy
        local enemy = self.enemies[delayData.index]
        if enemy and enemy.hp > 0 then
          -- Use stored intent if available, otherwise fall back to default damage
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
        -- Clear attacking enemy after attack completes (with small delay for visual feedback)
        -- The delay will be handled by checking if attack delays are empty
      else
        table.insert(aliveAttackDelays, delayData)
      end
    end
  end
  self._enemyAttackDelays = aliveAttackDelays
  
  -- Clear attacking enemy index when all attacks are done
  -- Add small delay after last attack completes for visual feedback
  if #self._enemyAttackDelays == 0 and not shockwaveActive and not calcifyActive then
    -- Keep attacking enemy visible for a brief moment after attack completes
    if not self._attackingEnemyClearDelay then
      self._attackingEnemyClearDelay = 0.3 -- 0.3s delay before clearing
    else
      self._attackingEnemyClearDelay = self._attackingEnemyClearDelay - dt
      if self._attackingEnemyClearDelay <= 0 then
        self._attackingEnemyIndex = nil
        self._attackingEnemyClearDelay = nil
      end
    end
  else
    -- Reset delay if attacks are still happening
    self._attackingEnemyClearDelay = nil
  end

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
        local projectileId = self._pendingPlayerAttackDamage.projectileId or "strike"
        local behavior = self._pendingPlayerAttackDamage.behavior
        local impactBlockCount = self._pendingPlayerAttackDamage.impactBlockCount or 1
        local impactIsCrit = self._pendingPlayerAttackDamage.impactIsCrit or false
        
        -- Create impact sprite animations first (before damage effects)
        if impactBlockCount and impactBlockCount > 0 then
          self:_createImpactInstances({
            blockCount = impactBlockCount,
            isCrit = impactIsCrit,
            isAOE = isAOE,
            projectileId = projectileId,
            behavior = behavior
          })
        end
        
        -- Build animated damage sequence
        local blockHitSequence = self._pendingPlayerAttackDamage.blockHitSequence or {}
        local orbBaseDamage = self._pendingPlayerAttackDamage.orbBaseDamage or 0
        
        -- Calculate baseDamage if not provided (exclude crit/multiplier blocks)
        local baseDamage = self._pendingPlayerAttackDamage.baseDamage
        if not baseDamage or baseDamage == 0 then
          baseDamage = orbBaseDamage
          for _, hit in ipairs(blockHitSequence) do
            local kind = (type(hit) == "table" and hit.kind) or "damage"
            local amount = (type(hit) == "table" and (hit.damage or hit.amount)) or 0
            -- Only add damage from blocks that actually deal damage
            -- Exclude crit/multiplier (they are multipliers) and armor/heal/potion (non-damage effects)
            if kind ~= "crit" and kind ~= "multiplier" and kind ~= "armor" and kind ~= "heal" and kind ~= "potion" then
              baseDamage = baseDamage + amount
            end
          end
        end
        
        local critCount = self._pendingPlayerAttackDamage.critCount or 0
        local multiplierCount = self._pendingPlayerAttackDamage.multiplierCount or 0
        local damageSequence = buildDamageAnimationSequence(blockHitSequence, baseDamage, orbBaseDamage, critCount, multiplierCount, dmg)
        
        -- Apply damage to all enemies if AOE, otherwise just selected enemy
        if isAOE then
          -- AOE attack: damage all enemies
          for i, enemy in ipairs(self.enemies or {}) do
            if enemy and enemy.hp > 0 then
              -- For black hole, delay HP reduction until damage animation completes
              if behavior.delayHPReduction then
                enemy.pendingDamage = (enemy.pendingDamage or 0) + dmg
              else
                self:_applyEnemyDamage(i, dmg)
              end
              
              -- Trigger enemy hit visual effects (flash, knockback, animated popup)
              -- Use behavior config to determine what effects to show
              if not behavior.suppressInitialFlash then
                enemy.flash = config.battle.hitFlashDuration
              end
              if not behavior.suppressInitialKnockback then
                enemy.knockbackTime = 1e-6
              end
              -- Calculate total animation duration + linger + disintegration time
              -- IMPORTANT: Sum ALL step durations to ensure we wait for the complete sequence
              local totalSequenceDuration = 0
              for _, step in ipairs(damageSequence) do
                totalSequenceDuration = totalSequenceDuration + (step.duration or 0.1)
              end
              -- Longer linger time if final step has exclamation mark
              local lastStep = damageSequence[#damageSequence]
              local hasExclamation = lastStep and lastStep.text and string.find(lastStep.text, "!") ~= nil
              local lingerTime = hasExclamation and 0.2 or 0.05 -- Longer linger for final "XX!" number
              -- Only keep popup visible for a short time during disintegration, not the full duration
              local disintegrationDisplayTime = 0.2 -- Show during first part of disintegration
              -- Add extra buffer to ensure sequence always completes (safety margin)
              local safetyBuffer = 0.5 -- Extra time to ensure sequence never times out prematurely
              local totalPopupLifetime = totalSequenceDuration + lingerTime + disintegrationDisplayTime + safetyBuffer
              
              -- Use behavior config for popup delay
              local popupStartDelay = behavior.popupDelay or 0
              
              table.insert(self.popups, { 
                x = 0, 
                y = 0, 
                kind = "animated_damage",
                sequence = damageSequence,
                sequenceIndex = 1,
                sequenceTimer = 0,
                bounceTimer = 0, -- Initialize bounce timer for bounce animation on step changes
                t = totalPopupLifetime, -- Long enough to cover animation + disintegration
                originalLifetime = totalPopupLifetime, -- Store original lifetime for progress calculation
                who = "enemy", 
                enemyIndex = i,
                startDelay = popupStartDelay -- Delay before popup becomes visible
              })
              -- Emit hit burst particles from enemy center (use behavior config)
              if self.particles and not behavior.suppressInitialParticles then
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
                  local impactsActive = (self.impactInstances and #self.impactInstances > 0) or (self.blackHoleAttacks and #self.blackHoleAttacks > 0)
                  -- Check if damage popup animation is still playing
                  local damagePopupActive = false
                  for _, popup in ipairs(self.popups or {}) do
                    if popup.who == "enemy" and popup.enemyIndex == i and popup.t > 0 then
                      if popup.kind == "animated_damage" and popup.sequence then
                        local sequenceIndex = popup.sequenceIndex or 1
                        if sequenceIndex < #popup.sequence then
                          damagePopupActive = true
                          break
                        elseif sequenceIndex == #popup.sequence then
                          local lastStep = popup.sequence[sequenceIndex]
                          -- Longer linger time if it has exclamation mark
                          local hasExclamation = lastStep.text and string.find(lastStep.text, "!") ~= nil
                          local lingerTime = hasExclamation and 0.2 or 0.05 -- Longer linger for final "XX!" number
                          local totalDisplayTime = (lastStep.duration or 0.15) + lingerTime
                          if lastStep and popup.sequenceTimer and popup.sequenceTimer < totalDisplayTime then
                            damagePopupActive = true
                            break
                          end
                        end
                      elseif popup.kind ~= "animated_damage" then
                        damagePopupActive = true
                        break
                      end
                    end
                  end
                  
                  if impactsActive or damagePopupActive then
                    -- Wait for impact animations or damage popup to finish before starting disintegration
                    enemy.pendingDisintegration = true
                    pushLog(self, "Enemy " .. i .. " defeated!")
                  else
                    -- Start disintegration effect immediately if no impacts or popups
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
            -- For black hole, delay HP reduction until damage animation completes
            if behavior.delayHPReduction then
              selectedEnemy.pendingDamage = (selectedEnemy.pendingDamage or 0) + dmg
            else
              self:_applyEnemyDamage(i, dmg)
            end
        
            -- Trigger enemy hit visual effects (flash, knockback, animated popup)
            -- Use behavior config to determine what effects to show
            if not behavior.suppressInitialFlash then
              selectedEnemy.flash = config.battle.hitFlashDuration
            end
            if not behavior.suppressInitialKnockback then
              selectedEnemy.knockbackTime = 1e-6
            end
            -- Calculate total animation duration + linger + disintegration time
            -- IMPORTANT: Sum ALL step durations to ensure we wait for the complete sequence
            local totalSequenceDuration = 0
            for _, step in ipairs(damageSequence) do
              totalSequenceDuration = totalSequenceDuration + (step.duration or 0.1)
            end
            local lingerTime = 0.3
            local disintegrationDuration = (config.battle.disintegration and config.battle.disintegration.duration) or 1.5
            -- Add extra buffer to ensure sequence always completes (safety margin)
            local safetyBuffer = 0.5 -- Extra time to ensure sequence never times out prematurely
            local totalPopupLifetime = totalSequenceDuration + lingerTime + disintegrationDuration + safetyBuffer
            
            -- Use behavior config for popup delay
            local popupStartDelay = behavior.popupDelay or 0
            
            table.insert(self.popups, { 
              x = 0, 
              y = 0, 
              kind = "animated_damage",
              sequence = damageSequence,
              sequenceIndex = 1,
              sequenceTimer = 0,
              bounceTimer = 0, -- Initialize bounce timer for bounce animation on step changes
              t = totalPopupLifetime, -- Long enough to cover animation + disintegration
              originalLifetime = totalPopupLifetime, -- Store original lifetime for progress calculation
              who = "enemy", 
              enemyIndex = i,
              startDelay = popupStartDelay -- Delay before popup becomes visible
            })
            -- Emit hit burst particles from enemy center (use behavior config)
            if self.particles and not behavior.suppressInitialParticles then
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
                local impactsActive = (self.impactInstances and #self.impactInstances > 0) or (self.blackHoleAttacks and #self.blackHoleAttacks > 0)
                -- Check if damage popup animation is still playing
                local damagePopupActive = false
                for _, popup in ipairs(self.popups or {}) do
                  if popup.who == "enemy" and popup.enemyIndex == i and popup.t > 0 then
                    if popup.kind == "animated_damage" and popup.sequence then
                      local sequenceIndex = popup.sequenceIndex or 1
                      if sequenceIndex < #popup.sequence then
                        damagePopupActive = true
                        break
                      elseif sequenceIndex == #popup.sequence then
                        local lastStep = popup.sequence[sequenceIndex]
                        if lastStep and popup.sequenceTimer and popup.sequenceTimer < (lastStep.duration * 0.5) then
                          damagePopupActive = true
                          break
                        end
                      end
                    elseif popup.kind ~= "animated_damage" then
                      damagePopupActive = true
                      break
                    end
                  end
                end
                
                if impactsActive or damagePopupActive then
                  -- Wait for impact animations or damage popup to finish before starting disintegration
                  selectedEnemy.pendingDisintegration = true
                  pushLog(self, "Enemy " .. i .. " defeated!")
                else
                  -- Start disintegration effect immediately if no impacts or popups
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



