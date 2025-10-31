local Trail = {}
Trail.__index = Trail

-- Shared trail shader (soft width edges, fades toward tail, gradient color support)
local TRAIL_SHADER = love.graphics.newShader([[ 
extern vec4 u_colorStart;  // Color at head (yellow)
extern vec4 u_colorEnd;    // Color at tail (orange)
extern float u_softness;
extern float u_invert; // 0 = head fades in, 1 = head bright
extern float u_useGradient; // 0 = single color, 1 = gradient

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  float edge = smoothstep(0.0, u_softness, uv.y) * (1.0 - smoothstep(1.0 - u_softness, 1.0, uv.y));
  float along = mix(1.0 - uv.x, uv.x, clamp(u_invert, 0.0, 1.0));
  float alpha = edge * along;
  
  // Interpolate between start and end colors based on position along trail
  vec4 trailColor = mix(u_colorEnd, u_colorStart, along);
  vec4 singleColor = u_colorStart;
  vec4 finalColor = mix(singleColor, trailColor, u_useGradient);
  
  return vec4(finalColor.rgb, finalColor.a * alpha);
}
]])

function Trail.new(cfg)
  return setmetatable({
    cfg = cfg or {},
    points = {},
    acc = 0,
    mesh = nil,
  }, Trail)
end

function Trail:addPoint(x, y)
  table.insert(self.points, 1, { x = x, y = y })
  local maxN = (self.cfg and self.cfg.maxPoints) or 32
  if #self.points > maxN then self.points[#self.points] = nil end
end

function Trail:update(dt, x, y)
  local tr = self.cfg
  if not tr or not tr.enabled then return end
  self.acc = self.acc + dt
  local step = math.max(1e-6, tr.sampleInterval or 0.016)
  while self.acc >= step do
    self.acc = self.acc - step
    self:addPoint(x, y)
  end
end

function Trail:draw()
  local tr = self.cfg
  if not tr or not tr.enabled then return end
  local pts = self.points
  local n = #pts
  if n < 2 then return end

  local cum = { 0 }
  for i = 2, n do
    local dx = pts[i].x - pts[i - 1].x
    local dy = pts[i].y - pts[i - 1].y
    cum[i] = cum[i - 1] + math.sqrt(dx * dx + dy * dy)
  end
  local total = math.max(1e-6, cum[n])

  local verts = {}
  local indices = {}
  local function addVert(px, py, u, v)
    table.insert(verts, { px, py, u, v })
  end

  for i = 1, n do
    local tx, ty
    if i == 1 then
      tx = pts[2].x - pts[1].x; ty = pts[2].y - pts[1].y
    elseif i == n then
      tx = pts[n].x - pts[n - 1].x; ty = pts[n].y - pts[n - 1].y
    else
      local ax = pts[i].x - pts[i - 1].x; local ay = pts[i].y - pts[i - 1].y
      local bx = pts[i + 1].x - pts[i].x; local by = pts[i + 1].y - pts[i].y
      local al = math.sqrt(ax * ax + ay * ay); if al > 0 then ax, ay = ax / al, ay / al end
      local bl = math.sqrt(bx * bx + by * by); if bl > 0 then bx, by = bx / bl, by / bl end
      tx, ty = ax + bx, ay + by
      if tx == 0 and ty == 0 then tx, ty = bx, by end
    end
    local tl = math.sqrt(tx * tx + ty * ty); if tl > 0 then tx, ty = tx / tl, ty / tl end
    local nx, ny = -ty, tx

    local t = 1 - (cum[i] / total)
    local pw = math.max(0.01, tr.taperPower or 1.4)
    local width = (tr.width or 18) * math.pow(t, pw)
    local lx = pts[i].x + nx * (width * 0.5)
    local ly = pts[i].y + ny * (width * 0.5)
    local rx = pts[i].x - nx * (width * 0.5)
    local ry = pts[i].y - ny * (width * 0.5)
    local u = 1 - (cum[i] / total)
    addVert(lx, ly, u, 0)
    addVert(rx, ry, u, 1)
  end

  for i = 1, n - 1 do
    local a = (i - 1) * 2 + 1
    local b = a + 1
    local c = a + 2
    local d = a + 3
    table.insert(indices, a); table.insert(indices, b); table.insert(indices, c)
    table.insert(indices, c); table.insert(indices, b); table.insert(indices, d)
  end

  if #verts < 4 then return end
  local mesh = self.mesh
  if not mesh or mesh:getVertexCount() ~= #verts then
    mesh = love.graphics.newMesh({ { "VertexPosition", "float", 2 }, { "VertexTexCoord", "float", 2 } }, verts, "triangles", "dynamic")
    self.mesh = mesh
  else
    for i = 1, #verts do mesh:setVertex(i, verts[i]) end
  end
  mesh:setVertexMap(indices)

  love.graphics.push("all")
  if tr.additive then love.graphics.setBlendMode("add") end
  local col = tr.color or { 1, 0.95, 0.65, 0.6 }
  local colStart = tr.colorStart or col  -- Color at head (yellow)
  local colEnd = tr.colorEnd or col      -- Color at tail (orange)
  local useGradient = (tr.colorStart and tr.colorEnd) and 1.0 or 0.0
  
  TRAIL_SHADER:send("u_colorStart", { colStart[1] or 1, colStart[2] or 1, colStart[3] or 1, colStart[4] or 1 })
  TRAIL_SHADER:send("u_colorEnd", { colEnd[1] or 1, colEnd[2] or 1, colEnd[3] or 1, colEnd[4] or 1 })
  TRAIL_SHADER:send("u_softness", math.max(0.001, math.min(0.5, tr.softness or 0.25)))
  TRAIL_SHADER:send("u_invert", (tr.invert and 1) or 0)
  TRAIL_SHADER:send("u_useGradient", useGradient)
  love.graphics.setShader(TRAIL_SHADER)
  love.graphics.draw(mesh)
  love.graphics.setShader()
  love.graphics.setBlendMode("alpha")
  love.graphics.pop()
end

return Trail


