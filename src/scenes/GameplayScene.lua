-- GameplayScene: Coordinator for ball-shooting gameplay
-- Refactored version using manager pattern for scalability
-- This file should be < 500 lines, delegating to specialized managers

local config = require("config")
local theme = require("theme")
local BlockManager = require("managers.BlockManager")
local Shooter = require("entities.Shooter")
local ParticleManager = require("managers.ParticleManager")
local TopBar = require("ui.TopBar")
local BattleState = require("core.BattleState")
local RelicSystem = require("core.RelicSystem")

-- New managers (extracted from GameplayScene)
local PhysicsManager = require("battle.PhysicsManager")
local BallManager = require("battle.BallManager")
local ProjectileEffects = require("battle.ProjectileEffects")
local VisualEffects = require("battle.VisualEffects")
local ProjectileManager = require("managers.ProjectileManager")

local GameplayScene = {}
GameplayScene.__index = GameplayScene

function GameplayScene.new()
  return setmetatable({
    -- Managers
    physics = nil,
    ballManager = nil,
    projectileEffects = nil,
    visualEffects = nil,
    blocks = nil,
    particles = nil,
    shooter = nil,
    topBar = TopBar.new(),
    state = nil,
    -- Legacy references (for compatibility with SplitScene and other systems)
    ball = nil,
    balls = {},
    blackHoles = {},
    
    -- Turn state
    turnManager = nil,
    turnsTaken = 0,
    
    -- Combo tracking
    comboCount = 0,
    comboTimeout = 0,
    lastHitTime = 0,
    
    -- Collision tracking
    _blocksHitThisFrame = {},
    
    -- Splinter split queue (deferred until after physics step)
    splinterSplitQueue = {},
    
    -- Projectile ID
    projectileId = "strike",
    
    -- Edge hit callback (set by parent scene)
    onEdgeHit = nil,
    
    -- Puff images for armor block spawn
    puffImageLeft = nil,
    puffImageRight = nil,
    -- Track puff animations for spawning armor blocks
    armorBlockPuffs = {}, -- {block = block, puffTime = 0, ...}
  }, GameplayScene)
end

function GameplayScene:load(bounds, projectileId, battleProfile)
  local width = (bounds and bounds.w) or love.graphics.getWidth()
  local height = (bounds and bounds.h) or love.graphics.getHeight()
  
  -- Initialize managers
  self.physics = PhysicsManager.new(bounds)
  self.particles = ParticleManager.new()
  self.visualEffects = VisualEffects.new()
  self.projectileEffects = ProjectileEffects.new(self)
  
  -- Load puff images for armor block spawn
  do
    local puffRPath = "assets/images/fx/fx_puff_r.png"
    local puffLPath = "assets/images/fx/fx_puff_l.png"
    local okR, puffRImg = pcall(love.graphics.newImage, puffRPath)
    if okR then self.puffImageRight = puffRImg end
    local okL, puffLImg = pcall(love.graphics.newImage, puffLPath)
    if okL then self.puffImageLeft = puffLImg end
  end
  
  -- Load smoke image for falling blocks
  do
    local smokePath = "assets/images/fx/fx_smoke.png"
    local okSmoke, smokeImg = pcall(love.graphics.newImage, smokePath)
    if okSmoke then self.smokeImage = smokeImg end
  end
  
  -- Store reference to GameplayScene in projectile effects
  self.projectileEffects.scene = self
  -- Initialize shared battle state
  self.state = BattleState.new({ profile = battleProfile })
  BattleState.setCanShoot(true)
  BattleState.resetTurnRewards()
  BattleState.resetBlocksDestroyedThisTurn()
  self.blackHoles = self.projectileEffects.blackHoles or {}
  self.canShoot = self.state.flags.canShoot

  -- Subscribe to BattleState events
  BattleState.on("can_shoot_changed", function(val) self.canShoot = val; if self.ballManager then self.ballManager:setCanShoot(val) end end)
  BattleState.on("rewards_updated", function(rewards) 
    self.score = rewards.score
    self.displayScore = rewards.score
    self.armorThisTurn = rewards.armorThisTurn
    self.healThisTurn = rewards.healThisTurn
    self.critThisTurn = rewards.critCount
    self.multiplierThisTurn = rewards.multiplierCount
    self.aoeThisTurn = rewards.aoeFlag
    self.blockHitSequence = rewards.blockHitSequence
    self.blocksHitThisTurn = #rewards.blockHitSequence
  end)
  BattleState.on("base_damage_changed", function(val) self.baseDamageThisTurn = val end)
  BattleState.on("blocks_destroyed_reset", function() self.destroyedThisTurn = 0 end)
  BattleState.on("turn_rewards_reset", function()
    self.score = 0
    self.displayScore = 0
    self.armorThisTurn = 0
    self.healThisTurn = 0
    self.critThisTurn = 0
    self.multiplierThisTurn = 0
    self.aoeThisTurn = false
    self.blockHitSequence = {}
    self.blocksHitThisTurn = 0
    self.baseDamageThisTurn = 0
  end)

  -- Apply start-of-battle relic effects (e.g., Rally Banner +6 armor)
  do
    local RelicSystem = require("core.RelicSystem")
    if RelicSystem and RelicSystem.applyBattleStart then
      RelicSystem.applyBattleStart()
    end
  end
  
  -- Initialize blocks
  self.blocks = BlockManager.new()
  local formationConfig = (battleProfile and battleProfile.blockFormation) or nil
  self.blocks:loadFormation(self.physics:getWorld(), width, height, formationConfig)
  
  -- Hook block destroy events to particles
  for _, b in ipairs(self.blocks.blocks) do
    b.onDestroyed = function()
      if self.particles and not b._suckedByBlackHole then
        local blockColor = theme.colors.block
        if b.kind == "armor" then
          blockColor = theme.colors.blockArmor
        elseif b.kind == "crit" then
          blockColor = { 1.0, 0.85, 0.3, 1 }
        end
        self.particles:emitExplosion(b.cx, b.cy, blockColor)
      end
      BattleState.registerBlockHit(b, { destroyed = true, kind = b.kind })
      self.destroyedThisTurn = (BattleState.get().blocks.destroyedThisTurn or 0)
    end
  end
  
  -- Initialize shooter
  self.projectileId = projectileId or "strike"
  local gridStartX, gridEndX = self.physics:getGridBounds()
  local shooterX = (gridStartX + gridEndX) * 0.5
  self.shooter = Shooter.new(shooterX, height - config.shooter.spawnYFromBottom, self.projectileId)
  
  -- Initialize ball manager
  self.ballManager = BallManager.new(self.physics:getWorld(), self.shooter)
  if self.ballManager then
    self.ballManager:setCanShoot(self.canShoot)
    self.ball = self.ballManager.ball
    self.balls = self.ballManager.balls
  end
  
  -- Set collision callbacks
  self.physics.onBeginContact = function(a, b, contact) self:beginContact(a, b, contact) end
  self.physics.onPreSolve = function(a, b, contact) self:preSolve(a, b, contact) end
  self.physics.onPostSolve = function(a, b, contact) self:postSolve(a, b, contact) end
  
  -- Load assets
  self.visualEffects:loadAssets()
  self.projectileEffects:loadAssets()
  
  -- Give shooter access to TurnManager if available
  if self.shooter and self.shooter.setTurnManager and self.turnManager then
    self.shooter:setTurnManager(self.turnManager)
  end
