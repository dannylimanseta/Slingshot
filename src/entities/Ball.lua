local theme = require("theme")
local config = require("config")
local math2d = require("utils.math2d")
local Trail = require("utils.trail")

local Ball = {}
Ball.__index = Ball

-- Shared trail shader (soft width edges, fades toward tail)
local TRAIL_SHADER = love.graphics.newShader([[
extern vec4 u_color;
extern float u_softness;
extern float u_invert; // 0 = head fades in, 1 = head bright

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  float edge = smoothstep(0.0, u_softness, uv.y) * (1.0 - smoothstep(1.0 - u_softness, 1.0, uv.y));
  float along = mix(1.0 - uv.x, uv.x, clamp(u_invert, 0.0, 1.0));
  float alpha = edge * along;
  return vec4(u_color.rgb, u_color.a * alpha);
}
]])

-- Simple brightness shader for projectile sprites
local BRIGHTNESS_SHADER = love.graphics.newShader([[
extern float u_brightness;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec4 c = Texel(tex, uv) * color;
  c.rgb = min(vec3(1.0), c.rgb * u_brightness);
  return c;
}
]])

-- Utility: radial gradient image for glow (alpha falls off toward edge)
local function makeRadialGlow(diameter)
  local data = love.image.newImageData(diameter, diameter)
  local cx = (diameter - 1) * 0.5
  local cy = (diameter - 1) * 0.5
  local r = diameter * 0.5 - 0.5
  data:mapPixel(function(x, y)
    local dx = x - cx
    local dy = y - cy
    local dist = math.sqrt(dx * dx + dy * dy)
    local t = math.min(1, math.max(0, dist / r))
    local a = (1 - t)
    a = a * a -- quadratic falloff for softer edge
    return 1, 1, 1, a
  end)
  return love.graphics.newImage(data)
end

function Ball.new(world, x, y, dirX, dirY, opts)
  opts = opts or {}
  local nx, ny = math2d.normalize(dirX, dirY)
  local targetSpeed = config.ball.speed
  local currentSpeed = targetSpeed
  if config.ball.easing and config.ball.easing.enabled then
    currentSpeed = targetSpeed * config.ball.easing.startFactor
  end
  
  -- Determine radius (can be overridden)
  local radius = opts.radius or config.ball.radius
  
  -- Determine maxBounces (can be overridden)
  local maxBounces = opts.maxBounces or config.ball.maxBounces
  
  -- Determine if this is a pierce orb and maxPierce (can be overridden)
  local pierce = opts.pierce or false
  local maxPierce = opts.maxPierce or nil
  
  -- Load ball sprite (can be overridden via opts.spritePath)
  local ballImg = nil
  local ballPath = opts.spritePath or ((config.assets and config.assets.images and config.assets.images.ball) or nil)
  if ballPath then
    local ok, img = pcall(love.graphics.newImage, ballPath)
    if ok then ballImg = img end
  end
  
  -- Use custom trail config if provided, otherwise use default
  local trailConfig = opts.trailConfig or config.ball.trail
  
  local self = setmetatable({
    speed = currentSpeed,
    targetSpeed = targetSpeed,
    radius = radius,
    maxBounces = maxBounces, -- store maxBounces per ball instance
    bounces = 0,
    pierce = pierce, -- whether this ball pierces through blocks
    maxPierce = maxPierce, -- maximum number of blocks to pierce through
    pierces = 0, -- current number of blocks pierced
    alive = true,
    score = 0,
    body = nil,
    shape = nil,
    fixture = nil,
    trail = Trail.new(trailConfig),
    glowImg = makeRadialGlow(128),
    ballImg = ballImg, -- sprite image for ball
    glowT = 0,
    burstTimer = 0, -- timer for glow burst effect on block hits
    onLastBounce = opts.onLastBounce or nil,
  }, Ball)

  self.body = love.physics.newBody(world, x, y, "dynamic")
  self.body:setBullet(true)
  self.body:setLinearDamping(0)
  self.shape = love.physics.newCircleShape(self.radius)
  self.fixture = love.physics.newFixture(self.body, self.shape, 1)
  -- Pierce orbs have 0 restitution (no bounce), regular orbs have 1 (full bounce)
  self.fixture:setRestitution(pierce and 0 or 1)
  self.fixture:setFriction(0)
  self.fixture:setUserData({ type = "ball", ref = self })
  self.body:setLinearVelocity(nx * currentSpeed, ny * currentSpeed)
  
  -- Store initial direction for pierce orbs to maintain straight path
  if pierce then
    self._initialDirection = { x = nx, y = ny }
  end

  return self
