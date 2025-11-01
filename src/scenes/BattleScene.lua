local config = require("config")
local theme = require("theme")
local Bar = require("ui.Bar")
local SpriteAnimation = require("utils.SpriteAnimation")
local DisintegrationShader = require("utils.DisintegrationShader")
local FogShader = require("utils.FogShader")
local ImpactSystem = require("scenes.battle.ImpactSystem")
local Animations = require("scenes.battle.Animations")
local Visuals = require("scenes.battle.Visuals")
local TurnManager = require("core.TurnManager")

local BattleScene = {}
BattleScene.__index = BattleScene

function BattleScene.new()
  return setmetatable({
    playerHP = config.battle.playerMaxHP,
    enemyHP = config.battle.enemyMaxHP,
    displayPlayerHP = config.battle.playerMaxHP, -- Display HP for smooth tweening
    displayEnemyHP = config.battle.enemyMaxHP, -- Display HP for smooth tweening
    playerArmor = 0,
    prevPlayerArmor = 0,
    enemyFlash = 0,
    playerFlash = 0,
    popups = {},
    log = {},
    state = "idle", -- idle | win | lose (deprecated, use TurnManager state)
    _enemyTurnDelay = nil, -- Delay timer for enemy turn start (after armor popup)
    _pendingEnemyTurnStart = false, -- Flag to track if enemy turn is waiting for player attack to complete
    _playerAttackDelayTimer = nil, -- Delay timer for player attack animation (after ball despawn)
    _pendingPlayerAttackDamage = nil, -- { damage, armor, wasJackpot, impactBlockCount, impactIsCrit } - stored when turn ends, applied after delay
    _pendingImpactParams = nil, -- { blockCount, isCrit } - stored by playImpact, merged into pending damage
    playerImg = nil,
    enemyImg = nil,
    playerScaleMul = 1,
    enemyScaleMul = 1,
    playerLungeTime = 0,
    enemyLungeTime = 0,
    shakeTime = 0,
    shakeDuration = 0,
    shakeMagnitude = 0,
    pendingArmor = 0,
    armorPopupShown = false,
    iconArmor = nil,
    playerKnockbackTime = 0,
    enemyKnockbackTime = 0,
    playerRotation = 0, -- Current rotation angle in radians (tweens back to 0)
    enemyRotation = 0, -- Current rotation angle in radians (tweens back to 0)
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
    -- Staggered flash and knockback events
    enemyFlashEvents = {}, -- Array of {delay, duration} for staggered flashes
    enemyKnockbackEvents = {}, -- Array of {delay, startTime} for staggered knockbacks
    -- Enemy disintegration effect
    enemyDisintegrating = false,
    enemyDisintegrationTime = 0,
    pendingDisintegration = false, -- Set to true when HP reaches 0 but waiting for impact animations
    disintegrationShader = nil,
    -- Lunge speed streaks
    lungeStreaks = {},
    lungeStreakAcc = 0,
    -- Pulse animation timers (different phase offsets for visual variety)
    playerPulseTime = love.math.random() * (2 * math.pi),
    enemyPulseTime = love.math.random() * (2 * math.pi),
    -- Fog shader
    fogShader = nil,
    fogTime = 0, -- Time accumulator for fog animation
  }, BattleScene)
end

function BattleScene:load(bounds)
  -- Load sprites (optional); fallback to circles if missing
  local playerPath = (config.assets and config.assets.images and config.assets.images.player) or nil
  local enemyPath = (config.assets and config.assets.images and config.assets.images.enemy) or nil
  if playerPath then
    local ok, img = pcall(love.graphics.newImage, playerPath)
    if ok then self.playerImg = img end
  end
  if enemyPath then
    local ok, img = pcall(love.graphics.newImage, enemyPath)
    if ok then self.enemyImg = img end
  end
  local iconArmorPath = (config.assets and config.assets.images and config.assets.images.icon_armor) or nil
  if iconArmorPath then
    local ok, img = pcall(love.graphics.newImage, iconArmorPath)
    if ok then self.iconArmor = img end
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
  
  -- Load fog shader
  local fogOk, fogShader = pcall(function() return FogShader.getShader() end)
  if fogOk and fogShader then
    self.fogShader = fogShader
  else
    -- Shader failed to load, disable fog effect
    self.fogShader = nil
  end