end

function GameplayScene:update(dt, bounds)
  -- Clear blocks hit this frame
  self._blocksHitThisFrame = {}
  
  -- Update physics
  self.physics:update(dt)
  
  -- Process splinter split queue (after physics step, world is unlocked)
  if self.splinterSplitQueue and #self.splinterSplitQueue > 0 then
    for i = #self.splinterSplitQueue, 1, -1 do
      local splitData = self.splinterSplitQueue[i]
      self:_processSplinterSplit(splitData)
      table.remove(self.splinterSplitQueue, i)
    end
  end
  
  -- Update ball manager
  self.ballManager:update(dt, bounds)
  -- Ensure legacy references stay in sync (other systems read these directly)
  self.ball = self.ballManager.ball
  self.balls = self.ballManager.balls
  -- Update BattleState ball metrics
  local aliveCount = 0
  if self.ballManager.ball and self.ballManager.ball.alive then aliveCount = aliveCount + 1 end
  if self.ballManager.balls then
    for _, ball in ipairs(self.ballManager.balls) do
      if ball and ball.alive then
        aliveCount = aliveCount + 1
      end
    end
  end
  BattleState.setBallsInFlight(aliveCount)
  
  -- Update projectile effects (pierce, lightning, black hole)
  self.projectileEffects:update(dt, self.ballManager)
  self.blackHoles = self.projectileEffects.blackHoles or {}
  BattleState.setBlackHoles(self.blackHoles)
  
  -- Update armor block puff animations
  local alivePuffs = {}
  for _, puffData in ipairs(self.armorBlockPuffs or {}) do
    if puffData.block and puffData.block.alive then
      puffData.puffTime = (puffData.puffTime or 0) + dt
      if puffData.puffTime < puffData.puffDuration then
        table.insert(alivePuffs, puffData)
      end
    end
  end
  self.armorBlockPuffs = alivePuffs
  
  -- Sync canShoot state
  local state = self.state or BattleState.get()
  if state then
    self.state = state
    if self.canShoot ~= state.flags.canShoot then
      self.canShoot = state.flags.canShoot
      if self.ballManager then
        self.ballManager:setCanShoot(self.canShoot)
      end
    end
  end
  
  -- Update blocks
  if self.blocks and self.blocks.update then
    self.blocks:update(dt)
  end
  
  -- Process delayed lightning hits (timestamp-based for exact sync with streak arrival)
  if self.blocks and self.blocks.blocks then
    for _, block in ipairs(self.blocks.blocks) do
      if block and block.alive and block._lightningHitPending then
        local now = love.timer.getTime()
        local due = false
        if block._lightningHitAt then
          due = now >= block._lightningHitAt
        else
          -- Backward-compat: fall back to delay counter if present
        block._lightningHitDelay = (block._lightningHitDelay or 0) - dt
          due = block._lightningHitDelay <= 0
        end
        if due then
          block._lightningHitPending = false
          block._lightningHitDelay = nil
          block._lightningHitAt = nil
          -- Emit particles at the moment the streak visually arrives
          if self.particles and block._emitLightningParticlesOnHit then
            self.particles:emitLightningSpark(block.cx or 0, block.cy or 0)
            block._emitLightningParticlesOnHit = nil
          end
          -- Now actually hit the block
          if not block.hitThisFrame and not self._blocksHitThisFrame[block] then
            self._blocksHitThisFrame[block] = true
            block:hit()
            -- Award rewards for the delayed hit
            if block._lightningHitRewardPending then
              self:awardBlockReward(block)
              -- For lightning, show damage number for this block and update all existing ones
              self:showDamageNumber(block)
              self:updateAllDamageNumbers()
              block._lightningHitRewardPending = nil
            end
          end
        end
      end
    end
  end
  
  -- Update aim guide alpha
  local width = (bounds and bounds.w) or love.graphics.getWidth()
  local height = (bounds and bounds.h) or love.graphics.getHeight()
  local gridStartX, gridEndX = self.physics:getGridBounds()
  
  if self.shooter then
    local shooterBounds = bounds or {}
    shooterBounds.gridStartX = gridStartX
    shooterBounds.gridEndX = gridEndX
    self.shooter:update(dt, shooterBounds)
  end
  
  -- Update visual effects (screenshake, popups, tooltips, aim guide)
  self.visualEffects:update(dt, self.canShoot, self.blocks, bounds)
  
  -- Update aim guide start position from shooter
  if self.shooter then
    local sx, sy = self.shooter:getMuzzle()
    self.visualEffects:setAimStart(sx, sy)
  end
  
  -- Update particles
  if self.particles then
    self.particles:update(dt)
  end
  
  -- Update combo timeout via BattleState
  if state then
    local combo = state.player and state.player.combo
    if combo and combo.timeout > 0 then
      local newTimeout = math.max(0, combo.timeout - dt)
      local newCount = combo.count
      if newTimeout == 0 and combo.count ~= 0 then
        newCount = 0
      end
      if newTimeout ~= combo.timeout or newCount ~= combo.count then
        BattleState.updateCombo(newCount, newTimeout, combo.lastHitAt)
      end
    end
    -- Update cached reward/state values for external consumers
    self.score = state.rewards.score
    self.displayScore = state.rewards.score
    self.armorThisTurn = state.rewards.armorThisTurn
    self.healThisTurn = state.rewards.healThisTurn
    self.blocksHitThisTurn = #state.rewards.blockHitSequence
    self.critThisTurn = state.rewards.critCount
    self.multiplierThisTurn = state.rewards.multiplierCount
    self.aoeThisTurn = state.rewards.aoeFlag
    self.blockHitSequence = state.rewards.blockHitSequence
    self.baseDamageThisTurn = state.rewards.baseDamage
    self.destroyedThisTurn = state.blocks.destroyedThisTurn or 0
  end
end

