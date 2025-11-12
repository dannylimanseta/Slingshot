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
-- isPierce: if true, create single horizontal slicing impact (left to right)
-- isBlackHole: if true, create black hole attack animation
function ImpactSystem.create(scene, blockCount, isCrit, isAOE, isPierce, isBlackHole)
  if not scene or not scene.impactAnimation then return end
  blockCount = blockCount or 1
  isCrit = isCrit or false
  isAOE = isAOE or false
  isPierce = isPierce or false
  isBlackHole = isBlackHole or false
  
  -- Black hole attack uses custom animation
  if isBlackHole then
    return ImpactSystem.createBlackHoleAttack(scene, isAOE)
  end

  -- If crit, always spawn 5 slashes; otherwise cap at 4 sprites max
  -- For pierce, use single impact
  local spriteCount = isPierce and 1 or (isCrit and 5 or math.min(blockCount, 4))

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

  -- Reuse the base animation's image and quads from impact_1.png sprite sheet
  -- baseImage is the impact_1.png sprite sheet image (not the orb sprite)
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
    -- Stagger delay: start with delay based on hit point index, then sprite index within that
    local baseDelay = (hitPointIdx - 1) * staggerDelay * 0.5 -- Small delay between enemies in AOE
    local spriteDelay = (i - 1) * staggerDelay
    local delay = baseDelay + spriteDelay
    
    if isPierce then
      -- Pierce impact: single image, no rotation, horizontal movement left to right
      -- Get enemy sprite width to determine start/end positions
      local enemySpriteWidth = enemy.img and (enemy.img:getWidth() * enemyScale) or (r * 2)
      local startX = hitX - enemySpriteWidth * 0.5 - 100 -- Start 100px to the left of enemy
      local endX = hitX + enemySpriteWidth * 0.5 + 100 -- End 100px to the right of enemy
      local pierceDuration = 0.3 -- Duration for pierce animation
      
      -- Use 9th quad from impact_1.png sprite sheet (9th frame of impact animation)
      local ninthQuad = baseQuads and baseQuads[9] or nil
      
      -- Random scale variation: base 1.5x with +/- 20% variation
      local baseScale = 2.0
      local scaleVariation = 0.8 + love.math.random() * 0.4 -- Random between 0.8 and 1.2
      local impactScale = baseScale * scaleVariation
      
      table.insert(scene.impactInstances, {
        isPierce = true,
        image = baseImage, -- Use impact_1.png sprite sheet image (not orb sprite)
        quad = ninthQuad, -- Use 9th frame quad from impact sprite sheet
        x = startX,
        y = hitY,
        startX = startX,
        endX = endX,
        rotation = 0, -- No rotation for pierce
        delay = delay,
        lifetime = 0,
        duration = pierceDuration,
        active = true,
        enemyIndex = enemyIndex,
        impactScale = impactScale, -- Store scale variation for this instance
      })
    else
      -- Regular impact: animation with rotation
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
      
      local rotation = love.math.random() * 2 * math.pi
      -- Random offset with slight leftward bias for better centering
      local offsetX = (love.math.random() - 0.5) * 20
      local offsetY = (love.math.random() - 0.5) * 20
      
      -- Random scale variation: base 1.5x with +/- 20% variation
      local baseScale = 1.5
      local scaleVariation = 0.8 + love.math.random() * 0.4 -- Random between 0.8 and 1.2
      local impactScale = baseScale * scaleVariation

      table.insert(scene.impactInstances, {
        anim = anim,
        x = hitX,
        y = hitY,
        rotation = rotation,
        delay = delay,
        offsetX = offsetX,
        offsetY = offsetY,
        enemyIndex = enemyIndex, -- Store enemy index for flash/knockback events
        impactScale = impactScale, -- Store scale variation for this instance
      })
    end

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

