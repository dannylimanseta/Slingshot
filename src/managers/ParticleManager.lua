local theme = require("theme")

local ParticleManager = {}
ParticleManager.__index = ParticleManager

local function makeTriangleImage(diameter)
  local data = love.image.newImageData(diameter, diameter)
  local cx = (diameter - 1) * 0.5
  local cy = (diameter - 1) * 0.5
  -- Create equilateral triangle pointing upward
  -- Triangle vertices: top, bottom-left, bottom-right
  local radius = diameter * 0.4 -- radius of circumscribed circle
  local topX, topY = cx, cy - radius
  local blX, blY = cx - radius * 0.866, cy + radius * 0.5 -- bottom-left (cos(210°) = -0.866, sin(210°) = -0.5)
  local brX, brY = cx + radius * 0.866, cy + radius * 0.5 -- bottom-right (cos(330°) = 0.866, sin(330°) = -0.5)
  
  -- Point-in-triangle test using barycentric coordinates
  local function pointInTriangle(px, py, x1, y1, x2, y2, x3, y3)
    local d = (y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3)
    if math.abs(d) < 0.0001 then return false end
    local a = ((y2 - y3) * (px - x3) + (x3 - x2) * (py - y3)) / d
    local b = ((y3 - y1) * (px - x3) + (x1 - x3) * (py - y3)) / d
    local c = 1 - a - b
    return a >= 0 and b >= 0 and c >= 0
  end
  
  data:mapPixel(function(x, y)
    if pointInTriangle(x, y, topX, topY, blX, blY, brX, brY) then
      return 1, 1, 1, 1
    else
      return 1, 1, 1, 0
    end
  end)
  return love.graphics.newImage(data)
end

local function makeCircleImage(diameter)
  local data = love.image.newImageData(diameter, diameter)
  local cx = (diameter - 1) * 0.5
  local cy = (diameter - 1) * 0.5
  local radius = diameter * 0.4 -- radius of circle
  
  data:mapPixel(function(x, y)
    local dx = x - cx
    local dy = y - cy
    local distSq = dx * dx + dy * dy
    local radiusSq = radius * radius
    if distSq <= radiusSq then
      return 1, 1, 1, 1
    else
      return 1, 1, 1, 0
    end
  end)
  return love.graphics.newImage(data)
end

function ParticleManager.new()
  return setmetatable({ 
    systems = {}, 
    img = makeTriangleImage(32),
    circleImg = makeCircleImage(32),
    whiteGlowImg = nil,
    glows = {},
  }, ParticleManager)
end

local function makeSpark(img, x, y, color)
  local ps = love.graphics.newParticleSystem(img, 32)
  -- Reduced lifetime to compensate for increased speed (reduce travel distance)
  ps:setParticleLifetime(0.1, 0.225) -- halved from 0.2, 0.45
  ps:setEmissionRate(0)
  -- Size shrinks quickly instead of fading: start normal, shrink to tiny later
  ps:setSizes(0.36, 0.36, 0.02) -- start at 0.36, stay normal until ~75% lifetime, then shrink to 0.02
  -- Speed increased by 100% (doubled)
  ps:setLinearAcceleration(-800, -800, 800, 800) -- doubled from -400, -400, 400, 400
  ps:setSpeed(440, 720) -- doubled from 220, 360
  ps:setSpread(math.pi)
  -- Color variation: add subtle tint variations for visual diversity
  -- Particles transition through slightly different colors for more interest
  ps:setColors(
    1, 1, 1, 1,  -- Start: white
    0.85, 0.92, 1, 1,  -- Early: cool blue-white
    1, 0.95, 0.88, 1,  -- Mid: warm yellow-white
    0.92, 1, 0.9, 1,  -- Late: slight green-white
    1, 1, 1, 1   -- End: white
  )
  ps:moveTo(x, y)
  ps:emit(8)
  return ps
end

