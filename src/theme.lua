local theme = {}
local config = require("config")

-- Colors in 0..1 range
theme.colors = {
  background = { 0.08, 0.09, 0.12, 1 },
  uiText = { 1, 1, 1, 0.75 },
  aim = { 0.3, 0.8, 1, 0.7 },
  ball = { 1, 1, 1, 1 },
  block = { 0.95, 0.6, 0.25, 1 },
  blockOutline = { 0, 0, 0, 0.2 },
  blockArmor = { 0.35, 0.75, 0.95, 1 },
  shooter = { 0.8, 0.9, 0.2, 1 },
}

do
  local fontPath = (config.assets and config.assets.fonts and config.assets.fonts.ui) or nil
  local base, large, popup, jackpot
  if fontPath then
    local ok1, f1 = pcall(love.graphics.newFont, fontPath, 20)
    local ok2, f2 = pcall(love.graphics.newFont, fontPath, 67)
    local ok3, f3 = pcall(love.graphics.newFont, fontPath, 40)
    local ok4, f4 = pcall(love.graphics.newFont, fontPath, 80)
    if ok1 then base = f1 end
    if ok2 then large = f2 end
    if ok3 then popup = f3 end
    if ok4 then jackpot = f4 end
  end
  theme.fonts = {
    base = base or love.graphics.newFont(20),
    large = large or love.graphics.newFont(67),
    popup = popup or love.graphics.newFont(40),
    jackpot = jackpot or love.graphics.newFont(100),
  }
end

-- Helper function to draw text with black outline for better legibility
function theme.drawTextWithOutline(text, x, y, r, g, b, a, outlineWidth)
  outlineWidth = outlineWidth or 2
  a = a or 1
  r = r or 1
  g = g or 1
  b = b or 1
  
  -- Draw black outline by drawing text in 8 directions (optimized)
  love.graphics.setColor(0, 0, 0, a)
  for i = 1, outlineWidth do
    love.graphics.print(text, x - i, y) -- left
    love.graphics.print(text, x + i, y) -- right
    love.graphics.print(text, x, y - i) -- up
    love.graphics.print(text, x, y + i) -- down
    love.graphics.print(text, x - i, y - i) -- top-left
    love.graphics.print(text, x + i, y - i) -- top-right
    love.graphics.print(text, x - i, y + i) -- bottom-left
    love.graphics.print(text, x + i, y + i) -- bottom-right
  end
  
  -- Draw main text on top
  love.graphics.setColor(r, g, b, a)
  love.graphics.print(text, x, y)
end

-- Helper function to draw formatted text with black outline
function theme.printfWithOutline(text, x, y, limit, align, r, g, b, a, outlineWidth)
  outlineWidth = outlineWidth or 2
  a = a or 1
  r = r or 1
  g = g or 1
  b = b or 1
  
  -- Draw black outline by drawing text in 8 directions (optimized)
  love.graphics.setColor(0, 0, 0, a)
  for i = 1, outlineWidth do
    love.graphics.printf(text, x - i, y, limit, align) -- left
    love.graphics.printf(text, x + i, y, limit, align) -- right
    love.graphics.printf(text, x, y - i, limit, align) -- up
    love.graphics.printf(text, x, y + i, limit, align) -- down
    love.graphics.printf(text, x - i, y - i, limit, align) -- top-left
    love.graphics.printf(text, x + i, y - i, limit, align) -- top-right
    love.graphics.printf(text, x - i, y + i, limit, align) -- bottom-left
    love.graphics.printf(text, x + i, y + i, limit, align) -- bottom-right
  end
  
  -- Draw main text on top
  love.graphics.setColor(r, g, b, a)
  love.graphics.printf(text, x, y, limit, align)
end

return theme


