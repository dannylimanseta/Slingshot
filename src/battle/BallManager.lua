-- BallManager: Handles ball lifecycle, shooting, and projectile spawning
-- Extracted from GameplayScene to improve maintainability

local config = require("config")
local math2d = require("utils.math2d")
local Ball = require("entities.Ball")
local ProjectileManager = require("managers.ProjectileManager")

local BallManager = {}
BallManager.__index = BallManager

function BallManager.new(world, shooter)
  return setmetatable({
    world = world,
    shooter = shooter,
    ball = nil,        -- Single ball (backward compatibility)
    balls = {},        -- Array of balls (for spread shot, twin strike, etc.)
    canShoot = true,
    isAiming = false,
    aimStartX = 0,
    aimStartY = 0,
  }, BallManager)
end

-- Check if any balls are alive
function BallManager:hasAliveBalls()
  if self.ball and self.ball.alive then
    return true
  end
  if self.balls then
    for _, ball in ipairs(self.balls) do
      if ball and ball.alive then
        return true
      end
    end
  end
  return false
end

-- Update all balls
function BallManager:update(dt, bounds)
  -- Update single ball (backward compatibility)
  if self.ball and self.ball.alive then
    self.ball:update(dt, { bounds = bounds })
  end
  
  -- Update multiple balls (spread shot, twin strike)
  if self.balls and #self.balls > 0 then
    for i = #self.balls, 1, -1 do
      local ball = self.balls[i]
      if ball and ball.alive then
        ball:update(dt, { bounds = bounds })
      else
        -- Remove dead balls
        table.remove(self.balls, i)
      end
    end
  end
  
  -- Failsafe: destroy balls that tunnel past bottom
  self:checkBallBounds(bounds)
end

-- Failsafe check for balls that tunnel past bottom sensor
function BallManager:checkBallBounds(bounds)
  local height = (bounds and bounds.h) or love.graphics.getHeight()
  local margin = 16
  
  -- Check single ball
  if self.ball and self.ball.alive and self.ball.body then
    local bx, by = self.ball.body:getX(), self.ball.body:getY()
    if by > height + margin then
      self.ball:destroy()
    end
  end
  
  -- Check multiple balls
  if self.balls and #self.balls > 0 then
    for i = #self.balls, 1, -1 do
      local ball = self.balls[i]
      if ball and ball.alive and ball.body then
        local bx, by = ball.body:getX(), ball.body:getY()
        if by > height + margin then
          ball:destroy()
          table.remove(self.balls, i)
        end
      end
    end
  end
end

-- Draw all balls
function BallManager:draw()
  -- Draw single ball
  if self.ball then
    self.ball:draw()
  end
  
  -- Draw multiple balls
  if self.balls then
    for _, ball in ipairs(self.balls) do
      if ball then
        ball:draw()
      end
    end
  end
end

