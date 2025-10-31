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

function ParticleManager.new()
  return setmetatable({ systems = {}, img = makeTriangleImage(32) }, ParticleManager)
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
  table.insert(self.systems, makeSpark(self.img, x, y, theme.colors.block))
end

function ParticleManager:emitExplosion(x, y, color)
  table.insert(self.systems, makeExplosion(self.img, x, y, color))
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
end

function ParticleManager:draw()
  for _, ps in ipairs(self.systems) do love.graphics.draw(ps) end
end

return ParticleManager


