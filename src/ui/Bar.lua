local theme = require("theme")

local Bar = {}
Bar.__index = Bar

function Bar.new()
  return setmetatable({}, Bar)
end

function Bar:draw(x, y, w, h, current, max, color)
  local ratio = 0
  if max > 0 then ratio = math.max(0, math.min(1, current / max)) end
  love.graphics.setColor(0, 0, 0, 0.35)
  love.graphics.rectangle("fill", x, y, w, h, 6, 6)
  -- Only draw colored bar if HP > 0
  if ratio > 0 then
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.rectangle("fill", x, y, w * ratio, h, 6, 6)
  end
  -- Draw black border around HP bar
  love.graphics.setColor(0, 0, 0, 1)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, w, h, 6, 6)
  -- Centered HP text (current/max) - scaled down by 30%
  do
    local font = theme.fonts.base
    local fontScale = 0.7 -- 30% reduction
    love.graphics.push()
    love.graphics.scale(fontScale, fontScale)
    love.graphics.setFont(font)
    local cur = math.max(0, math.floor(current or 0))
    local mx = math.max(0, math.floor(max or 0))
    local text = tostring(cur) .. "/" .. tostring(mx)
    local tw = font:getWidth(text) * fontScale
    local th = font:getHeight() * fontScale
    local tx = (x + (w - tw) * 0.5) / fontScale
    local ty = (y + (h - th) * 0.5) / fontScale
    theme.drawTextWithOutline(text, tx, ty, 1, 1, 1, 0.95, 2)
    love.graphics.pop()
  end
  love.graphics.setColor(1, 1, 1, 1)
end

return Bar


