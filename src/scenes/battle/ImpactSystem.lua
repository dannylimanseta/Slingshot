local config = require("config")
local SpriteAnimation = require("utils.SpriteAnimation")

local ImpactSystem = {}

-- Helper function to create a splatter instance at a given position
-- spriteCenterX, spriteCenterY: The center pivot point of the sprite (where scaling originates from)
local function createSplatter(scene, spriteCenterX, spriteCenterY)
  local splatterImages = scene.splatterImages or (scene.splatterImage and {scene.splatterImage} or {})
  if #splatterImages == 0 then return end
  
  -- Randomly select a splatter image from the pool
  local selectedImage = splatterImages[love.math.random(1, #splatterImages)]
  
  local splatterLifetime = (config.battle and config.battle.splatterLifetime) or 0.4
  local splatterScale = (config.battle and config.battle.splatterScale) or 0.9
  local rotation = love.math.random() * 2 * math.pi
  -- No offset - splatter appears exactly at sprite center
  local offsetX = 0
  local offsetY = 0
  
  local splatterFadeDuration = (config.battle and config.battle.splatterFadeDuration) or 0.1
  local splatterGrowDuration = (config.battle and config.battle.splatterGrowDuration) or 0.15
  local targetScale = splatterScale * (0.7 + love.math.random() * 0.04) -- Random scale variation (very small range)
  scene.splatterInstances = scene.splatterInstances or {}
  table.insert(scene.splatterInstances, {
    spriteCenterX = spriteCenterX, -- Store sprite center pivot for scaling origin
    spriteCenterY = spriteCenterY,
    offsetX = offsetX, -- Offset from sprite center
    offsetY = offsetY,
    rotation = rotation,
    image = selectedImage, -- Store the randomly selected image
    targetScale = targetScale, -- Target scale to grow to
    currentScale = 0, -- Start at 0, will ease-in to targetScale
    alpha = 1.0,
    lifetime = 0,
    maxLifetime = splatterLifetime,
    fadeDuration = splatterFadeDuration,
    growDuration = splatterGrowDuration
  })
end

-- Create multiple staggered impact instances and schedule flash/knockback events
-- isAOE: if true, create impacts at all enemy positions
function ImpactSystem.create(scene, blockCount, isCrit, isAOE)
  if not scene or not scene.impactAnimation then return end
  blockCount = blockCount or 1
  isCrit = isCrit or false
  isAOE = isAOE or false

  -- If crit, always spawn 5 slashes; otherwise cap at 4 sprites max
  local spriteCount = isCrit and 5 or math.min(blockCount, 4)

  local w = (scene._lastBounds and scene._lastBounds.w) or love.graphics.getWidth()
  local h = (scene._lastBounds and scene._lastBounds.h) or love.graphics.getHeight()
  local center = scene._lastBounds and scene._lastBounds.center or nil
  local centerX = center and center.x or math.floor(w * 0.5) - math.floor((w * 0.5) * 0.5)
  local centerW = center and center.w or math.floor(w * 0.5)
  
  -- Get hit points: all enemies if AOE, otherwise just selected enemy
  local hitPoints = {}
  if isAOE and scene.getAllEnemyHitPoints then
    -- Get hit points for all enemies
    hitPoints = scene:getAllEnemyHitPoints({ x = 0, y = 0, w = w, h = h, center = { x = centerX, w = centerW, h = h } })
  else
    -- Get hit point for selected enemy only
  local hitX, hitY = scene:getEnemyHitPoint({ x = 0, y = 0, w = w, h = h, center = { x = centerX, w = centerW, h = h } })
  -- Use hit point directly (already centered on enemy)
    table.insert(hitPoints, { x = hitX, y = hitY, enemyIndex = scene.selectedEnemyIndex })
  end
  
  -- If no hit points found, return early
  if #hitPoints == 0 then return end

  local staggerDelay = (config.battle and config.battle.impactStaggerDelay) or 0.05
  local fps = (config.battle and config.battle.impactFps) or 30

  -- Reuse the base animation's image and quads
  local baseImage = scene.impactAnimation and scene.impactAnimation.image
  local baseQuads = scene.impactAnimation and scene.impactAnimation.quads

  scene.impactInstances = scene.impactInstances or {}
  scene.enemyFlashEvents = scene.enemyFlashEvents or {}
  scene.enemyKnockbackEvents = scene.enemyKnockbackEvents or {}
  scene.splatterInstances = scene.splatterInstances or {}

  -- Create impact instances for each hit point (each enemy in AOE mode)
  for hitPointIdx, hitPoint in ipairs(hitPoints) do
    local hitX = hitPoint.x
    local hitY = hitPoint.y
    local enemyIndex = hitPoint.enemyIndex

    -- Get enemy sprite visual center for splatter pivot (actual center of sprite, not baseline anchor)
    local enemy = scene.enemies and scene.enemies[enemyIndex]
    local spriteCenterX = hitX -- X is already at sprite center
    local r = 24
    local yOffset = (config.battle and config.battle.positionOffsetY) or 0
    local h = (scene._lastBounds and scene._lastBounds.h) or love.graphics.getHeight()
    local baselineY = h * 0.55 + r + yOffset
    
    -- Calculate enemy sprite visual center (midpoint of sprite height)
    local enemyScaleCfg = enemy.spriteScale or (config.battle and (config.battle.enemySpriteScale or config.battle.spriteScale)) or 4
    local enemyScale = 1
    if enemy.img then
      local ih = enemy.img:getHeight()
      enemyScale = ((2 * r) / math.max(1, ih)) * enemyScaleCfg * (enemy.scaleMul or 1)
    end
    local enemySpriteHeight = enemy.img and (enemy.img:getHeight() * enemyScale) or (r * 2)
    local spriteCenterY = baselineY - enemySpriteHeight * 0.5 -- Visual center (halfway up from baseline)
    
    -- Create splatter effect (one per hit point, appears immediately)
    createSplatter(scene, spriteCenterX, spriteCenterY)

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

      -- Stagger delay: start with delay based on hit point index, then sprite index within that
      local baseDelay = (hitPointIdx - 1) * staggerDelay * 0.5 -- Small delay between enemies in AOE
      local spriteDelay = (i - 1) * staggerDelay
      local delay = baseDelay + spriteDelay
      
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
        enemyIndex = enemyIndex, -- Store enemy index for flash/knockback events
    })

      -- Schedule per-sprite flash and knockback (store enemy index for AOE)
    local flashDuration = (config.battle and config.battle.hitFlashDuration) or 0.5
      table.insert(scene.enemyFlashEvents, { delay = delay, duration = flashDuration, enemyIndex = enemyIndex })
      table.insert(scene.enemyKnockbackEvents, { delay = delay, startTime = nil, enemyIndex = enemyIndex })
    end
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

