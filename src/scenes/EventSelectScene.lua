local config = require("config")
local theme = require("theme")
local events = require("data.events")
local PlayerState = require("core.PlayerState")

local EventSelectScene = {}
EventSelectScene.__index = EventSelectScene

local function virtualSize()
  local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
  local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
  return vw, vh
end

local function clamp(value, minVal, maxVal)
  return math.max(minVal, math.min(maxVal, value))
end

function EventSelectScene.new()
  return setmetatable({
    entries = {},
    selectedIndex = 1,
    hoveredIndex = nil,
    previousScene = nil,
    scroll = {
      y = 0,
      target = 0,
      smoothing = 12,
    },
    mouse = { x = 0, y = 0 },
    layout = {
      rowHeight = 32,
      rowSpacing = 4,
      listPadding = 16,
    },
  }, EventSelectScene)
end

function EventSelectScene:setPreviousScene(scene)
  self.previousScene = scene
end

function EventSelectScene:load()
  self:_refreshEntries()
end

function EventSelectScene:update(dt)
  local diff = self.scroll.target - self.scroll.y
  if math.abs(diff) > 0.25 then
    local smoothing = self.scroll.smoothing or 12
    self.scroll.y = self.scroll.y + diff * math.min(1, dt * smoothing)
  else
    self.scroll.y = self.scroll.target
  end

  self:_clampScroll()
  self:_updateHoverFromMouse()
  
  return nil
end

function EventSelectScene:draw()
  local w, h = virtualSize()
  love.graphics.setColor(0, 0, 0, 0.84)
  love.graphics.rectangle("fill", 0, 0, w, h)

  local titleFont = theme.fonts.large or theme.fonts.title or theme.fonts.base
  local subtitleFont = theme.fonts.small or theme.fonts.base

  -- Title
  love.graphics.setFont(titleFont)
  love.graphics.setColor(1, 1, 1, 0.95)
  love.graphics.print("EVENTS DEBUG MENU", 48, 36)

  -- Instructions
  love.graphics.setFont(subtitleFont)
  love.graphics.setColor(1, 1, 1, 0.65)
  love.graphics.print("Click to open • Enter/Space to open • Esc to return", 48, 76)

  local listX = math.floor(w * 0.2)
  local listW = math.floor(w * 0.6)
  local listY = 120
  local listH = math.floor(h - listY - 60)

  -- Background panel
  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", listX - 10, listY - 10, listW + 20, listH + 20, 8, 8)
  love.graphics.setColor(0.12, 0.16, 0.24, 0.92)
  love.graphics.rectangle("fill", listX, listY, listW, listH, 6, 6)

  self:_drawEventList(listX, listY, listW, listH)
  self:_drawScrollBar(listX + listW + 12, listY, listH)
end