local function makeExplosion(img, x, y, color)
  color = color or theme.colors.block -- Default to block color if not provided
  local ps = love.graphics.newParticleSystem(img, 64)
  -- Reduced lifetime to compensate for increased speed (reduce travel distance)
  ps:setParticleLifetime(0.175, 0.4) -- halved from 0.35, 0.8
  ps:setEmissionRate(0)
  -- Size shrinks quickly instead of fading: start normal, shrink to super small later
  ps:setSizes(0.54, 0.54, 0.02) -- start at 0.54, stay normal until ~75% lifetime, then shrink to 0.02
  -- Particles fall downward with slight horizontal spread - speed increased by 100% (doubled)
  -- Gravity pulls particles down (positive Y is downward in LÖVE)
  ps:setLinearAcceleration(-50, 400 * 3, 50, 1200 * 3) -- doubled from 1.5x to 3x (100% faster)
  ps:setSpeed(160 * 3, 360 * 3) -- doubled from 1.5x to 3x (100% faster initial speed)
  ps:setSpread(math.pi * 0.5) -- Spread of 90 degrees (downward cone)
  ps:setDirection(-math.pi * 0.5) -- Point downward (270 degrees = straight down)
  -- Random rotation for triangles (full 360 degrees rotation range)
  ps:setRotation(0, 2 * math.pi)
  -- Variable size variation for skew effect (0.5 means 50% size variation)
  ps:setSizeVariation(0.5)
  -- Color transition: start white, fade to block color with per-particle variation
  -- Using multiple color stops for smooth transitions and visual diversity
  local r, g, b = color[1] or 1, color[2] or 1, color[3] or 1
  -- Create color variations for per-particle diversity (brighter/darker/saturated versions)
  local rVar1 = math.min(1, r * 1.2) -- brighter, more saturated variant
  local gVar1 = math.min(1, g * 1.2)
  local bVar1 = math.min(1, b * 1.2)
  local rVar2 = math.max(0, r * 0.8) -- darker variant
  local gVar2 = math.max(0, g * 0.8)
  local bVar2 = math.max(0, b * 0.8)
  -- Add a complementary hue shift variant for more visual interest
  local rVar3 = math.min(1, (r + 0.1))
  local gVar3 = math.min(1, (g + 0.05))
  local bVar3 = math.max(0, (b - 0.05))
  ps:setColors(
    1, 1, 1, 1,  -- 0%: white, full opacity
    rVar1, gVar1, bVar1, 1,  -- ~20%: brighter block color variant
    r, g, b, 1,  -- ~40%: original block color
    rVar3, gVar3, bVar3, 1,  -- ~60%: hue-shifted variant
    rVar2, gVar2, bVar2, 1,  -- ~80%: darker variant
    r, g, b, 1   -- 100%: original block color, still fully opaque (shrinks instead)
  )
  ps:moveTo(x, y)
  ps:emit(16)
  return ps
end

function ParticleManager:emitSpark(x, y)
  -- Add a brief white glow at the impact position
  if x and y then
    self:emitWhiteGlow(x, y)
  end
  table.insert(self.systems, makeSpark(self.img, x, y, theme.colors.block))
end

function ParticleManager:emitExplosion(x, y, color)
  table.insert(self.systems, makeExplosion(self.img, x, y, color))
end

local function makeHitBurst(img, x, y, color, isCrit)
  -- Default colors: FFE7B3 (lighter) to D79752 (darker)
  -- FFE7B3 = RGB(255, 231, 179) = (1.0, 0.906, 0.702)
  -- D79752 = RGB(215, 151, 82) = (0.843, 0.592, 0.322)
  local lightR, lightG, lightB = 1.0, 0.906, 0.702
  local darkR, darkG, darkB = 0.843, 0.592, 0.322
  
  -- Use provided color or calculate midpoint between light and dark
  local r, g, b
  if color then
    r, g, b = color[1] or 0.922, color[2] or 0.749, color[3] or 0.512
  else
    -- Midpoint between light and dark
    r, g, b = (lightR + darkR) * 0.5, (lightG + darkG) * 0.5, (lightB + darkB) * 0.5
  end
  
  -- Crit mode: increase particle count and speed/intensity
  local particleCount = isCrit and 35 or 20
  local minSpeed = isCrit and 300 or 200
  local maxSpeed = isCrit and 600 or 400
  local minAccelY = isCrit and 500 or 400
  local maxAccelY = isCrit and 1000 or 800
  
  local ps = love.graphics.newParticleSystem(img, 32)
  -- Lifetime: particles burst outward then fall
  ps:setParticleLifetime(0.4, 0.8)
  ps:setEmissionRate(0)
  -- Size: start small, grow slightly, then shrink as they fade
  -- Wider size range for more variation
  ps:setSizes(0.2, 0.6, 0.08)
  -- Initial burst: particles spurt outward in all directions
  -- Increased speed for crit hits
  ps:setSpeed(minSpeed, maxSpeed)
  ps:setSpread(2 * math.pi) -- Full 360 degree spread
  -- Linear acceleration: gravity pulls particles down after initial burst
  -- Horizontal: slight random drift (-20 to 20)
  -- Vertical: strong downward gravity (increased for crit)
  ps:setLinearAcceleration(-20, minAccelY, 20, maxAccelY)
  -- Random rotation
  ps:setRotation(0, 2 * math.pi)
  -- Size variation for visual diversity (increased for more variation)
  ps:setSizeVariation(0.6)
  -- Color transition: start bright (FFE7B3), fade to darker (D79752)
  ps:setColors(
    lightR, lightG, lightB, 1,  -- Start: lighter color (FFE7B3), full opacity
    r, g, b, 1,  -- Early: midpoint color
    r, g, b, 0.9,  -- Mid: midpoint color, slight fade
    darkR, darkG, darkB, 0.5,  -- Late: darker color (D79752), more fade
    darkR * 0.7, darkG * 0.7, darkB * 0.7, 0  -- End: very dark, fully transparent
  )
  ps:moveTo(x, y)
  ps:emit(particleCount) -- More particles for crit hits
  return ps