-- Create splatter at player position (called when player is hit)
function ImpactSystem.createPlayerSplatter(scene, bounds)
  if not scene or not scene.splatterImage then return end
  
  local w = (bounds and bounds.w) or love.graphics.getWidth()
  local h = (bounds and bounds.h) or love.graphics.getHeight()
  local center = bounds and bounds.center or nil
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
  
  local playerLunge = lungeOffset(scene.playerLungeTime, (scene.impactInstances and #scene.impactInstances > 0))
  local playerKB = knockbackOffset(scene.playerKnockbackTime)
  local curPlayerX = playerX + playerLunge - playerKB
  
  -- Calculate player sprite height for hit point
  local playerScaleCfg = (config.battle and (config.battle.playerSpriteScale or config.battle.spriteScale)) or 1
  local playerScale = 1
  if scene.playerImg then
    local ih = scene.playerImg:getHeight()
    playerScale = ((2 * r) / math.max(1, ih)) * playerScaleCfg * (scene.playerScaleMul or 1)
  end
  
  local playerHalfH = scene.playerImg and ((scene.playerImg:getHeight() * playerScale) * 0.5) or r
  local hitX = curPlayerX
  local hitY = baselineY - playerHalfH * 0.7 -- slightly above center
  
  -- Calculate player sprite visual center (midpoint of sprite height, not baseline anchor)
  local playerSpriteHeight = scene.playerImg and (scene.playerImg:getHeight() * playerScale) or (r * 2)
  local playerSpriteCenterX = curPlayerX
  local playerSpriteCenterY = baselineY - playerSpriteHeight * 0.5 -- Visual center (halfway up from baseline)
  
  createSplatter(scene, playerSpriteCenterX, playerSpriteCenterY)
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
          -- Apply flash and rotation to the specified enemy (or selected/first as fallback)
          local enemy = nil
          if event.enemyIndex and scene.enemies and scene.enemies[event.enemyIndex] then
            -- Use the stored enemy index from AOE mode
            enemy = scene.enemies[event.enemyIndex]
          elseif scene.getSelectedEnemy then
            -- Fallback to selected enemy
            enemy = scene:getSelectedEnemy()
          end
          if not enemy and scene.enemies and #scene.enemies > 0 then
            -- Fallback to first enemy
            enemy = scene.enemies[1]
          end
            if enemy then
              enemy.flash = math.max(enemy.flash or 0, flashDuration)
          -- Apply slight rotation nudge on hit
          local rotationDegrees = love.math.random(1, 3)
          local rotationRadians = math.rad(rotationDegrees)
          if love.math.random() < 0.5 then rotationRadians = -rotationRadians end
              enemy.rotation = (enemy.rotation or 0) + rotationRadians
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
  
  -- Update splatter instances (scale up with ease-in throughout lifetime, fade out at the end)
  do
    local activeSplatters = {}
    for _, splatter in ipairs(scene.splatterInstances or {}) do
      splatter.lifetime = (splatter.lifetime or 0) + dt
      if splatter.lifetime < splatter.maxLifetime then
        -- Stay fully visible until fade starts, then fade quickly
        local fadeStart = splatter.maxLifetime - (splatter.fadeDuration or 0.1)
        
        if splatter.lifetime >= fadeStart then
          -- Fade out over the fade duration
          local fadeProgress = (splatter.lifetime - fadeStart) / (splatter.fadeDuration or 0.1)
          splatter.alpha = 1.0 - fadeProgress
          
          -- Scale shrinks as it fades (shrink from targetScale, but only partially)
          local fadeT = 1 - fadeProgress -- Goes from 1 to 0 as fade progresses
          local fadeStartScale = splatter.targetScale -- Scale at start of fade
          local shrinkAmount = 0.97 -- Only shrink to 30% of original size (shrink by 70%)
          local minScale = fadeStartScale * shrinkAmount
          splatter.currentScale = fadeStartScale - (fadeStartScale - minScale) * (1 - fadeT * fadeT) -- Ease-out shrink (quadratic)
        else
          -- Stay fully visible and grow with ease-out
          splatter.alpha = 1.0
          -- Scale animation: ease-out from 0, grows until fade starts (15% faster)
          local t = (splatter.lifetime / fadeStart) * 1.15 -- Speed up by 15%
          t = math.min(1.0, t) -- Clamp to 1.0 maximum
          local easeOut = 1 - (1 - t) * (1 - t) -- Quadratic ease-out (starts fast, slows down)
          splatter.currentScale = splatter.targetScale * easeOut
        end
        table.insert(activeSplatters, splatter)
      end
    end
    scene.splatterInstances = activeSplatters
  end
end

-- Draw impact animations (additive) above sprites but below overlays
function ImpactSystem.draw(scene)
  if not scene then return end
  
  -- Draw splatter effects first (behind impacts)
  -- Disable scissor testing to allow splatters to extend beyond screen edges
  if scene.splatterInstances and #scene.splatterInstances > 0 then
    love.graphics.push("all")
    love.graphics.setBlendMode("alpha")
    love.graphics.setScissor() -- Disable scissor to allow drawing outside bounds
    for _, splatter in ipairs(scene.splatterInstances) do
      if splatter.image then
        local imgW = splatter.image:getWidth()
        local imgH = splatter.image:getHeight()
        local scale = splatter.currentScale or splatter.targetScale
        
        -- Calculate position: sprite center + offset * scale
        -- As scale increases from 0 to targetScale, the splatter moves from sprite center outward
        local drawX = splatter.spriteCenterX + splatter.offsetX * scale
        local drawY = splatter.spriteCenterY + splatter.offsetY * scale
        
        -- Origin point: Set so that scaling happens from sprite center pivot
        -- When scale=0, splatter should be at sprite center; when scale increases, it grows outward
        -- Origin is adjusted by the offset so the scaling pivot is at sprite center
        local originX = imgW * 0.5 - splatter.offsetX
        local originY = imgH * 0.5 - splatter.offsetY
        
        love.graphics.setColor(1, 1, 1, splatter.alpha)
        love.graphics.draw(
          splatter.image,
          drawX,
          drawY,
          splatter.rotation,
          scale,
          scale,
          originX,
          originY
        )
      end
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.pop()
  end
  
  -- Draw impact animations
  if not scene.impactAnimation then return end
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


