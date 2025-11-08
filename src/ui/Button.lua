local theme = require("theme")

local Button = {}
Button.__index = Button

-- Global defaults for all buttons (change here to affect all)
Button.defaults = {
  hoverScale = 1.05,  -- background scale on hover
  tweenSpeed = 12.0,  -- how quickly hover scale eases
  cornerRadius = 10,
  paddingX = 20,
  paddingY = 8,
  bgColor = { 0, 0, 0, 0.55 },
  textColor = { 0.78, 0.92, 0.6, 1 }, -- light green (matches stepFilled)
}

function Button.new(opts)
  opts = opts or {}
  local self = setmetatable({
    x = opts.x or 0,
    y = opts.y or 0,
    w = opts.w or 120,
    h = opts.h or 40,
    label = opts.label or "Button",
    font = opts.font or theme.fonts.base,
    icon = opts.icon or nil, -- love Image
    iconScale = opts.iconScale or 1.0,
    iconTint = opts.iconTint or { 1, 1, 1, 0.8 },
    align = opts.align or "left", -- "left" or "center"
    onClick = opts.onClick,
    bgColor = opts.bgColor, -- optional per-instance override
    alpha = opts.alpha or 1.0, -- overall opacity multiplier
    -- internal state
    _hovered = false,
    _scale = 1.0,
    _hitRect = { x = 0, y = 0, w = 0, h = 0 },
  }, Button)
  return self
end

function Button:setLayout(x, y, w, h)
  self.x, self.y, self.w, self.h = x, y, w, h
end

function Button:update(dt, mouseX, mouseY)
  -- Determine hover using current hit rect (from last frame's scale)
  local r = self._hitRect
  if r and mouseX and mouseY then
    self._hovered = (mouseX >= r.x and mouseX <= r.x + r.w and mouseY >= r.y and mouseY <= r.y + r.h)
  else
    self._hovered = false
  end
  -- Tween scale toward target
  local target = self._hovered and Button.defaults.hoverScale or 1.0
  local k = math.min(1, dt * Button.defaults.tweenSpeed)
  self._scale = self._scale + (target - self._scale) * k
end

function Button:draw()
  if not self.font then self.font = theme.fonts.base end
  love.graphics.push()
  -- Compute center and effective hit rect based on scale
  local cx = self.x + self.w * 0.5
  local cy = self.y + self.h * 0.5
  local s = self._scale or 1.0
  local drawW = self.w * s
  local drawH = self.h * s
  self._hitRect.x = math.floor(cx - drawW * 0.5)
  self._hitRect.y = math.floor(cy - drawH * 0.5)
  self._hitRect.w = math.floor(drawW)
  self._hitRect.h = math.floor(drawH)

  -- Enter scaled space to grow/shrink both background and content
  love.graphics.translate(cx, cy)
  love.graphics.scale(s, s)

  -- Background
  local bg = self.bgColor or Button.defaults.bgColor
  love.graphics.setColor(bg[1], bg[2], bg[3], (bg[4] or 1) * (self.alpha or 1))
  love.graphics.rectangle("fill", -self.w * 0.5, -self.h * 0.5, self.w, self.h, Button.defaults.cornerRadius, Button.defaults.cornerRadius)

  -- Icon + text (scaled together)
  love.graphics.setFont(self.font)
  local tw = self.font:getWidth(self.label)
  local th = self.font:getHeight()

  local iconW, iconH = 0, 0
  if self.icon then
    local iw, ih = self.icon:getWidth(), self.icon:getHeight()
    iconW = iw * (self.iconScale or 1.0)
    iconH = ih * (self.iconScale or 1.0)
  end

  local spacing = (self.icon and 16) or 0
  local contentWidth = iconW + spacing + tw

  local startX
  if self.align == "center" then
    startX = -contentWidth * 0.5
  else
    startX = -self.w * 0.5 + Button.defaults.paddingX
  end

  local centerY = -th * 0.5
  if self.icon then
    local it = self.iconTint or {1,1,1,1}
    love.graphics.setColor(it[1], it[2], it[3], (it[4] or 1) * (self.alpha or 1))
    love.graphics.draw(self.icon, startX, -iconH * 0.5, 0, (self.iconScale or 1.0), (self.iconScale or 1.0))
    startX = startX + iconW + spacing
  end

  local tc = Button.defaults.textColor
  love.graphics.setColor(tc[1], tc[2], tc[3], (tc[4] or 1) * (self.alpha or 1))
  love.graphics.print(self.label, startX, centerY)

  love.graphics.pop()
end

function Button:mousepressed(x, y, button)
  if button ~= 1 then return false end
  local r = self._hitRect
  if r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
    if self.onClick then self.onClick(self) end
    return true
  end
  return false
end

return Button