end

-- Set a new enemy sprite and optional size multiplier at runtime
function BattleScene:setEnemySprite(path, scaleMultiplier)
  if path then
    local ok, img = pcall(love.graphics.newImage, path)
    if ok then self.enemyImg = img end
  end
  if scaleMultiplier then
    self.enemyScaleMul = scaleMultiplier
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

function BattleScene:onPlayerTurnEnd(turnScore, armor)
  -- Check win/lose states via TurnManager
  local tmState = self.turnManager and self.turnManager:getState()
  if tmState == TurnManager.States.VICTORY or tmState == TurnManager.States.DEFEAT then return end
  if turnScore and turnScore > 0 then
    local dmg = math.floor(turnScore)
    
    -- Store damage info to apply after delay (merge with pending impact params if any)
    self._pendingPlayerAttackDamage = {
      damage = dmg,
      armor = armor or 0,
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

function BattleScene:update(dt, bounds)
  -- Cache latest bounds for positioning helper usage from other methods
  self._lastBounds = bounds or self._lastBounds

  if self.enemyFlash > 0 then self.enemyFlash = math.max(0, self.enemyFlash - dt) end
  if self.playerFlash > 0 then self.playerFlash = math.max(0, self.playerFlash - dt) end
  
  -- Update impact system (slashes, flashes, knockback)
  ImpactSystem.update(self, dt)
  
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
  -- Enemy HP bar tween (exponential interpolation)
  local enemyDelta = self.enemyHP - (self.displayEnemyHP or self.enemyHP)
  if math.abs(enemyDelta) > 0.01 then
    local k = math.min(1, hpTweenSpeed * dt) -- Fraction to move this frame
    self.displayEnemyHP = (self.displayEnemyHP or self.enemyHP) + enemyDelta * k
  else
    self.displayEnemyHP = self.enemyHP
  end
  
  -- Check if enemy should start disintegrating (safeguard for any code path)
  -- Only auto-start if no impact animations are active and disintegration isn't pending
  if self.enemyHP <= 0 and not self.enemyDisintegrating and not self.pendingDisintegration and self.state ~= "win" then
    local impactsActive = (self.impactInstances and #self.impactInstances > 0)
    if impactsActive then
      -- Wait for impact animations to finish
      self.pendingDisintegration = true
    else
      -- No impacts, start disintegration immediately
      self.enemyDisintegrating = true
      self.enemyDisintegrationTime = 0
    end
  end
  
  -- Update enemy disintegration effect
  if self.enemyDisintegrating then
    local cfg = config.battle.disintegration or {}
    local duration = cfg.duration or 1.5
    self.enemyDisintegrationTime = self.enemyDisintegrationTime + dt
    if self.enemyDisintegrationTime >= duration then
      -- Disintegration complete, transition to win state
      self.state = "win"
      self.enemyDisintegrating = false
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

  -- Handle player attack delay (between ball despawn and attack animation)
  if self._playerAttackDelayTimer and self._playerAttackDelayTimer > 0 then
    self._playerAttackDelayTimer = self._playerAttackDelayTimer - dt
    if self._playerAttackDelayTimer <= 0 then
      self._playerAttackDelayTimer = nil
      
      -- Apply pending damage and visual effects
      if self._pendingPlayerAttackDamage then
        local dmg = self._pendingPlayerAttackDamage.damage
        local armor = self._pendingPlayerAttackDamage.armor
        local impactBlockCount = self._pendingPlayerAttackDamage.impactBlockCount or 1
        local impactIsCrit = self._pendingPlayerAttackDamage.impactIsCrit or false
        
        -- Create impact sprite animations first (before damage effects)
        if impactBlockCount and impactBlockCount > 0 then
          self:_createImpactInstances(impactBlockCount, impactIsCrit)
        end
        
        -- Apply damage to enemy HP
        self.enemyHP = math.max(0, self.enemyHP - dmg)
        
        -- Trigger enemy hit visual effects (flash, knockback, popup)
        self.enemyFlash = config.battle.hitFlashDuration
        self.enemyKnockbackTime = 1e-6
        table.insert(self.popups, { x = 0, y = 0, text = tostring(dmg), t = config.battle.popupLifetime, who = "enemy" })
        pushLog(self, "You dealt " .. dmg)
        
        -- Check if enemy is defeated
        if self.enemyHP <= 0 then
          -- Check if impact animations are still playing
          local impactsActive = (self.impactInstances and #self.impactInstances > 0)
          if impactsActive then
            -- Wait for impact animations to finish before starting disintegration
            self.pendingDisintegration = true
            pushLog(self, "Enemy defeated!")
          else
            -- Start disintegration effect immediately if no impacts
            if not self.enemyDisintegrating then
              self.enemyDisintegrating = true
              self.enemyDisintegrationTime = 0
              pushLog(self, "Enemy defeated!")
            end
          end
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
  -- Don't attack if enemy is already defeated
  if (self.enemyHP and self.enemyHP <= 0) or 
     (self.displayEnemyHP and self.displayEnemyHP <= 0.1) or
     (self.turnManager and self.turnManager:getState() == TurnManager.States.VICTORY) then
    return
  end
  
  minDamage = minDamage or config.battle.enemyDamageMin
  maxDamage = maxDamage or config.battle.enemyDamageMax
  local dmg = love.math.random(minDamage, maxDamage)
  local blocked = math.min(self.playerArmor or 0, dmg)
  local net = dmg - blocked
  self.playerArmor = math.max(0, (self.playerArmor or 0) - blocked)
  self.playerHP = math.max(0, self.playerHP - net)
  
  -- If damage is fully blocked, show armor icon popup and flash icon
  if net <= 0 then
    self.armorIconFlashTimer = 0.5 -- Flash duration
    -- Show floating armor icon above player
    table.insert(self.popups, { x = 0, y = 0, kind = "armor_blocked", t = config.battle.popupLifetime, who = "player" })
  else
    self.playerFlash = config.battle.hitFlashDuration
    self.playerKnockbackTime = 1e-6
    table.insert(self.popups, { x = 0, y = 0, text = tostring(net), t = config.battle.popupLifetime, who = "player" })
    pushLog(self, "Enemy dealt " .. net)
    -- Trigger callback for player damage
    if self.onPlayerDamage then
      self.onPlayerDamage()
    end
  end
  -- Trigger enemy lunge animation
  self.enemyLungeTime = 1e-6
  -- Trigger screenshake
  self:triggerShake((config.battle and config.battle.shakeMagnitude) or 10, (config.battle and config.battle.shakeDuration) or 0.25)
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
      -- Don't start enemy turn if enemy is already defeated
      if (self.enemyHP and self.enemyHP <= 0) or 
         (self.displayEnemyHP and self.displayEnemyHP <= 0.1) or
         (turnManager:getState() == TurnManager.States.VICTORY) then
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

-- Compute current enemy hit point (screen coordinates), matching draw layout
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
  local enemyX = (rightWidth > 0) and (rightStart + rightWidth * 0.5) or (w - 12 - r)

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
  local enemyLunge = lungeOffset(self.enemyLungeTime)
  local curEnemyX = enemyX - enemyLunge

  -- Aim mid-height of sprite if available; else circle center
  local rHalf = r
  local enemyScaleCfg = (config.battle and (config.battle.enemySpriteScale or config.battle.spriteScale)) or 1
  local enemyHalfH = rHalf
  if self.enemyImg then
    local ih = self.enemyImg:getHeight()
    local s = ((2 * r) / math.max(1, ih)) * enemyScaleCfg * (self.enemyScaleMul or 1)
    enemyHalfH = (self.enemyImg:getHeight() * s) * 0.5
  end
  local hitX = curEnemyX
  local hitY = baselineY - enemyHalfH * 0.7 -- slightly above center
  return hitX, hitY
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
function BattleScene:_createImpactInstances(blockCount, isCrit)
  if not self.impactAnimation then return end
  ImpactSystem.create(self, blockCount or 1, isCrit or false)
end

return BattleScene



