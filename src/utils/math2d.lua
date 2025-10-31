local M = {}

function M.length(x, y)
  return math.sqrt(x * x + y * y)
end

function M.normalize(x, y)
  local len = M.length(x, y)
  if len == 0 then return 0, 0 end
  return x / len, y / len
end

function M.clamp(value, min, max)
  if value < min then return min end
  if value > max then return max end
  return value
end

function M.reflect(vx, vy, nx, ny)
  -- Reflect vector v across normal n (expects n normalized)
  local dot = vx * nx + vy * ny
  return vx - 2 * dot * nx, vy - 2 * dot * ny
end

return M


