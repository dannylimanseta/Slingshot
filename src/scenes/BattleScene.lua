local config = require("config")
local theme = require("theme")
local Bar = require("ui.Bar")
local SpriteAnimation = require("utils.SpriteAnimation")
local DisintegrationShader = require("utils.DisintegrationShader")
local FogShader = require("utils.FogShader")
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
    -- Jackpot damage display state
    jackpotActive = false,
    jackpotTarget = 0,
    jackpotDisplay = 0,
    jackpotFalling = false,
    jackpotFallDelayT = 0,
    jackpotFallT = 0,
    jackpotFragments = {},
    jackpotCrit = false,
    jackpotShakeT = 0,
    jackpotBobT = 0,
    _lastBounds = nil,
    -- Turn indicator state
    turnIndicator = nil, -- { text = "PLAYER'S TURN" or "ENEMY'S TURN", t = lifetime }
    turnIndicatorDelay = 0, -- Delay timer before showing turn indicator
    _pendingTurnIndicator = nil, -- Queued turn indicator waiting for delay
    -- Pending damage for jackpot sync
    pendingDamage = 0, -- Damage to apply when jackpot crashes down
    pendingArmorFromTurn = 0, -- Armor to apply after damage (delayed for jackpot sync)
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
    
    -- If jackpot is active, apply damage immediately and end jackpot display
    if self.jackpotActive then
      -- End jackpot display immediately
      self.jackpotActive = false
      self.jackpotTarget = 0
      self.jackpotDisplay = 0
      self.jackpotFalling = false
      self.jackpotFragments = {}
      
      -- Apply damage immediately
      self.enemyHP = math.max(0, self.enemyHP - dmg)
      self.enemyFlash = config.battle.hitFlashDuration
      self.enemyKnockbackTime = 1e-6
      table.insert(self.popups, { x = 0, y = 0, text = tostring(dmg), t = config.battle.popupLifetime, who = "enemy" })
      pushLog(self, "You dealt " .. dmg)
      -- Trigger player lunge animation
      self.playerLungeTime = 1e-6
      -- Trigger screenshake
      self:triggerShake((config.battle and config.battle.shakeMagnitude) or 10, (config.battle and config.battle.shakeDuration) or 0.25)
      
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
      else
        -- Queue incoming armor for TurnManager to handle
        self.pendingArmor = armor or 0
        self.armorPopupShown = false
      end
    else
      -- No jackpot: apply damage immediately (backward compatibility for non-jackpot path)
      self.enemyHP = math.max(0, self.enemyHP - dmg)
      self.enemyFlash = config.battle.hitFlashDuration
      self.enemyKnockbackTime = 1e-6
      table.insert(self.popups, { x = 0, y = 0, text = tostring(dmg), t = config.battle.popupLifetime, who = "enemy" })
      pushLog(self, "You dealt " .. dmg)
      -- Trigger player lunge animation
      self.playerLungeTime = 1e-6
      -- Trigger screenshake
      self:triggerShake((config.battle and config.battle.shakeMagnitude) or 10, (config.battle and config.battle.shakeDuration) or 0.25)
      
      if self.enemyHP <= 0 then
        -- Check if impact animations are still playing
        local impactsActive = (self.impactInstances and #self.impactInstances > 0)
        if impactsActive then
          -- Wait for impact animations to finish before starting disintegration
          self.pendingDisintegration = true
        else
          -- Start disintegration effect immediately if no impacts
          if not self.enemyDisintegrating then
            self.enemyDisintegrating = true
            self.enemyDisintegrationTime = 0
          end
        end
        -- State will change to "win" after disintegration completes
        return
      end
      
      -- Queue incoming armor for TurnManager to handle
      self.pendingArmor = armor or 0
      self.armorPopupShown = false
    end
  end
end

function BattleScene:update(dt, bounds)
  -- Cache latest bounds for positioning helper usage from other methods
  self._lastBounds = bounds or self._lastBounds

  if self.enemyFlash > 0 then self.enemyFlash = math.max(0, self.enemyFlash - dt) end
  if self.playerFlash > 0 then self.playerFlash = math.max(0, self.playerFlash - dt) end
  
  -- Update staggered flash events
  local activeFlashEvents = {}
  local flashDuration = (config.battle and config.battle.hitFlashDuration) or 0.5
  for _, event in ipairs(self.enemyFlashEvents) do
    event.delay = math.max(0, event.delay - dt)
    if event.delay <= 0 then
      -- Trigger flash when delay expires
      if not event.triggered then
        event.triggered = true
        event.startTime = 0
        self.enemyFlash = math.max(self.enemyFlash, flashDuration)
        -- Apply random rotation (1-3 degrees) when hit
        local rotationDegrees = love.math.random(1, 3)
        local rotationRadians = math.rad(rotationDegrees)
        -- Randomly choose positive or negative rotation
        if love.math.random() < 0.5 then
          rotationRadians = -rotationRadians
        end
        -- Add rotation to current rotation (will tween back to 0)
        self.enemyRotation = self.enemyRotation + rotationRadians
      end
      -- Track elapsed time for this flash
      event.startTime = (event.startTime or 0) + dt
      -- Keep event active until flash duration expires
      if event.startTime < flashDuration then
        table.insert(activeFlashEvents, event)
      end
    else
      table.insert(activeFlashEvents, event)
    end
  end
  self.enemyFlashEvents = activeFlashEvents
  
  -- Update staggered knockback events
  local activeKnockbackEvents = {}
  for _, event in ipairs(self.enemyKnockbackEvents) do
    event.delay = math.max(0, event.delay - dt)
    if event.delay <= 0 then
      -- Start knockback timer if not already started
      if not event.startTime then
        event.startTime = 0
      end
      event.startTime = event.startTime + dt
      local kbTotal = (config.battle.knockbackDuration or 0) + (config.battle.knockbackReturnDuration or 0)
      if event.startTime < kbTotal then
        table.insert(activeKnockbackEvents, event)
      end
    else
      table.insert(activeKnockbackEvents, event)
    end
  end
  self.enemyKnockbackEvents = activeKnockbackEvents
  
  -- Update impact animation instances (with staggered delays)
  if self.impactAnimation then
    local activeInstances = {}
    local staggerDelay = (config.battle and config.battle.impactStaggerDelay) or 0.05
    for _, instance in ipairs(self.impactInstances) do
      instance.delay = math.max(0, instance.delay - dt)
      if instance.delay <= 0 then
        -- Start playing if not already active
        if not instance.anim.playing and instance.anim.play then
          instance.anim:play(false)
        end
        -- Update animation
        if instance.anim.update then
          instance.anim:update(dt)
        end
        -- Keep instance if still active
        if instance.anim.active then
          table.insert(activeInstances, instance)
        end
      else
        -- Still waiting for delay, keep instance
        table.insert(activeInstances, instance)
      end
    end
    self.impactInstances = activeInstances
    
    -- Check if impact animations finished and disintegration is pending
    if self.pendingDisintegration and #self.impactInstances == 0 then
      -- All impact animations finished, start disintegration
      if not self.enemyDisintegrating then
        self.enemyDisintegrating = true
        self.enemyDisintegrationTime = 0
      end
      self.pendingDisintegration = false
    end
  end
  
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

  -- Handle enemy turn delay (for armor popup timing)
  if self._enemyTurnDelay and self._enemyTurnDelay > 0 then
    self._enemyTurnDelay = self._enemyTurnDelay - dt
    if self._enemyTurnDelay <= 0 then
      self._enemyTurnDelay = nil
      if self.turnManager then
        self.turnManager:startEnemyTurn()
      end
    end
  end

  -- Advance lunge timers (hold at peak until impact FX finish)
  do
    local d = (config.battle and config.battle.lungeDuration) or 0
    local rdur = (config.battle and config.battle.lungeReturnDuration) or 0
    local totalPlayer = d + rdur
    if self.playerLungeTime > 0 then
      local t = self.playerLungeTime
      local impactsActive = (self.impactInstances and #self.impactInstances > 0)
      local inForward = t < d
      local inReturn = t >= d and t < d + rdur
      local shouldHold = (not inForward) and inReturn and impactsActive
      if not shouldHold then
        self.playerLungeTime = self.playerLungeTime + dt
        if self.playerLungeTime > totalPlayer then self.playerLungeTime = 0 end
      end
    end
  end
  local totalEnemy = (config.battle.lungeDuration or 0) + (config.battle.lungeReturnDuration or 0)
  if self.enemyLungeTime > 0 then
    self.enemyLungeTime = self.enemyLungeTime + dt
    if self.enemyLungeTime > totalEnemy then self.enemyLungeTime = 0 end
  end
  -- Advance knockback timers
  local kbTotalPlayer = (config.battle.knockbackDuration or 0) + (config.battle.knockbackReturnDuration or 0)
  if self.playerKnockbackTime > 0 then
    self.playerKnockbackTime = self.playerKnockbackTime + dt
    if self.playerKnockbackTime > kbTotalPlayer then self.playerKnockbackTime = 0 end
  end
  local kbTotalEnemy = (config.battle.knockbackDuration or 0) + (config.battle.knockbackReturnDuration or 0)
  if self.enemyKnockbackTime > 0 then
    self.enemyKnockbackTime = self.enemyKnockbackTime + dt
    if self.enemyKnockbackTime > kbTotalEnemy then self.enemyKnockbackTime = 0 end
  end
  
  -- Tween rotation back to 0
  local rotationTweenSpeed = 8 -- Speed of rotation tween (similar to HP bar tween)
  -- Player rotation always tweens toward 0
  if math.abs(self.playerRotation) > 0.001 then
    local k = math.min(1, rotationTweenSpeed * dt)
    self.playerRotation = self.playerRotation * (1 - k)
    if math.abs(self.playerRotation) < 0.001 then
      self.playerRotation = 0
    end
  end
  -- Enemy rotation always tweens toward 0
  if math.abs(self.enemyRotation) > 0.001 then
    local k = math.min(1, rotationTweenSpeed * dt)
    self.enemyRotation = self.enemyRotation * (1 - k)
    if math.abs(self.enemyRotation) < 0.001 then
      self.enemyRotation = 0
    end
  end
  -- Update fog time for animation
  self.fogTime = (self.fogTime or 0) + dt
  
  -- Advance screenshake timer
  if self.shakeTime > 0 then
    self.shakeTime = self.shakeTime - dt
    if self.shakeTime <= 0 then
      self.shakeTime = 0
      self.shakeDuration = 0
      self.shakeMagnitude = 0
    end
  end
  -- Idle bob time
  self.idleT = (self.idleT or 0) + dt
  
  -- Update pulse animation timers
  local pulseConfig = config.battle.pulse
  if pulseConfig and (pulseConfig.enabled ~= false) then
    local speed = pulseConfig.speed or 1.2
    self.playerPulseTime = (self.playerPulseTime or 0) + dt * speed * 2 * math.pi
    self.enemyPulseTime = (self.enemyPulseTime or 0) + dt * speed * 2 * math.pi
  end

  -- Emit and update lunge speed streaks during forward phase
  do
    local cfg = config.battle and config.battle.speedStreaks
    if cfg and cfg.enabled then
      local t = self.playerLungeTime or 0
      local d = (config.battle and config.battle.lungeDuration) or 0
      local pause = (config.battle and config.battle.lungePauseDuration) or 0
      if t > 0 and t < d then
        -- Determine player position and vertical span
        local w = (self._lastBounds and self._lastBounds.w) or love.graphics.getWidth()
        local h = (self._lastBounds and self._lastBounds.h) or love.graphics.getHeight()
        local center = self._lastBounds and self._lastBounds.center or nil
        local centerX = center and center.x or math.floor(w * 0.5) - math.floor((w * 0.5) * 0.5)
        local centerW = center and center.w or math.floor(w * 0.5)
        local leftWidth = math.max(0, centerX)
        local pad = 12
        local r = 24
        local yOffset = (config.battle and config.battle.positionOffsetY) or 0
        local baselineY = h * 0.55 + r + yOffset
        local playerX = (leftWidth > 0) and (leftWidth * 0.5) or (pad + r)
        -- Current lunge offset
        local curPlayerX = playerX + (config.battle.lungeDistance or 0) * (t / math.max(0.0001, d))
        -- Determine player sprite half dimensions for placement
        local playerHalfH = r
        local playerHalfW = r
        do
          local scaleCfg = (config.battle and (config.battle.playerSpriteScale or config.battle.spriteScale)) or 1
          if self.playerImg then
            local iw, ih = self.playerImg:getWidth(), self.playerImg:getHeight()
            local s = ((2 * r) / math.max(1, ih)) * scaleCfg * (self.playerScaleMul or 1)
            playerHalfH = (ih * s) * 0.5
            playerHalfW = (iw * s) * 0.5
          end
        end
        -- Emit at configured rate
        self.lungeStreakAcc = (self.lungeStreakAcc or 0) + dt * (cfg.emitRate or 60)
        while self.lungeStreakAcc >= 1 do
          self.lungeStreakAcc = self.lungeStreakAcc - 1
          -- Distribute vertically across full sprite height
          local yTop = baselineY - playerHalfH * 2
          local fullH = playerHalfH * 2
          local y = yTop + love.math.random() * fullH
          local len = (cfg.lengthMin or 24) + love.math.random() * math.max(0, (cfg.lengthMax or 60) - (cfg.lengthMin or 24))
          local vx = (cfg.speedMin or -900) + love.math.random() * math.max(0, (cfg.speedMax or -600) - (cfg.speedMin or -900))
          local life = (cfg.lifetimeMin or 0.12) + love.math.random() * math.max(0, (cfg.lifetimeMax or 0.22) - (cfg.lifetimeMin or 0.12))
          table.insert(self.lungeStreaks, {
            -- Start at (or slightly ahead of) the player's front edge so streaks cover the sprite
            x = curPlayerX + playerHalfW + 4,
            y = y,
            vx = vx,
            life = life,
            maxLife = life,
            len = len,
          })
        end
      end
    end
  end
  -- Update streaks
  do
    if self.lungeStreaks and #self.lungeStreaks > 0 then
      local alive = {}
      for _, s in ipairs(self.lungeStreaks) do
        s.life = s.life - dt
        if s.life > 0 then
          s.x = s.x + s.vx * dt
          table.insert(alive, s)
        end
      end
      self.lungeStreaks = alive
    end
  end

  -- Update jackpot display tick toward target (dynamic speed based on damage delta)
  if self.jackpotActive then
    local scoreConfig = require("config").score or {}
    local baseSpeed = scoreConfig.tickerSpeed or 10
    local delta = (self.jackpotTarget - (self.jackpotDisplay or 0))
    
    -- Dynamic speed: faster for larger deltas
    local dynamicSpeed = baseSpeed
    local dynamicTicker = scoreConfig.dynamicTicker
    if dynamicTicker and (dynamicTicker.enabled ~= false) then
      local speedMultiplier = dynamicTicker.speedMultiplier or 3
      local threshold = dynamicTicker.threshold or 20
      local maxSpeed = dynamicTicker.maxSpeed or 60
      
      if math.abs(delta) > threshold then
        -- Scale speed based on delta (capped at maxSpeed)
        local speedScale = math.min(maxSpeed / baseSpeed, 1 + (math.abs(delta) - threshold) / threshold * (speedMultiplier - 1))
        dynamicSpeed = baseSpeed * speedScale
      end
    end
    
    local step = math.min(1, math.max(-1, dynamicSpeed * dt))
    self.jackpotDisplay = (self.jackpotDisplay or 0) + delta * step
    if math.abs(self.jackpotTarget - self.jackpotDisplay) < 0.01 then
      self.jackpotDisplay = self.jackpotTarget
    end
    -- Advance crit shake timer if active
    if self.jackpotCrit then
      self.jackpotShakeT = (self.jackpotShakeT or 0) + dt
    end
    -- Advance bob timer
    if self.jackpotBobT and self.jackpotBobT > 0 then
      local dur = ((require("config").battle and require("config").battle.jackpot and require("config").battle.jackpot.bobDuration) or 0.18)
      self.jackpotBobT = self.jackpotBobT + dt
      if self.jackpotBobT >= dur then
        self.jackpotBobT = 0
      end
    end
  end


  -- Update jackpot fragment physics and fade
  if self.jackpotFragments and #self.jackpotFragments > 0 then
    local alive = {}
    for _, frag in ipairs(self.jackpotFragments) do
      frag.lifetime = frag.lifetime - dt
      if frag.lifetime > 0 then
        local t = frag.lifetime / math.max(0.0001, frag.maxLifetime)
        local velScale = 0.3 + t * 0.7
        frag.x = frag.x + frag.vx * dt * velScale
        frag.y = frag.y + frag.vy * dt * velScale
        frag.rotation = frag.rotation + frag.rotationSpeed * dt
        table.insert(alive, frag)
      end
    end
    self.jackpotFragments = alive
  end
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
  local w = (bounds and bounds.w) or love.graphics.getWidth()
  local h = (bounds and bounds.h) or love.graphics.getHeight()

  local pad = 12
  local center = bounds and bounds.center or nil
  local centerX = center and center.x or math.floor(w * 0.5) - math.floor((w * 0.5) * 0.5)
  local centerW = center and center.w or math.floor(w * 0.5)
  local leftWidth = math.max(0, centerX)
  local rightStart = centerX + centerW
  local rightWidth = math.max(0, w - rightStart)

  -- Character anchors
  local r = 24
  local yOffset = (config.battle and config.battle.positionOffsetY) or 0
  local baselineY = h * 0.55 + r + yOffset -- keep bottoms aligned to prior visual baseline
  local playerX = (leftWidth > 0) and (leftWidth * 0.5) or (pad + r)
  local enemyX = (rightWidth > 0) and (rightStart + rightWidth * 0.5) or (w - pad - r)

  -- Ensure UI uses the configured UI font
  love.graphics.setFont(theme.fonts.base)

  -- Apply screenshake as a camera translation (ease-out)
  love.graphics.push()
  if self.shakeTime > 0 and self.shakeDuration > 0 then
    local t = self.shakeTime / self.shakeDuration
    local ease = t * t -- quadratic ease-out on remaining time
    local mag = self.shakeMagnitude * ease
    local ox = (love.math.random() * 2 - 1) * mag
    local oy = (love.math.random() * 2 - 1) * mag
    love.graphics.translate(ox, oy)
  end

  -- Compute lunge offsets (forward toward center), with dynamic pause at peak
  local function lungeOffset(t, pauseActive)
    if not t or t <= 0 then return 0 end
    local d = config.battle.lungeDuration or 0
    local rdur = config.battle.lungeReturnDuration or 0
    local dist = config.battle.lungeDistance or 0
    if t < d then
      return dist * (t / math.max(0.0001, d))
    elseif pauseActive and t < d + rdur then
      return dist -- hold at peak while pause is active
    elseif t < d + rdur then
      local tt = (t - d) / math.max(0.0001, rdur)
      return dist * (1 - tt)
    else
      return 0
    end
  end
  local playerLunge = lungeOffset(self.playerLungeTime, (self.impactInstances and #self.impactInstances > 0))
  local enemyLunge = lungeOffset(self.enemyLungeTime, false)
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
  local playerKB = knockbackOffset(self.playerKnockbackTime)
  -- Sum all active staggered knockback offsets
  local enemyKB = 0
  for _, event in ipairs(self.enemyKnockbackEvents) do
    if event.startTime then
      enemyKB = enemyKB + knockbackOffset(event.startTime)
    end
  end
  -- Also include the main knockback timer for backward compatibility
  enemyKB = enemyKB + knockbackOffset(self.enemyKnockbackTime)
  local curPlayerX = playerX + playerLunge - playerKB
  local curEnemyX = enemyX - enemyLunge + enemyKB

  -- Compute per-sprite scales to position HP bars above actual sprite heights
  local playerScaleCfg = (config.battle and (config.battle.playerSpriteScale or config.battle.spriteScale)) or 1
  local enemyScaleCfg = (config.battle and (config.battle.enemySpriteScale or config.battle.spriteScale)) or 1
  local playerScale = 1
  local enemyScale = 1
  if self.playerImg then
    local ih = self.playerImg:getHeight()
    playerScale = ((2 * r) / math.max(1, ih)) * playerScaleCfg * (self.playerScaleMul or 1)
  end
  if self.enemyImg then
    local ih = self.enemyImg:getHeight()
    enemyScale = ((2 * r) / math.max(1, ih)) * enemyScaleCfg * (self.enemyScaleMul or 1)
  end

  local playerHalfH = self.playerImg and ((self.playerImg:getHeight() * playerScale) * 0.5) or r
  local enemyHalfH = self.enemyImg and ((self.enemyImg:getHeight() * enemyScale) * 0.5) or r

  -- HP bars and names below each sprite
  local barH = 12
  local playerBarW = math.max(120, math.min(220, leftWidth - pad * 2)) * 0.7
  local enemyBarW = math.max(120, math.min(220, rightWidth - pad * 2)) * 0.7

  local barY = baselineY + 16

  if playerBarW > 0 then
    local playerBarX = playerX - playerBarW * 0.5
    -- Store bar position for fragment creation
    self.playerBarX = playerBarX
    self.playerBarY = barY
    self.playerBarW = playerBarW
    self.playerBarH = barH
    
    -- Draw shatter fragments if animating
    if #self.borderFragments > 0 then
      drawBorderFragments(self.borderFragments)
    end
    
    -- Draw glow if player has armor (and not shattering)
    if (self.playerArmor or 0) > 0 and #self.borderFragments == 0 then
      -- Simple linear tween: fade from 0 to 1 over duration
      local alpha = 1.0
      if self.borderFadeInTime > 0 and self.borderFadeInDuration > 0 then
        alpha = 1.0 - (self.borderFadeInTime / self.borderFadeInDuration)
      end
      drawBarGlow(playerBarX, barY, playerBarW, barH, alpha)
    end
    Bar:draw(playerBarX, barY, playerBarW, barH, self.displayPlayerHP or self.playerHP, config.battle.playerMaxHP, { 224/255, 112/255, 126/255 })
    love.graphics.setColor(1, 1, 1, 1)
  end
  if enemyBarW > 0 and self.state ~= "win" then
    local enemyBarX = enemyX - enemyBarW * 0.5
    
    -- Calculate fade alpha during disintegration
    local barAlpha = 1.0
    if self.enemyDisintegrating then
      local cfg = config.battle.disintegration or {}
      local duration = cfg.duration or 1.5
      local progress = math.min(1, self.enemyDisintegrationTime / duration)
      -- Fade out as disintegration progresses (fade faster - complete by 70% progress)
      barAlpha = math.max(0, 1.0 - (progress / 0.7))
    end
    
    if barAlpha > 0 then
      love.graphics.push()
      love.graphics.setColor(1, 1, 1, barAlpha)
      
      -- Draw glow if enemy has armor (future-proofing)
      if (self.enemyArmor or 0) > 0 then
        drawBarGlow(enemyBarX, barY, enemyBarW, barH)
      end
      
      -- Draw HP bar with alpha
      love.graphics.setColor(0, 0, 0, 0.35 * barAlpha)
      love.graphics.rectangle("fill", enemyBarX, barY, enemyBarW, barH, 6, 6)
      local barColor = { 153/255, 224/255, 122/255 }
      local ratio = 0
      local maxHP = config.battle.enemyMaxHP
      local currentHP = self.displayEnemyHP or self.enemyHP
      if maxHP > 0 then ratio = math.max(0, math.min(1, currentHP / maxHP)) end
      -- Only draw colored bar if HP > 0
      if ratio > 0 then
        love.graphics.setColor(barColor[1], barColor[2], barColor[3], barAlpha)
        love.graphics.rectangle("fill", enemyBarX, barY, enemyBarW * ratio, barH, 6, 6)
      end
      -- Draw dark grey border around HP bar
      love.graphics.setColor(0.25, 0.25, 0.25, barAlpha)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", enemyBarX, barY, enemyBarW, barH, 6, 6)
      -- Centered HP text (current/max)
      do
        local font = theme.fonts.base
        love.graphics.setFont(font)
        local cur = math.max(0, math.floor(currentHP or 0))
        local mx = math.max(0, math.floor(maxHP or 0))
        local text = tostring(cur) .. "/" .. tostring(mx)
        local tw = font:getWidth(text)
        local th = font:getHeight()
        local tx = enemyBarX + (enemyBarW - tw) * 0.5
        local ty = barY + (barH - th) * 0.5
        theme.drawTextWithOutline(text, tx, ty, 1, 1, 1, 0.95 * barAlpha, 2)
      end
      
      -- Draw enemy name with alpha
      love.graphics.setColor(theme.colors.uiText[1], theme.colors.uiText[2], theme.colors.uiText[3], theme.colors.uiText[4] * barAlpha)
      drawCenteredText("Enemy", enemyBarX, barY + barH + 6, enemyBarW)
      
      love.graphics.pop()
      love.graphics.setColor(1, 1, 1, 1)
    end
  end
  -- Armor indicator (beside player HP bar, left side) with icon
  if (self.playerArmor or 0) > 0 and playerBarW > 0 then
    local valueStr = tostring(self.playerArmor)
    local textW = theme.fonts.base:getWidth(valueStr)
    local iconW, iconH, s = 0, 0, 1
    if self.iconArmor then
      iconW, iconH = self.iconArmor:getWidth(), self.iconArmor:getHeight()
      s = 20 / math.max(1, iconH)
    end
    local barLeftEdge = playerX - playerBarW * 0.5
    local armorSpacing = 8
    local startX = barLeftEdge - (textW + (self.iconArmor and (iconW * s + 6) or 0) + armorSpacing)
    local y = barY + (barH - theme.fonts.base:getHeight()) * 0.5
    
    -- Flash effect when damage is fully blocked
    local flashAlpha = 1
    local flashScale = 1
    if self.armorIconFlashTimer > 0 then
      local flashProgress = 1 - (self.armorIconFlashTimer / 0.5) -- 0 to 1
      -- Pulse effect: quick flash in, slow fade out
      flashAlpha = 1 + math.sin(flashProgress * math.pi * 4) * 0.5 -- Pulse 4 times
      flashAlpha = math.max(0.3, math.min(1.5, flashAlpha)) -- Clamp
      flashScale = 1 + math.sin(flashProgress * math.pi * 2) * 0.2 -- Scale pulse
    end
    
    if self.iconArmor then
      local iconX = startX
      local iconY = y + (theme.fonts.base:getHeight() - iconH * s) * 0.5
      love.graphics.push()
      love.graphics.translate(iconX + iconW * s * 0.5, iconY + iconH * s * 0.5)
      love.graphics.scale(flashScale, flashScale)
      love.graphics.translate(-iconW * s * 0.5, -iconH * s * 0.5)
      love.graphics.setColor(1, 1, 1, flashAlpha)
      love.graphics.draw(self.iconArmor, 0, 0, 0, s, s)
      love.graphics.pop()
      startX = startX + iconW * s + 6
    end
    love.graphics.setColor(1, 1, 1, 0.9)
    theme.drawTextWithOutline(valueStr, startX, y, 1, 1, 1, 0.9, 2)
    love.graphics.setColor(1, 1, 1, 1)
  end

  -- Draw fog effect (behind player and enemy sprites)
  local fogConfig = config.battle.fog or {}
  if (fogConfig.enabled ~= false) and self.fogShader then
    love.graphics.push("all")
    -- Use normal alpha blending to overlay fog (fog color is white, alpha controls density)
    love.graphics.setBlendMode("alpha")
    
    -- Set shader and send uniforms
    love.graphics.setShader(self.fogShader)
    self.fogShader:send("u_time", self.fogTime or 0)
    self.fogShader:send("u_resolution", {w, h})
    self.fogShader:send("u_cloudDensity", fogConfig.cloudDensity or 0.15)
    self.fogShader:send("u_noisiness", fogConfig.noisiness or 0.35)
    self.fogShader:send("u_speed", fogConfig.speed or 0.1)
    self.fogShader:send("u_cloudHeight", fogConfig.cloudHeight or 2.5)
    self.fogShader:send("u_fogStartY", fogConfig.startY or 0.65)
    
    -- Draw fullscreen quad for fog (shader uses screen coordinates)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, w, h)
    
    -- Reset shader
    love.graphics.setShader()
    love.graphics.pop()
  end

  -- Enemy/Player silhouettes with flash
  -- Draw player sprite or fallback circle
  if self.playerImg then
    local iw, ih = self.playerImg:getWidth(), self.playerImg:getHeight()
    local s = playerScale
    -- Vertical-only idle bob: 1..(1+idleBobScaleY), anchored at bottom
    local bobA = (config.battle and config.battle.idleBobScaleY) or 0
    local bobF = (config.battle and config.battle.idleBobSpeed) or 1
    local bob = 1 + bobA * (0.5 - 0.5 * math.cos(2 * math.pi * bobF * (self.idleT or 0)))
    local sx, sy = s, s * bob
    -- Apply rotation from hit effects
    local tilt = self.playerRotation or 0
    -- Calculate alpha fade during lunge: fade out quickly on forward, fade back on return
    local drawAlpha = 1.0
    do
      local d = (config.battle and config.battle.lungeDuration) or 0
      local rdur = (config.battle and config.battle.lungeReturnDuration) or 0
      local t = self.playerLungeTime or 0
      local impactsActive = (self.impactInstances and #self.impactInstances > 0)
      if t > 0 and (d > 0 or rdur > 0) then
        if t < d and d > 0 then
          -- Forward phase: 1 -> 0.0
          local p = math.max(0, math.min(1, t / d))
          drawAlpha = 1.0 - p
        elseif impactsActive and t < d + rdur then
          -- Pause at peak while impacts active: fully invisible
          drawAlpha = 0.0
        elseif t < d + rdur and rdur > 0 then
          -- Return phase: 0.0 -> 1.0
          local p = math.max(0, math.min(1, (t - d) / math.max(0.0001, rdur)))
          drawAlpha = p
        else
          drawAlpha = 1.0
        end
      end
    end
    -- Calculate pulse brightness multiplier
    local brightnessMultiplier = 1
    local pulseConfig = config.battle.pulse
    if pulseConfig and (pulseConfig.enabled ~= false) then
      local variation = pulseConfig.brightnessVariation or 0.08
      brightnessMultiplier = 1 + math.sin(self.playerPulseTime or 0) * variation
    end
    love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, drawAlpha)
    love.graphics.draw(self.playerImg, curPlayerX, baselineY, tilt, sx, sy, iw * 0.5, ih)
    if self.playerFlash and self.playerFlash > 0 then
      local base = self.playerFlash / math.max(0.0001, config.battle.hitFlashDuration)
      local a = math.min(1, base * ((config.battle and config.battle.hitFlashAlphaScale) or 1))
      local passes = (config.battle and config.battle.hitFlashPasses) or 1
      love.graphics.setBlendMode("add")
      -- Apply flash scaled by current sprite alpha so fade is consistent (flash remains white)
      love.graphics.setColor(1, 1, 1, a * (drawAlpha or 1))
      for i = 1, math.max(1, passes) do
        love.graphics.draw(self.playerImg, curPlayerX, baselineY, self.playerRotation or 0, sx, sy, iw * 0.5, ih)
      end
      love.graphics.setBlendMode("alpha")
      love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, drawAlpha)
    end
  else
    -- Fallback circle (apply pulse brightness)
    local brightnessMultiplier = 1
    local pulseConfig = config.battle.pulse
    if pulseConfig and (pulseConfig.enabled ~= false) then
      local variation = pulseConfig.brightnessVariation or 0.08
      brightnessMultiplier = 1 + math.sin(self.playerPulseTime or 0) * variation
    end
    if self.playerFlash > 0 then
      love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, 1)
    else
      love.graphics.setColor(0.2 * brightnessMultiplier, 0.8 * brightnessMultiplier, 0.3 * brightnessMultiplier, 1)
    end
    love.graphics.circle("fill", curPlayerX, baselineY - r, r)
    love.graphics.setColor(1, 1, 1, 1)
  end

  -- Draw lunge speed streaks (behind sprites)
  do
    local cfg = config.battle and config.battle.speedStreaks
    if cfg and cfg.enabled and self.lungeStreaks and #self.lungeStreaks > 0 then
      love.graphics.push("all")
      love.graphics.setBlendMode("add")
      local thickness = cfg.thickness or 3
      for _, s in ipairs(self.lungeStreaks) do
        local t = math.max(0, s.life / math.max(0.0001, s.maxLife))
        local alpha = (cfg.alpha or 0.45) * t
        if alpha > 0 then
          love.graphics.setColor(1, 1, 1, alpha)
          love.graphics.rectangle("fill", s.x - s.len, s.y - thickness * 0.5, s.len, thickness, 2, 2)
        end
      end
      love.graphics.pop()
    end
  end

  -- Draw enemy sprite or fallback circle (skip if enemy is dead/disintegrated)
  if self.enemyImg and self.state ~= "win" then
    local iw, ih = self.enemyImg:getWidth(), self.enemyImg:getHeight()
    local s = enemyScale
    -- Vertical-only idle bob
    local bobA = (config.battle and config.battle.idleBobScaleY) or 0
    local bobF = (config.battle and config.battle.idleBobSpeed) or 1
    local bob = 1 + bobA * (0.5 - 0.5 * math.cos(2 * math.pi * bobF * (self.idleT or 0)))
    local sx, sy = s, s * bob
    -- Apply rotation from hit effects
    local tilt = self.enemyRotation or 0
    
    -- Apply disintegration shader if enemy is disintegrating
    if self.enemyDisintegrating and self.disintegrationShader then
      local cfg = config.battle.disintegration or {}
      local duration = cfg.duration or 1.5
      local progress = math.min(1, self.enemyDisintegrationTime / duration)
      local noiseScale = cfg.noiseScale or 20
      local thickness = cfg.thickness or 0.25
      local lineColor = cfg.lineColor or {1.0, 0.3, 0.1, 1.0}
      local colorIntensity = cfg.colorIntensity or 2.0
      
      love.graphics.setShader(self.disintegrationShader)
      self.disintegrationShader:send("u_time", self.enemyDisintegrationTime)
      self.disintegrationShader:send("u_noiseScale", noiseScale)
      self.disintegrationShader:send("u_thickness", thickness)
      self.disintegrationShader:send("u_lineColor", lineColor)
      self.disintegrationShader:send("u_colorIntensity", colorIntensity)
      self.disintegrationShader:send("u_progress", progress)
    end
    
    -- Calculate pulse brightness multiplier
    local brightnessMultiplier = 1
    local pulseConfig = config.battle.pulse
    if pulseConfig and (pulseConfig.enabled ~= false) then
      local variation = pulseConfig.brightnessVariation or 0.08
      brightnessMultiplier = 1 + math.sin(self.enemyPulseTime or 0) * variation
    end
    
    love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, 1)
    love.graphics.draw(self.enemyImg, curEnemyX, baselineY, tilt, sx, sy, iw * 0.5, ih)
    
    -- Reset shader after drawing
    if self.enemyDisintegrating and self.disintegrationShader then
      love.graphics.setShader()
    end
    
    -- Skip flash effect during disintegration (shader handles the visual effect)
    if self.enemyFlash and self.enemyFlash > 0 and not self.enemyDisintegrating then
      local base = self.enemyFlash / math.max(0.0001, config.battle.hitFlashDuration)
      local a = math.min(1, base * ((config.battle and config.battle.hitFlashAlphaScale) or 1))
      local passes = (config.battle and config.battle.hitFlashPasses) or 1
      love.graphics.setBlendMode("add")
      love.graphics.setColor(1, 1, 1, a) -- Flash remains white for proper visual feedback
      for i = 1, math.max(1, passes) do
        love.graphics.draw(self.enemyImg, curEnemyX, baselineY, self.enemyRotation or 0, sx, sy, iw * 0.5, ih)
      end
      love.graphics.setBlendMode("alpha")
      love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, 1)
    end
  elseif self.state ~= "win" then
    -- Fallback circle (only draw if enemy is not dead, apply pulse brightness)
    local brightnessMultiplier = 1
    local pulseConfig = config.battle.pulse
    if pulseConfig and (pulseConfig.enabled ~= false) then
      local variation = pulseConfig.brightnessVariation or 0.08
      brightnessMultiplier = 1 + math.sin(self.enemyPulseTime or 0) * variation
    end
    if self.enemyFlash > 0 then
      love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, 1)
    else
      love.graphics.setColor(0.9 * brightnessMultiplier, 0.2 * brightnessMultiplier, 0.2 * brightnessMultiplier, 1)
    end
    love.graphics.circle("fill", curEnemyX, baselineY - r, r)
    love.graphics.setColor(1, 1, 1, 1)
  end
  
  -- Draw impact animation instances at enemy hit point (above sprites, below jackpot)
  if self.impactAnimation and #self.impactInstances > 0 then
    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    love.graphics.setColor(1, 1, 1, 1)
    local scale = (config.battle and config.battle.impactScale) or 0.96
    for _, instance in ipairs(self.impactInstances) do
      -- Only draw if delay has passed and animation is active
      if instance.delay <= 0 and instance.anim.active then
        instance.anim:draw(instance.x + (instance.offsetX or 0), instance.y + (instance.offsetY or 0), instance.rotation, scale, scale)
      end
    end
    love.graphics.pop()
  end

  -- Jackpot number (accumulating damage display above enemy) - HIDDEN
  do
    if false and (self.jackpotActive or (self.jackpotFragments and #self.jackpotFragments > 0)) then
      local cfg = config.battle and config.battle.jackpot or {}
      local startYBase = baselineY - enemyHalfH - (cfg.offsetY or 120)
      local hitX = w * 0.5 -- Center horizontally across screen
      local y = startYBase
      if self.jackpotActive then
        local font = self.jackpotCrit and (theme.fonts.jackpot or theme.fonts.large) or theme.fonts.large
        love.graphics.setFont(font)
        local text = tostring(math.floor(self.jackpotDisplay or 0))
        local dx, dy = 0, 0
        if self.jackpotCrit then
          local jc = cfg
          local amp = jc.shakeAmplitude or 3
          local sp = jc.shakeSpeed or 42
          local t = (self.jackpotShakeT or 0)
          dx = math.sin(t * sp) * amp
          dy = math.cos(t * sp * 0.9) * amp
        end
        -- Apply small bob upward when number increments
        do
          local dur = (cfg.bobDuration or 0.18)
          local amp = (cfg.bobAmplitude or 8)
          local t = self.jackpotBobT or 0
          if t > 0 and dur > 0 then
            local p = math.min(1, t / math.max(0.0001, dur))
            local bob = math.sin(p * math.pi) -- up then down
            dy = dy - amp * bob
          end
        end
        
        love.graphics.push()
        love.graphics.translate(hitX + dx, y + dy)
        local textW = font:getWidth(text)
        -- Keep jackpot number at full opacity at all times
        local alpha = 1.0
        theme.drawTextWithOutline(text, -textW * 0.5, -40, 1, 1, 1, alpha, 3)
        love.graphics.pop()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(theme.fonts.base)
      end
      -- Draw shatter fragments
      if self.jackpotFragments and #self.jackpotFragments > 0 then
        love.graphics.setColor(1, 1, 1, 1)
        for _, frag in ipairs(self.jackpotFragments) do
          local prog = math.max(0, frag.lifetime / math.max(0.0001, frag.maxLifetime))
          local alpha = prog * prog
          if alpha > 0 then
            love.graphics.push()
            love.graphics.translate(frag.x, frag.y)
            love.graphics.rotate(frag.rotation)
            love.graphics.setColor(1, 1, 1, alpha)
            local L = frag.length or 10
            local W = frag.width or 5
            -- Draw an isosceles triangle pointing forward along +X
            love.graphics.polygon("fill",
              0, 0,             -- tip
              -L,  W * 0.5,     -- base top
              -L, -W * 0.5      -- base bottom
            )
            love.graphics.pop()
          end
        end
        love.graphics.setColor(1, 1, 1, 1)
      end
    end
  end

  -- Popups (with fade; single smooth bounce upward)
  love.graphics.setFont(theme.fonts.large)
  local function singleSoftBounce(t)
    -- easeOutBack: smooth single overshoot, reads as one soft bounce
    local c1, c3 = 1.70158, 2.70158
    local u = (t - 1)
    return 1 + c3 * (u * u * u) + c1 * (u * u)
  end
  for _, p in ipairs(self.popups) do
    local life = math.max(0.0001, config.battle.popupLifetime)
    local prog = 1 - math.max(0, p.t / life)
    local baseTop = (p.who == "enemy") and (baselineY - (self.enemyImg and (self.enemyImg:getHeight() * enemyScale) or (2 * r)))
                                   or (baselineY - (self.playerImg and (self.playerImg:getHeight() * playerScale) or (2 * r)))
    local bounce = singleSoftBounce(math.min(1, prog))
    local height = (config.battle and config.battle.popupBounceHeight) or 60
    local y = baseTop - 20 - bounce * height
    local x = (p.who == "enemy") and curEnemyX or curPlayerX
    
    -- Calculate fade alpha
    local start = (config.battle and config.battle.popupFadeStart) or 0.7
    local mul = (config.battle and config.battle.popupFadeMultiplier) or 0.5
    local alpha
    if prog <= start then
      alpha = 1
    else
      local frac = (prog - start) / math.max(1e-6, (1 - start)) -- 0..1 within fade window
      local scaled = frac / math.max(1e-6, mul) -- mul <1 fades faster
      alpha = math.max(0, 1 - scaled)
    end
    
    -- Set color based on who took damage (player = #E0707E, enemy = white)
    -- Armor popups always use white
    local r, g, b = 1, 1, 1 -- default white
    if p.who == "player" and p.kind ~= "armor" then
      -- Player damage color: #E0707E = RGB(224, 112, 126)
      r, g, b = 224/255, 112/255, 126/255
    end
    
    if p.kind == "armor" and self.iconArmor then
      local valueStr = tostring(p.value or 0)
      local textW = theme.fonts.large:getWidth(valueStr)
      local iconW, iconH = self.iconArmor:getWidth(), self.iconArmor:getHeight()
      local s = 28 / math.max(1, iconH)
      local totalW = textW + iconW * s + 6
      local startX = x - totalW * 0.5
      love.graphics.setColor(r, g, b, alpha)
      love.graphics.draw(self.iconArmor, startX, y - 40 + (theme.fonts.large:getHeight() - iconH * s) * 0.5, 0, s, s)
      theme.printfWithOutline(valueStr, startX + iconW * s + 6, y - 40, totalW - (iconW * s + 6), "left", r, g, b, alpha, 2)
    elseif p.kind == "armor_blocked" and self.iconArmor then
      -- Show armor icon only (no text) when damage is blocked
      local iconW, iconH = self.iconArmor:getWidth(), self.iconArmor:getHeight()
      local s = 28 / math.max(1, iconH)
      local startX = x - (iconW * s) * 0.5
      love.graphics.setColor(1, 1, 1, alpha) -- White color for blocked armor icon
      love.graphics.draw(self.iconArmor, startX, y - 40 + (theme.fonts.large:getHeight() - iconH * s) * 0.5, 0, s, s)
    else
      theme.printfWithOutline(p.text or "", x - 40, y - 40, 80, "center", r, g, b, alpha, 2)
    end
  end
  love.graphics.setFont(theme.fonts.base)
  
  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, 1)

  -- Combat log removed
end

-- External API: start jackpot display at beginning of player shot
function BattleScene:startJackpotDisplay()
  self.jackpotActive = true
  self.jackpotTarget = 0
  self.jackpotDisplay = 0
  self.jackpotFalling = false
  self.jackpotFallDelayT = 0
  self.jackpotFallT = 0
  self.jackpotCrit = false
  self.jackpotShakeT = 0
  self.jackpotBobT = 0
  -- Clear any pending damage from previous turn
  self.pendingDamage = 0
  self.pendingArmorFromTurn = 0
  self.impactEffectsPlayed = false
end

-- External API: update jackpot target (live score)
function BattleScene:setJackpotTarget(value)
  if not self.jackpotActive then return end
  local v = tonumber(value) or 0
  if v < 0 then v = 0 end
  if v > (self.jackpotTarget or 0) then
    -- Start a bob cycle when number increases
    self.jackpotBobT = 1e-6
  end
  self.jackpotTarget = math.floor(v)
end

-- External API: mark jackpot as crit (enables shake/scale)
function BattleScene:setJackpotCrit(isCrit)
  self.jackpotCrit = not not isCrit
  if self.jackpotCrit and (self.jackpotShakeT or 0) == 0 then
    self.jackpotShakeT = 0
  end
end

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
      -- If we have pending armor, show popup first, then trigger enemy turn after delay
      if (self.pendingArmor or 0) > 0 and not self.armorPopupShown then
        self.playerArmor = self.pendingArmor
        table.insert(self.popups, { x = 0, y = 0, kind = "armor", value = self.pendingArmor, t = config.battle.popupLifetime, who = "player" })
        self.armorPopupShown = true
        -- Queue enemy turn start after armor popup duration + delay
        local delay = (config.battle.popupLifetime or 0.8) + (config.battle.enemyAttackPostArmorDelay or 0.3)
        -- Use a simple timer to trigger enemy turn after delay
        self._enemyTurnDelay = delay
      else
        -- No armor, start enemy turn immediately
        turnManager:startEnemyTurn()
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
  
  -- If crit, always spawn 5 slashes; otherwise cap at 4 sprites max
  local spriteCount = isCrit and 5 or math.min(blockCount, 4)
  
  local w = (self._lastBounds and self._lastBounds.w) or love.graphics.getWidth()
  local h = (self._lastBounds and self._lastBounds.h) or love.graphics.getHeight()
  local center = self._lastBounds and self._lastBounds.center or nil
  local centerX = center and center.x or math.floor(w * 0.5) - math.floor((w * 0.5) * 0.5)
  local centerW = center and center.w or math.floor(w * 0.5)
  local hitX, hitY = self:getEnemyHitPoint({ x = 0, y = 0, w = w, h = h, center = { x = centerX, w = centerW, h = h } })
  
  local staggerDelay = (config.battle and config.battle.impactStaggerDelay) or 0.05
  local fps = (config.battle and config.battle.impactFps) or 30
  local impactPath = (config.assets and config.assets.images and config.assets.images.impact) or nil
  
  -- Create multiple impact instances with staggered delays
  -- Reuse the base animation's image and quads to avoid reloading
  local baseImage = self.impactAnimation and self.impactAnimation.image
  local baseQuads = self.impactAnimation and self.impactAnimation.quads
  
  for i = 1, spriteCount do
    -- Create a lightweight animation instance that shares the image and quads
    local anim = {
      image = baseImage,
      quads = baseQuads,
      frameW = 512,
      frameH = 512,
      fps = fps,
      time = 0,
      index = 1,
      playing = false,
      loop = false,
      active = false
    }
    setmetatable(anim, SpriteAnimation)
    
    local delay = (i - 1) * staggerDelay
    local rotation = love.math.random() * 2 * math.pi
    -- Add slight position offset for visual separation (randomized per instance)
    local offsetX = (love.math.random() - 0.5) * 20
    local offsetY = (love.math.random() - 0.5) * 20
    
    table.insert(self.impactInstances, {
      anim = anim,
      x = hitX,
      y = hitY,
      rotation = rotation,
      delay = delay,
      offsetX = offsetX,
      offsetY = offsetY
    })
  end
  
  -- Trigger staggered flash and knockback events (one per impact sprite)
  local flashDuration = (config.battle and config.battle.hitFlashDuration) or 0.5
  for i = 1, spriteCount do
    local delay = (i - 1) * staggerDelay
    -- Add flash event
    table.insert(self.enemyFlashEvents, {
      delay = delay,
      duration = flashDuration
    })
    -- Add knockback event
    table.insert(self.enemyKnockbackEvents, {
      delay = delay,
      startTime = nil -- Will be set when delay expires
    })
  end
  
  -- Trigger player lunge and screenshake immediately (only once)
  if spriteCount > 0 then
    self.playerLungeTime = 1e-6
    self:triggerShake((config.battle and config.battle.shakeMagnitude) or 10, (config.battle and config.battle.shakeDuration) or 0.25)
    self.impactEffectsPlayed = true
  end
end

return BattleScene