-- Shoot a projectile
-- Returns: { baseDamage, projectileId, balls } where balls is array of spawned balls
function BallManager:shoot(dirX, dirY, projectileId)
  -- Normalize direction
  local ndx, ndy = math2d.normalize(dirX, dirY)
  if ndx == 0 and ndy == 0 then
    return nil -- Invalid direction
  end
  
  -- Get spawn position from shooter
  local startX, startY = self.aimStartX, self.aimStartY
  if self.shooter then
    startX, startY = self.shooter:getMuzzle()
  end
  
  -- Get projectile data and effective stats
  local projectileData = ProjectileManager.getProjectile(projectileId)
  local effective = ProjectileManager.getEffective(projectileData)
  local spritePath = projectileData and projectileData.icon or nil
  local baseDamage = (effective and effective.baseDamage) or ((config.score and config.score.baseSeed) or 0)
  
  -- Apply relic bonuses to base damage
  local RelicSystem = require("core.RelicSystem")
  if RelicSystem and RelicSystem.getOrbBaseDamageBonus then
    local bonus = RelicSystem.getOrbBaseDamageBonus(baseDamage, {
      projectileId = projectileId,
      projectileData = projectileData,
    })
    baseDamage = baseDamage + bonus
  end
  
  -- Create balls based on projectile type
  local spawnedBalls = {}
  local totalDamage = 0
  
  if projectileId == "twin_strike" then
    spawnedBalls = self:_spawnTwinStrike(startX, startY, ndx, ndy, effective, spritePath, baseDamage)
    totalDamage = baseDamage * 2
  elseif projectileId == "multi_strike" then
    spawnedBalls = self:_spawnMultiStrike(startX, startY, ndx, ndy, effective, spritePath, baseDamage)
    totalDamage = baseDamage * #spawnedBalls
  elseif projectileId == "pierce" then
    spawnedBalls = self:_spawnPierce(startX, startY, ndx, ndy, effective, spritePath, baseDamage)
    totalDamage = baseDamage
  elseif projectileId == "black_hole" then
    spawnedBalls = self:_spawnBlackHole(startX, startY, ndx, ndy, effective, spritePath, baseDamage, projectileData)
    totalDamage = baseDamage
  elseif projectileId == "lightning" then
    spawnedBalls = self:_spawnLightning(startX, startY, ndx, ndy, effective, spritePath, baseDamage)
    totalDamage = baseDamage
  else
    -- Standard single projectile
    spawnedBalls = self:_spawnStandard(startX, startY, ndx, ndy, effective, spritePath, baseDamage, projectileId)
    totalDamage = baseDamage
  end
  
  return {
    baseDamage = totalDamage,
    projectileId = projectileId,
    balls = spawnedBalls
  }
end

-- Spawn twin strike projectiles (2 mirrored balls)
function BallManager:_spawnTwinStrike(x, y, dirX, dirY, effective, spritePath, baseDamage)
  self.ball = nil
  self.balls = {}
  
  if not spritePath then
    spritePath = (config.assets.images.ball_3) or "assets/images/orb_twin_strike.png"
  end
  
  local maxBounces = (effective and effective.maxBounces) or 5
  local trailConfig = (config.ball and config.ball.twinStrike and config.ball.twinStrike.trail) or nil
  
  -- First ball: original direction
  local ball1 = Ball.new(self.world, x, y, dirX, dirY, {
    maxBounces = maxBounces,
    spritePath = spritePath,
    trailConfig = trailConfig,
    onLastBounce = function(ball) ball:destroy() end
  })
  
  -- Second ball: mirrored on x-axis
  local ball2 = Ball.new(self.world, x, y, -dirX, dirY, {
    maxBounces = maxBounces,
    spritePath = spritePath,
    trailConfig = trailConfig,
    onLastBounce = function(ball) ball:destroy() end
  })
  
  if ball1 then
    ball1.projectileId = "twin_strike"
    ball1.score = baseDamage
    table.insert(self.balls, ball1)
  end
  
  if ball2 then
    ball2.projectileId = "twin_strike"
    ball2.score = baseDamage
    table.insert(self.balls, ball2)
  end
  
  return self.balls
end

-- Spawn multi-strike projectiles (spread shot)
function BallManager:_spawnMultiStrike(x, y, dirX, dirY, effective, spritePath, baseDamage)
  self.ball = nil
  self.balls = {}
  
  local spreadConfig = config.ball.spreadShot
  if not spreadConfig or not spreadConfig.enabled then
    -- Fallback to single projectile if spread shot not configured
    return self:_spawnStandard(x, y, dirX, dirY, effective, spritePath, baseDamage, "multi_strike")
  end
  
  local count = (effective and effective.count) or (spreadConfig.count or 3)
  local spreadAngle = spreadConfig.spreadAngle or 0.15
  local radiusScale = spreadConfig.radiusScale or 0.7
  
  if not spritePath then
    spritePath = spreadConfig.sprite or (config.assets.images.ball_2) or "assets/images/orb_multi_strike.png"
  end
  
  local maxBounces = (effective and effective.maxBounces) or (spreadConfig.maxBounces or 3)
  local baseAngle = math.atan2(dirY, dirX)
  
  -- Spawn projectiles in spread pattern
  for i = 1, count do
    local offset = 0
    if count > 1 then
      offset = (i - (count + 1) / 2) * (spreadAngle / (count - 1))
    end
    
    local angle = baseAngle + offset
    local projDx = math.cos(angle)
    local projDy = math.sin(angle)
    
    local ball = Ball.new(self.world, x, y, projDx, projDy, {
      radius = config.ball.radius * radiusScale,
      maxBounces = maxBounces,
      spritePath = spritePath,
      trailConfig = spreadConfig.trail,
      onLastBounce = function(ball) ball:destroy() end
    })
    
    if ball then
      ball.projectileId = "multi_strike"
      ball.score = baseDamage
      table.insert(self.balls, ball)
    end
  end
  
  return self.balls
