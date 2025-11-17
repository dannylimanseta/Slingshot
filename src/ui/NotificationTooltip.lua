-- NotificationTooltip: Reusable notification tooltip component
-- Displays animated tooltips in the top-right corner of the screen
-- Supports fade in, hold, and fade out animations with upward movement
--
-- Usage example:
--   local NotificationTooltip = require("ui.NotificationTooltip")
--   local tooltip = NotificationTooltip.new()
--   
--   -- In update:
--   tooltip:update(dt)
--   
--   -- To show a notification:
--   tooltip:show({
--     name = "Item Name",
--     description = "Item description text",
--     icon = "path/to/icon.png"  -- optional
--   })
--   
--   -- In draw:
--   tooltip:draw(fadeAlpha)  -- fadeAlpha is optional (default: 1.0)
--
-- For stacking multiple tooltips:
--   tooltip1:setStackIndex(0)  -- First tooltip
--   tooltip2:setStackIndex(1)   -- Second tooltip (below first)

local config = require("config")
local theme = require("theme")

local NotificationTooltip = {}
NotificationTooltip.__index = NotificationTooltip

-- Default configuration
NotificationTooltip.defaults = {
  fadeInDuration = 0.2,    -- Fade in duration (seconds)
  holdDuration = 0.5,      -- Hold duration (seconds)
  fadeOutDuration = 0.2,   -- Fade out duration (seconds)
  moveDistance = 80,        -- Distance to move up during animation (pixels)
  iconSize = 48,            -- Icon size (pixels)
  iconPadding = 8,          -- Padding between icon and text
  padding = 8,              -- Internal padding
  textScale = 0.75,         -- Text scale factor
  maxTextWidth = 200,       -- Maximum text width before wrapping
  cornerRadius = 4,         -- Corner radius for rounded rectangle
  bgAlpha = 0.85,           -- Background alpha
  borderAlpha = 0.3,        -- Border alpha
  rightMargin = 20,         -- Margin from right edge
  topOffset = 20,           -- Offset from top bar
  stackOffset = 100,        -- Vertical offset when stacking multiple tooltips
}

function NotificationTooltip.new(opts)
  opts = opts or {}
  local defaults = NotificationTooltip.defaults
  
  local self = setmetatable({
    -- Animation state
    _active = false,
    _time = 0,
    _data = nil, -- { name, description, icon }
    
    -- Configuration
    fadeInDuration = opts.fadeInDuration or defaults.fadeInDuration,
    holdDuration = opts.holdDuration or defaults.holdDuration,
    fadeOutDuration = opts.fadeOutDuration or defaults.fadeOutDuration,
    moveDistance = opts.moveDistance or defaults.moveDistance,
    iconSize = opts.iconSize or defaults.iconSize,
    iconPadding = opts.iconPadding or defaults.iconPadding,
    padding = opts.padding or defaults.padding,
    textScale = opts.textScale or defaults.textScale,
    maxTextWidth = opts.maxTextWidth or defaults.maxTextWidth,
    cornerRadius = opts.cornerRadius or defaults.cornerRadius,
    bgAlpha = opts.bgAlpha or defaults.bgAlpha,
    borderAlpha = opts.borderAlpha or defaults.borderAlpha,
    rightMargin = opts.rightMargin or defaults.rightMargin,
    topOffset = opts.topOffset or defaults.topOffset,
    stackOffset = opts.stackOffset or defaults.stackOffset,
    
    -- Stacking support
    _stackIndex = 0, -- 0 = first, 1 = second, etc.
  }, NotificationTooltip)
  
  return self
end

-- Show a notification with the given data
-- data: { name, description, icon }
function NotificationTooltip:show(data)
  if not data then return end
  self._data = data
  self._time = 0
  self._active = true
end

-- Hide the notification immediately
function NotificationTooltip:hide()
  self._active = false
  self._data = nil
  self._time = 0
end

-- Check if the notification is currently active
function NotificationTooltip:isActive()
  return self._active and self._data ~= nil