-- Update black hole attack animations
function ImpactSystem.updateBlackHoleAttacks(scene, dt)
  if not scene or not scene.blackHoleAttacks then return end
  
  local aliveAttacks = {}
  for _, attack in ipairs(scene.blackHoleAttacks) do
    attack.t = attack.t + dt
    local progress = attack.t / attack.duration
    
    -- Phase 1 (0-0.4): Open with ease-in-out
    -- Phase 2 (0.4-0.5): Hold open
    -- Phase 3 (0.5-1.0): Shatter into triangles (longer phase, slower fade)
    if progress < 0.4 then
      -- Opening phase: ease-in-out (sine wave)
      local t = progress / 0.4
      local easeInOut = (1 - math.cos(t * math.pi)) / 2
      attack.currentRadius = attack.maxRadius * easeInOut
      attack.phase = "opening"
    elseif progress < 0.5 then
      -- Hold phase
      attack.currentRadius = attack.maxRadius
      attack.phase = "hold"
    elseif progress < 1.0 then
      -- Shatter phase (longer for slower fade)
      attack.phase = "shatter"
      -- Generate shards on first frame of shatter
      if #attack.shards == 0 then
        -- Get target enemies (for AOE, this will be 2-3 enemies; for single target, just one)
        local targetEnemyIndices = attack.targetEnemyIndices or {attack.enemyIndex}
        local hitPoints = attack.hitPoints or {}
        
        -- Get enemy positions for all targets
        local targetEnemyPositions = {}
        for _, enemyIndex in ipairs(targetEnemyIndices) do
          local enemy = scene.enemies and scene.enemies[enemyIndex]
          local enemyX, enemyY = attack.x, attack.y + 350 -- Default fallback
          if enemy then
            local bounds = scene._lastBounds
            local w = (bounds and bounds.w) or love.graphics.getWidth()
            local h = (bounds and bounds.h) or love.graphics.getHeight()
            local r = 24
            local yOffset = (config.battle and config.battle.positionOffsetY) or 0
            local baselineY = h * 0.55 + r + yOffset
            local enemyScaleCfg = enemy.spriteScale or (config.battle and (config.battle.enemySpriteScale or config.battle.spriteScale)) or 4
            local enemyScale = 1
            if enemy.img then
              local ih = enemy.img:getHeight()
              enemyScale = ((2 * r) / math.max(1, ih)) * enemyScaleCfg * (enemy.scaleMul or 1)
            end
            local enemySpriteHeight = enemy.img and (enemy.img:getHeight() * enemyScale) or (r * 2)
            enemyY = baselineY - enemySpriteHeight * 0.5
            
            -- Find hit point for this enemy
            for _, hp in ipairs(hitPoints) do
              if hp.enemyIndex == enemyIndex then
                enemyX = hp.x
                break
              end
            end
          end
          table.insert(targetEnemyPositions, { x = enemyX, y = enemyY, enemyIndex = enemyIndex })
        end
        
        local numShards = 35 -- Reduced by 30% (was 50)
        for i = 1, numShards do
          -- Distribute shards among target enemies (for AOE, spread across 2-3 enemies)
          local targetIdx = ((i - 1) % #targetEnemyPositions) + 1
          local targetPos = targetEnemyPositions[targetIdx]
          local enemyX, enemyY = targetPos.x, targetPos.y
          
          local angle = (i / numShards) * math.pi * 2
          -- More extreme variation for larger, more scattered burst (50-600 px/s)
          local speedTier = love.math.random()
          local speed
          if speedTier < 0.3 then
            -- 30% slow shards (close to center)
            speed = 50 + love.math.random() * 120
          elseif speedTier < 0.7 then
            -- 40% medium shards
            speed = 170 + love.math.random() * 180
          else
            -- 30% fast shards (explosive outer ring)
            speed = 350 + love.math.random() * 250
          end
          local rotSpeed = (love.math.random() * 3 - 1.5) * math.pi -- Slower rotation
          -- More varied triangle sizes and aspect ratios
          local baseSize = 4 + love.math.random() * 14 -- 4-18px
          local aspectRatio = 0.4 + love.math.random() * 1.2 -- Width/height ratio (0.4 to 1.6)
          -- Random offset within medium radius around enemy center
          local offsetRadius = 60 -- Medium radius for spread
          local offsetAngle = love.math.random() * math.pi * 2
          local offsetDist = love.math.random() * offsetRadius
          local targetX = enemyX + math.cos(offsetAngle) * offsetDist
          local targetY = enemyY + math.sin(offsetAngle) * offsetDist
          -- Vary homing speed by +/- 25% so shards hit at different times
          local homingSpeedVariance = 0.75 + love.math.random() * 0.5
          -- Add random angle variation to burst for more scatter
          local angleVariation = (love.math.random() - 0.5) * 0.3 -- +/- 8.6 degrees
          local scatteredAngle = angle + angleVariation
          -- Calculate burst endpoint (control point for stronger curve)
          local burstDist = 120 + love.math.random() * 100 -- Larger burst distance 120-220px for stronger curve
          local burstEndX = attack.x + math.cos(scatteredAngle) * burstDist
          local burstEndY = attack.y + math.sin(scatteredAngle) * burstDist + 200 * 0.3 -- More downward drift for arc
          table.insert(attack.shards, {
            x = attack.x,
            y = attack.y,
            startX = attack.x, -- Store start position for bezier
            startY = attack.y,
            burstEndX = burstEndX, -- Burst endpoint (control point)
            burstEndY = burstEndY,
            vx = math.cos(scatteredAngle) * speed,
            vy = math.sin(scatteredAngle) * speed + 150,
            rotation = love.math.random() * math.pi * 2,
            rotSpeed = rotSpeed,
            size = baseSize,
            aspect = aspectRatio,
            alpha = 1.0,
            targetX = targetX, -- Final target (enemy position)
            targetY = targetY,
            progress = 0, -- Overall progress through animation (0 to 1)
            homingSpeedMul = homingSpeedVariance
          })
        end
      end
      -- Update shards: smooth bezier curve from start -> burst endpoint -> target
      local shatterProgress = (progress - 0.5) / 0.5 -- Shatter phase (0.5-1.0)
      for _, shard in ipairs(attack.shards) do
        -- Update progress based on shard's individual speed
        local progressSpeed = 1.2 * (shard.homingSpeedMul or 1) -- Speed affects how fast shard completes its path
        shard.progress = math.min(1, shard.progress + dt * progressSpeed)
        
        -- Quadratic bezier curve: P(t) = (1-t)²·P0 + 2(1-t)t·P1 + t²·P2
        -- P0 = start (black hole), P1 = burst endpoint (control point), P2 = target (enemy)
        local t = shard.progress
        local oneMinusT = 1 - t
        local oneMinusT2 = oneMinusT * oneMinusT
        local t2 = t * t
        local bezierTerm = 2 * oneMinusT * t
        
        shard.x = oneMinusT2 * shard.startX + bezierTerm * shard.burstEndX + t2 * shard.targetX
        shard.y = oneMinusT2 * shard.startY + bezierTerm * shard.burstEndY + t2 * shard.targetY
        
        shard.rotation = shard.rotation + shard.rotSpeed * dt
        -- Fade only in the last 30% of the animation
        local fadeStart = 0.7 -- Start fading at 70% of duration
        if shatterProgress < fadeStart then
          shard.alpha = 1.0 -- Fully visible
        else
          -- Fade in last 30%
          local fadeProgress = (shatterProgress - fadeStart) / (1.0 - fadeStart)
          shard.alpha = 1.0 - fadeProgress
        end
      end
    end
    
    if attack.t < attack.duration then
      table.insert(aliveAttacks, attack)
    end
  end
  scene.blackHoleAttacks = aliveAttacks
end

-- Update impact instances and related flash/knockback events
function ImpactSystem.update(scene, dt)
  if not scene then return end
  
  -- Update black hole attacks
  ImpactSystem.updateBlackHoleAttacks(scene, dt)

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
        if instance.isPierce then
          -- Update pierce impact: move horizontally left to right
          instance.lifetime = (instance.lifetime or 0) + dt
          if instance.lifetime < instance.duration then
            -- Interpolate position from startX to endX
            local progress = instance.lifetime / instance.duration
            -- Use ease-out for smoother animation
            local easedProgress = 1 - (1 - progress) * (1 - progress) -- Quadratic ease-out
            instance.x = instance.startX + (instance.endX - instance.startX) * easedProgress
            table.insert(activeInstances, instance)
          end
        else
          -- Regular impact animation
          if not instance.anim.playing and instance.anim.play then
            instance.anim:play(false)
          end
          if instance.anim.update then
            instance.anim:update(dt)
          end
          if instance.anim.active then
            table.insert(activeInstances, instance)
          end
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

-- Draw black hole attack animations
function ImpactSystem.drawBlackHoleAttacks(scene)
  if not scene or not scene.blackHoleAttacks then return end
  
  for _, attack in ipairs(scene.blackHoleAttacks) do
    if attack.phase == "opening" or attack.phase == "hold" then
      -- Draw black hole circle
      love.graphics.push("all")
      love.graphics.setBlendMode("alpha")
      love.graphics.setColor(0, 0, 0, 0.95)
      love.graphics.circle("fill", attack.x, attack.y, attack.currentRadius or 0)
      love.graphics.pop()
    elseif attack.phase == "shatter" then
      -- Draw falling triangle shards
      love.graphics.push("all")
      love.graphics.setBlendMode("alpha")
      for _, shard in ipairs(attack.shards) do
        love.graphics.setColor(0, 0, 0, shard.alpha * 0.95)
        love.graphics.push()
        love.graphics.translate(shard.x, shard.y)
        love.graphics.rotate(shard.rotation)
        -- Draw triangle with varied aspect ratio (width * aspect, height)
        local width = shard.size * (shard.aspect or 1)
        local height = shard.size
        love.graphics.polygon("fill", 
          0, -height * 0.67,  -- top
          -width * 0.5, height * 0.33,  -- bottom left
          width * 0.5, height * 0.33   -- bottom right
        )
        love.graphics.pop()
      end
      love.graphics.pop()
    end
  end
end

-- Draw impact animations (additive) above sprites but below overlays
function ImpactSystem.draw(scene)
  if not scene then return end
  
  -- Draw black hole attacks first
  ImpactSystem.drawBlackHoleAttacks(scene)
  
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
  local baseScale = (config.battle and config.battle.impactScale) or 0.96
  for _, instance in ipairs(scene.impactInstances) do
    if instance.delay <= 0 then
      -- Use instance-specific scale variation (1.5x base with +/- 20% variation)
      local impactScale = instance.impactScale or 1.5
      local finalScale = baseScale * impactScale
      
      if instance.isPierce then
        -- Draw pierce impact: single image, no rotation, horizontal movement
        if instance.image then
          local frameW = 512 -- Frame width from sprite sheet
          local frameH = 512 -- Frame height from sprite sheet
          local quad = instance.quad
          if quad then
            -- Draw using quad (9th frame from sprite sheet) with scale variation
            love.graphics.draw(
              instance.image,
              quad,
              instance.x,
              instance.y,
              0, -- No rotation
              finalScale,
              finalScale,
              frameW * 0.5, -- Center origin
              frameH * 0.5
            )
          else
            -- Fallback: draw whole image if no quad available
            local imgW = instance.image:getWidth()
            local imgH = instance.image:getHeight()
            love.graphics.draw(
              instance.image,
              instance.x,
              instance.y,
              0, -- No rotation
              finalScale,
              finalScale,
              imgW * 0.5, -- Center origin
              imgH * 0.5
            )
          end
        end
      elseif instance.anim and instance.anim.active then
        -- Draw regular impact animation with scale variation
        instance.anim:draw(
          instance.x + (instance.offsetX or 0),
          instance.y + (instance.offsetY or 0),
          instance.rotation,
          finalScale,
          finalScale
        )
      end
    end
  end
  love.graphics.pop()
end

-- Create black hole attack animation (giant hole above enemies that shatters into triangles)
function ImpactSystem.createBlackHoleAttack(scene, isAOE)
  local w = (scene._lastBounds and scene._lastBounds.w) or love.graphics.getWidth()
  local h = (scene._lastBounds and scene._lastBounds.h) or love.graphics.getHeight()
  local center = scene._lastBounds and scene._lastBounds.center or nil
  local centerX = center and center.x or math.floor(w * 0.5) - math.floor((w * 0.5) * 0.5)
  local centerW = center and center.w or math.floor(w * 0.5)
  
  scene.blackHoleAttacks = scene.blackHoleAttacks or {}
  scene.enemyFlashEvents = scene.enemyFlashEvents or {}
  scene.enemyKnockbackEvents = scene.enemyKnockbackEvents or {}
  scene.splatterInstances = scene.splatterInstances or {}
  
  if isAOE then
    -- AOE: Create single giant black hole above center of all enemies
    local hitPoints = {}
    if scene.getAllEnemyHitPoints then
      hitPoints = scene:getAllEnemyHitPoints({ x = 0, y = 0, w = w, h = h, center = { x = centerX, w = centerW, h = h } })
    end
    
    if #hitPoints == 0 then return end
    
    -- Calculate center position of all enemies
    local centerX_sum = 0
    local centerY_sum = 0
    local validEnemies = {}
    for _, hitPoint in ipairs(hitPoints) do
      centerX_sum = centerX_sum + hitPoint.x
      centerY_sum = centerY_sum + hitPoint.y
      table.insert(validEnemies, hitPoint.enemyIndex)
    end
    local avgX = centerX_sum / #hitPoints
    local avgY = centerY_sum / #hitPoints
    
    -- Select 2-3 enemies to target (randomly select from available enemies)
    local numTargets = math.min(2 + love.math.random(2), #validEnemies) -- 2 or 3 targets
    local targetEnemyIndices = {}
    local shuffled = {}
    for i = 1, #validEnemies do
      shuffled[i] = validEnemies[i]
    end
    -- Simple shuffle
    for i = #shuffled, 2, -1 do
      local j = love.math.random(i)
      shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    for i = 1, numTargets do
      table.insert(targetEnemyIndices, shuffled[i])
    end
    
    -- Position giant black hole higher above center
    local holeY = avgY - 400 -- Even higher for giant hole
    
    -- Create splatters at each target enemy center
    for _, enemyIndex in ipairs(targetEnemyIndices) do
      local enemy = scene.enemies and scene.enemies[enemyIndex]
      if enemy then
        -- Find hit point for this enemy
        local hitPoint = hitPoints[1] -- Default fallback
        for _, hp in ipairs(hitPoints) do
          if hp.enemyIndex == enemyIndex then
            hitPoint = hp
            break
          end
        end
        local spriteCenterX = hitPoint.x
        local r = 24
        local yOffset = (config.battle and config.battle.positionOffsetY) or 0
        local baselineY = h * 0.55 + r + yOffset
        local enemyScaleCfg = enemy.spriteScale or (config.battle and (config.battle.enemySpriteScale or config.battle.spriteScale)) or 4
        local enemyScale = 1
        if enemy.img then
          local ih = enemy.img:getHeight()
          enemyScale = ((2 * r) / math.max(1, ih)) * enemyScaleCfg * (enemy.scaleMul or 1)
        end
        local enemySpriteHeight = enemy.img and (enemy.img:getHeight() * enemyScale) or (r * 2)
        local spriteCenterY = baselineY - enemySpriteHeight * 0.5
        createSplatter(scene, spriteCenterX, spriteCenterY)
      end
    end
    
    -- Create single giant black hole
    table.insert(scene.blackHoleAttacks, {
      x = avgX,
      y = holeY,
      t = 0,
      maxRadius = 180, -- Giant hole (50% bigger than normal)
      duration = 1.6,
      enemyIndex = targetEnemyIndices[1], -- Store first enemy for compatibility, but we'll use targetEnemyIndices
      targetEnemyIndices = targetEnemyIndices, -- Store all target enemies
      hitPoints = hitPoints, -- Store hit points for shard targeting
      shards = {} -- Will be populated during shatter phase
    })
    
    -- Schedule flashes for all target enemies
    local blinkDuration = 0.08
    for _, enemyIndex in ipairs(targetEnemyIndices) do
      table.insert(scene.enemyFlashEvents, { delay = 1.25, duration = blinkDuration, enemyIndex = enemyIndex })
      table.insert(scene.enemyKnockbackEvents, { delay = 1.25, startTime = nil, enemyIndex = enemyIndex })
      table.insert(scene.enemyFlashEvents, { delay = 1.4, duration = blinkDuration, enemyIndex = enemyIndex })
      table.insert(scene.enemyKnockbackEvents, { delay = 1.4, startTime = nil, enemyIndex = enemyIndex })
      table.insert(scene.enemyFlashEvents, { delay = 1.55, duration = blinkDuration, enemyIndex = enemyIndex })
      table.insert(scene.enemyKnockbackEvents, { delay = 1.55, startTime = nil, enemyIndex = enemyIndex })
    end
  else
    -- Single target: Create one black hole per enemy hit (original behavior)
    local hitPoints = {}
    local hitX, hitY = scene:getEnemyHitPoint({ x = 0, y = 0, w = w, h = h, center = { x = centerX, w = centerW, h = h } })
    table.insert(hitPoints, { x = hitX, y = hitY, enemyIndex = scene.selectedEnemyIndex })
    
    if #hitPoints == 0 then return end
    
    for _, hitPoint in ipairs(hitPoints) do
      local hitX = hitPoint.x
      local hitY = hitPoint.y
      local enemyIndex = hitPoint.enemyIndex
      
      -- Position hole even higher above enemy
      local holeY = hitY - 350
      
      -- Create splatter at enemy center
      local enemy = scene.enemies and scene.enemies[enemyIndex]
      if enemy then
        local spriteCenterX = hitX
        local r = 24
        local yOffset = (config.battle and config.battle.positionOffsetY) or 0
        local baselineY = h * 0.55 + r + yOffset
        local enemyScaleCfg = enemy.spriteScale or (config.battle and (config.battle.enemySpriteScale or config.battle.spriteScale)) or 4
        local enemyScale = 1
        if enemy.img then
          local ih = enemy.img:getHeight()
          enemyScale = ((2 * r) / math.max(1, ih)) * enemyScaleCfg * (enemy.scaleMul or 1)
        end
        local enemySpriteHeight = enemy.img and (enemy.img:getHeight() * enemyScale) or (r * 2)
        local spriteCenterY = baselineY - enemySpriteHeight * 0.5
        createSplatter(scene, spriteCenterX, spriteCenterY)
      end
      
      table.insert(scene.blackHoleAttacks, {
        x = hitX,
        y = holeY,
        t = 0,
        maxRadius = 120, -- Normal size hole
        duration = 1.6,
        enemyIndex = enemyIndex,
        targetEnemyIndices = {enemyIndex}, -- Single target
        hitPoints = {hitPoint}, -- Single hit point
        shards = {} -- Will be populated during shatter phase
      })
      
      -- Schedule multiple enemy flashes as shards hit (3 quick, separated blinks)
      local blinkDuration = 0.08 -- Very short blink duration
      -- First blink: early shards arrive (later timing)
      table.insert(scene.enemyFlashEvents, { delay = 1.25, duration = blinkDuration, enemyIndex = enemyIndex })
      table.insert(scene.enemyKnockbackEvents, { delay = 1.25, startTime = nil, enemyIndex = enemyIndex })
      -- Second blink: main group arrives
      table.insert(scene.enemyFlashEvents, { delay = 1.4, duration = blinkDuration, enemyIndex = enemyIndex })
      table.insert(scene.enemyKnockbackEvents, { delay = 1.4, startTime = nil, enemyIndex = enemyIndex })
      -- Third blink: late shards arrive
      table.insert(scene.enemyFlashEvents, { delay = 1.55, duration = blinkDuration, enemyIndex = enemyIndex })
      table.insert(scene.enemyKnockbackEvents, { delay = 1.55, startTime = nil, enemyIndex = enemyIndex })
    end
  end
end

return ImpactSystem


