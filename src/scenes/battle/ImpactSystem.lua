local config = require("config")
local SpriteAnimation = require("utils.SpriteAnimation")

local ImpactSystem = {}

-- Create multiple staggered impact instances and schedule flash/knockback events
function ImpactSystem.create(scene, blockCount, isCrit)
  if not scene or not scene.impactAnimation then return end
  blockCount = blockCount or 1
  isCrit = isCrit or false

  -- If crit, always spawn 5 slashes; otherwise cap at 4 sprites max
  local spriteCount = isCrit and 5 or math.min(blockCount, 4)

  local w = (scene._lastBounds and scene._lastBounds.w) or love.graphics.getWidth()
  local h = (scene._lastBounds and scene._lastBounds.h) or love.graphics.getHeight()
  local center = scene._lastBounds and scene._lastBounds.center or nil
  local centerX = center and center.x or math.floor(w * 0.5) - math.floor((w * 0.5) * 0.5)
  local centerW = center and center.w or math.floor(w * 0.5)
  local hitX, hitY = scene:getEnemyHitPoint({ x = 0, y = 0, w = w, h = h, center = { x = centerX, w = centerW, h = h } })
  -- Shift impact sprites slightly to the left for better visual centering
  hitX = hitX - 20

  local staggerDelay = (config.battle and config.battle.impactStaggerDelay) or 0.05
  local fps = (config.battle and config.battle.impactFps) or 30

  -- Reuse the base animation's image and quads
  local baseImage = scene.impactAnimation and scene.impactAnimation.image
  local baseQuads = scene.impactAnimation and scene.impactAnimation.quads

  scene.impactInstances = scene.impactInstances or {}
  scene.enemyFlashEvents = scene.enemyFlashEvents or {}
  scene.enemyKnockbackEvents = scene.enemyKnockbackEvents or {}

  for i = 1, spriteCount do
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
      active = false,
    }
    setmetatable(anim, SpriteAnimation)

    local delay = (i - 1) * staggerDelay
    local rotation = love.math.random() * 2 * math.pi
    -- Random offset with slight leftward bias for better centering
    local offsetX = (love.math.random() - 0.5) * 20
    local offsetY = (love.math.random() - 0.5) * 20

    table.insert(scene.impactInstances, {
      anim = anim,
      x = hitX,
      y = hitY,
      rotation = rotation,
      delay = delay,
      offsetX = offsetX,
      offsetY = offsetY,
    })

    -- Schedule per-sprite flash and knockback
    local flashDuration = (config.battle and config.battle.hitFlashDuration) or 0.5
    table.insert(scene.enemyFlashEvents, { delay = delay, duration = flashDuration })
    table.insert(scene.enemyKnockbackEvents, { delay = delay, startTime = nil })
  end
end

-- High-level entry: play impact by queuing instances with delay
function ImpactSystem.play(scene, blockCount, isCrit)
  if not scene or not scene.impactAnimation then return end
  ImpactSystem.create(scene, blockCount, isCrit)
  scene.impactEffectsPlayed = true
  if not scene._playerAttackDelayTimer then
    scene._playerAttackDelayTimer = (config.battle and config.battle.playerAttackDelay) or 1.0
  end
end

-- Update impact instances and related flash/knockback events
function ImpactSystem.update(scene, dt)
  if not scene then return end

  -- Update staggered flash events
  do
    local activeFlashEvents = {}
    local flashDuration = (config.battle and config.battle.hitFlashDuration) or 0.5
    for _, event in ipairs(scene.enemyFlashEvents or {}) do
      event.delay = math.max(0, event.delay - dt)
      if event.delay <= 0 then
        if not event.triggered then
          event.triggered = true
          event.startTime = 0
          -- Apply flash and rotation to first enemy (primary target)
          if scene.enemies and #scene.enemies > 0 then
            local enemy = scene.enemies[1]
            if enemy then
              enemy.flash = math.max(enemy.flash or 0, flashDuration)
          -- Apply slight rotation nudge on hit
          local rotationDegrees = love.math.random(1, 3)
          local rotationRadians = math.rad(rotationDegrees)
          if love.math.random() < 0.5 then rotationRadians = -rotationRadians end
              enemy.rotation = (enemy.rotation or 0) + rotationRadians
            end
          end
        end
        event.startTime = (event.startTime or 0) + dt
        if event.startTime < flashDuration then
          table.insert(activeFlashEvents, event)
        end
      else
        table.insert(activeFlashEvents, event)
      end
    end
    scene.enemyFlashEvents = activeFlashEvents
  end

  -- Update staggered knockback events
  do
    local activeKnockbackEvents = {}
    local kbTotal = ((config.battle and config.battle.knockbackDuration) or 0) + ((config.battle and config.battle.knockbackReturnDuration) or 0)
    for _, event in ipairs(scene.enemyKnockbackEvents or {}) do
      event.delay = math.max(0, event.delay - dt)
      if event.delay <= 0 then
        if not event.startTime then event.startTime = 0 end
        event.startTime = event.startTime + dt
        if event.startTime < kbTotal then
          table.insert(activeKnockbackEvents, event)
        end
      else
        table.insert(activeKnockbackEvents, event)
      end
    end
    scene.enemyKnockbackEvents = activeKnockbackEvents
  end

  -- Update impact animation instances (with staggered start delays)
  if scene.impactAnimation then
    local activeInstances = {}
    for _, instance in ipairs(scene.impactInstances or {}) do
      instance.delay = math.max(0, instance.delay - dt)
      if instance.delay <= 0 then
        if not instance.anim.playing and instance.anim.play then
          instance.anim:play(false)
        end
        if instance.anim.update then
          instance.anim:update(dt)
        end
        if instance.anim.active then
          table.insert(activeInstances, instance)
        end
      else
        table.insert(activeInstances, instance)
      end
    end
    scene.impactInstances = activeInstances

    -- If we owe a disintegration after impacts, trigger when all slashes are done
    -- Check all enemies for pending disintegration
    for _, enemy in ipairs(scene.enemies or {}) do
      if enemy.pendingDisintegration and (#scene.impactInstances == 0) then
        -- Check if disintegration has already completed (prevent restarting)
        local cfg = config.battle and config.battle.disintegration or {}
        local duration = cfg.duration or 1.5
        local hasCompletedDisintegration = (enemy.disintegrationTime or 0) >= duration
        
        if not enemy.disintegrating and not hasCompletedDisintegration then
          enemy.disintegrating = true
          enemy.disintegrationTime = 0
        end
        enemy.pendingDisintegration = false
      end
    end
  end
end

-- Draw impact animations (additive) above sprites but below overlays
function ImpactSystem.draw(scene)
  if not scene or not scene.impactAnimation then return end
  if not scene.impactInstances or #scene.impactInstances == 0 then return end

  love.graphics.push("all")
  love.graphics.setBlendMode("add")
  love.graphics.setColor(1, 1, 1, 1)
  local scale = (config.battle and config.battle.impactScale) or 0.96
  for _, instance in ipairs(scene.impactInstances) do
    if instance.delay <= 0 and instance.anim.active then
      instance.anim:draw(
        instance.x + (instance.offsetX or 0),
        instance.y + (instance.offsetY or 0),
        instance.rotation,
        scale,
        scale
      )
    end
  end
  love.graphics.pop()
end

return ImpactSystem