end

function ParticleManager:emitHitBurst(x, y, color, isCrit)
  table.insert(self.systems, makeHitBurst(self.circleImg, x, y, color, isCrit))
end

-- Emit lightning spark particles (bright white glow)
function ParticleManager:emitLightningSpark(x, y)
  -- Add a brief white glow at the impact position
  if x and y then
    self:emitWhiteGlow(x, y)
  end
  local ps = love.graphics.newParticleSystem(self.circleImg, 16)
  ps:setParticleLifetime(0.2, 0.4)
  ps:setEmissionRate(0)
  ps:setSizes(0.4, 0.5, 0.05) -- Start medium, stay bright, shrink at end
  ps:setSpeed(100, 200) -- Medium-fast particles
  ps:setSpread(2 * math.pi) -- Full 360 spread
  ps:setLinearAcceleration(-400, -400, 400, 400) -- Spread outward
  -- Bright white to cyan-blue
  ps:setColors(
    1.0, 1.0, 1.0, 1.0,      -- Start: pure white
    1.0, 1.0, 1.0, 0.9,      -- Mid: pure white, slight fade
    1.0, 1.0, 1.0, 0.5,      -- Late: pure white, more fade
    1.0, 1.0, 1.0, 0.0       -- Final: pure white, transparent
  )
  ps:moveTo(x, y)
  ps:emit(12) -- 12 particles per spark
  table.insert(self.systems, ps)
end

-- Add a transient white glow sprite at a position
function ParticleManager:emitWhiteGlow(x, y)
  -- Lazy-load asset
  if not self.whiteGlowImg then
    local ok, img = pcall(love.graphics.newImage, "assets/images/fx/white_glow.png")
    if ok and img then
      self.whiteGlowImg = img
    end
  end
  table.insert(self.glows, {
    x = x,
    y = y,
    t = 0,
    duration = 0.40, -- slightly longer flash
    scale = 1.4, -- slightly larger base size
  })
end

function ParticleManager:update(dt)
  local alive = {}
  for _, ps in ipairs(self.systems) do
    ps:update(dt)
    if ps:getCount() > 0 then
      table.insert(alive, ps)
    end
  end
  self.systems = alive
  -- Update glows
  local glowAlive = {}
  for _, g in ipairs(self.glows or {}) do
    g.t = (g.t or 0) + dt
    if g.t < (g.duration or 0.28) then
      table.insert(glowAlive, g)
    end
  end
  self.glows = glowAlive
end

function ParticleManager:draw()
  -- Draw white glows (additive)
  if self.glows and #self.glows > 0 then
    love.graphics.push("all")
    love.graphics.setBlendMode("add")
    for _, g in ipairs(self.glows) do
      local a = 1.0
      local d = g.duration or 0.28
      local u = math.max(0, math.min(1, (g.t or 0) / d))
      -- Ease-out alpha
      a = 1.0 - u
      -- Scale up slightly over time
      local s = (g.scale or 1.0) * (1.0 + 0.5 * u)
      if self.whiteGlowImg then
        local iw, ih = self.whiteGlowImg:getWidth(), self.whiteGlowImg:getHeight()
        love.graphics.setColor(1, 1, 1, a)
        love.graphics.draw(self.whiteGlowImg, g.x, g.y, 0, s, s, iw * 0.5, ih * 0.5)
      else
        -- Fallback: draw a simple white circle
        love.graphics.setColor(1, 1, 1, a * 0.7)
        love.graphics.circle("fill", g.x, g.y, 24 * s)
      end
    end
    love.graphics.pop()
  end
  for _, ps in ipairs(self.systems) do love.graphics.draw(ps) end
end

return ParticleManager