function EventSelectScene:keypressed(key, scancode, isRepeat)
  if isRepeat then return nil end

  if key == "up" then
    self:_moveSelection(-1)
  elseif key == "down" then
    self:_moveSelection(1)
  elseif key == "pageup" then
    self:_moveSelection(-5)
  elseif key == "pagedown" then
    self:_moveSelection(5)
  elseif key == "home" then
    self:_setSelection(1)
  elseif key == "end" then
    self:_setSelection(#self.entries)
  elseif key == "return" or key == "enter" or key == "space" then
    self:_openSelectedEvent()
  elseif key == "escape" then
    return "cancel"
  end

  return nil
end

function EventSelectScene:mousemoved(x, y)
  self.mouse.x, self.mouse.y = x, y
  self:_updateHoverFromMouse()
end

function EventSelectScene:mousepressed(x, y, button)
  if button ~= 1 then return nil end

  local listRect = self:_listRect()
  if not self:_pointInRect(x, y, listRect) then
    return nil
  end

  local index = self:_indexAtPosition(x, y)
  if index then
    self:_setSelection(index)
    -- Open event immediately on click
    return self:_openSelectedEvent()
  end

  return nil
end

function EventSelectScene:wheelmoved(dx, dy)
  if dy == 0 then return end
  local listRect = self:_listRect()
  local totalHeight = self:_contentHeight()
  local viewHeight = listRect.h - self.layout.listPadding * 2
  if totalHeight <= viewHeight then return end

  local step = (self.layout.rowHeight + self.layout.rowSpacing) * 1.2
  self.scroll.target = clamp(self.scroll.target - dy * step, 0, totalHeight - viewHeight)
end

function EventSelectScene:_refreshEntries()
  local eventList = events.list() or {}
  self.entries = {}
  for _, event in ipairs(eventList) do
    table.insert(self.entries, {
      id = event.id,
      title = event.title or event.id,
    })
  end

  if #self.entries == 0 then
    self.selectedIndex = 0
  else
    self.selectedIndex = clamp(self.selectedIndex, 1, #self.entries)
  end
  self.scroll.y = 0
  self.scroll.target = 0
end

function EventSelectScene:_drawEventList(listX, listY, listW, listH)
  local padding = self.layout.listPadding
  local innerX = listX + padding
  local innerY = listY + padding
  local innerW = listW - padding * 2

  -- Scale scissor coordinates by supersampling factor (scissor uses actual canvas pixels, not virtual resolution)
  local supersamplingFactor = _G.supersamplingFactor or 1
  local scissorX = listX * supersamplingFactor
  local scissorY = listY * supersamplingFactor
  local scissorW = listW * supersamplingFactor
  local scissorH = listH * supersamplingFactor
  love.graphics.setScissor(scissorX, scissorY, scissorW, scissorH)
  love.graphics.push()
  love.graphics.translate(0, -self.scroll.y)

  local baseFont = theme.fonts.base
  local rowHeight = self.layout.rowHeight
  local spacing = self.layout.rowSpacing

  local player = PlayerState.getInstance()
  local seenEvents = player and player.seenEvents or {}

  for index, entry in ipairs(self.entries) do
    local rowY = innerY + (index - 1) * (rowHeight + spacing)
    local isHovered = (index == self.hoveredIndex)
    local isSelected = (index == self.selectedIndex)
    local isSeen = seenEvents[entry.id] == true

    -- Background
    local fillAlpha = isHovered and 0.7 or (isSelected and 0.6 or 0.5)
    love.graphics.setColor(0.16, 0.22, 0.34, fillAlpha)
    love.graphics.rectangle("fill", innerX, rowY, innerW, rowHeight, 4, 4)

    -- Selection indicator
    if isSelected then
      love.graphics.setColor(0.32, 0.58, 0.96, 0.95)
      love.graphics.setFont(baseFont)
      love.graphics.print("→", innerX + 12, rowY + 8)
    end

    -- Seen indicator (subtle)
    if isSeen then
      love.graphics.setColor(0.5, 0.5, 0.5, 0.6)
      love.graphics.setFont(baseFont)
      love.graphics.print("•", innerX + (isSelected and 36 or 16), rowY + 8)
    end

    -- Event title
    love.graphics.setFont(baseFont)
    love.graphics.setColor(1, 1, 1, isSeen and 0.7 or 0.95)
    local textX = innerX + (isSelected and 36 or 16) + (isSeen and 20 or 0)
    love.graphics.print(entry.title, textX, rowY + 8)
  end

  love.graphics.pop()
  love.graphics.setScissor()
end

function EventSelectScene:_drawScrollBar(barX, listY, listH)
  local totalHeight = self:_contentHeight()
  local viewHeight = listH - self.layout.listPadding * 2
  if totalHeight <= viewHeight then return end

  local thumbHeight = math.max(36, (viewHeight / totalHeight) * (listH - 20))
  local availableHeight = listH - 20 - thumbHeight
  local scrollRatio = self.scroll.y / (totalHeight - viewHeight)
  local thumbY = listY + 10 + availableHeight * scrollRatio

  love.graphics.setColor(0, 0, 0, 0.38)
  love.graphics.rectangle("fill", barX - 2, listY + 10, 6, listH - 20, 3, 3)
  love.graphics.setColor(0.32, 0.58, 0.96, 0.9)
  love.graphics.rectangle("fill", barX - 3, thumbY, 8, thumbHeight, 3, 3)
end

function EventSelectScene:_moveSelection(delta)
  if #self.entries == 0 then return end
  local newIndex = clamp(self.selectedIndex + delta, 1, #self.entries)
  self:_setSelection(newIndex)
end

function EventSelectScene:_setSelection(index)
  if #self.entries == 0 then
    self.selectedIndex = 0
    return
  end
  self.selectedIndex = clamp(index, 1, #self.entries)
  self:_scrollSelectionIntoView()
end

function EventSelectScene:_openSelectedEvent()
  local entry = self.entries[self.selectedIndex]
  if not entry then return end

  return { type = "open_event", eventId = entry.id }
end

function EventSelectScene:_updateHoverFromMouse()
  local index = self:_indexAtPosition(self.mouse.x, self.mouse.y)
  self.hoveredIndex = index
end

function EventSelectScene:_indexAtPosition(x, y)
  local listRect = self:_listRect()
  if not self:_pointInRect(x, y, listRect) then
    return nil
  end

  local padding = self.layout.listPadding
  local innerY = listRect.y + padding
  local localY = y + self.scroll.y - innerY
  local rowSlot = self.layout.rowHeight + self.layout.rowSpacing
  if rowSlot <= 0 then return nil end

  local index = math.floor(localY / rowSlot) + 1
  if index < 1 or index > #self.entries then
    return nil
  end

  local offsetWithinRow = localY % rowSlot
  if offsetWithinRow > self.layout.rowHeight then
    return nil
  end

  return index
end

function EventSelectScene:_scrollSelectionIntoView()
  local listRect = self:_listRect()
  local padding = self.layout.listPadding
  local innerY = listRect.y + padding
  local viewHeight = listRect.h - padding * 2
  if viewHeight <= 0 then return end

  local rowSlot = self.layout.rowHeight + self.layout.rowSpacing
  local top = innerY + (self.selectedIndex - 1) * rowSlot
  local bottom = top + self.layout.rowHeight

  if top < innerY + self.scroll.target then
    self.scroll.target = math.max(0, top - innerY)
  elseif bottom > innerY + self.scroll.target + viewHeight then
    self.scroll.target = math.min(bottom - innerY - viewHeight, self:_contentHeight() - viewHeight)
  end
end

function EventSelectScene:_clampScroll()
  local listRect = self:_listRect()
  local padding = self.layout.listPadding
  local viewHeight = listRect.h - padding * 2
  local totalHeight = self:_contentHeight()
  if totalHeight <= viewHeight then
    self.scroll.y = 0
    self.scroll.target = 0
    return
  end
  local maxScroll = totalHeight - viewHeight
  self.scroll.y = clamp(self.scroll.y, 0, maxScroll)
  self.scroll.target = clamp(self.scroll.target, 0, maxScroll)
end

function EventSelectScene:_contentHeight()
  if #self.entries == 0 then return 0 end
  local rowSlot = self.layout.rowHeight + self.layout.rowSpacing
  return #self.entries * rowSlot - self.layout.rowSpacing
end

function EventSelectScene:_listRect()
  local w, h = virtualSize()
  local listX = math.floor(w * 0.2)
  local listW = math.floor(w * 0.6)
  local listY = 120
  local listH = math.floor(h - listY - 60)
  return { x = listX, y = listY, w = listW, h = listH }
end

function EventSelectScene:_pointInRect(x, y, rect)
  return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

return EventSelectScene

