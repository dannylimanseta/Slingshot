local collision = {}

-- Circle vs AABB collision with bounce normal
function collision.circleAABB(cx, cy, radius, rx, ry, rw, rh)
  local closestX = math.max(rx, math.min(cx, rx + rw))
  local closestY = math.max(ry, math.min(cy, ry + rh))
  local dx = cx - closestX
  local dy = cy - closestY
  local distSq = dx * dx + dy * dy
  if distSq > radius * radius then
    return false
  end

  -- Normal is from rectangle to circle contact point
  local nx, ny = 0, 0
  if dx == 0 and dy == 0 then
    -- Rare: center exactly on corner/edge; choose axis by deeper penetration
    local leftPen = (cx - rx)
    local rightPen = ((rx + rw) - cx)
    local topPen = (cy - ry)
    local bottomPen = ((ry + rh) - cy)
    local minPen = math.min(leftPen, rightPen, topPen, bottomPen)
    if minPen == leftPen then nx = -1 elseif minPen == rightPen then nx = 1 elseif minPen == topPen then ny = -1 else ny = 1 end
  else
    local len = math.sqrt(distSq)
    nx, ny = dx / len, dy / len
  end
  return true, nx, ny
end

return collision