end

function Ball:update(dt, world)
  if not self.alive then return end

  -- Ease speed toward target and enforce velocity magnitude
  if config.ball.easing and config.ball.easing.enabled then
    local k = config.ball.easing.easeK
    local dv = (self.targetSpeed - self.speed) * math.min(1, k * dt)
    self.speed = self.speed + dv
  end
  
  -- For pierce orbs, maintain the initial direction (straight path)
  -- For regular orbs, normalize current velocity (allows bouncing)
  local vx, vy = self.body:getLinearVelocity()
  local nx, ny
  if self.pierce and self._initialDirection then
    -- Pierce orbs always go in their initial direction
    nx, ny = self._initialDirection.x, self._initialDirection.y
  else
    -- Regular orbs normalize current velocity (allows bouncing)
    nx, ny = math2d.normalize(vx, vy)
    if nx ~= nx or ny ~= ny or (nx == 0 and ny == 0) then
      -- If direction invalid, nudge upwards
      nx, ny = 0, -1
    end
  end
  self.body:setLinearVelocity(nx * self.speed, ny * self.speed)

  -- Trail sampling
  local x, y = self.body:getX(), self.body:getY()
  if self.trail then self.trail:update(dt, x, y) end

  -- Advance glow time
  self.glowT = self.glowT + dt
  
  -- Decay burst effect
  if self.burstTimer > 0 then
    self.burstTimer = math.max(0, self.burstTimer - dt)
  end
end