function GameplayScene:draw(bounds)
  local width = (bounds and bounds.w) or love.graphics.getWidth()
  local height = (bounds and bounds.h) or love.graphics.getHeight()
  local gridStartX, gridEndX = self.physics:getGridBounds()
  
  -- Apply screenshake and draw effects
  love.graphics.push()
  self.visualEffects:applyScreenshake()
  
  -- Draw projectile effects that sit below block layer
  self.projectileEffects:drawBlackHoles()

  -- Draw blocks (lightning streaks should appear above this layer)
  self.blocks:draw()

  -- Draw puffs above blocks for spawning armor blocks (after blocks so they appear on top)
  if self.armorBlockPuffs and #self.armorBlockPuffs > 0 then
    for _, puffData in ipairs(self.armorBlockPuffs) do
      local block = puffData.block
      if block and block.alive and block.cx and block.cy then
        local progress = math.min(1, puffData.puffTime / puffData.puffDuration)
        local blockSize = block.size or (config.blocks and config.blocks.baseSize) or 32
        local scaleMul = (config.blocks and config.blocks.spriteScale) or 1
        local blockHeight = blockSize * scaleMul
        
        -- Puff position: above the block
        local puffY = block.cy - blockHeight * 0.5 - 20 -- 20px above block top
        local puffXLeft = block.cx - 30 -- Left puff offset
        local puffXRight = block.cx + 30 -- Right puff offset
        
        -- Animate puffs: fade in quickly, then fade out, move upward diagonally
        local fadeInDuration = 0.2 -- Quick fade in
        local fadeOutStart = 0.6 -- Start fading out at 60% progress
        local alpha = 1
        if progress < fadeInDuration then
          -- Fade in
          alpha = progress / fadeInDuration
        elseif progress > fadeOutStart then
          -- Fade out
          alpha = 1 - ((progress - fadeOutStart) / (1 - fadeOutStart))
        end
        
        -- Move upward diagonally
        local rise = progress * 40 -- Move up 40px over the duration
        local leftOffsetX = -progress * 20 -- Left puff moves left
        local rightOffsetX = progress * 20 -- Right puff moves right
        
        -- Draw left puff (flipped)
        if self.puffImageLeft then
          local pw, ph = self.puffImageLeft:getWidth(), self.puffImageLeft:getHeight()
          local puffScale = 0.8
          love.graphics.setColor(1, 1, 1, alpha)
          love.graphics.draw(self.puffImageLeft, 
            puffXLeft + leftOffsetX, 
            puffY - rise, 
            0, 
            -puffScale, puffScale, -- Flip horizontally
            pw * 0.5, ph * 0.5)
        end
        
        -- Draw right puff
        if self.puffImageRight then
          local pw, ph = self.puffImageRight:getWidth(), self.puffImageRight:getHeight()
          local puffScale = 0.8
          love.graphics.setColor(1, 1, 1, alpha)
          love.graphics.draw(self.puffImageRight, 
            puffXRight + rightOffsetX, 
            puffY - rise, 
            0, 
            puffScale, puffScale,
            pw * 0.5, ph * 0.5)
        end
        
        love.graphics.setColor(1, 1, 1, 1) -- Reset color
      end
    end
  end

  -- Draw smoke sprites around blocks that are falling off
  if self.smokeImage and self.blocks and self.blocks.blocks then
    love.graphics.push("all")
    love.graphics.setBlendMode("alpha")
    
    for _, block in ipairs(self.blocks.blocks) do
      if block and block.alive and block.shakeTime and block.shakeTime > 0 and block.cx and block.cy then
        local shakeDuration = 0.6 -- Match the duration from Block.lua
        local progress = 1 - (block.shakeTime / shakeDuration) -- Progress from 0 to 1
        
        -- Calculate block position with offsets (for falling animation)
        local blockX = block.cx + (block.shakeOffsetX or 0)
        local blockY = block.cy + (block.dropOffsetY or 0) + (block.shakeOffsetY or 0)
        
        -- Fade in and out: quick fade in (0-0.2), hold (0.2-0.6), fade out (0.6-1.0)
        local alpha = 1.0
        if progress < 0.2 then
          -- Fade in quickly
          alpha = progress / 0.2
        elseif progress > 0.6 then
          -- Fade out
          alpha = 1.0 - ((progress - 0.6) / 0.4)
        end
        
        -- Scale: start small, grow, then shrink slightly (but less than before)
        local baseScale = 0.5
        local maxScale = 1.0
        local scale = baseScale
        if progress < 0.5 then
          -- Grow from baseScale to maxScale
          scale = baseScale + (maxScale - baseScale) * (progress / 0.5)
        else
          -- Slightly shrink from maxScale (reduced shrinkage - only to 95% of baseScale)
          scale = maxScale - (maxScale - baseScale * 0.95) * ((progress - 0.5) / 0.5)
        end
        
        -- Draw multiple smoke puffs around the block
        local smokeImg = self.smokeImage
        local smokeW, smokeH = smokeImg:getWidth(), smokeImg:getHeight()
        local numPuffs = 4
        local spreadRadius = 25 * (0.8 + progress * 0.4) -- Expands over time
        
        for j = 1, numPuffs do
          -- Distribute puffs around the block in a circle
          local angle = (j / numPuffs) * 2 * math.pi
          -- Add slight random offset for more natural distribution
          local angleOffset = (j % 2 == 0) and 0.15 or -0.15
          local finalAngle = angle + angleOffset
          
          -- Horizontal and vertical spread
          local offsetX = math.cos(finalAngle) * spreadRadius
          local offsetY = math.sin(finalAngle) * spreadRadius * 0.6
          
          -- Slight rotation variation per puff
          local rotation = finalAngle + progress * 0.5
          
          -- Individual puff scale variation
          local puffScale = scale * (0.8 + (j % 3) * 0.1)
          
          love.graphics.setColor(1, 1, 1, alpha * 0.7) -- Slightly transparent
          love.graphics.draw(
            smokeImg,
            blockX + offsetX,
            blockY + offsetY,
            rotation,
            puffScale,
            puffScale,
            smokeW * 0.5,
            smokeH * 0.5
          )
        end
      end
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.pop()
  end

  -- Draw lightning streaks above blocks for clarity
  self.projectileEffects:drawLightningStreaks(self.ballManager)
  
  -- Draw balls
  self.ballManager:draw()
  
  -- Draw shooter
  if self.shooter then
    self.shooter:draw()
  end
  
  -- Draw particles
  if self.particles then
    self.particles:draw()
  end
  
  -- Draw visual effects (popups, damage numbers, aim guide)
  self.visualEffects:drawPopups()
  self.visualEffects:drawDamageNumbers()
  self.visualEffects:drawAimGuide(self.shooter, self.blocks, gridStartX, gridEndX, width, height)
  
  love.graphics.pop()
  
  -- Draw tooltip (outside screenshake)
  self.visualEffects:drawTooltip(bounds)
  
  -- Draw top bar
  if self.topBar and not self.disableTopBar then
    self.topBar:draw()
  end
end

-- ============================================================================
-- INPUT HANDLING
-- ============================================================================

function GameplayScene:mousepressed(x, y, button, bounds)
  if button == 1 and self.canShoot and not self.ballManager:hasAliveBalls() then
    if self.shooter then
      local sx, sy = self.shooter:getMuzzle()
      self.ballManager:startAiming(sx, sy)
      self.visualEffects:setAimStart(sx, sy)
    else
      local width = (bounds and bounds.w) or love.graphics.getWidth()
      local height = (bounds and bounds.h) or love.graphics.getHeight()
      local startY = height - config.ball.spawnYFromBottom
      local gridStartX, gridEndX = self.physics:getGridBounds()
      local startX = (gridStartX + gridEndX) * 0.5
      self.ballManager:startAiming(startX, startY)
      self.visualEffects:setAimStart(startX, startY)
    end
  end
end

function GameplayScene:mousemoved(x, y, dx, dy, bounds)
  self.visualEffects:updateCursor(x, y)
end

