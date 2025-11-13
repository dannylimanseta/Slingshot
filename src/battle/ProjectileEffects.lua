-- ProjectileEffects: Handles projectile-specific behaviors and effects
-- Extracted from GameplayScene to improve maintainability

local config = require("config")
local ProjectileManager = require("managers.ProjectileManager")

local ProjectileEffects = {}
ProjectileEffects.__index = ProjectileEffects

function ProjectileEffects.new(scene)
  return setmetatable({
    scene = scene, -- Reference to parent GameplayScene
    blackHoles = {},
    blackHoleImage = nil,
  }, ProjectileEffects)
end

function ProjectileEffects:loadAssets()
  -- Load black hole image
  local ok, img = pcall(love.graphics.newImage, "assets/images/fx/black_hole.png")
  if ok then
    self.blackHoleImage = img
  end
end

-- ============================================================================
-- PIERCE ORBS
-- ============================================================================

-- Correct pierce orb position after physics step
function ProjectileEffects:correctPiercePosition(ball)
  if not ball or not ball.pierce or not ball._piercePosition or not ball._initialDirection then
    return
  end
  
  local storedX = ball._piercePosition.x
  local storedY = ball._piercePosition.y
  local currentX = ball.body:getX()
  local currentY = ball.body:getY()
  
  -- Calculate vector from stored position to current position
  local dx = currentX - storedX
  local dy = currentY - storedY
  
  -- Project this vector onto the initial direction
  local dirX = ball._initialDirection.x
  local dirY = ball._initialDirection.y
  local dot = dx * dirX + dy * dirY
  
  -- Calculate correct position along straight path
  local correctX = storedX + dirX * dot
  local correctY = storedY + dirY * dot
  
  -- Set corrected position
  ball.body:setPosition(correctX, correctY)
  
  -- Clear correction flags
  ball._piercePosition = nil
  ball._pierceTime = nil
  ball._needsPositionCorrection = false
end

-- ============================================================================
-- LIGHTNING ORBS
-- ============================================================================

-- Update lightning sequence (handles delayed bounces)
function ProjectileEffects:updateLightningSequence(ball, dt)
  if not ball._lightningSequence then
    return
  end
  
  local seq = ball._lightningSequence
  seq.timer = seq.timer - dt
  
  if seq.timer <= 0 and seq.currentIndex <= #seq.targets then
    -- Execute next bounce
    local target = seq.targets[seq.currentIndex]
    
    -- Skip if target block was destroyed
    if not target.block or not target.block.alive then
      seq.currentIndex = seq.currentIndex + 1
      seq.timer = seq.bounceDelay
      
      if seq.currentIndex > #seq.targets then
        if ball.fixture then
          ball.fixture:setSensor(false)
        end
        ball:destroy()
      end
      return
    end
    
    -- Teleport ball
    ball.body:setPosition(target.x, target.y)
    ball.body:setLinearVelocity(0, 0)
    
    -- Add to path
    table.insert(ball._lightningPath, {
      x = target.x,
      y = target.y,
      time = love.timer.getTime()
    })
    
    -- Emit particles
    if self.scene.particles then
      self.scene.particles:emitLightningSpark(target.x, target.y)
    end
    
    -- Hit the block (with small delay for streak animation)
    if target.block and target.block.alive and not self.scene._blocksHitThisFrame[target.block] then
      self.scene._blocksHitThisFrame[target.block] = true
      -- Small delay to match lightning streak animation timing
      local lcfg = (config.ball and config.ball.lightning) or {}
      local streakAnimDuration = lcfg.streakAnimDuration or 0.18
      target.block._lightningHitDelay = streakAnimDuration * 0.5 -- Half the animation duration for subtle delay
      target.block._lightningHitPending = true
      target.block._lightningHitRewardPending = true
      if self.scene.particles then
        self.scene.particles:emitSpark(target.x, target.y)
      end
    end
    
    seq.currentIndex = seq.currentIndex + 1
    seq.timer = seq.bounceDelay
    
    if seq.currentIndex > #seq.targets then
      -- Sequence complete, destroy ball
      if ball.fixture then
        ball.fixture:setSensor(false)
      end
      ball:destroy()
    end
  end
end

