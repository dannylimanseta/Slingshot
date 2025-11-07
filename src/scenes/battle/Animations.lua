local config = require("config")

local Animations = {}

function Animations.update(scene, dt)
  if not scene then return end

  -- Advance lunge timers (hold at peak while impacts play)
  do
    local d = (config.battle and config.battle.lungeDuration) or 0
    local rdur = (config.battle and config.battle.lungeReturnDuration) or 0
    local totalPlayer = d + rdur
    if scene.playerLungeTime and scene.playerLungeTime > 0 then
      local t = scene.playerLungeTime
      local impactsActive = (scene.impactInstances and #scene.impactInstances > 0)
      local inForward = t < d
      local inReturn = t >= d and t < d + rdur
      local shouldHold = (not inForward) and inReturn and impactsActive
      if not shouldHold then
        scene.playerLungeTime = scene.playerLungeTime + dt
        if scene.playerLungeTime > totalPlayer then scene.playerLungeTime = 0 end
      end
    end
  end

  -- Advance enemy lunge timers
  local totalEnemy = ((config.battle and config.battle.lungeDuration) or 0) + ((config.battle and config.battle.lungeReturnDuration) or 0)
  for _, enemy in ipairs(scene.enemies or {}) do
    if enemy.lungeTime and enemy.lungeTime > 0 then
      enemy.lungeTime = enemy.lungeTime + dt
      if enemy.lungeTime > totalEnemy then enemy.lungeTime = 0 end
    end
  end

  -- Advance enemy jump timers (for shockwave attack)
  local jumpUpDuration = 0.3 -- Time to jump up
  local jumpDownDuration = 0.2 -- Time to land
  local totalJump = jumpUpDuration + jumpDownDuration
  for _, enemy in ipairs(scene.enemies or {}) do
    if enemy.jumpTime and enemy.jumpTime > 0 then
      enemy.jumpTime = enemy.jumpTime + dt
      if enemy.jumpTime > totalJump then enemy.jumpTime = 0 end
    end
  end

  -- Advance knockback timers
  local kbTotalPlayer = ((config.battle and config.battle.knockbackDuration) or 0) + ((config.battle and config.battle.knockbackReturnDuration) or 0)
  if scene.playerKnockbackTime and scene.playerKnockbackTime > 0 then
    scene.playerKnockbackTime = scene.playerKnockbackTime + dt
    if scene.playerKnockbackTime > kbTotalPlayer then scene.playerKnockbackTime = 0 end
  end

  local kbTotalEnemy = ((config.battle and config.battle.knockbackDuration) or 0) + ((config.battle and config.battle.knockbackReturnDuration) or 0)
  for _, enemy in ipairs(scene.enemies or {}) do
    if enemy.knockbackTime and enemy.knockbackTime > 0 then
      enemy.knockbackTime = enemy.knockbackTime + dt
      if enemy.knockbackTime > kbTotalEnemy then enemy.knockbackTime = 0 end
    end
  end

  -- Tween rotation back to 0
  local rotationTweenSpeed = 8
  if scene.playerRotation and math.abs(scene.playerRotation) > 0.001 then
    local k = math.min(1, rotationTweenSpeed * dt)
    scene.playerRotation = scene.playerRotation * (1 - k)
    if math.abs(scene.playerRotation) < 0.001 then scene.playerRotation = 0 end
  end
  for _, enemy in ipairs(scene.enemies or {}) do
    if enemy.rotation and math.abs(enemy.rotation) > 0.001 then
    local k = math.min(1, rotationTweenSpeed * dt)
      enemy.rotation = enemy.rotation * (1 - k)
      if math.abs(enemy.rotation) < 0.001 then enemy.rotation = 0 end
    end
  end

  -- Update fog time
  scene.fogTime = (scene.fogTime or 0) + dt

  -- Advance screenshake timer
  if scene.shakeTime and scene.shakeTime > 0 then
    scene.shakeTime = scene.shakeTime - dt
    if scene.shakeTime <= 0 then
      scene.shakeTime = 0
      scene.shakeDuration = 0
      scene.shakeMagnitude = 0
    end
  end

  -- Idle bob time
  scene.idleT = (scene.idleT or 0) + dt

  -- Update pulse animation timers (separate phases)
  local pulseConfig = config.battle and config.battle.pulse
  if pulseConfig and (pulseConfig.enabled ~= false) then
    local speed = pulseConfig.speed or 1.2
    scene.playerPulseTime = (scene.playerPulseTime or 0) + dt * speed * 2 * math.pi
    for _, enemy in ipairs(scene.enemies or {}) do
      enemy.pulseTime = (enemy.pulseTime or 0) + dt * speed * 2 * math.pi
    end
  end

  -- Emit lunge speed streaks during player forward phase
  do
    local cfg = config.battle and config.battle.speedStreaks
    if cfg and cfg.enabled then
      local t = scene.playerLungeTime or 0
      local d = (config.battle and config.battle.lungeDuration) or 0
      if t > 0 and t < d then
        local w = (scene._lastBounds and scene._lastBounds.w) or love.graphics.getWidth()
        local h = (scene._lastBounds and scene._lastBounds.h) or love.graphics.getHeight()
        local center = scene._lastBounds and scene._lastBounds.center or nil
        local centerX = center and center.x or math.floor(w * 0.5) - math.floor((w * 0.5) * 0.5)
        local centerW = center and center.w or math.floor(w * 0.5)
        local leftWidth = math.max(0, centerX)
        local pad = 12
        local r = 24
        local yOffset = (config.battle and config.battle.positionOffsetY) or 0
        local baselineY = h * 0.55 + r + yOffset
        local playerX = (leftWidth > 0) and (leftWidth * 0.5) or (pad + r)
        local curPlayerX = playerX + (config.battle.lungeDistance or 0) * (t / math.max(0.0001, d))

        local playerHalfH = r
        local playerHalfW = r
        if scene.playerImg then
          local iw, ih = scene.playerImg:getWidth(), scene.playerImg:getHeight()
          local scaleCfg = (config.battle and (config.battle.playerSpriteScale or config.battle.spriteScale)) or 1
          local s = ((2 * r) / math.max(1, ih)) * scaleCfg * (scene.playerScaleMul or 1)
          playerHalfH = (ih * s) * 0.5
          playerHalfW = (iw * s) * 0.5
        end

        scene.lungeStreakAcc = (scene.lungeStreakAcc or 0) + dt * (cfg.emitRate or 60)
        while scene.lungeStreakAcc >= 1 do
          scene.lungeStreakAcc = scene.lungeStreakAcc - 1
          local yTop = baselineY - playerHalfH * 2
          local fullH = playerHalfH * 2
          local y = yTop + love.math.random() * fullH
          local len = (cfg.lengthMin or 24) + love.math.random() * math.max(0, (cfg.lengthMax or 60) - (cfg.lengthMin or 24))
          local vx = (cfg.speedMin or -900) + love.math.random() * math.max(0, (cfg.speedMax or -600) - (cfg.speedMin or -900))
          local life = (cfg.lifetimeMin or 0.12) + love.math.random() * math.max(0, (cfg.lifetimeMax or 0.22) - (cfg.lifetimeMin or 0.12))
          scene.lungeStreaks = scene.lungeStreaks or {}
          table.insert(scene.lungeStreaks, {
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

  -- Update streak lifetimes and positions
  if scene.lungeStreaks and #scene.lungeStreaks > 0 then
    local alive = {}
    for _, s in ipairs(scene.lungeStreaks) do
      s.life = s.life - dt
      if s.life > 0 then
        s.x = s.x + s.vx * dt
        table.insert(alive, s)
      end
    end
    scene.lungeStreaks = alive
  end
end

return Animations