function GameplayScene:mousereleased(x, y, button, bounds)
  if button == 1 and self.ballManager.isAiming and self.canShoot and not self.ballManager:hasAliveBalls() then
    local dx = x - self.ballManager.aimStartX
    local dy = y - self.ballManager.aimStartY
    
    -- Get current projectile ID from shooter
    local projectileId = "strike"
    if self.shooter and self.shooter.getCurrentProjectileId then
      projectileId = self.shooter:getCurrentProjectileId()
    else
      projectileId = self.projectileId or "strike"
    end
    
    -- Reset turn state via BattleState
    BattleState.resetTurnRewards()
    BattleState.setBaseDamage(0)
    BattleState.updateCombo(0, 0, love.timer.getTime())
    BattleState.setLastProjectile(projectileId)
    
    -- Shoot projectile
    local result = self.ballManager:shoot(dx, dy, projectileId)
    if result then
      BattleState.setBaseDamage(result.baseDamage or 0)
      
      -- Spend the turn
      BattleState.setCanShoot(false)
      self.canShoot = false
    end
    
    self.ballManager:stopAiming()
  end
end

-- ============================================================================
-- COLLISION HANDLING
-- ============================================================================

function GameplayScene:preSolve(fixA, fixB, contact)
  local a = fixA and fixA:getUserData() or nil
  local b = fixB and fixB:getUserData() or nil
  
  local function getBall(x)
    return x and x.type == "ball" and x.ref or nil
  end
  local function getBlock(x)
    return x and x.type == "block" and x.ref or nil
  end
  
  local ball = getBall(a) or getBall(b)
  local block = getBlock(a) or getBlock(b)
  
  -- Pierce orbs: disable collision response (no bounce)
  if ball and block and ball.pierce then
    if not ball._piercePosition then
      ball._piercePosition = { x = ball.body:getX(), y = ball.body:getY() }
      ball._pierceTime = love.timer.getTime()
    end
    contact:setEnabled(false)
  end
  
  -- Lightning orbs: ignore collisions after first hit
  if ball and block and ball.lightning and ball._lightningHidden then
    contact:setEnabled(false)
  end
end

function GameplayScene:postSolve(fixA, fixB, contact)
  local a = fixA and fixA:getUserData() or nil
  local b = fixB and fixB:getUserData() or nil
  
  local function getBall(x)
    return x and x.type == "ball" and x.ref or nil
  end
  local function getBlock(x)
    return x and x.type == "block" and x.ref or nil
  end
  
  local ball = getBall(a) or getBall(b)
  local block = getBlock(a) or getBlock(b)
  
  -- Mark pierce orb for position correction
  if ball and block and ball.pierce and ball._piercePosition and ball._initialDirection then
    ball._needsPositionCorrection = true
  end
end

function GameplayScene:beginContact(fixA, fixB, contact)
  local a = fixA and fixA:getUserData() or nil
  local b = fixB and fixB:getUserData() or nil
  
  local function types(x)
    return x and x.type or nil
  end
  local function getBall(x)
    return x and x.type == "ball" and x.ref or nil
  end
  local function getBlock(x)
    return x and x.type == "block" and x.ref or nil
  end
  
  local aType, bType = types(a), types(b)
  local ball = getBall(a) or getBall(b)
  local block = getBlock(a) or getBlock(b)
  
  -- Ball vs Wall
  if ball and (aType == "wall" or bType == "wall") then
    self:handleBallWallCollision(ball, a, b, aType, bType, contact)
  end
  
  -- Ball vs Block
  if ball and block then
    self:handleBallBlockCollision(ball, block, contact)
  end
  
  -- Ball vs Bottom Sensor
  if ball and (aType == "bottom" or bType == "bottom") then
    ball:destroy()
  end
end

-- Handle ball-wall collision
function GameplayScene:handleBallWallCollision(ball, a, b, aType, bType, contact)
  local wallData = (aType == "wall" and a) or (bType == "wall" and b)
  
  if ball.pierce then
    -- Pierce orbs: destroy immediately when hitting any edge/wall
    ball:destroy()
  else
    -- Regular orbs: bounce
    ball:onBounce()
    
    -- Trigger edge glow effect
    if wallData and wallData.side and self.onEdgeHit then
      local x, y = contact:getPositions()
      local bounceY = y or -200
      pcall(function() self.onEdgeHit(wallData.side, bounceY) end)
    end
  end
end

-- Handle ball-block collision
function GameplayScene:handleBallBlockCollision(ball, block, contact)
  -- Lightning orbs: only process first collision
  if ball.lightning then
    if ball._lightningFirstHit then
      return
    else
      ball._lightningFirstHit = true
    end
  end
  
  -- Early exit: block already hit or destroyed
  if not block.alive or block.hitThisFrame or self._blocksHitThisFrame[block] then
    if not ball.pierce and not ball.lightning then
      ball:onBounce()
    end
    return
  end
  
  -- Pierce orbs: store position before hit
  if ball.pierce and not ball._piercePosition then
    ball._piercePosition = { x = ball.body:getX(), y = ball.body:getY() }
  end
  
  -- Mark block as hit
  self._blocksHitThisFrame[block] = true
  
  -- Spore blocks destroy the orb when hit
  if block.kind == "spore" then
    -- Emit purple circular burst at hit point
    local hx, hy = contact and contact:getPositions()
    local px = hx or block.cx
    local py = hy or block.cy
    if self.particles and px and py then
      -- Purple color
      self.particles:emitHitBurst(px, py, {0.75, 0.45, 1.0})
    end
    -- Destroy the ball/orb immediately
    if ball and ball.destroy then
      ball:destroy()
    end
    -- Still process the block hit (destroy the spore block)
    block:hit()
    -- Don't award rewards for spore blocks
    return
  end
  
  -- For lightning, schedule hit exactly when the streak visually reaches the block
  local lightningFirstHit = false
  if ball.lightning and ball.alive and not ball._lightningHidden then
    lightningFirstHit = true
    -- Timestamp-based scheduling to match streak animation timing precisely
    local lcfg = config.ball.lightning or {}
    local streakAnimDuration = lcfg.streakAnimDuration or 0.18
    local now = love.timer.getTime()
    block._lightningHitAt = now + streakAnimDuration -- fire when streak arrives
    block._lightningHitPending = true
    block._lightningHitRewardPending = true -- Mark first block for reward when delayed hit processes
  else
    block:hit()
  end
  
  -- Combo tracking via BattleState
  local currentTime = love.timer.getTime()
  local comboWindow = (config.gameplay and config.gameplay.comboWindow) or 0.5
  local comboCount = 1
  local comboState = self.state and self.state.player and self.state.player.combo
  if comboState and currentTime - (comboState.lastHitAt or 0) < comboWindow then
    comboCount = (comboState.count or 0) + 1
  else
    comboCount = 1
  end
  BattleState.updateCombo(comboCount, comboWindow, currentTime)
  
  -- Trigger screenshake for combos
  if comboCount >= 2 then
    local comboShake = config.gameplay and config.gameplay.comboShake or {}
    local baseMag = comboShake.baseMagnitude or 2
    local scalePerCombo = comboShake.scalePerCombo or 0.5
    local maxMagnitude = comboShake.maxMagnitude or 8
    local duration = comboShake.duration or 0.15
    local magnitude = math.min(maxMagnitude, baseMag + (comboCount - 2) * scalePerCombo)
    self.visualEffects:triggerShake(magnitude, duration)
  end
  
  -- Emit particles
  local x, y = contact:getPositions()
  if x and y and self.particles then
    self.particles:emitSpark(x, y)
  end
  ball:onBlockHit()
  
  -- Projectile-specific behavior
  local destroyBallAfter = false
  
  if ball.projectileId == "black_hole" and not ball._blackHoleTriggered then
    -- Black hole: spawn effect on first hit
    ball._blackHoleTriggered = true
    local hx = x or (ball.body and select(1, ball.body:getPosition())) or block.cx
    local hy = y or (ball.body and select(2, ball.body:getPosition())) or block.cy
    local level = ball.projectileLevel or 1
    self.projectileEffects:addBlackHole(hx, hy, level)
    destroyBallAfter = true
  elseif ball.lightning and ball.alive and not ball._lightningHidden then
    -- Lightning: build chain sequence
    ball.body:setLinearVelocity(0, 0)
    ball._lightningHidden = true
    ball._lightningPath = {}
    
    local blockX = block.cx or (x or 0)
    local blockY = block.cy or (y or 0)
    
    table.insert(ball._lightningPath, {
      x = blockX,
      y = blockY,
      time = love.timer.getTime()
    })
    
    if self.particles then
      self.particles:emitLightningSpark(blockX, blockY)
    end
    
    self.projectileEffects:buildLightningSequence(ball, block)
    
    if ball.fixture then
      ball.fixture:setSensor(true)
    end
    -- Don't award rewards immediately for lightning first hit - will be awarded when delayed hit processes
  elseif ball.pierce then
    -- Pierce: pass through
    ball:onPierce()
  elseif ball.projectileId == "splinter" and not ball._splinterSplit then
    -- Splinter: queue split to happen after physics step (world is locked during collision)
    ball._splinterSplit = true
    local hx = x or (ball.body and select(1, ball.body:getPosition())) or block.cx
    local hy = y or (ball.body and select(2, ball.body:getPosition())) or block.cy
    
    -- Get current velocity direction
    local vx, vy = ball.body:getLinearVelocity()
    local speed = math.sqrt(vx * vx + vy * vy)
    if speed == 0 then
      -- Fallback: use direction from ball to block
      local dx = (block.cx or hx) - hx
      local dy = (block.cy or hy) - hy
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist > 0 then
        vx = (dx / dist) * (config.ball.speed or 400)
        vy = (dy / dist) * (config.ball.speed or 400)
      else
        vx, vy = 1, 0
      end
    end
    
    -- Queue the split to process after physics step
    table.insert(self.splinterSplitQueue, {
      ball = ball,
      x = hx,
      y = hy,
      vx = vx,
      vy = vy
    })
    
    -- Destroy the original ball after split
    destroyBallAfter = true
  elseif not ball.lightning then
    -- Regular: bounce
    ball:onBounce()
  end
  
  -- Award rewards (skip for lightning hits - handled in delayed hit processing)
  if not lightningFirstHit then
    self:awardBlockReward(block)
    -- Show damage number with latest damage tally
    self:showDamageNumber(block)
  end
  
  if destroyBallAfter and ball and ball.alive then
    ball:destroy()
  end
