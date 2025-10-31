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
  -- Draw dark grey border around HP bar
  love.graphics.setColor(0.25, 0.25, 0.25, 1) -- dark grey
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, w, h, 6, 6)
  -- Centered HP text (current/max)
  do
    local font = theme.fonts.base
    love.graphics.setFont(font)
    local cur = math.max(0, math.floor(current or 0))
    local mx = math.max(0, math.floor(max or 0))
    local text = tostring(cur) .. "/" .. tostring(mx)
    local tw = font:getWidth(text)
    local th = font:getHeight()
    local tx = x + (w - tw) * 0.5
    local ty = y + (h - th) * 0.5
    theme.drawTextWithOutline(text, tx, ty, 1, 1, 1, 0.95, 2)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

return Bar