-- Build lightning chain sequence on first block hit
function ProjectileEffects:buildLightningSequence(ball, startBlock)
  if not ball or not ball.lightning or not ball.alive then return end
  if not startBlock or not startBlock.cx or not startBlock.cy then return end
  
  -- Get effective stats
  local projectileData = ProjectileManager.getProjectile(ball.projectileId or "lightning")
  local effective = ProjectileManager.getEffective(projectileData)
  local maxBounces = (effective and effective.maxBounces) or 4
  
  local lightningConfig = config.ball.lightning or {}
  local jumpDistance = lightningConfig.gridJumpDistance or 3
  local bounceDelay = lightningConfig.bounceDelay or 0.4
  
  -- Grid setup
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local margin = config.playfield.margin
  local playfieldW = width - 2 * margin
  local horizontalSpacingFactor = (config.playfield and config.playfield.horizontalSpacingFactor) or 1.0
  local effectivePlayfieldW = playfieldW * horizontalSpacingFactor
  local playfieldXOffset = playfieldW * (1 - horizontalSpacingFactor) * 0.5
  local gridPadding = (config.blocks.gridSnap.padding) or 30
  local sidePadding = (config.blocks.gridSnap.sidePadding) or 40
  local gridAvailableWidth = effectivePlayfieldW - 2 * gridPadding - 2 * sidePadding
  local cellSize = (config.blocks.gridSnap.cellSize) or 38
  local numCellsX = math.floor(gridAvailableWidth / cellSize)
  local gridWidth = numCellsX * cellSize
  local gridOffsetX = sidePadding + gridPadding + (gridAvailableWidth - gridWidth) * 0.5
  local gridStartX = margin + playfieldXOffset + gridOffsetX
  local playfieldY = margin + ((config.playfield and config.playfield.topBarHeight) or 60)
  
  -- Build chain of targets
  local targets = {}
  local hitBlocks = {[startBlock] = true}
  local currentBlock = startBlock
  
  for bounce = 1, maxBounces do
    local blockGridX = math.floor((currentBlock.cx - gridStartX) / cellSize)
    local blockGridY = math.floor((currentBlock.cy - playfieldY) / cellSize)
    
    -- Try multiple search radii
    local searchRadii = {
      {min = jumpDistance - 1, max = jumpDistance + 1},
      {min = jumpDistance - 2, max = jumpDistance + 2},
      {min = 1, max = jumpDistance + 3},
    }
    
    local candidates = {}
    for _, range in ipairs(searchRadii) do
      candidates = {}
      for _, otherBlock in ipairs(self.scene.blocks.blocks or {}) do
        if otherBlock and otherBlock.alive and not hitBlocks[otherBlock] then
          local otherGridX = math.floor((otherBlock.cx - gridStartX) / cellSize)
          local otherGridY = math.floor((otherBlock.cy - playfieldY) / cellSize)
          local gridDx = math.abs(otherGridX - blockGridX)
          local gridDy = math.abs(otherGridY - blockGridY)
          local gridDist = math.max(gridDx, gridDy)
          
          if gridDist >= range.min and gridDist <= range.max then
            table.insert(candidates, otherBlock)
          end
        end
      end
      
      if #candidates > 0 then
        break
      end
    end
    
    if #candidates == 0 then
      break
    end
    
    -- Pick random target
    local targetBlock = candidates[love.math.random(#candidates)]
    hitBlocks[targetBlock] = true
    table.insert(targets, {
      x = targetBlock.cx,
      y = targetBlock.cy,
      block = targetBlock
    })
    currentBlock = targetBlock
  end
  
  if #targets == 0 then
    ball:destroy()
    return
  end
  
  -- Create sequence
  ball._lightningSequence = {
    targets = targets,
    currentIndex = 1,
    timer = bounceDelay,
    bounceDelay = bounceDelay
  }
  
  -- Stop ball and disable collisions
  ball.body:setLinearVelocity(0, 0)
  if ball.fixture then
    ball.fixture:setSensor(true)
  end
end

-- Draw lightning streaks
function ProjectileEffects:drawLightningStreaks(ballManager)
  love.graphics.push("all")
  love.graphics.setBlendMode("add")
  
  local function drawLightningStreak(x1, y1, x2, y2, alpha, seed, progress)
    progress = progress or 1.0
    
    local dx = x2 - x1
    local dy = y2 - y1
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 1 then return end
    
    local numSegments = math.max(3, math.floor(dist / 15))
    local ndx = dx / dist
    local ndy = dy / dist
    local perpX = -ndy
    local perpY = ndx
    
    local function hash(n)
      n = ((n + seed) * 1103515245 + 12345) % 2147483647
      return (n % 2000) / 2000.0
    end
    
    local points = {}
    table.insert(points, {x = x1, y = y1})
    
    for i = 1, numSegments - 1 do
      local t = i / numSegments
      if t <= progress then
        local baseX = x1 + dx * t
        local baseY = y1 + dy * t
        local offsetAmount = (hash(i) * 2 - 1) * 8
        local offsetX = perpX * offsetAmount
        local offsetY = perpY * offsetAmount
        table.insert(points, {x = baseX + offsetX, y = baseY + offsetY})
      end
    end
    
    if progress >= 1.0 then
      table.insert(points, {x = x2, y = y2})
    else
      table.insert(points, {x = x1 + dx * progress, y = y1 + dy * progress})
    end
    
    local lcfg = (config.ball and config.ball.lightning) or {}
    local layers = {
      {width = lcfg.streakOuterWidth or 12, color = {0.3, 0.7, 1.0}, alpha = (lcfg.streakOuterAlpha or 0.45) * alpha},
      {width = lcfg.streakMainWidth or 6, color = {0.5, 0.9, 1.0}, alpha = (lcfg.streakMainAlpha or 0.9) * alpha},
      {width = lcfg.streakCoreWidth or 3, color = {1.0, 1.0, 1.0}, alpha = (lcfg.streakCoreAlpha or 1.0) * alpha},
    }
    
    for _, layer in ipairs(layers) do
      for i = 1, #points - 1 do
        local segmentPos = i / (#points - 1)
        local taperFactor = 1.0 - (segmentPos * 0.85)
        local segmentWidth = layer.width * taperFactor
        
        if progress < 1.0 and i >= #points - 1 then
          segmentWidth = segmentWidth * 0.3
        end
        
        love.graphics.setColor(layer.color[1], layer.color[2], layer.color[3], layer.alpha)
        love.graphics.setLineWidth(math.max(0.5, segmentWidth))
        love.graphics.line(points[i].x, points[i].y, points[i + 1].x, points[i + 1].y)
      end
    end
  end
  
  -- Draw streaks for all balls
  local balls = {}
  if ballManager.ball then
    table.insert(balls, ballManager.ball)
  end
  if ballManager.balls then
    for _, ball in ipairs(ballManager.balls) do
      if ball then table.insert(balls, ball) end
    end
  end
  
  for _, ball in ipairs(balls) do
    if ball and ball.lightning and ball._lightningPath and #ball._lightningPath > 1 then
      local path = ball._lightningPath
      local currentTime = love.timer.getTime()
      local lcfg = (config.ball and config.ball.lightning) or {}
      local streakLifetime = lcfg.streakLifetime or 1.2
      
      for i = 1, #path - 1 do
        local streakTime = math.max(path[i].time, path[i + 1].time)
        local age = currentTime - streakTime
        
        local animDuration = lcfg.streakAnimDuration or 0.15
        local progress = 1.0
        if age < animDuration then
          progress = age / animDuration
        end
        
        if age < streakLifetime then
          local fadeAge = math.max(0, age - animDuration)
          local fadeLifetime = streakLifetime - animDuration
          local alpha = 1.0 - (fadeAge / fadeLifetime)
          alpha = math.max(0, math.min(1, alpha))
          
          local seed = (path[i].x * 1000 + path[i].y * 1000 + i) % 1000000
          drawLightningStreak(path[i].x, path[i].y, path[i + 1].x, path[i + 1].y, alpha, seed, progress)
        end
      end
    end
  end
  
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(1)
  love.graphics.pop()
end

-- ============================================================================
-- BLACK HOLE EFFECTS
-- ============================================================================

-- Update black hole effects
function ProjectileEffects:updateBlackHoles(dt)
  if not self.blackHoles or #self.blackHoles == 0 then return end
  
  local aliveEffects = {}
  local cfg = (config.gameplay and config.gameplay.blackHole) or {}
  local baseRadius = cfg.radius or 96
  local duration = cfg.duration or 1.8
  local suckSpeed = (cfg.suckSpeed or 220) * 1.2
  local swirlBase = (cfg.swirlSpeed or 240) * 1.2
  
  for _, hole in ipairs(self.blackHoles) do
    hole.t = (hole.t or 0) + dt
    hole.rotation = (hole.rotation or 0) - (math.pi * 2 * dt * 0.7)
    
    -- Scale radius based on level
    local level = hole.level or 1
    local radiusScale = (1.0 + (level - 1) * 0.125) * 0.7
    local radius = baseRadius * radiusScale
    
    -- Animate radius (open, hold, close)
    local u = math.max(0, math.min(1, (hole.t or 0) / math.max(1e-6, duration)))
    local openFrac = cfg.openFrac or 0.25
    local closeFrac = cfg.closeFrac or 0.35
    local r
    
    if u < openFrac then
      local x = u / math.max(1e-6, openFrac)
      local easeOut = 1 - (1 - x) * (1 - x)
      r = radius * easeOut
    elseif u <= 1 - closeFrac then
      r = radius
    else
      local x = (u - (1 - closeFrac)) / math.max(1e-6, closeFrac)
      local easeIn = x * x
      r = radius * (1 - easeIn)
    end
    
    hole.r = r
    
    -- Pull blocks toward black hole
    self:updateBlackHolePull(hole, r, radius, suckSpeed, swirlBase, dt)
    
    if (hole.t or 0) < duration then
      table.insert(aliveEffects, hole)
    end
  end
  
  self.blackHoles = aliveEffects
  
  -- Cleanup: destroy blocks that were pulled in but hole closed
  self:cleanupBlackHoleBlocks()
end

-- Update black hole pull effect on blocks
function ProjectileEffects:updateBlackHolePull(hole, r, radius, suckSpeed, swirlBase, dt)
  if not self.scene.blocks or not self.scene.blocks.blocks then return end
  
  for _, b in ipairs(self.scene.blocks.blocks) do
    if b and b.alive then
      local dx = hole.x - b.cx
      local dy = hole.y - b.cy
      local dist = math.sqrt(dx * dx + dy * dy)
      
      local isWithinRadius = dist <= r
      local wasBeingPulled = b._bhSpeedMul ~= nil
      
      if isWithinRadius or wasBeingPulled then
        -- Initialize block-specific properties
        if not b._bhSpeedMul then
          b._bhSpeedMul = 0.8 + love.math.random() * 0.4
          b._bhSwirlDir = (love.math.random() < 0.5) and -1 or 1
          b._bhSwirlSpeed = swirlBase * (0.8 + love.math.random() * 0.4)
          b._bhTwistSpeed = (2.0 + love.math.random() * 2.0) * b._bhSwirlDir * (0.8 + love.math.random() * 0.4)
          b._bhTwistAngle = b._bhTwistAngle or 0
          b._bhBaseTargetSize = b._bhBaseTargetSize or b.targetSize
        end
        
        local ndx = (dist > 0) and (dx / dist) or 0
        local ndy = (dist > 0) and (dy / dist) or 0
        local tdx, tdy = -ndy, ndx
        
        local effectiveRadius = isWithinRadius and r or radius
        local proximity = 1 - math.min(1, dist / math.max(1e-6, effectiveRadius))
        proximity = math.max(0, math.min(1, proximity))
        
        local easeIn = 0.3 + 0.7 * (proximity * proximity)
        local radialMove = suckSpeed * (b._bhSpeedMul or 1) * easeIn * dt
        local swirlMove = (b._bhSwirlSpeed or swirlBase) * (0.2 + 0.8 * proximity) * easeIn * dt
        
        local stepX = ndx * radialMove + tdx * swirlMove * (b._bhSwirlDir or 1)
        local stepY = ndy * radialMove + tdy * swirlMove * (b._bhSwirlDir or 1)
        
        -- Clamp step to distance
        if (stepX * stepX + stepY * stepY) > (dist * dist) then
          local sm = math.sqrt(stepX * stepX + stepY * stepY)
          if sm > 0 then
            stepX = stepX / sm * dist
            stepY = stepY / sm * dist
          end
        end
        
        b.cx = b.cx + stepX
        b.cy = b.cy + stepY
        b.pendingResize = true
        
        if b._bhTwistSpeed then
          b._bhTwistAngle = (b._bhTwistAngle or 0) + b._bhTwistSpeed * (0.4 + 0.6 * proximity) * dt
        end
        
        local t = 1 - math.min(1, dist / math.max(1e-6, effectiveRadius))
        b._bhTint = math.max(b._bhTint or 0, t)
        
        if b._bhBaseTargetSize then
          local shrink = 1 - 0.35 * (1 - math.min(1, dist / math.max(1e-6, effectiveRadius)))
          local newTarget = math.max(4, b._bhBaseTargetSize * shrink)
          if math.abs(newTarget - b.targetSize) > 0.1 then
            b.targetSize = newTarget
            b.pendingResize = true
          end
        end
        
        -- Destroy block if reached center
        if dist <= 8 then
          self:destroyBlockByBlackHole(b)
        end
      end
    end
  end
end

-- Destroy a block pulled into black hole
function ProjectileEffects:destroyBlockByBlackHole(block)
  block._suckedByBlackHole = true
  
  -- Use BattleState to track damage (ensures multipliers are counted correctly)
  local BattleState = require("core.BattleState")
  local perHit = (config.score and config.score.rewardPerHit) or 1
  local hitReward = perHit
  local kind = block.kind or "damage"
  local rewardData = { kind = kind, damage = hitReward, destroyed = false }
  
  if kind == "crit" then
    BattleState.trackDamage("crit", hitReward)
  elseif kind == "multiplier" then
    BattleState.trackDamage("multiplier", hitReward)
  elseif kind == "aoe" then
    hitReward = hitReward + 3
    rewardData.damage = hitReward
    BattleState.trackDamage("aoe", hitReward)
  elseif kind == "armor" then
    hitReward = 0
    local rewardByHp = (config.armor and config.armor.rewardByHp) or {}
    local hp = (block and block.hp) or 1
    local armorGain = rewardByHp[hp] or rewardByHp[1] or 3
    rewardData.armorGain = armorGain
    BattleState.trackDamage("armor", armorGain)
  elseif kind == "potion" then
    hitReward = 0
    local healAmount = (config.heal and config.heal.potionHeal) or 8
    rewardData.healAmount = healAmount
    BattleState.trackDamage("heal", healAmount)
  else
    BattleState.trackDamage(kind, hitReward)
  end
  
  BattleState.registerBlockHit(block, rewardData)
  
  -- Show damage number before destroying block
  if self.scene and self.scene.showDamageNumber then
    self.scene:showDamageNumber(block)
  end
  
  block:destroy()
end

-- Cleanup blocks after black hole closes
function ProjectileEffects:cleanupBlackHoleBlocks()
  if #self.blackHoles > 0 then return end
  if not self.scene.blocks or not self.scene.blocks.blocks then return end
  
  for _, b in ipairs(self.scene.blocks.blocks) do
    if b and b.alive and b._bhSpeedMul then
      self:destroyBlockByBlackHole(b)
    end
  end
end

-- Add black hole effect
function ProjectileEffects:addBlackHole(x, y, level)
  level = level or 1
  table.insert(self.blackHoles, {
    x = x,
    y = y,
    t = 0,
    r = 0,
    level = level,
    rotation = 0
  })
end

-- Draw black hole effects
function ProjectileEffects:drawBlackHoles()
  if not self.blackHoles or #self.blackHoles == 0 then return end
  
  love.graphics.push("all")
  love.graphics.setBlendMode("alpha")
  
  for _, hole in ipairs(self.blackHoles) do
    local r = hole.r or 0
    if self.blackHoleImage and r > 0 then
      love.graphics.setColor(1, 1, 1, 0.95)
      local imgW, imgH = self.blackHoleImage:getDimensions()
      local scale = (r * 2) / math.max(imgW, imgH)
      love.graphics.draw(self.blackHoleImage, hole.x, hole.y, hole.rotation or 0, scale, scale, imgW * 0.5, imgH * 0.5)
    end
  end
  
  love.graphics.pop()
  
  -- Draw tint overlay on blocks
  if self.scene.blocks and self.scene.blocks.blocks then
    love.graphics.push("all")
    love.graphics.setBlendMode("alpha")
    for _, b in ipairs(self.scene.blocks.blocks) do
      if b and b.alive and b._bhTint and b._bhTint > 0 then
        local x, y, w, h = b:getAABB()
        local expand = math.max(w, h) * 0.1
        love.graphics.setColor(0, 0, 0, math.max(0, math.min(1, b._bhTint)) * 0.9)
        love.graphics.rectangle("fill", x - expand, y - expand, w + expand * 2, h + expand * 2, 4, 4)
      end
    end
    love.graphics.pop()
  end
end

-- Update all projectile effects
function ProjectileEffects:update(dt, ballManager)
  -- Update pierce corrections
  if ballManager.ball and ballManager.ball.alive and ballManager.ball.pierce and ballManager.ball._needsPositionCorrection then
    self:correctPiercePosition(ballManager.ball)
  end
  if ballManager.balls then
    for _, ball in ipairs(ballManager.balls) do
      if ball and ball.alive and ball.pierce and ball._needsPositionCorrection then
        self:correctPiercePosition(ball)
      end
    end
  end
  
  -- Update lightning sequences
  if ballManager.ball and ballManager.ball.alive and ballManager.ball.lightning and ballManager.ball._lightningSequence then
    self:updateLightningSequence(ballManager.ball, dt)
  end
  if ballManager.balls then
    for _, ball in ipairs(ballManager.balls) do
      if ball and ball.alive and ball.lightning and ball._lightningSequence then
        self:updateLightningSequence(ball, dt)
      end
    end
  end
  
  -- Update black holes
  self:updateBlackHoles(dt)
end

-- Draw all projectile effects
function ProjectileEffects:draw(ballManager)
  self:drawBlackHoles()
  self:drawLightningStreaks(ballManager)
end

-- Cleanup
function ProjectileEffects:unload()
  self.blackHoles = {}
end

return ProjectileEffects