end

-- Process splinter split (called after physics step when world is unlocked)
function GameplayScene:_processSplinterSplit(splitData)
  if not splitData or not splitData.ball then return end
  
  local ball = splitData.ball
  local hx = splitData.x
  local hy = splitData.y
  local vx = splitData.vx
  local vy = splitData.vy
  
  -- Calculate split angles (60 degrees spread for more divergent paths)
  local baseAngle = math.atan2(vy, vx)
  local spreadAngle = math.rad(90)
  local angle1 = baseAngle - spreadAngle * 0.5
  local angle2 = baseAngle + spreadAngle * 0.5
  
  local dirX1 = math.cos(angle1)
  local dirY1 = math.sin(angle1)
  local dirX2 = math.cos(angle2)
  local dirY2 = math.sin(angle2)
  
  -- Get projectile data for the split orbs
  local projectileData = ProjectileManager.getProjectile("splinter")
  local effective = projectileData and ProjectileManager.getEffective(projectileData) or {}
  local spritePath = projectileData and projectileData.icon or nil
  local maxBounces = (effective and effective.maxBounces) or 5
  local splitDamage = (effective and effective.baseDamage) or (ball.score or 3)
  
  -- Spawn two new balls
  local Ball = require("entities.Ball")
  if not self.ballManager.balls then
    self.ballManager.balls = {}
  end
  
  local world = self.physics:getWorld()
  local ball1 = Ball.new(world, hx, hy, dirX1, dirY1, {
    radius = config.ball.radius,
    maxBounces = maxBounces,
    spritePath = spritePath,
    onLastBounce = function(ball) ball:destroy() end
  })
  if ball1 then
    ball1.projectileId = "splinter"
    ball1.score = splitDamage
    ball1._splinterSplit = true -- Mark as already split so they don't split again
    table.insert(self.ballManager.balls, ball1)
  end
  
  local ball2 = Ball.new(world, hx, hy, dirX2, dirY2, {
    radius = config.ball.radius,
    maxBounces = maxBounces,
    spritePath = spritePath,
    onLastBounce = function(ball) ball:destroy() end
  })
  if ball2 then
    ball2.projectileId = "splinter"
    ball2.score = splitDamage
    ball2._splinterSplit = true -- Mark as already split so they don't split again
    table.insert(self.ballManager.balls, ball2)
  end
end

-- Award rewards for hitting a block
function GameplayScene:awardBlockReward(block)
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
    local baseArmor = rewardByHp[hp] or rewardByHp[1] or 3
    local armorGain = RelicSystem.applyArmorReward(baseArmor, {
      hp = hp,
      block = block,
      scene = self,
    })
    armorGain = math.floor(armorGain + 0.5)
    rewardData.armorGain = armorGain
    rewardData.baseArmorGain = baseArmor
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
end

-- Calculate final damage (shared logic for showDamageNumber and updateAllDamageNumbers)
function GameplayScene:calculateFinalDamage()
  local state = self.state or BattleState.get()
  if not state or not state.rewards then return 0 end
  
  local blockHitSequence = state.rewards.blockHitSequence or {}
  local orbBaseDamage = state.rewards.baseDamage or 0
  
  -- Calculate cumulative damage (excluding crit/multiplier/armor/potion blocks from base)
  -- Match the exact calculation used for final damage in SplitScene
  local baseDamage = orbBaseDamage
  for _, hit in ipairs(blockHitSequence) do
    local kind = (type(hit) == "table" and hit.kind) or "damage"
    local amount = (type(hit) == "table" and (hit.damage or hit.amount)) or 0
    -- Only add damage from blocks that contribute to damage (exclude crit, multiplier, armor, potion)
    if kind ~= "crit" and kind ~= "multiplier" and kind ~= "armor" and kind ~= "heal" and kind ~= "potion" then
      baseDamage = baseDamage + amount
    end
  end
  
  -- Apply multipliers to match final damage calculation (same as SplitScene)
  local critCount = state.rewards.critCount or 0
  local multiplierCount = state.rewards.multiplierCount or 0
  local finalDamage = baseDamage
  
  -- Apply crit multiplier (2x per crit)
  if critCount > 0 then
    local mult = (config.score and config.score.critMultiplier) or 2
    finalDamage = finalDamage * (mult ^ critCount)
  end
  
  -- Apply damage multiplier once if any multiplier block was hit
  if multiplierCount > 0 then
    local dmgMult = (config.score and config.score.powerCritMultiplier) or 4
    finalDamage = finalDamage * dmgMult
  end
  
  return finalDamage
