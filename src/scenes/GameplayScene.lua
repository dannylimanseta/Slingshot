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

-- New managers (extracted from GameplayScene)
local PhysicsManager = require("battle.PhysicsManager")
local BallManager = require("battle.BallManager")
local ProjectileEffects = require("battle.ProjectileEffects")
local VisualEffects = require("battle.VisualEffects")

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
    canShoot = true,
    _prevCanShoot = true,
    
    -- Score tracking
    score = 0,
    displayScore = 0,
    armorThisTurn = 0,
    healThisTurn = 0,
    destroyedThisTurn = 0,
    blocksHitThisTurn = 0,
    critThisTurn = 0,
    multiplierThisTurn = 0,
    aoeThisTurn = false,
    blockHitSequence = {},
    baseDamageThisTurn = 0,
    
    -- Combo tracking
    comboCount = 0,
    comboTimeout = 0,
    lastHitTime = 0,
    
    -- Collision tracking
    _blocksHitThisFrame = {},
    
    -- Projectile ID
    projectileId = "strike",
    
    -- Edge hit callback (set by parent scene)
    onEdgeHit = nil,
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
  
  -- Store reference to GameplayScene in projectile effects
  self.projectileEffects.scene = self
  -- Initialize shared battle state
  self.state = BattleState.new({ profile = battleProfile })
  BattleState.setCanShoot(true)
  BattleState.resetTurnRewards()
  BattleState.resetBlocksDestroyedThisTurn()
  self.blackHoles = self.projectileEffects.blackHoles or {}
  self.canShoot = self.state.flags.canShoot
  self.score = self.state.rewards.score
  self.displayScore = self.state.rewards.score
  self.armorThisTurn = self.state.rewards.armorThisTurn
  self.healThisTurn = self.state.rewards.healThisTurn
  self.blocksHitThisTurn = #self.state.rewards.blockHitSequence
  self.critThisTurn = self.state.rewards.critCount
  self.multiplierThisTurn = self.state.rewards.multiplierCount
  self.aoeThisTurn = self.state.rewards.aoeFlag
  self.blockHitSequence = self.state.rewards.blockHitSequence
  self.baseDamageThisTurn = self.state.rewards.baseDamage
  self.destroyedThisTurn = self.state.blocks.destroyedThisTurn or 0
  
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
  
  -- Process delayed lightning hits (small delay to match streak animation)
  if self.blocks and self.blocks.blocks then
    for _, block in ipairs(self.blocks.blocks) do
      if block and block.alive and block._lightningHitPending then
        block._lightningHitDelay = (block._lightningHitDelay or 0) - dt
        if block._lightningHitDelay <= 0 then
          block._lightningHitPending = false
          block._lightningHitDelay = nil
          -- Now actually hit the block
          if not block.hitThisFrame and not self._blocksHitThisFrame[block] then
            self._blocksHitThisFrame[block] = true
            block:hit()
            -- Award rewards for the delayed hit
            if block._lightningHitRewardPending then
              self:awardBlockReward(block)
              self:showDamageNumber(block)
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
    -- Pierce orbs: destroy when hitting walls (after piercing blocks)
    local bx, by = ball.body:getPosition()
    local dx = bx - (ball.spawnX or bx)
    local dy = by - (ball.spawnY or by)
    local distFromSpawn = math.sqrt(dx * dx + dy * dy)
    local hasPierced = (ball.pierces or 0) > 0
    
    if distFromSpawn >= 3 and hasPierced then
      ball:destroy()
    end
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
  
  -- For lightning, add a small delay so block stays visible until streak reaches it
  local lightningFirstHit = false
  if ball.lightning and ball.alive and not ball._lightningHidden then
    lightningFirstHit = true
    -- Small delay to match lightning streak animation timing
    local lcfg = config.ball.lightning or {}
    local streakAnimDuration = lcfg.streakAnimDuration or 0.18
    block._lightningHitDelay = streakAnimDuration * 0.5 -- Half the animation duration for subtle delay
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
end

-- Show damage number above block with latest damage tally
function GameplayScene:showDamageNumber(block)
  if not self.visualEffects or not block then return end
  
  -- Calculate current total damage from BattleState
  local state = self.state or BattleState.get()
  if not state or not state.rewards then return end
  
  local blockHitSequence = state.rewards.blockHitSequence or {}
  local orbBaseDamage = state.rewards.baseDamage or 0
  
  -- Calculate cumulative damage (excluding crit/multiplier blocks from base)
  local cumulative = orbBaseDamage
  for _, hit in ipairs(blockHitSequence) do
    local kind = (type(hit) == "table" and hit.kind) or "damage"
    local amount = (type(hit) == "table" and (hit.damage or hit.amount)) or 0
    -- Only add damage from blocks that aren't crit or multiplier
    if kind ~= "crit" and kind ~= "multiplier" then
      cumulative = cumulative + amount
    end
  end
  
  -- Apply multipliers if any
  local critCount = state.rewards.critCount or 0
  local multiplierCount = state.rewards.multiplierCount or 0
  if critCount > 0 then
    local mult = (config.score and config.score.critMultiplier) or 2
    cumulative = cumulative * (mult ^ critCount)
  end
  if multiplierCount > 0 then
    local dmgMult = (config.score and config.score.powerCritMultiplier) or 4
    cumulative = cumulative * dmgMult
  end
  
  -- Show damage number (will accumulate if block already has one)
  self.visualEffects:addDamageNumber(block, cumulative)
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

