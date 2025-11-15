local config = require("config")
local theme = require("theme")
local relics = require("data.relics")
local PlayerState = require("core.PlayerState")
local RelicSystem = require("core.RelicSystem")

local RelicSelectScene = {}
RelicSelectScene.__index = RelicSelectScene

local RARITY_COLORS = {
  common = { 0.75, 0.75, 0.75, 0.9 },
  uncommon = { 0.38, 0.78, 0.48, 0.95 },
  rare = { 0.35, 0.58, 0.94, 0.95 },
  epic = { 0.74, 0.46, 0.94, 0.95 },
  legendary = { 0.98, 0.76, 0.32, 0.95 },
}

local function virtualSize()
  local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
  local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
  return vw, vh
end

local function clamp(value, minVal, maxVal)
  return math.max(minVal, math.min(maxVal, value))
end

function RelicSelectScene.new()
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
      rowHeight = 68,
      rowSpacing = 10,
      listPadding = 20,
    },
  }, RelicSelectScene)
end

function RelicSelectScene:setPreviousScene(scene)
  self.previousScene = scene
end

function RelicSelectScene:load()
  self:_refreshEntries()
end

function RelicSelectScene:update(dt)
  local diff = self.scroll.target - self.scroll.y
  if math.abs(diff) > 0.25 then
    local smoothing = self.scroll.smoothing or 12
    self.scroll.y = self.scroll.y + diff * math.min(1, dt * smoothing)
  else
    self.scroll.y = self.scroll.target
  end

  self:_clampScroll()
  self:_updateHoverFromMouse()
end

function RelicSelectScene:draw()
  local w, h = virtualSize()
  love.graphics.setColor(0, 0, 0, 0.84)
  love.graphics.rectangle("fill", 0, 0, w, h)

  local titleFont = theme.fonts.large or theme.fonts.title or theme.fonts.base
  local subtitleFont = theme.fonts.small or theme.fonts.base

  love.graphics.setFont(subtitleFont)
  love.graphics.setColor(1, 1, 1, 0.65)
  love.graphics.print("Up/Down to navigate • Enter to toggle equip • A equip all • C clear all • Esc to return", 48, 48)

  local listX = math.floor(w * 0.2)
  local listW = math.floor(w * 0.6)
  local listY = 140
  local listH = math.floor(h - listY - 80)

  -- Background panel
  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", listX - 10, listY - 10, listW + 20, listH + 20, 12, 12)
  love.graphics.setColor(0.12, 0.16, 0.24, 0.92)
  love.graphics.rectangle("fill", listX, listY, listW, listH, 10, 10)

  self:_drawRelicList(listX, listY, listW, listH)
  self:_drawScrollBar(listX + listW + 12, listY, listH)
end

function RelicSelectScene:keypressed(key, scancode, isRepeat)
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
    self:_toggleSelectedRelic()
  elseif key == "a" then
    self:_equipAll()
  elseif key == "c" or key == "delete" or key == "backspace" then
    self:_clearAll()
  elseif key == "escape" then
    return "cancel"
  end

  return nil
end

function RelicSelectScene:mousemoved(x, y)
  self.mouse.x, self.mouse.y = x, y
  self:_updateHoverFromMouse()
end

function RelicSelectScene:mousepressed(x, y, button)
  if button ~= 1 then return nil end

  local listRect = self:_listRect()
  if not self:_pointInRect(x, y, listRect) then
    return nil
  end

  local index = self:_indexAtPosition(x, y)
  if index then
    if index == self.selectedIndex then
      self:_toggleSelectedRelic()
    else
      self:_setSelection(index)
    end
  end

  return nil
end

function RelicSelectScene:wheelmoved(dx, dy)
  if dy == 0 then return end
  local listRect = self:_listRect()
  local totalHeight = self:_contentHeight()
  local viewHeight = listRect.h - self.layout.listPadding * 2
  if totalHeight <= viewHeight then return end

  local step = (self.layout.rowHeight + self.layout.rowSpacing) * 1.2
  self.scroll.target = clamp(self.scroll.target - dy * step, 0, totalHeight - viewHeight)
end