end

-- Show damage number above block with latest damage tally
function GameplayScene:showDamageNumber(block)
  if not self.visualEffects or not block then return end
  local finalDamage = self:calculateFinalDamage()
  -- Show final damage number (with multipliers applied) to match what's shown above enemy
  self.visualEffects:addDamageNumber(block, finalDamage)
end

-- Update all existing damage numbers (useful for lightning attacks where multiple blocks are hit sequentially)
function GameplayScene:updateAllDamageNumbers()
  if not self.visualEffects then return end
  local finalDamage = self:calculateFinalDamage()
  
  -- Update all existing damage numbers with the latest cumulative damage
  for block, _ in pairs(self.visualEffects.damageNumbers or {}) do
    if block and block.alive then
      self.visualEffects:addDamageNumber(block, finalDamage)
    end
  end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

-- Respawn blocks based on destroyed count
function GameplayScene:respawnDestroyedBlocks(bounds, count)
  if not (self.blocks and self.blocks.addRandomBlocks) then return end
  
  local width = (bounds and bounds.w) or love.graphics.getWidth()
  local height = (bounds and bounds.h) or love.graphics.getHeight()
  
  local availableSpaces = 0
  if self.blocks.countAvailableSpaces then
    availableSpaces = self.blocks:countAvailableSpaces(width, height)
  end
  
  if availableSpaces <= 0 then return end
  
  local destroyed = tonumber(count or 0) or 0
  if destroyed <= 0 then return end
  
  local desiredSpawn
  if destroyed <= 2 then
    desiredSpawn = 1
  else
    desiredSpawn = love.math.random(1, 2)
  end
  
  local toSpawn = math.min(desiredSpawn, availableSpaces)
  if toSpawn <= 0 then return end
  
  local newBlocks = self.blocks:addRandomBlocks(self.physics:getWorld(), width, height, toSpawn)
  for _, nb in ipairs(newBlocks) do
    nb.onDestroyed = function()
      if self.particles and not nb._suckedByBlackHole then
        local blockColor = theme.colors.block
        if nb.kind == "armor" then
          blockColor = theme.colors.blockArmor
        elseif nb.kind == "crit" then
          blockColor = { 1.0, 0.85, 0.3, 1 }
        end
        self.particles:emitExplosion(nb.cx, nb.cy, blockColor)
      end
      BattleState.registerBlockHit(nb, { destroyed = true, kind = nb.kind })
      self.destroyedThisTurn = BattleState.get().blocks.destroyedThisTurn or 0
    end
  end
  BattleState.resetBlocksDestroyedThisTurn()
  self.destroyedThisTurn = 0
end