function Ball:draw()
  if not self.alive then return end
  -- Trail first
  if self.trail then self.trail:draw() end
  love.graphics.setColor(theme.colors.ball)
  local x, y = self.body:getX(), self.body:getY()
  -- Glow behind ball (multi-layered for stronger illumination)
  do
    local g = config.ball.glow
    if g and g.enabled and self.glowImg then
      love.graphics.push("all")
      love.graphics.setBlendMode("add")
      
      -- Calculate burst intensity (fades from 1.0 to 0.0 over burst duration)
      local burst = g.burst
      local burstIntensity = 0
      if burst and burst.enabled and self.burstTimer > 0 then
        local burstDuration = burst.duration or 0.15
        burstIntensity = self.burstTimer / burstDuration -- Starts at 1.0, fades to 0.0
      end
      
      -- Outer glow layer (softer, larger for ambient illumination)
      if g.outerGlow and g.outerGlow.enabled then
        local outer = g.outerGlow
        local outerCol = outer.color or { 0.3, 0.8, 1, 0.4 }
        do
          local trailCfg = self.trail and self.trail.cfg or nil
          if trailCfg then
            local src = trailCfg.colorStart or trailCfg.color or trailCfg.colorEnd
            if src then
              outerCol = { src[1] or outerCol[1], src[2] or outerCol[2], src[3] or outerCol[3], outerCol[4] or 0.4 }
            end
          end
        end
        local outerAlpha = outerCol[4] or 0.4
        -- Apply burst intensity to outer glow too (scaled up for more visibility)
        if burstIntensity > 0 then
          outerAlpha = outerAlpha * (1 + burstIntensity * ((burst.intensityMultiplier or 4.5) - 1) * 0.8)
        end
        love.graphics.setColor(outerCol[1] or 1, outerCol[2] or 1, outerCol[3] or 1, outerAlpha)
        local iw, ih = self.glowImg:getWidth(), self.glowImg:getHeight()
        local outerRadiusScale = (outer.radiusScale or 7.0)
        -- Apply burst radius multiplier
        if burstIntensity > 0 then
          outerRadiusScale = outerRadiusScale * (1 + burstIntensity * ((burst.radiusMultiplier or 1.3) - 1))
        end
        local outerS = ((self.radius * outerRadiusScale) * 2) / math.max(1, iw)
        love.graphics.draw(self.glowImg, x, y, 0, outerS, outerS, iw * 0.5, ih * 0.5)
      end
      
      -- Main glow layer (brighter, closer to ball)
      local col = g.color or { 0.3, 0.8, 1, 0.7 }
      do
        local trailCfg = self.trail and self.trail.cfg or nil
        if trailCfg then
          local src = trailCfg.colorStart or trailCfg.color or trailCfg.colorEnd
          if src then
            col = { src[1] or col[1], src[2] or col[2], src[3] or col[3], col[4] or 0.7 }
          end
        end
      end
      local alpha = col[4] or 0.7
      if g.pulse then
        local p = (math.sin(self.glowT * (g.pulseSpeed or 1.6)) * 0.5 + 0.5) * (g.pulseAmount or 0.2)
        alpha = math.max(0, math.min(1.5, alpha + p)) -- Allow higher alpha for stronger glow
      end
      -- Apply burst intensity multiplier
      if burstIntensity > 0 then
        alpha = alpha * (1 + burstIntensity * ((burst.intensityMultiplier or 2.5) - 1))
      end
      love.graphics.setColor(col[1] or 1, col[2] or 1, col[3] or 1, alpha)
      local iw, ih = self.glowImg:getWidth(), self.glowImg:getHeight()
      local radiusScale = (g.radiusScale or 2.2)
      -- Apply burst radius multiplier
      if burstIntensity > 0 then
        radiusScale = radiusScale * (1 + burstIntensity * ((burst.radiusMultiplier or 1.3) - 1))
      end
      local s = ((self.radius * radiusScale) * 2) / math.max(1, iw)
      love.graphics.draw(self.glowImg, x, y, 0, s, s, iw * 0.5, ih * 0.5)
      
      love.graphics.pop()
    end
  end
  
  -- Draw ball sprite or fallback circle
  love.graphics.setColor(1, 1, 1, 1)
  if self.ballImg then
    local imgW, imgH = self.ballImg:getWidth(), self.ballImg:getHeight()
    local scale = (self.radius * 2) / math.max(imgW, imgH) -- scale to fit radius
    love.graphics.push("all")
    love.graphics.setShader(BRIGHTNESS_SHADER)
    BRIGHTNESS_SHADER:send("u_brightness", 1.5) -- +50% brightness
    love.graphics.draw(self.ballImg, x, y, 0, scale, scale, imgW * 0.5, imgH * 0.5)
    love.graphics.setShader()
    love.graphics.pop()
  else
    -- Fallback to circle if sprite missing
    love.graphics.setColor(theme.colors.ball)
    love.graphics.circle("fill", x, y, self.radius)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function Ball:onBounce()
  if not self.alive then return end
  -- Pierce orbs don't bounce
  if self.pierce then return end
  self.bounces = self.bounces + 1
  if config.ball.bounceSpeedScale and config.ball.bounceSpeedScale > 1 then
    self.targetSpeed = self.targetSpeed * config.ball.bounceSpeedScale
  end
  -- Use instance maxBounces if set, otherwise fall back to config
  local maxBounces = self.maxBounces or config.ball.maxBounces
  if self.bounces >= maxBounces then
    if self.onLastBounce then
      pcall(function() self.onLastBounce(self) end)
    end
  end
  -- Insert an immediate trail sample at the bounce point to help bridge joins
  local tr = config.ball.trail
  if tr and tr.enabled then
    local x, y = self.body:getX(), self.body:getY()
    if self.trail and self.trail.addPoint then
      self.trail:addPoint(x, y)
    end
  end
end

function Ball:onPierce()
  if not self.alive then return end
  if not self.pierce then return end
  self.pierces = (self.pierces or 0) + 1
  -- Check if we've pierced max blocks
  if self.maxPierce and self.pierces >= self.maxPierce then
    -- Destroy the ball after piercing max blocks
    self:destroy()
  end
end

function Ball:onBlockHit()
  if not self.alive then return end
  -- Trigger glow burst effect
  local burst = config.ball.glow and config.ball.glow.burst
  if burst and burst.enabled then
    self.burstTimer = burst.duration or 0.15
  end
end

function Ball:destroy()
  if not self.alive then return end
  self.alive = false
  if self.fixture then pcall(function() self.fixture:destroy() end) end
  if self.body then pcall(function() self.body:destroy() end) end
end

return Ball