end

-- Check if the notification animation has completed
function NotificationTooltip:isComplete()
  if not self._active then return true end
  local totalDuration = self.fadeInDuration + self.holdDuration + self.fadeOutDuration
  return self._time >= totalDuration
end

-- Set the stacking index (0 = first, 1 = second, etc.)
function NotificationTooltip:setStackIndex(index)
  self._stackIndex = index or 0
end

-- Update the animation (call in scene's update method)
function NotificationTooltip:update(dt)
  if not self._active then return end
  
  self._time = self._time + dt
  
  -- Auto-hide when animation completes
  if self:isComplete() then
    self._active = false
    self._data = nil
    self._time = 0
  end
end

-- Calculate animation progress values
function NotificationTooltip:_calculateAnimation()
  local totalDuration = self.fadeInDuration + self.holdDuration + self.fadeOutDuration
  
  -- Phase 1: Fade in + move up
  local fadeInProgress = 1.0
  local moveProgress = 0.0
  if self._time < self.fadeInDuration then
    local phaseT = self._time / self.fadeInDuration
    fadeInProgress = phaseT
    -- Ease-in-out cubic: t < 0.5 ? 4t³ : 1 - pow(-2t + 2, 3) / 2
    if phaseT < 0.5 then
      moveProgress = 4 * phaseT * phaseT * phaseT
    else
      moveProgress = 1 - math.pow(-2 * phaseT + 2, 3) / 2
    end
    -- Scale to 50% of total movement during fade in
    moveProgress = moveProgress * 0.5
  end
  
  -- Phase 2: Hold - movement stays at 50%
  local holdStart = self.fadeInDuration
  local holdEnd = holdStart + self.holdDuration
  if self._time >= holdStart and self._time <= holdEnd then
    moveProgress = 0.5
  end
  
  -- Phase 3: Fade out + move up more
  local fadeOutStart = self.fadeInDuration + self.holdDuration
  local fadeOutProgress = 1.0
  if self._time > fadeOutStart then
    local phaseT = (self._time - fadeOutStart) / self.fadeOutDuration
    fadeOutProgress = 1.0 - phaseT
    -- Ease-in-out for movement during fade out (from 50% to 100%)
    local moveOutT = phaseT
    local moveOutEased = 0.0
    if moveOutT < 0.5 then
      moveOutEased = 4 * moveOutT * moveOutT * moveOutT
    else
      moveOutEased = 1 - math.pow(-2 * moveOutT + 2, 3) / 2
    end
    -- Scale from 0.5 to 1.0
    moveProgress = 0.5 + (moveOutEased * 0.5)
  end
  
  return fadeInProgress, fadeOutProgress, moveProgress
end

-- Word wrap text to fit within max width
function NotificationTooltip:_wordWrap(text, maxWidth, font)
  local lines = {}
  for line in text:gmatch("[^\n]+") do
    table.insert(lines, line)
  end
  
  local wrappedLines = {}
  for _, line in ipairs(lines) do
    local words = {}
    for word in line:gmatch("%S+") do
      table.insert(words, word)
    end
    
    local currentLine = ""
    for _, word in ipairs(words) do
      local testLine = currentLine == "" and word or currentLine .. " " .. word
      local testW = font:getWidth(testLine)
      if testW > maxWidth and currentLine ~= "" then
        table.insert(wrappedLines, currentLine)
        currentLine = word
      else
        currentLine = testLine
      end
    end
    if currentLine ~= "" then
      table.insert(wrappedLines, currentLine)
    end
  end
  
  return wrappedLines
end

-- Draw the notification tooltip
-- fadeAlpha: Optional scene fade alpha multiplier (default: 1.0)
-- otherTooltips: Optional array of other active tooltips for stacking calculation
function NotificationTooltip:draw(fadeAlpha, otherTooltips)
  if not self:isActive() then return end
  
  fadeAlpha = fadeAlpha or 1.0
  local data = self._data
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  
  local font = theme.fonts.base
  love.graphics.setFont(font)
  
  -- Load icon
  local iconImg = nil
  if data.icon then
    local ok, img = pcall(love.graphics.newImage, data.icon)
    if ok then iconImg = img end
  end
  
  -- Build tooltip text (name + description)
  local tooltipText = ""
  if data.name then
    tooltipText = tooltipText .. data.name
  end
  if data.description then
    if tooltipText ~= "" then
      tooltipText = tooltipText .. "\n" .. data.description
    else
      tooltipText = data.description
    end
  end
  
  if tooltipText == "" then return end
  
  -- Calculate text size
  local textLines = {}
  for line in tooltipText:gmatch("[^\n]+") do
    table.insert(textLines, line)
  end
  
  local maxTextW = 0
  for _, line in ipairs(textLines) do
    local w = font:getWidth(line) * self.textScale
    if w > maxTextW then maxTextW = w end
  end
  
  local textW = maxTextW
  if textW > self.maxTextWidth then
    textW = self.maxTextWidth
  end
  
  -- Calculate tooltip dimensions
  local tooltipW = self.padding * 2
  if iconImg then
    tooltipW = tooltipW + self.iconSize + self.iconPadding
  end
  tooltipW = tooltipW + textW
  
  -- Calculate text wrap width
  local availableTextWidth = tooltipW - self.padding * 2
  if iconImg then
    availableTextWidth = availableTextWidth - self.iconSize - self.iconPadding
  end
  local textWrapWidth = availableTextWidth / self.textScale
  
  -- Word wrap text
  local wrappedLines = self:_wordWrap(tooltipText, textWrapWidth, font)
  local actualTextH = font:getHeight() * #wrappedLines * self.textScale
  local tooltipH = self.padding * 2 + math.max(self.iconSize, actualTextH)
  
  -- Calculate position (top right, with stacking support)
  local topBarHeight = (config.playfield and config.playfield.topBarHeight) or 60
  local startY = topBarHeight + self.topOffset
  
  -- Apply stacking offset based on stack index
  if self._stackIndex > 0 then
    startY = startY + (self._stackIndex * self.stackOffset)
  end
  
  -- Calculate animation progress
  local fadeInProgress, fadeOutProgress, moveProgress = self:_calculateAnimation()
  
  -- Apply movement
  local tooltipY = startY - (moveProgress * self.moveDistance)
  
  -- Position at top right
  local tooltipX = vw - tooltipW - self.rightMargin
  
  -- Calculate alpha (combine fade in, fade out, and scene fade)
  local alpha = fadeInProgress * fadeOutProgress * fadeAlpha
  
  -- Draw background
  love.graphics.setColor(0, 0, 0, self.bgAlpha * alpha)
  love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipW, tooltipH, 
                          self.cornerRadius, self.cornerRadius)
  
  -- Draw border
  love.graphics.setColor(1, 1, 1, self.borderAlpha * alpha)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", tooltipX, tooltipY, tooltipW, tooltipH, 
                          self.cornerRadius, self.cornerRadius)
  
  -- Draw icon (top left)
  if iconImg then
    local iconX = tooltipX + self.padding
    local iconY = tooltipY + self.padding
    local iconScale = self.iconSize / math.max(iconImg:getWidth(), iconImg:getHeight())
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(iconImg, iconX, iconY, 0, iconScale, iconScale)
  end
  
  -- Draw text (to the right of icon, or left if no icon)
  local textX = tooltipX + self.padding
  if iconImg then
    textX = textX + self.iconSize + self.iconPadding
  end
  local textY = tooltipY + self.padding
  
  love.graphics.push()
  love.graphics.translate(textX, textY)
  love.graphics.scale(self.textScale, self.textScale)
  local currentY = 0
  for i, line in ipairs(wrappedLines) do
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.print(line, 0, currentY)
    currentY = currentY + font:getHeight()
  end
  love.graphics.pop()
end

return NotificationTooltip