-- Spawn a specific number of armor blocks at random positions on the board
-- Used by enemy skills (e.g., Deranged Boar's Charge)
function GameplayScene:spawnArmorBlocks(bounds, count)
  if not (self.blocks and self.blocks.addRandomBlocks) then return end
  count = count or 0
  if count <= 0 then return end
  
  local width = (bounds and bounds.w) or love.graphics.getWidth()
  local height = (bounds and bounds.h) or love.graphics.getHeight()
  
  -- Request more blocks than needed since some may be filtered out due to collisions
  -- This accounts for blocks that might overlap with existing blocks after positioning
  local requestedCount = math.max(count, count * 2) -- Request 2x to account for filtering
  
  -- Spawn blocks in the full area - BlockManager will handle margin
  -- We'll filter out blocks that are too close to edges or overlap existing blocks
  local newBlocks = self.blocks:addRandomBlocks(self.physics:getWorld(), width, height, requestedCount)
  
  -- Immediately set all spawned blocks to armor type before filtering
  for _, block in ipairs(newBlocks) do
    if block then
      block.kind = "armor"
    end
  end
  
  -- Helper function to check if a block overlaps with existing blocks
  local function checkBlockOverlap(block, allBlocks)
    if not block or not block.cx or not block.cy then return false end
    
    local pad = (config.blocks and config.blocks.minGap) or 0
    local scaleMul = math.max(1, (config.blocks and config.blocks.spriteScale) or 1)
    local size = config.blocks.baseSize
    local visSize = size * scaleMul
    local halfVis = visSize * 0.5
    
    local blockX = block.cx - halfVis
    local blockY = block.cy - halfVis
    
    for _, otherBlock in ipairs(allBlocks) do
      if otherBlock ~= block and otherBlock and otherBlock.alive then
        local bx, by, bw, bh
        if type(otherBlock.getPlacementAABB) == "function" then
          bx, by, bw, bh = otherBlock:getPlacementAABB()
        end
        if type(bx) ~= "number" or type(by) ~= "number" or type(bw) ~= "number" or type(bh) ~= "number" then
          if type(otherBlock.getAABB) == "function" then
            bx, by, bw, bh = otherBlock:getAABB()
          end
        end
        if type(bx) == "number" and type(by) == "number" and type(bw) == "number" and type(bh) == "number" then
          -- Check expanded overlap (with padding)
          if blockX < bx + bw + pad and bx - pad < blockX + visSize and
             blockY < by + bh + pad and by - pad < blockY + visSize then
            return true -- Overlap detected
          end
        end
      end
    end
    return false
  end
  
  -- Get all existing blocks for collision checking
  local allBlocks = {}
  if self.blocks and self.blocks.blocks then
    for _, b in ipairs(self.blocks.blocks) do
      if b and b.alive then
        table.insert(allBlocks, b)
      end
    end
  end
  
  -- Filter blocks: remove ones too close to edges or overlapping with existing blocks
  local edgeBuffer = 50 -- Minimum distance from edges
  local validBlocks = {}
  for _, block in ipairs(newBlocks) do
    if block and block.cx and block.cy then
      -- Check if block is too close to edges
      local tooCloseToEdge = 
        block.cx < edgeBuffer or block.cx > width - edgeBuffer or
        block.cy < edgeBuffer or block.cy > height - edgeBuffer
      
      -- Check if block overlaps with existing blocks
      local overlaps = checkBlockOverlap(block, allBlocks)
      
      if not tooCloseToEdge and not overlaps then
        -- Block is valid: far enough from edges and no overlap
        if block.rebuildFixture then
          block:rebuildFixture()
        end
        table.insert(validBlocks, block)
        table.insert(allBlocks, block) -- Add to allBlocks for subsequent checks
        
        -- Stop once we have enough valid blocks
        if #validBlocks >= count then
          break
        end
      else
        -- Block is invalid: too close to edge or overlaps, remove it
        if block.body then
          block.body:destroy()
        end
        block.alive = false
        -- Remove from BlockManager's blocks list
        if self.blocks and self.blocks.blocks then
          for i, b in ipairs(self.blocks.blocks) do
            if b == block then
              table.remove(self.blocks.blocks, i)
              break
            end
          end
        end
      end
    end
  end
  
  -- Update newBlocks to only include valid (non-overlapping) blocks
  newBlocks = validBlocks
  
  -- Add staggered spawn delays and puff animations
  local staggerDelay = 0.2 -- Delay between each block spawn (in seconds) - increased for more noticeable stagger
  for i, nb in ipairs(newBlocks) do
    -- Force these blocks to be armor blocks
    nb.kind = "armor"
    
    -- Enable spawn animation with staggered delay
    nb.spawnAnimating = true
    nb.spawnAnimT = 0
    nb.spawnAnimDelay = (i - 1) * staggerDelay -- Each block spawns 0.1s after the previous
    nb.spawnAnimDuration = (config.blocks and config.blocks.spawnAnim and config.blocks.spawnAnim.duration) or 0.35
    -- Set fixture to sensor during spawn animation (blocks can't be hit until fully spawned)
    if nb.fixture then
      nb.fixture:setSensor(true)
    end
    
    -- Add puff animation tracking
    table.insert(self.armorBlockPuffs, {
      block = nb,
      puffTime = 0,
      puffDuration = nb.spawnAnimDelay + nb.spawnAnimDuration, -- Puff lasts for spawn delay + animation
    })
    
    nb.onDestroyed = function()
      if self.particles and not nb._suckedByBlackHole then
        local blockColor = theme.colors.blockArmor
        self.particles:emitExplosion(nb.cx, nb.cy, blockColor)
      end
      BattleState.registerBlockHit(nb, { destroyed = true, kind = nb.kind })
      self.destroyedThisTurn = BattleState.get().blocks.destroyedThisTurn or 0
      
      -- Remove puff tracking when block is destroyed
      for j, puffData in ipairs(self.armorBlockPuffs) do
        if puffData.block == nb then
          table.remove(self.armorBlockPuffs, j)
          break
        end
      end
    end
  end
end

-- Spawn spore blocks (Spore Caller ability)
function GameplayScene:spawnSporeBlocks(bounds, count)
  if not (self.blocks and self.blocks.addRandomBlocks) then return end
  count = count or 0
  if count <= 0 then return end
  
  local width = (bounds and bounds.w) or love.graphics.getWidth()
  local height = (bounds and bounds.h) or love.graphics.getHeight()
  
  -- Request more blocks than needed since some may be filtered out due to collisions
  local requestedCount = math.max(count, count * 2)
  
  -- Spawn blocks in the full area - BlockManager will handle margin
  local newBlocks = self.blocks:addRandomBlocks(self.physics:getWorld(), width, height, requestedCount)
  
  -- Immediately set all spawned blocks to spore type before filtering
  for _, block in ipairs(newBlocks) do
    if block then
      block.kind = "spore"
    end
  end
  
  -- Helper function to check if a block overlaps with existing blocks
  local function checkBlockOverlap(block, allBlocks)
    if not block or not block.cx or not block.cy then return false end
    
    local pad = (config.blocks and config.blocks.minGap) or 0
    local scaleMul = math.max(1, (config.blocks and config.blocks.spriteScale) or 1)
    local size = config.blocks.baseSize
    local visSize = size * scaleMul
    local halfVis = visSize * 0.5
    
    local blockX = block.cx - halfVis
    local blockY = block.cy - halfVis
    
    for _, otherBlock in ipairs(allBlocks) do
      if otherBlock ~= block and otherBlock and otherBlock.alive then
        local bx, by, bw, bh
        if type(otherBlock.getPlacementAABB) == "function" then
          bx, by, bw, bh = otherBlock:getPlacementAABB()
        end
        if type(bx) ~= "number" or type(by) ~= "number" or type(bw) ~= "number" or type(bh) ~= "number" then
          if type(otherBlock.getAABB) == "function" then
            bx, by, bw, bh = otherBlock:getAABB()
          end
        end
        if type(bx) == "number" and type(by) == "number" and type(bw) == "number" and type(bh) == "number" then
          -- Check expanded overlap (with padding)
          if blockX < bx + bw + pad and bx - pad < blockX + visSize and
             blockY < by + bh + pad and by - pad < blockY + visSize then
            return true -- Overlap detected
          end
        end
      end
    end
    return false
  end
  
  -- Get all existing blocks for collision checking
  local allBlocks = {}
  if self.blocks and self.blocks.blocks then
    for _, b in ipairs(self.blocks.blocks) do
      if b and b.alive then
        table.insert(allBlocks, b)
      end
    end
  end
  
  -- Filter blocks: remove ones too close to edges or overlapping with existing blocks
  local edgeBuffer = 50 -- Minimum distance from edges
  local validBlocks = {}
  for _, block in ipairs(newBlocks) do
    if block and block.cx and block.cy then
      -- Check if block is too close to edges
      local tooCloseToEdge = 
        block.cx < edgeBuffer or block.cx > width - edgeBuffer or
        block.cy < edgeBuffer or block.cy > height - edgeBuffer
      
      -- Check if block overlaps with existing blocks
      local overlaps = checkBlockOverlap(block, allBlocks)
      
      if not tooCloseToEdge and not overlaps then
        -- Block is valid: far enough from edges and no overlap
        if block.rebuildFixture then
          block:rebuildFixture()
        end
        table.insert(validBlocks, block)
        table.insert(allBlocks, block) -- Add to allBlocks for subsequent checks
        
        -- Stop once we have enough valid blocks
        if #validBlocks >= count then
          break
        end
      else
        -- Block is invalid: too close to edge or overlaps, remove it
        if block.body then
          block.body:destroy()
        end
        block.alive = false
        -- Remove from BlockManager's blocks list
        if self.blocks and self.blocks.blocks then
          for i, b in ipairs(self.blocks.blocks) do
            if b == block then
              table.remove(self.blocks.blocks, i)
              break
            end
          end
        end
      end
    end
  end
  
  -- Update newBlocks to only include valid (non-overlapping) blocks
  newBlocks = validBlocks
  
  -- Add staggered spawn delays
  local staggerDelay = 0.2 -- Delay between each block spawn
  for i, nb in ipairs(newBlocks) do
    -- Force these blocks to be spore blocks
    nb.kind = "spore"
    
    -- Enable spawn animation with staggered delay
    nb.spawnAnimating = true
    nb.spawnAnimT = 0
    nb.spawnAnimDelay = (i - 1) * staggerDelay
    nb.spawnAnimDuration = (config.blocks and config.blocks.spawnAnim and config.blocks.spawnAnim.duration) or 0.35
    -- Set fixture to sensor during spawn animation (blocks can't be hit until fully spawned)
    if nb.fixture then
      nb.fixture:setSensor(true)
    end
    
    nb.onDestroyed = function()
      if self.particles and not nb._suckedByBlackHole then
        local blockColor = {0.5, 0.8, 0.3, 1} -- Green/purple spore color
        self.particles:emitExplosion(nb.cx, nb.cy, blockColor)
      end
      BattleState.registerBlockHit(nb, { destroyed = true, kind = nb.kind })
      self.destroyedThisTurn = BattleState.get().blocks.destroyedThisTurn or 0
    end
  end
end

-- Compute candidate positions for spore block spawning (no creation)
function GameplayScene:getSporeSpawnPositions(count)
  count = count or 0
  if count <= 0 then return {} end
  if not (self.blocks and self.blocks.addRandomBlocks) then return {} end
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local requestedCount = math.max(count, count * 2)
  local tempBlocks = self.blocks:addRandomBlocks(self.physics:getWorld(), width, height, requestedCount)
  
  -- Helper to test overlap
  local function getAABB(block)
    if type(block.getPlacementAABB) == "function" then
      return block:getPlacementAABB()
    end
    return block:getAABB()
  end
  local function overlaps(block, others)
    local pad = (config.blocks and config.blocks.minGap) or 0
    local bx, by, bw, bh = getAABB(block)
    for _, ob in ipairs(others) do
      if ob ~= block and ob.alive then
        local ox, oy, ow, oh = getAABB(ob)
        if bx < ox + ow + pad and ox - pad < bx + bw and
           by < oy + oh + pad and oy - pad < by + bh then
          return true
        end
      end
    end
    return false
  end
  
  -- Existing blocks
  local existing = {}
  if self.blocks and self.blocks.blocks then
    for _, b in ipairs(self.blocks.blocks) do
      if b and b.alive then table.insert(existing, b) end
    end
  end
  
  local edgeBuffer = 50
  local positions = {}
  for _, b in ipairs(tempBlocks) do
    if b and b.cx and b.cy then
      local tooEdge = (b.cx < edgeBuffer or b.cx > width - edgeBuffer or b.cy < edgeBuffer or b.cy > height - edgeBuffer)
      if not tooEdge and not overlaps(b, existing) then
        table.insert(positions, { x = b.cx, y = b.cy })
        table.insert(existing, b) -- reserve space
        if #positions >= count then break end
      end
    end
  end
  
  -- Cleanup temp blocks
  for _, b in ipairs(tempBlocks) do
    if b and b.body then pcall(function() b.body:destroy() end) end
    b.alive = false
  end
  -- Remove any references to temp blocks from manager list
  if self.blocks and self.blocks.blocks then
    local remaining = {}
    for _, b in ipairs(self.blocks.blocks) do
      if b and b.alive then table.insert(remaining, b) end
    end
    self.blocks.blocks = remaining
  end
  return positions
end

-- Spawn a single spore block at exact coordinates
function GameplayScene:spawnSporeBlockAt(x, y)
  if not (self.blocks and self.blocks.blocks and self.physics and self.physics.getWorld) then return end
  local world = self.physics:getWorld()
  local Block = require("entities.Block")
  local block = Block.new(world, x, y, 1, "spore", { animateSpawn = true, spawnDelay = 0 })
  block.spawnAnimating = true
  block.spawnAnimT = 0
  block.spawnAnimDelay = 0
  block.spawnAnimDuration = (config.blocks and config.blocks.spawnAnim and config.blocks.spawnAnim.duration) or 0.35
  if block.fixture then block.fixture:setSensor(true) end
  table.insert(self.blocks.blocks, block)
end

-- Set projectile ID
function GameplayScene:setProjectile(projectileId)
  self.projectileId = projectileId or "strike"
  if self.shooter and self.shooter.setProjectile then
    self.shooter:setProjectile(self.projectileId)
  end
end

-- Update walls when canvas width changes
function GameplayScene:updateWalls(newWidth, newHeight)
  self.physics:updateWalls(newWidth, newHeight)
  
  -- Update shooter position
  local gridStartX, gridEndX = self.physics:getGridBounds()
  if self.shooter then
    self.shooter.x = (gridStartX + gridEndX) * 0.5
  end
end

-- Set TurnManager reference
function GameplayScene:setTurnManager(turnManager)
  self.turnManager = turnManager
  if self.shooter and self.shooter.setTurnManager then
    self.shooter:setTurnManager(turnManager)
  end
end

-- Reload blocks from battle profile
function GameplayScene:reloadBlocks(battleProfile, bounds)
  if not self.blocks or not self.physics then return end
  
  self.blocks:clearAll()
  
  local width = (bounds and bounds.w) or love.graphics.getWidth()
  local height = (bounds and bounds.h) or love.graphics.getHeight()
  
  local formationConfig = (battleProfile and battleProfile.blockFormation) or nil
  self.blocks:loadFormation(self.physics:getWorld(), width, height, formationConfig)
end

-- Trigger block shake and drop (enemy shockwave)
function GameplayScene:triggerBlockShakeAndDrop()
  if not self.blocks or not self.blocks.blocks then return end
  
  local aliveBlocks = {}
  for _, block in ipairs(self.blocks.blocks) do
    if block and block.alive then
      table.insert(aliveBlocks, block)
    end
  end
  
  if #aliveBlocks == 0 then return end
  
  local count = 3
  count = math.min(count, #aliveBlocks)
  
  local indices = {}
  for i = 1, #aliveBlocks do
    table.insert(indices, i)
  end
  
  -- Fisher-Yates shuffle
  for i = #indices, 1, -1 do
    local j = love.math.random(i)
    indices[i], indices[j] = indices[j], indices[i]
  end
  
  for i = 1, count do
    local block = aliveBlocks[indices[i]]
    block.shakeTime = 0.6
    block.dropVelocity = 0
    block.dropOffsetY = 0
    block.fadeAlpha = 1
    block.shakeOffsetX = 0
    block.shakeOffsetY = 0
    block.dropRotation = love.math.random() * math.pi * 2
    block.dropRotationSpeed = (love.math.random() * 2 - 1) * 3
    block.onDestroyed = nil
  end
end

-- Get calcify block positions
function GameplayScene:getCalcifyBlockPositions(count)
  if not self.blocks or not self.blocks.blocks then return {} end
  
  count = count or 3
  
  local eligibleBlocks = {}
  for _, block in ipairs(self.blocks.blocks) do
    if block and block.alive and not block.calcified then
      table.insert(eligibleBlocks, block)
    end
  end
  
  if #eligibleBlocks == 0 then return {} end
  
  local toSelect = math.min(count, #eligibleBlocks)
  local indices = {}
  for i = 1, #eligibleBlocks do
    table.insert(indices, i)
  end
  
  for i = #indices, 1, -1 do
    local j = love.math.random(i)
    indices[i], indices[j] = indices[j], indices[i]
  end
  
  local positions = {}
  for i = 1, toSelect do
    local block = eligibleBlocks[indices[i]]
    if block then
      table.insert(positions, {
        x = block.cx,
        y = block.cy,
        block = block,
      })
    end
  end
  
  return positions
end

-- Calcify blocks
function GameplayScene:calcifyBlocks(count)
  local positions = self:getCalcifyBlockPositions(count)
  for _, pos in ipairs(positions) do
    if pos.block and pos.block.calcify then
      pos.block:calcify(nil)
    end
  end
end

-- Cleanup
function GameplayScene:unload()
  if self.ballManager then
    self.ballManager:unload()
  end
  
  if self.blocks and self.blocks.clearAll then
    self.blocks:clearAll()
  end
  
  if self.physics then
    self.physics:unload()
  end
  
  if self.projectileEffects then
    self.projectileEffects:unload()
  end
  
  self.blocks = nil
  self.physics = nil
  self.ballManager = nil
  self.projectileEffects = nil
  self.shooter = nil
  self.particles = nil
  self.turnManager = nil
end

return GameplayScene

