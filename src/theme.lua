local theme = {}
local config = require("config")

-- Colors in 0..1 range
theme.colors = {
  -- Background: hex #21232E -> {33,35,46}/255
  background = { 33/255, 35/255, 46/255, 1 },
  -- Top bar: hex #0E1014 -> {14,16,20}/255
  topbar = { 14/255, 16/255, 20/255, 1 },
  topbarDivider = { 0, 0, 0, 1 },
  uiText = { 1, 1, 1, 0.75 },
  uiTextStrong = { 1, 1, 1, 1 },
  aim = { 0.3, 0.8, 1, 0.7 },
  ball = { 1, 1, 1, 1 },
  block = { 0.95, 0.6, 0.25, 1 },
  blockOutline = { 0, 0, 0, 0.2 },
  blockArmor = { 0.35, 0.75, 0.95, 1 },
  shooter = { 0.8, 0.9, 0.2, 1 },
  -- Steps indicator (top bar)
  stepFilled = { 0.78, 0.92, 0.6, 1 },   -- light green
  stepEmpty = { 0.18, 0.2, 0.22, 1 },     -- dark gray
}

-- Shared UI metrics
theme.metrics = {
  stepCornerRadius = 3, -- corner radius for step rectangles in the top bar
}

-- Get supersampling factor for font scaling
local function getSupersamplingFactor()
  if config.video and config.video.supersampling and config.video.supersampling.enabled then
    return config.video.supersampling.factor or 1
  end
  return 1
end

-- Wrap a font to scale down measurements for layout calculations
local function wrapFont(font, scale)
  if scale <= 1 then return font end
  
  local wrapper = {
    _font = font,
    _scale = scale,
    _invScale = 1 / scale
  }
  
  -- Proxy all font methods, scaling measurements
  setmetatable(wrapper, {
    __index = function(t, k)
      local fontMethod = font[k]
      if type(fontMethod) == "function" then
        if k == "getWidth" or k == "getHeight" or k == "getAscent" or k == "getDescent" or k == "getBaseline" or k == "getLineHeight" then
          return function(self, ...)
            local result = fontMethod(font, ...)
            return result * wrapper._invScale
          end
        else
          -- For setFont and other methods, pass through to actual font
          return function(self, ...)
            return fontMethod(font, ...)
          end
        end
      elseif k == "_font" then
        -- Allow access to underlying font for setFont
        return font
      else
        return fontMethod
      end
    end,
    __call = function(self, ...)
      -- If wrapper is called directly, return the actual font
      return font
    end
  })
  
  return wrapper
end

-- Helper function to create a font at supersampled resolution for crisp rendering
-- baseSize: the desired font size at virtual resolution
-- Returns: a wrapped font object that scales measurements correctly
function theme.newFont(baseSize, fontPath)
  fontPath = fontPath or (config.assets and config.assets.fonts and config.assets.fonts.ui) or nil
  
  -- Create font at supersampled resolution for crisp rendering
  local supersamplingFactor = getSupersamplingFactor()
  local scaledSize = baseSize * supersamplingFactor
  
  local font
  if fontPath then
    local ok, f = pcall(love.graphics.newFont, fontPath, scaledSize)
    if ok then font = f end
  end
  
  if not font then
    font = love.graphics.newFont(scaledSize)
  end
  
  -- Wrap font to scale measurements
  return wrapFont(font, supersamplingFactor)
end

-- Store original love.graphics functions
local originalPrint = love.graphics.print
local originalPrintf = love.graphics.printf

-- Override love.graphics.setFont to handle wrapped fonts
local originalSetFont = love.graphics.setFont
love.graphics.setFont = function(font)
  -- If font is wrapped, extract the actual font
  if font and font._font then
    return originalSetFont(font._font)
  end
  return originalSetFont(font)
end

-- Override love.graphics.print to automatically scale down supersampled fonts
love.graphics.print = function(text, x, y, r, sx, sy, ox, oy, kx, ky)
  local scale = theme._supersamplingFactor or 1
  if scale > 1 then
    local invScale = 1 / scale
    love.graphics.push()
    love.graphics.translate(x or 0, y or 0)
    love.graphics.scale(invScale, invScale)
    originalPrint(text, 0, 0, r, sx, sy, ox, oy, kx, ky)
    love.graphics.pop()
  else
    originalPrint(text, x, y, r, sx, sy, ox, oy, kx, ky)
  end
end

-- Override love.graphics.printf to automatically scale down supersampled fonts
love.graphics.printf = function(text, x, y, limit, align, r, g, b, a)
  local scale = theme._supersamplingFactor or 1
  if scale > 1 then
    local invScale = 1 / scale
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(invScale, invScale)
    originalPrintf(text, 0, 0, limit * scale, align, r, g, b, a)
    love.graphics.pop()
  else
    originalPrintf(text, x, y, limit, align, r, g, b, a)
  end
end

