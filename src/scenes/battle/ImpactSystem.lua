local config = require("config")
local SpriteAnimation = require("utils.SpriteAnimation")
local impactConfigs = require("data.impact_configs")

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

-- Create impact animations based on projectile type
-- Uses data-driven approach via impact_configs.lua
function ImpactSystem.create(scene, impactData)
  if not scene or not scene.impactAnimation then return end
  
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
  
  local blockCount = impactData.blockCount or 1
  local isCrit = impactData.isCrit or false
  local isAOE = impactData.isAOE or false
  local projectileId = impactData.projectileId or "strike"
  local behavior = impactData.behavior or impactConfigs.getBehavior(projectileId)
  
  -- Dispatch to appropriate impact type based on behavior config
  local impactType = behavior.impactType
  
  if impactType == "black_hole" then
    return ImpactSystem.createBlackHoleAttack(scene, isAOE)
  elseif impactType == "lightning_strike" then
    return ImpactSystem.createLightningAttack(scene, blockCount, isAOE)
  end
  
  -- Standard impact animation (for most projectiles)
  -- Pierce uses single impact, splinter uses 2, flurry_strikes uses 3, crit uses 5, others based on block count
  local spriteCount = (projectileId == "pierce") and 1 or (projectileId == "splinter") and 2 or (projectileId == "flurry_strikes") and 3 or (isCrit and 5 or math.min(blockCount, 4))

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
    
    if projectileId == "pierce" then
      -- Pierce impact: single image, no rotation, horizontal movement left to right
      -- Get enemy sprite width to determine start/end positions
      local enemySpriteWidth = enemy.img and (enemy.img:getWidth() * enemyScale) or (r * 2)
      local startX = hitX - enemySpriteWidth * 0.5 - 100 -- Start 100px to the left of enemy
      local endX = hitX + enemySpriteWidth * 0.5 + 100 -- End 100px to the right of enemy
      local pierceDuration = 0.3 -- Duration for pierce animation
      
      -- Load impact_1a.png for pierce (yellowish-green impact sprite)
      local pierceImagePath = "assets/images/fx/impact_1a.png"
      local pierceImage = nil
      local ok, img = pcall(love.graphics.newImage, pierceImagePath)
      if ok then pierceImage = img end
      
      -- If impact_1a.png is a sprite sheet (512x512 frames), use 9th quad like impact_1.png
      -- Otherwise use the whole image
      local pierceQuad = nil
      if pierceImage then
        local imgW, imgH = pierceImage:getWidth(), pierceImage:getHeight()
        -- Check if it's a sprite sheet (multiple frames)
        if imgW >= 2048 and imgH >= 2048 then
          -- It's a sprite sheet, use 9th quad (3rd row, 1st column, 0-indexed: row 2, col 0 = index 8)
          local frameW, frameH = 512, 512
          local col = 0 -- 9th frame is in column 0 (0-indexed)
          local row = 2 -- 9th frame is in row 2 (0-indexed, frames 1-4 row 0, 5-8 row 1, 9-12 row 2)
          pierceQuad = love.graphics.newQuad(col * frameW, row * frameH, frameW, frameH, imgW, imgH)
        end
      end
      
      -- Fallback to base image if pierce image failed to load
      if not pierceImage then
        pierceImage = baseImage
        pierceQuad = baseQuads and baseQuads[9] or nil
      end
      
      -- Random scale variation: base 1.5x with +/- 20% variation
      local baseScale = 2.0
      local scaleVariation = 0.8 + love.math.random() * 0.4 -- Random between 0.8 and 1.2
      local impactScale = baseScale * scaleVariation
      
      table.insert(scene.impactInstances, {
        isPierce = true,
        image = pierceImage, -- Use impact_1a.png for pierce
        quad = pierceQuad, -- Use quad if sprite sheet, nil if single image
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
-- Update lightning strike animations
function ImpactSystem.updateLightningStrikes(scene, dt)
  if not scene.lightningStrikes then return end
  
  local activeStrikes = {}
  for _, strike in ipairs(scene.lightningStrikes) do
    strike.timer = strike.timer + dt
    
    if strike.timer >= strike.delay then
      if not strike.active then
        strike.active = true
        strike.lifetime = 0
      end
      
      strike.lifetime = strike.lifetime + dt
      
      -- Keep strike active during its duration
      if strike.lifetime < strike.duration then
        table.insert(activeStrikes, strike)
      end
    else
      table.insert(activeStrikes, strike)
    end
  end
  
  scene.lightningStrikes = activeStrikes
end

function ImpactSystem.updateBlackHoleAttacks(scene, dt)
  if not scene or not scene.blackHoleAttacks then return end
  
  local aliveAttacks = {}
  for _, attack in ipairs(scene.blackHoleAttacks) do
    attack.t = attack.t + dt
    -- Update rotation (anti-clockwise is negative in Love2D, 30% slower)
    attack.rotation = (attack.rotation or 0) - (math.pi * 2 * dt * 0.7)
    local progress = attack.t / attack.duration
    
    -- Phase 1 (0-0.4): Open with ease-in-out
    -- Phase 2 (0.4-0.5): Hold open
    -- Phase 3 (0.5-0.65): Expand quickly before shattering
    -- Phase 4 (0.65-1.0): Shatter into triangles
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
    elseif progress < 0.65 then
      -- Expansion phase: quickly expand before shattering
      local expandT = (progress - 0.5) / 0.15
      attack.currentRadius = attack.maxRadius * (1.0 + expandT * 0.5) -- Expand 50% larger
      attack.phase = "expanding"
    elseif progress < 1.0 then
      -- Shatter phase
      attack.phase = "shatter"
      -- Keep expanded radius during shatter
      attack.currentRadius = attack.maxRadius * 1.5
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
          local rotSpeed = 0 -- No spinning, triangles just face target
          -- More varied shard sizes
          local baseSize = 4 + love.math.random() * 14 -- 4-18px
          
          -- Calculate target direction for elongation alignment
          local offsetRadius = 60 -- Medium radius for spread
          local offsetAngle = love.math.random() * math.pi * 2
          local offsetDist = love.math.random() * offsetRadius
          local targetX = enemyX + math.cos(offsetAngle) * offsetDist
          local targetY = enemyY + math.sin(offsetAngle) * offsetDist
          local targetDx = targetX - attack.x
          local targetDy = targetY - attack.y
          local targetDist = math.sqrt(targetDx * targetDx + targetDy * targetDy)
          local targetDirection = targetDist > 0.1 and math.atan2(targetDy, targetDx) or angle
          
          -- Create irregular shard shape (3 or 4 vertices for more varied shapes)
          local vertexCount = love.math.random() < 0.6 and 3 or 4 -- 60% triangular, 40% quadrilateral
          local shardVertices = {}
          -- Create pointed edge at angle 0 (pointing right), then rotate to face target
          -- Elongation along x-axis (angle 0) so pointed edge points right initially
          local elongationAngle = 0 -- Pointed edge always at angle 0 (pointing right)
          local elongationFactor = 1.2 + love.math.random() * 1.8 -- 1.2-3.0x stretch for thinner shards
          -- Generate vertices in a roughly circular pattern with lots of variation
          for v = 1, vertexCount do
            local angle = (v / vertexCount) * math.pi * 2 + (love.math.random() - 0.5) * 0.8 -- Add angle jitter
            local radius = baseSize * (0.4 + love.math.random() * 0.8) -- Vary distance from center (40-120%)
            -- Apply elongation along x-axis (angle 0) to create pointed edge pointing right
            local vx = math.cos(angle) * radius
            local vy = math.sin(angle) * radius
            -- Stretch vertices along x-axis (angle 0) to create pointed edge
            local dotProduct = vx * math.cos(elongationAngle) + vy * math.sin(elongationAngle)
            vx = vx + math.cos(elongationAngle) * dotProduct * (elongationFactor - 1)
            vy = vy + math.sin(elongationAngle) * dotProduct * (elongationFactor - 1)
            table.insert(shardVertices, vx)
            table.insert(shardVertices, vy)
          end
          -- Use already calculated target position and direction
          -- Calculate initial direction toward target for proper orientation
          local initialDx = targetX - attack.x
          local initialDy = targetY - attack.y
          local initialDist = math.sqrt(initialDx * initialDx + initialDy * initialDy)
          local initialTargetAngle = initialDist > 0.1 and math.atan2(initialDy, initialDx) or targetDirection
          -- Vary homing speed by +/- 25% so shards hit at different times
          local homingSpeedVariance = 0.75 + love.math.random() * 0.5
          -- Add random angle variation to burst for more scatter
          local angleVariation = (love.math.random() - 0.5) * 0.3 -- +/- 8.6 degrees
          local scatteredAngle = angle + angleVariation
          -- Calculate burst endpoint (control point for stronger curve)
          local burstDist = 120 + love.math.random() * 100 -- Larger burst distance 120-220px for stronger curve
          local burstEndX = attack.x + math.cos(scatteredAngle) * burstDist
          local burstEndY = attack.y + math.sin(scatteredAngle) * burstDist + 200 * 0.3 -- More downward drift for arc
          
          -- Spawn shards from random positions within the black hole radius
          local spawnAngle = love.math.random() * math.pi * 2
          local spawnDist = love.math.random() * attack.currentRadius * 0.9 -- Spawn within 90% of radius
          local shardStartX = attack.x + math.cos(spawnAngle) * spawnDist
          local shardStartY = attack.y + math.sin(spawnAngle) * spawnDist
          
          table.insert(attack.shards, {
            x = shardStartX,
            y = shardStartY,
            startX = shardStartX, -- Store start position for bezier
            startY = shardStartY,
            burstEndX = burstEndX, -- Burst endpoint (control point)
            burstEndY = burstEndY,
            vx = math.cos(scatteredAngle) * speed,
            vy = math.sin(scatteredAngle) * speed + 150,
            rotation = initialTargetAngle, -- Start facing toward target
            rotSpeed = rotSpeed,
            size = baseSize,
            alpha = 1.0,
            targetX = targetX, -- Final target (enemy position)
            targetY = targetY,
            enemyIndex = targetPos.enemyIndex, -- Store enemy index for flash triggering
            progress = 0, -- Overall progress through animation (0 to 1)
            homingSpeedMul = homingSpeedVariance,
            flashTriggered = false, -- Track if flash was triggered
            -- Irregular shard shape
            vertices = shardVertices
          })
        end
      end
      -- Update shards: two-phase animation (explosion then homing)
      local shatterProgress = (progress - 0.65) / 0.35 -- Shatter phase (0.65-1.0)
      for _, shard in ipairs(attack.shards) do
        -- Update progress based on shard's individual speed
        local progressSpeed = 1.2 * (shard.homingSpeedMul or 1)
        shard.progress = math.min(1, shard.progress + dt * progressSpeed)
        
        -- Two-phase animation:
        -- Phase 1 (0-0.3): Explode outward from black hole
        -- Phase 2 (0.3-1.0): Curve toward target enemy
        local linearProgress = shard.progress
        
        if linearProgress < 0.3 then
          -- Explosion phase: fly outward from spawn position
          local explosionT = linearProgress / 0.3
          -- Ease-out for slowing down at the end of explosion
          local easeOut = 1 - (1 - explosionT) * (1 - explosionT)
          
          -- Calculate direction away from black hole center
          local dx = shard.burstEndX - shard.startX
          local dy = shard.burstEndY - shard.startY
          
          shard.x = shard.startX + dx * easeOut
          shard.y = shard.startY + dy * easeOut
        else
          -- Homing phase: curve toward target
          local homingT = (linearProgress - 0.3) / 0.7
          -- Ease-in-cubic for acceleration toward target
          local t = homingT * homingT * homingT
          
          -- Bezier from burst endpoint to target
          local oneMinusT = 1 - t
          
          shard.x = oneMinusT * shard.burstEndX + t * shard.targetX
          shard.y = oneMinusT * shard.burstEndY + t * shard.targetY
        end
        
        -- Calculate direction toward target to orient pointed edge toward enemy
        local dx = shard.targetX - shard.x
        local dy = shard.targetY - shard.y
        local distToTarget = math.sqrt(dx * dx + dy * dy)
        if distToTarget > 0.1 then
          -- Calculate angle toward target (pointed edge faces this direction)
          -- No spinning, just face the target directly
          shard.rotation = math.atan2(dy, dx)
        end
        
        -- Trigger flash and splatter when shard gets close to enemy (70% progress)
        if not shard.flashTriggered and linearProgress >= 0.7 then
          shard.flashTriggered = true
          -- Find the enemy index for this shard's target
          local enemyIndex = shard.enemyIndex
          if enemyIndex then
            local blinkDuration = 0.08
            table.insert(scene.enemyFlashEvents, { delay = 0, duration = blinkDuration, enemyIndex = enemyIndex })
            -- No knockback for black hole - shards pull enemies in, don't push them
            
            -- Create splatter and particle effects when shard hits (only once per enemy)
            attack.splatterCreated = attack.splatterCreated or {}
            if not attack.splatterCreated[enemyIndex] then
              attack.splatterCreated[enemyIndex] = true
              local enemy = scene.enemies and scene.enemies[enemyIndex]
              if enemy and shard.targetX and shard.targetY then
                -- Get enemy sprite center for splatter
                local bounds = scene._lastBounds
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
                local spriteCenterY = baselineY - enemySpriteHeight * 0.5
                createSplatter(scene, shard.targetX, spriteCenterY)
                
                -- Emit hit burst particles at enemy position
                if scene.particles then
                  scene.particles:emitHitBurst(shard.targetX, spriteCenterY, nil, false)
                end
              end
            end
          end
        end
        
        -- If very close to target, keep last rotation (no change needed)
        -- Stay fully visible until last 10%, then fade to 0.0
        local fadeStart = 0.9 -- Start fading at 90% of shard animation
        if linearProgress < fadeStart then
          shard.alpha = 1.0 -- Fully visible
        else
          -- Fade to 0.0 in last 10%
          local fadeProgress = (linearProgress - fadeStart) / (1.0 - fadeStart)
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
  
  -- Update lightning strikes
  ImpactSystem.updateLightningStrikes(scene, dt)
  
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
-- Draw lightning strike animations
function ImpactSystem.drawLightningStrikes(scene)
  if not scene.lightningStrikes or #scene.lightningStrikes == 0 then return end
  
  love.graphics.push("all")
  love.graphics.setBlendMode("add")
  
  for _, strike in ipairs(scene.lightningStrikes) do
    if strike.active and strike.lifetime < strike.duration then
      -- Calculate animation progress
      local progress = math.min(1.0, strike.lifetime / strike.animDuration)
      
      -- Calculate fade-out alpha
      local fadeStart = strike.animDuration
      local alpha = 1.0
      if strike.lifetime > fadeStart then
        local fadeProgress = (strike.lifetime - fadeStart) / (strike.duration - fadeStart)
        alpha = 1.0 - fadeProgress
      end
      
      -- Calculate current end position (animates downward)
      local strikeHeight = strike.endY - strike.startY
      local currentEndY = strike.startY + strikeHeight * progress
      
      -- Draw lightning bolt
      local x1, y1 = strike.x, strike.startY
      local x2, y2 = strike.x, currentEndY
      
      local dx = x2 - x1
      local dy = y2 - y1
      local dist = math.sqrt(dx * dx + dy * dy)
      
      if dist > 1 then
        -- Create jagged lightning path
        local numSegments = math.max(3, math.floor(dist / 20))
        local points = {{x = x1, y = y1}}
        
        -- Simple hash for consistent randomness
        local seed = (strike.x * 1000 + strike.y * 1000) % 1000000
        local function hash(n)
          n = ((n + seed) * 1103515245 + 12345) % 2147483647
          return (n % 2000) / 2000.0
        end
        
        -- More varied jaggedness (changes per segment)
        for i = 1, numSegments - 1 do
          local t = i / numSegments
          local baseX = x1
          local baseY = y1 + dy * t
          -- Varied jaggedness: alternates between small and large offsets for more organic look
          local jagScale = 1.0 + hash(i + 100) * 0.5 -- 1.0 to 1.5x variation
          local offsetX = (hash(i) * 2 - 1) * 15 * jagScale -- 15-22.5px horizontal jaggedness
          table.insert(points, {x = baseX + offsetX, y = baseY})
        end
        
        table.insert(points, {x = x2, y = y2})
        
        -- Draw three-layer lightning with tapering and thickness variety
        local thicknessScale = strike.thicknessScale or 1.0
        for layerIdx, layerCfg in ipairs({
          {width = 22 * thicknessScale, color = {0.3, 0.7, 1.0}, alpha = 0.4}, -- Much thicker outer
          {width = 11 * thicknessScale, color = {0.6, 0.9, 1.0}, alpha = 0.8}, -- Much thicker main
          {width = 5 * thicknessScale, color = {1.0, 1.0, 1.0}, alpha = 1.0}  -- Much thicker core
        }) do
          for i = 1, #points - 1 do
            local segmentPos = i / (#points - 1)
            -- All streaks taper to thin at the end
            local taperFactor = 1.0 - (segmentPos * 0.9) -- Thick to very thin (10% remaining)
            local segmentWidth = layerCfg.width * taperFactor
            
            love.graphics.setColor(layerCfg.color[1], layerCfg.color[2], layerCfg.color[3], layerCfg.alpha * alpha)
            love.graphics.setLineWidth(math.max(0.5, segmentWidth))
            love.graphics.line(points[i].x, points[i].y, points[i + 1].x, points[i + 1].y)
          end
        end
        
        -- Bright endpoint glow (traveling tip)
        if progress < 1.0 then
          local endPoint = points[#points]
          love.graphics.setColor(1.0, 1.0, 1.0, 0.4 * alpha)
          love.graphics.circle("fill", endPoint.x, endPoint.y, 16)
          love.graphics.setColor(1.0, 1.0, 1.0, 0.7 * alpha)
          love.graphics.circle("fill", endPoint.x, endPoint.y, 10)
          love.graphics.setColor(1.0, 1.0, 1.0, alpha)
          love.graphics.circle("fill", endPoint.x, endPoint.y, 5)
        end
        
        -- Big cyan-white glow at the origin (start of lightning) - MASSIVE and dramatic
        local startPoint = points[1]
        -- Huge outer glow (soft cyan)
        love.graphics.setColor(0.3, 0.7, 1.0, 0.2 * alpha)
        love.graphics.circle("fill", startPoint.x, startPoint.y, 70)
        love.graphics.setColor(0.3, 0.7, 1.0, 0.3 * alpha)
        love.graphics.circle("fill", startPoint.x, startPoint.y, 55)
        -- Large cyan glow
        love.graphics.setColor(0.4, 0.8, 1.0, 0.4 * alpha)
        love.graphics.circle("fill", startPoint.x, startPoint.y, 42)
        love.graphics.setColor(0.5, 0.85, 1.0, 0.5 * alpha)
        love.graphics.circle("fill", startPoint.x, startPoint.y, 32)
        -- Medium bright glow (white-cyan blend)
        love.graphics.setColor(0.7, 0.9, 1.0, 0.6 * alpha)
        love.graphics.circle("fill", startPoint.x, startPoint.y, 24)
        love.graphics.setColor(0.85, 0.95, 1.0, 0.75 * alpha)
        love.graphics.circle("fill", startPoint.x, startPoint.y, 16)
        -- Bright white-cyan core
        love.graphics.setColor(0.95, 0.98, 1.0, 0.85 * alpha)
        love.graphics.circle("fill", startPoint.x, startPoint.y, 10)
        love.graphics.setColor(1.0, 1.0, 1.0, 0.95 * alpha)
        love.graphics.circle("fill", startPoint.x, startPoint.y, 6)
        -- Pure white center
        love.graphics.setColor(1.0, 1.0, 1.0, alpha)
        love.graphics.circle("fill", startPoint.x, startPoint.y, 3)
      end
    end
  end
  
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
  love.graphics.pop()
end

function ImpactSystem.drawBlackHoleAttacks(scene)
  if not scene or not scene.blackHoleAttacks then return end
  
  for _, attack in ipairs(scene.blackHoleAttacks) do
    if attack.phase == "opening" or attack.phase == "hold" or attack.phase == "expanding" then
      -- Draw black hole
      love.graphics.push("all")
      love.graphics.setBlendMode("alpha")
      local r = attack.currentRadius or 0
      if scene.blackHoleImage and r > 0 then
        -- Draw spinning black hole image
        love.graphics.setColor(1, 1, 1, 0.95)
        local imgW, imgH = scene.blackHoleImage:getDimensions()
        local scale = (r * 2) / math.max(imgW, imgH)
        love.graphics.draw(scene.blackHoleImage, attack.x, attack.y, attack.rotation or 0, scale, scale, imgW * 0.5, imgH * 0.5)
      else
        -- Fallback to circle if image not loaded
      love.graphics.setColor(0, 0, 0, 0.95)
        love.graphics.circle("fill", attack.x, attack.y, r)
      end
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
        -- Draw irregular shard shape using stored vertices
        if shard.vertices and #shard.vertices >= 6 then
          love.graphics.polygon("fill", shard.vertices)
        end
        love.graphics.pop()
      end
      love.graphics.pop()
    end
  end
end

-- Draw impact animations (additive) above sprites but below overlays
function ImpactSystem.draw(scene)
  if not scene then return end
  
  -- Draw lightning strikes first
  ImpactSystem.drawLightningStrikes(scene)
  
  -- Draw black hole attacks
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
        -- Uses impact_1a.png (no color tint needed)
        if instance.image then
          local quad = instance.quad
          if quad then
            -- Draw using quad (from sprite sheet) with scale variation
            local frameW = 512 -- Frame width from sprite sheet
            local frameH = 512 -- Frame height from sprite sheet
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
            -- Draw whole image if no quad available (single image file)
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

-- Create lightning strike attack animation
function ImpactSystem.createLightningAttack(scene, blockCount, isAOE)
  local w = (scene._lastBounds and scene._lastBounds.w) or love.graphics.getWidth()
  local h = (scene._lastBounds and scene._lastBounds.h) or love.graphics.getHeight()
  local center = scene._lastBounds and scene._lastBounds.center or nil
  local centerX = center and center.x or math.floor(w * 0.5) - math.floor((w * 0.5) * 0.5)
  local centerW = center and center.w or math.floor(w * 0.5)
  
  -- Get hit points: all enemies if AOE, otherwise just selected enemy
  local hitPoints = {}
  if isAOE and scene.getAllEnemyHitPoints then
    hitPoints = scene:getAllEnemyHitPoints({ x = 0, y = 0, w = w, h = h, center = { x = centerX, w = centerW, h = h } })
  else
    local hitX, hitY = scene:getEnemyHitPoint({ x = 0, y = 0, w = w, h = h, center = { x = centerX, w = centerW, h = h } })
    table.insert(hitPoints, { x = hitX, y = hitY, enemyIndex = scene.selectedEnemyIndex })
  end
  
  if #hitPoints == 0 then return end
  
  -- Initialize lightning strikes array
  scene.lightningStrikes = scene.lightningStrikes or {}
  scene.enemyFlashEvents = scene.enemyFlashEvents or {}
  scene.enemyKnockbackEvents = scene.enemyKnockbackEvents or {}
  
  -- Number of strikes per enemy (based on block count, more blocks = more strikes)
  local strikesPerEnemy = math.min(blockCount, 5) -- 1-5 strikes
  local baseStaggerDelay = 0.08 -- Base delay between strikes
  
  -- Create multiple lightning strikes for each enemy
  for _, hitPoint in ipairs(hitPoints) do
    local hitX = hitPoint.x
    local hitY = hitPoint.y
    local enemyIndex = hitPoint.enemyIndex
    
    for strikeIdx = 1, strikesPerEnemy do
      -- Add random variance to timing (±50% of base delay for more spread)
      local delayVariance = (love.math.random() - 0.5) * baseStaggerDelay * 1.0
      local delay = (strikeIdx - 1) * baseStaggerDelay + delayVariance
      delay = math.max(0, delay) -- Ensure non-negative
      
      -- Random horizontal offset for variety
      local offsetX = (love.math.random() - 0.5) * 40
      local strikeX = hitX + offsetX
      
      -- Random thickness variation (some strikes much thicker than others)
      local thicknessScale = 1.2 + love.math.random() * 1.3 -- 1.2 to 2.5x scale (more variety, thicker)
      
      table.insert(scene.lightningStrikes, {
        x = strikeX,
        y = hitY,
        startY = hitY - 380, -- Lightning starts 380px above enemy (80px higher)
        endY = hitY + 50, -- Extends slightly below hit point
        delay = delay,
        timer = 0,
        lifetime = 0,
        duration = 0.3, -- How long each strike lasts
        animDuration = 0.08, -- How fast lightning travels downward
        active = false,
        enemyIndex = enemyIndex,
        thicknessScale = thicknessScale -- Random thickness for variety
      })
      
      -- Schedule flash and knockback for each strike
      local flashDuration = 0.15
      table.insert(scene.enemyFlashEvents, { delay = delay, duration = flashDuration, enemyIndex = enemyIndex })
      table.insert(scene.enemyKnockbackEvents, { delay = delay, startTime = nil, enemyIndex = enemyIndex })
    end
  end
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
    
    -- Don't create splatters immediately - will be created when shards hit
    
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
    
    -- Don't schedule pre-timed flashes - let shards trigger flashes when they hit
    -- (Flash will be triggered by shard collision detection or timing in update)
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
      
      -- Don't create splatter immediately - will be created when shards hit
      
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
      
      -- Don't schedule pre-timed flashes - let shards trigger flashes when they hit
    end
  end
end

return ImpactSystem