end

-- Spawn pierce projectile
function BallManager:_spawnPierce(x, y, dirX, dirY, effective, spritePath, baseDamage)
  self.balls = {}
  
  local maxPierce = (effective and effective.maxPierce) or 6
  local pierceRadiusScale = 2.0
  
  self.ball = Ball.new(self.world, x, y, dirX, dirY, {
    pierce = true,
    maxPierce = maxPierce,
    radius = config.ball.radius * pierceRadiusScale,
    spritePath = spritePath,
    onLastBounce = function(ball) ball:destroy() end
  })
  
  if self.ball then
    self.ball.projectileId = "pierce"
    self.ball.score = baseDamage
  end
  
  return { self.ball }
end

-- Spawn black hole projectile
function BallManager:_spawnBlackHole(x, y, dirX, dirY, effective, spritePath, baseDamage, projectileData)
  self.balls = {}
  
  self.ball = Ball.new(self.world, x, y, dirX, dirY, {
    maxBounces = (effective and effective.maxBounces) or config.ball.maxBounces,
    spritePath = spritePath,
    onLastBounce = function(ball) ball:destroy() end
  })
  
  if self.ball then
    self.ball.projectileId = "black_hole"
    self.ball.score = baseDamage
    
    -- Store projectile level for level-based scaling
    if projectileData and projectileData.level then
      self.ball.projectileLevel = projectileData.level
    end
  end
  
  return { self.ball }
end

-- Spawn lightning projectile
function BallManager:_spawnLightning(x, y, dirX, dirY, effective, spritePath, baseDamage)
  self.balls = {}
  
  local maxBounces = (effective and effective.maxBounces) or config.ball.maxBounces
  local lightningConfig = config.ball.lightning or {}
  local trailConfig = lightningConfig.trail or config.ball.trail
  
  self.ball = Ball.new(self.world, x, y, dirX, dirY, {
    lightning = true,
    maxBounces = maxBounces,
    spritePath = spritePath,
    trailConfig = trailConfig,
    onLastBounce = function(ball) ball:destroy() end
  })
  
  if self.ball then
    self.ball.projectileId = "lightning"
    self.ball.score = baseDamage
  end
  
  return { self.ball }
end

-- Spawn standard projectile
function BallManager:_spawnStandard(x, y, dirX, dirY, effective, spritePath, baseDamage, projectileId)
  self.balls = {}
  
  self.ball = Ball.new(self.world, x, y, dirX, dirY, {
    maxBounces = (effective and effective.maxBounces) or config.ball.maxBounces,
    spritePath = spritePath,
    onLastBounce = function(ball) ball:destroy() end
  })
  
  if self.ball then
    self.ball.projectileId = projectileId
    self.ball.score = baseDamage
  end
  
  return { self.ball }
end

-- Begin aiming
function BallManager:startAiming(x, y)
  self.isAiming = true
  self.aimStartX = x
  self.aimStartY = y
end

-- End aiming
function BallManager:stopAiming()
  self.isAiming = false
end

-- Enable/disable shooting
function BallManager:setCanShoot(canShoot)
  self.canShoot = canShoot
end

function BallManager:getCanShoot()
  return self.canShoot
end

-- Cleanup
function BallManager:unload()
  -- Destroy all balls
  if self.ball and self.ball.alive then
    self.ball:destroy()
    self.ball = nil
  end
  
  if self.balls then
    for i = #self.balls, 1, -1 do
      local ball = self.balls[i]
      if ball and ball.alive then
        ball:destroy()
      end
      table.remove(self.balls, i)
    end
    self.balls = {}
  end
end

return BallManager