do
  local fontPath = (config.assets and config.assets.fonts and config.assets.fonts.ui) or nil
  local supersamplingFactor = getSupersamplingFactor()
  -- Increased base font size from 20 to 24 for better readability in UI elements
  local baseSize = 24
  local tiny, small, base, large, popup, jackpot
  if fontPath then
    local ok00, f00 = pcall(love.graphics.newFont, fontPath, 10 * supersamplingFactor)
    local ok0, f0 = pcall(love.graphics.newFont, fontPath, 16 * supersamplingFactor)
    local ok1, f1 = pcall(love.graphics.newFont, fontPath, baseSize * supersamplingFactor)
    local ok2, f2 = pcall(love.graphics.newFont, fontPath, 67 * supersamplingFactor)
    local ok3, f3 = pcall(love.graphics.newFont, fontPath, 40 * supersamplingFactor)
    local ok4, f4 = pcall(love.graphics.newFont, fontPath, 80 * supersamplingFactor)
    if ok00 then tiny = wrapFont(f00, supersamplingFactor) end
    if ok0 then small = wrapFont(f0, supersamplingFactor) end
    if ok1 then base = wrapFont(f1, supersamplingFactor) end
    if ok2 then large = wrapFont(f2, supersamplingFactor) end
    if ok3 then popup = wrapFont(f3, supersamplingFactor) end
    if ok4 then jackpot = wrapFont(f4, supersamplingFactor) end
  end
  if not tiny then tiny = wrapFont(love.graphics.newFont(10 * supersamplingFactor), supersamplingFactor) end
  if not small then small = wrapFont(love.graphics.newFont(16 * supersamplingFactor), supersamplingFactor) end
  if not base then base = wrapFont(love.graphics.newFont(baseSize * supersamplingFactor), supersamplingFactor) end
  if not large then large = wrapFont(love.graphics.newFont(67 * supersamplingFactor), supersamplingFactor) end
  if not popup then popup = wrapFont(love.graphics.newFont(40 * supersamplingFactor), supersamplingFactor) end
  if not jackpot then jackpot = wrapFont(love.graphics.newFont(100 * supersamplingFactor), supersamplingFactor) end
  
  theme.fonts = {
    tiny = tiny,
    small = small,
    base = base,
    large = large,
    popup = popup,
    jackpot = jackpot,
  }
  -- Store supersampling factor for text drawing helpers
  theme._supersamplingFactor = supersamplingFactor
end

-- Helper function to draw text with black outline for better legibility
-- Automatically handles scaling for crisp supersampled fonts
function theme.drawTextWithOutline(text, x, y, r, g, b, a, outlineWidth)
  outlineWidth = outlineWidth or 2
  a = a or 1
  r = r or 1
  g = g or 1
  b = b or 1
  
  local scale = theme._supersamplingFactor or 1
  local invScale = 1 / scale
  
  -- Scale down to compensate for supersampled font size
  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.scale(invScale, invScale)
  
  -- Draw black outline by drawing text in 8 directions (optimized)
  -- Use originalPrint to avoid double-scaling
  love.graphics.setColor(0, 0, 0, a)
  for i = 1, outlineWidth do
    originalPrint(text, -i * scale, 0) -- left
    originalPrint(text, i * scale, 0) -- right
    originalPrint(text, 0, -i * scale) -- up
    originalPrint(text, 0, i * scale) -- down
    originalPrint(text, -i * scale, -i * scale) -- top-left
    originalPrint(text, i * scale, -i * scale) -- top-right
    originalPrint(text, -i * scale, i * scale) -- bottom-left
    originalPrint(text, i * scale, i * scale) -- bottom-right
  end
  
  -- Draw main text on top
  love.graphics.setColor(r, g, b, a)
  originalPrint(text, 0, 0)
  
  love.graphics.pop()
end

-- Helper function to draw formatted text with black outline
-- Automatically handles scaling for crisp supersampled fonts
function theme.printfWithOutline(text, x, y, limit, align, r, g, b, a, outlineWidth)
  outlineWidth = outlineWidth or 2
  a = a or 1
  r = r or 1
  g = g or 1
  b = b or 1
  
  local scale = theme._supersamplingFactor or 1
  local invScale = 1 / scale
  
  -- Scale down to compensate for supersampled font size
  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.scale(invScale, invScale)
  
  -- Draw black outline by drawing text in 8 directions (optimized)
  -- Use originalPrintf to avoid double-scaling
  love.graphics.setColor(0, 0, 0, a)
  for i = 1, outlineWidth do
    originalPrintf(text, -i * scale, 0, limit * scale, align) -- left
    originalPrintf(text, i * scale, 0, limit * scale, align) -- right
    originalPrintf(text, 0, -i * scale, limit * scale, align) -- up
    originalPrintf(text, 0, i * scale, limit * scale, align) -- down
    originalPrintf(text, -i * scale, -i * scale, limit * scale, align) -- top-left
    originalPrintf(text, i * scale, -i * scale, limit * scale, align) -- top-right
    originalPrintf(text, -i * scale, i * scale, limit * scale, align) -- bottom-left
    originalPrintf(text, i * scale, i * scale, limit * scale, align) -- bottom-right
  end
  
  -- Draw main text on top
  love.graphics.setColor(r, g, b, a)
  originalPrintf(text, 0, 0, limit * scale, align)
  
  love.graphics.pop()
end

return theme