function RelicSelectScene:_refreshEntries()
  local list = relics.list() or {}
  self.entries = {}
  for _, relic in ipairs(list) do
    table.insert(self.entries, {
      id = relic.id,
      name = relic.name or relic.id,
      rarity = relic.rarity or relics.Rarity and relics.Rarity.COMMON or "common",
      description = relic.description or "",
      flavor = relic.flavor or "",
      tags = relic.tags or {},
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

function RelicSelectScene:_drawRelicList(listX, listY, listW, listH)
  local padding = self.layout.listPadding
  local innerX = listX + padding
  local innerY = listY + padding
  local innerW = listW - padding * 2
  local innerH = listH - padding * 2

  love.graphics.setScissor(listX, listY, listW, listH)
  love.graphics.push()
  love.graphics.translate(0, -self.scroll.y)

  local baseFont = theme.fonts.base
  local smallFont = theme.fonts.small or theme.fonts.tiny or baseFont
  local rowHeight = self.layout.rowHeight
  local spacing = self.layout.rowSpacing

  local player = PlayerState.getInstance()
  local relicState = player and player:getRelicState() or { equipped = {}, owned = {} }
  local equipped = relicState.equipped or {}

  for index, entry in ipairs(self.entries) do
    local rowY = innerY + (index - 1) * (rowHeight + spacing)
    local isSelected = (index == self.selectedIndex)
    local isHovered = (index == self.hoveredIndex)
    local isEquipped = equipped[entry.id] == true

    local fillAlpha = isSelected and 0.9 or (isHovered and 0.65 or 0.55)
    love.graphics.setColor(0, 0, 0, fillAlpha * 0.45)
    love.graphics.rectangle("fill", innerX, rowY + 3, innerW, rowHeight, 10, 10)

    love.graphics.setColor(0.16, 0.22, 0.34, fillAlpha)
    love.graphics.rectangle("fill", innerX, rowY, innerW, rowHeight, 10, 10)

    if isEquipped then
      love.graphics.setColor(0.32, 0.78, 0.52, 0.95)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", innerX + 2, rowY + 2, innerW - 4, rowHeight - 4, 9, 9)
    end

    local rarityColor = RARITY_COLORS[string.lower(entry.rarity or "")] or RARITY_COLORS.common
    love.graphics.setFont(baseFont)
    love.graphics.setColor(rarityColor)
    love.graphics.print(entry.name, innerX + 16, rowY + 12)

    love.graphics.setFont(smallFont)
    love.graphics.setColor(1, 1, 1, 0.75)
    local rarityLabel = string.upper(entry.rarity or "COMMON")
    love.graphics.print(rarityLabel, innerX + innerW - 160, rowY + 12)

    love.graphics.setColor(1, 1, 1, 0.85)
    local desc = entry.description ~= "" and entry.description or "(no description)"
    love.graphics.printf(desc, innerX + 16, rowY + 34, innerW - 180, "left")
  end

  love.graphics.pop()
  love.graphics.setScissor()
end

function RelicSelectScene:_drawScrollBar(barX, listY, listH)
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

function RelicSelectScene:_moveSelection(delta)
  if #self.entries == 0 then return end
  local newIndex = clamp(self.selectedIndex + delta, 1, #self.entries)
  self:_setSelection(newIndex)
end

function RelicSelectScene:_setSelection(index)
  if #self.entries == 0 then
    self.selectedIndex = 0
    return
  end
  self.selectedIndex = clamp(index, 1, #self.entries)
  self:_scrollSelectionIntoView()
end

function RelicSelectScene:_toggleSelectedRelic()
  local entry = self.entries[self.selectedIndex]
  if not entry then return end

  local player = PlayerState.getInstance()
  if not player then return end

  if player:hasRelic(entry.id) then
    player:removeRelic(entry.id)
  else
    player:addRelic(entry.id)
  end
end

function RelicSelectScene:_equipAll()
  local player = PlayerState.getInstance()
  if not player then return end
  for _, entry in ipairs(self.entries) do
    player:addRelic(entry.id)
  end
end

function RelicSelectScene:_clearAll()
  local player = PlayerState.getInstance()
  if not player then return end
  for _, entry in ipairs(self.entries) do
    player:removeRelic(entry.id)
  end
end

function RelicSelectScene:_updateHoverFromMouse()
  local index = self:_indexAtPosition(self.mouse.x, self.mouse.y)
  self.hoveredIndex = index
end

function RelicSelectScene:_indexAtPosition(x, y)
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

function RelicSelectScene:_scrollSelectionIntoView()
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

function RelicSelectScene:_clampScroll()
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

function RelicSelectScene:_contentHeight()
  if #self.entries == 0 then return 0 end
  local rowSlot = self.layout.rowHeight + self.layout.rowSpacing
  return #self.entries * rowSlot - self.layout.rowSpacing
end

function RelicSelectScene:_listRect()
  local w, h = virtualSize()
  local listX = math.floor(w * 0.2)
  local listW = math.floor(w * 0.6)
  local listY = 140
  local listH = math.floor(h - listY - 80)
  return { x = listX, y = listY, w = listW, h = listH }
end

function RelicSelectScene:_pointInRect(x, y, rect)
  return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

return RelicSelectScene


