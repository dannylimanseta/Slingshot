local config = require("config")
local theme = require("theme")
local encounters = require("data.encounters")
local enemies = require("data.enemies")
local EncounterManager = require("core.EncounterManager")

local EncounterSelectScene = {}
EncounterSelectScene.__index = EncounterSelectScene

local MIN_SCROLLBAR_HEIGHT = 32

function EncounterSelectScene.new()
  return setmetatable({
    encounters = {},
    selectedIndex = 1,
    hoveredIndex = nil,
    previousScene = nil,
    _isEliteFilter = nil, -- nil = show all, true = show only elite, false = show only non-elite

    layoutCache = nil,
    _deferScrollToSelection = true,

    scroll = {
      y = 0,
      target = 0,
      smoothing = 12,
    },

    drag = {
      pending = false,
      active = false,
      startY = 0,
      startScroll = 0,
      threshold = 18,
    },

    mouse = { x = 0, y = 0 },
    click = { index = nil, startedAt = 0 },
  }, EncounterSelectScene)
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function EncounterSelectScene:load()
  local allEncounters = encounters.list() or {}
  
  -- Filter encounters based on elite status
  if self._isEliteFilter ~= nil then
    self.encounters = {}
    for _, enc in ipairs(allEncounters) do
      local isElite = (enc.elite == true)
      if self._isEliteFilter then
        -- Show only elite encounters
        if isElite then
          table.insert(self.encounters, enc)
        end
      else
        -- Show only non-elite encounters
        if not isElite then
          table.insert(self.encounters, enc)
        end
      end
    end
  else
    -- Show all encounters
    self.encounters = allEncounters
  end

  if #self.encounters == 0 then
    self.selectedIndex = 0
  else
    self.selectedIndex = math.max(1, math.min(self.selectedIndex, #self.encounters))
  end

  self.scroll.y = 0
  self.scroll.target = 0
  self._deferScrollToSelection = true
  self.hoveredIndex = nil
end

-- ============================================================================
-- UPDATE LOOP
-- ============================================================================

function EncounterSelectScene:update(dt)
  local diff = self.scroll.target - self.scroll.y
  if math.abs(diff) > 0.25 then
    local smoothing = self.scroll.smoothing or 12
    self.scroll.y = self.scroll.y + diff * math.min(1, dt * smoothing)
  else
    self.scroll.y = self.scroll.target
  end

  local layout = self.layoutCache
  if layout then
    local maxScroll = self:_maxScroll(layout)
    if maxScroll >= 0 then
      self.scroll.y = math.max(0, math.min(self.scroll.y, maxScroll))
      self.scroll.target = math.max(0, math.min(self.scroll.target, maxScroll))
    end
  end

  if not self.drag.active then
    self:_updateHover()
  end
end

-- ============================================================================
-- DRAWING
-- ============================================================================

function EncounterSelectScene:draw()
  local w, h = self:_virtualSize()

  -- Backdrop
  love.graphics.setColor(0, 0, 0, 0.82)
  love.graphics.rectangle("fill", 0, 0, w, h)

  -- Title
  local titleFont = theme.fonts.large or theme.fonts.base
  love.graphics.setFont(titleFont)
  love.graphics.setColor(1, 1, 1, 1)
  local title = "Select Encounter"
  local titleW = titleFont:getWidth(title)
  love.graphics.print(title, (w - titleW) * 0.5, 48)

  -- Instructions
  local infoFont = theme.fonts.base
  love.graphics.setFont(infoFont)
  love.graphics.setColor(0.82, 0.82, 0.82, 1)
  local instructions = "Arrow Keys / Scroll: Navigate   Enter / Click: Start   Esc: Back"
  local instW = infoFont:getWidth(instructions)
  love.graphics.print(instructions, (w - instW) * 0.5, h - 48)

  -- Layout
  local layout = self:_computeLayout(w, h)
  self.layoutCache = layout

  if self._deferScrollToSelection then
    self:_scrollSelectionIntoView(layout, true)
    self._deferScrollToSelection = false
  end

  -- List container
  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", layout.x, layout.y, layout.w, layout.h, layout.cornerRadius, layout.cornerRadius)
  love.graphics.setColor(1, 1, 1, 0.08)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", layout.x, layout.y, layout.w, layout.h, layout.cornerRadius, layout.cornerRadius)

  if #self.encounters == 0 then
    self:_drawEmptyState(layout)
    return
  end

  self:_drawEncounters(layout)
  self:_drawScrollBar(layout)
end

function EncounterSelectScene:_drawEmptyState(layout)
  local font = theme.fonts.base
  local text = "No encounters available."
  local textW = font:getWidth(text)
  local textH = font:getHeight()

  love.graphics.setFont(font)
  love.graphics.setColor(1, 1, 1, 0.7)
  love.graphics.print(text, layout.x + (layout.w - textW) * 0.5, layout.y + (layout.h - textH) * 0.5)
end

function EncounterSelectScene:_drawEncounters(layout)
  local primaryFont = theme.fonts.base
  local secondaryFont = theme.fonts.small or theme.fonts.base
  local rowHeight = layout.rowHeight
  local spacing = layout.rowSpacing
  local radius = layout.cornerRadius
  local innerX = layout.x + 8
  local innerWidth = layout.w - 16

  for index, enc in ipairs(self.encounters) do
    local itemY = layout.y + (index - 1) * (rowHeight + spacing) - self.scroll.y
    local itemBottom = itemY + rowHeight

    if itemBottom >= layout.y - rowHeight and itemY <= layout.y + layout.h then
      local isSelected = (index == self.selectedIndex)
      local isHovered = (index == self.hoveredIndex)

      local baseAlpha = isSelected and 0.95 or (isHovered and 0.8 or 0.6)
      love.graphics.setColor(0.16, 0.2, 0.28, baseAlpha)
      love.graphics.rectangle("fill", innerX, itemY, innerWidth, rowHeight, radius, radius)

      if isSelected or isHovered then
        love.graphics.setColor(0.45, 0.65, 0.95, isSelected and 0.9 or 0.55)
        love.graphics.setLineWidth(isSelected and 2 or 1)
        love.graphics.rectangle("line", innerX, itemY, innerWidth, rowHeight, radius, radius)
      end

      local textX = innerX + 16
      local textY = itemY + 12

      love.graphics.setFont(primaryFont)
      love.graphics.setColor(1, 1, 1, isSelected and 1 or 0.88)

      local label = enc.name or enc.id or ("Encounter " .. index)
      love.graphics.print(label, textX, textY)

      local metaParts = {}
      -- Show difficulty from Progress system (what will actually be used) instead of static encounter difficulty
      local Progress = require("core.Progress")
      local actualDifficulty = Progress.peekDifficultyLevel() or (enc.difficulty or 1)
      table.insert(metaParts, "Difficulty: " .. tostring(actualDifficulty))

      local enemySummary = self:_enemySummary(enc)
      if enemySummary then
        table.insert(metaParts, enemySummary)
      end

      if #metaParts > 0 then
        love.graphics.setFont(secondaryFont)
        love.graphics.setColor(1, 1, 1, isSelected and 0.85 or 0.65)
        local metaText = table.concat(metaParts, "  |  ")
        love.graphics.print(metaText, textX, textY + primaryFont:getHeight() + 4)
      end
    end
  end
end

function EncounterSelectScene:_drawScrollBar(layout)
  local maxScroll = self:_maxScroll(layout)
  if maxScroll <= 0.5 then
    return
  end

  local totalHeight = self:_totalContentHeight(layout)
  if totalHeight <= 0 then
    return
  end

  local trackX = layout.x + layout.w - 10
  local trackTop = layout.y + 8
  local trackHeight = layout.h - 16

  local viewRatio = layout.h / totalHeight
  local barHeight = math.max(trackHeight * viewRatio, MIN_SCROLLBAR_HEIGHT)
  local scrollRatio = maxScroll > 0 and (self.scroll.y / maxScroll) or 0
  local barY = trackTop + (trackHeight - barHeight) * scrollRatio

  love.graphics.setColor(1, 1, 1, 0.12)
  love.graphics.rectangle("fill", trackX, trackTop, 2, trackHeight, 1, 1)

  love.graphics.setColor(1, 1, 1, 0.38)
  love.graphics.rectangle("fill", trackX - 1, barY, 4, barHeight, 2, 2)
end

-- ============================================================================
-- INPUT: KEYBOARD
-- ============================================================================

function EncounterSelectScene:keypressed(key, scancode, isRepeat)
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
    self:_setSelection(#self.encounters)
  elseif key == "return" or key == "enter" then
    return self:_activateSelection()
  elseif key == "escape" then
    return "cancel"
  end

  return nil
end

-- ============================================================================
-- INPUT: MOUSE
-- ============================================================================

function EncounterSelectScene:mousemoved(x, y, dx, dy, isTouch)
  self.mouse.x, self.mouse.y = x, y
  local layout = self:_ensureLayout()

  if self.drag.pending or self.drag.active then
    if not love.mouse.isDown(1) then
      self.drag.pending = false
      self.drag.active = false
    end
  end

  if self.drag.pending and not self.drag.active then
    local distance = math.abs(y - self.drag.startY)
    local threshold = math.max(12, layout.rowHeight * 0.2)
    if distance > threshold then
      self.drag.active = true
    end
  end

  if self.drag.active then
    local delta = y - self.drag.startY
    self:_setScrollTarget(layout, self.drag.startScroll - delta, true)
    self.scroll.y = self.scroll.target
    return
  end

  self:_updateHover()
end

function EncounterSelectScene:wheelmoved(dx, dy)
  if dy == 0 or #self.encounters == 0 then return end

  local layout = self:_ensureLayout()
  local step = (layout.rowHeight + layout.rowSpacing) * 0.6
  self:_setScrollTarget(layout, self.scroll.target + dy * step, false)

  local hovered = self:_positionToIndex(self.mouse.x, self.mouse.y)
  if hovered then
    self.selectedIndex = hovered
    self:_onSelectionChanged(false)
  end
end

function EncounterSelectScene:mousepressed(x, y, button, isTouch, presses)
  if button ~= 1 then return nil end

  self.mouse.x, self.mouse.y = x, y
  local layout = self:_ensureLayout()

  if not self:_pointInRect(x, y, layout) then
    self.drag.pending = false
    self.drag.active = false
    return nil
  end

  self.drag.pending = true
  self.drag.active = false
  self.drag.startY = y
  self.drag.startScroll = self.scroll.target
  self.drag.threshold = math.max(12, layout.rowHeight * 0.2)

  self.click.index = self:_positionToIndex(x, y)
  self.click.startedAt = love.timer.getTime()

  if self.click.index and self.click.index ~= self.selectedIndex then
    self.selectedIndex = self.click.index
    self:_onSelectionChanged(false)
  end

  return nil
end

function EncounterSelectScene:mousereleased(x, y, button, isTouch, presses)
  if button ~= 1 then return nil end

  self.mouse.x, self.mouse.y = x, y
  local layout = self:_ensureLayout()

  local wasDragging = self.drag.active
  local startY = self.drag.startY or y
  self.drag.pending = false
  self.drag.active = false

  local clickIndex = self.click.index
  local clickStart = self.click.startedAt or 0
  self.click.index = nil
  self.click.startedAt = 0

  if wasDragging then
    self:_updateHover()
    return nil
  end

  if not clickIndex then
    return nil
  end

  if not self:_pointInRect(x, y, layout) then
    return nil
  end

  local distance = math.abs(y - startY)
  local duration = love.timer.getTime() - clickStart
  local threshold = math.max(12, layout.rowHeight * 0.2)

  if distance > threshold or duration > 0.6 then
    return nil
  end

  local targetIndex = self:_positionToIndex(x, y) or clickIndex
  if not targetIndex then
    return nil
  end

  if targetIndex ~= self.selectedIndex then
    self.selectedIndex = targetIndex
    self:_onSelectionChanged(false)
  end

  return self:_activateSelection()
end

-- ============================================================================
-- HELPERS
-- ============================================================================

function EncounterSelectScene:setPreviousScene(scene)
  self.previousScene = scene
end

function EncounterSelectScene:setEliteFilter(isElite)
  -- nil = show all, true = show only elite, false = show only non-elite
  self._isEliteFilter = isElite
end

function EncounterSelectScene:_virtualSize()
  local w = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
  local h = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
  return w, h
end

function EncounterSelectScene:_computeLayout(w, h)
  local listWidth = math.min(600, w * 0.6)
  local x = (w - listWidth) * 0.5
  local y = 130
  local height = h - y - 160

  return {
    x = x,
    y = y,
    w = listWidth,
    h = height,
    rowHeight = 68,
    rowSpacing = 10,
    cornerRadius = 10,
  }
end

function EncounterSelectScene:_ensureLayout()
  if self.layoutCache then
    return self.layoutCache
  end

  local w, h = self:_virtualSize()
  local layout = self:_computeLayout(w, h)
  self.layoutCache = layout
  return layout
end

function EncounterSelectScene:_totalContentHeight(layout)
  local count = #self.encounters
  if count == 0 then
    return 0
  end

  local rowHeight = layout.rowHeight
  local spacing = layout.rowSpacing
  return count * rowHeight + math.max(0, count - 1) * spacing
end

function EncounterSelectScene:_maxScroll(layout)
  return math.max(0, self:_totalContentHeight(layout) - layout.h)
end

function EncounterSelectScene:_setScrollTarget(layout, value, immediate)
  local maxScroll = self:_maxScroll(layout)
  local clamped = math.max(0, math.min(value, maxScroll))
  self.scroll.target = clamped

  if immediate then
    self.scroll.y = clamped
  end
end

function EncounterSelectScene:_scrollSelectionIntoView(layout, immediate)
  if #self.encounters == 0 or self.selectedIndex == 0 then
    return
  end

  local totalRow = layout.rowHeight + layout.rowSpacing
  local itemTop = (self.selectedIndex - 1) * totalRow
  local itemBottom = itemTop + layout.rowHeight
  local viewTop = self.scroll.target
  local viewBottom = self.scroll.target + layout.h

  local target

  if itemTop < viewTop then
    target = itemTop
  elseif itemBottom > viewBottom then
    target = itemBottom - layout.h
  end

  if target then
    self:_setScrollTarget(layout, target, immediate)
  elseif immediate then
    self:_setScrollTarget(layout, self.scroll.target, true)
  end
end

function EncounterSelectScene:_moveSelection(step)
  if #self.encounters == 0 or self.selectedIndex == 0 then
    return
  end

  local newIndex = math.max(1, math.min(self.selectedIndex + step, #self.encounters))
  if newIndex ~= self.selectedIndex then
    self.selectedIndex = newIndex
    self.hoveredIndex = nil
    self:_onSelectionChanged(false)
  end
end

function EncounterSelectScene:_setSelection(index)
  if #self.encounters == 0 then
    self.selectedIndex = 0
    return
  end

  local clamped = math.max(1, math.min(index, #self.encounters))
  if clamped ~= self.selectedIndex then
    self.selectedIndex = clamped
    self.hoveredIndex = nil
    self:_onSelectionChanged(true)
  end
end

function EncounterSelectScene:_activateSelection()
  if #self.encounters == 0 or self.selectedIndex == 0 then
    return nil
  end

  local enc = self.encounters[self.selectedIndex]
  if enc and enc.id then
    EncounterManager.setEncounterById(enc.id)
    return "start_battle"
  end

  return nil
end

function EncounterSelectScene:_pointInRect(x, y, rect)
  return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

function EncounterSelectScene:_positionToIndex(x, y)
  if #self.encounters == 0 then
    return nil
  end

  local layout = self.layoutCache
  if not layout then
    return nil
  end

  if not self:_pointInRect(x, y, layout) then
    return nil
  end

  local relativeY = y - layout.y + self.scroll.y
  if relativeY < 0 then
    return nil
  end

  local totalRow = layout.rowHeight + layout.rowSpacing
  local index = math.floor(relativeY / totalRow) + 1

  if index < 1 or index > #self.encounters then
    return nil
  end

  local rowTop = (index - 1) * totalRow
  if (relativeY - rowTop) > layout.rowHeight then
    return nil
  end

  return index
end

function EncounterSelectScene:_updateHover()
  if self.drag.active then
    self.hoveredIndex = nil
    return
  end

  local layout = self.layoutCache
  if not layout then
    return
  end

  if not self:_pointInRect(self.mouse.x, self.mouse.y, layout) then
    self.hoveredIndex = nil
    return
  end

  self.hoveredIndex = self:_positionToIndex(self.mouse.x, self.mouse.y)
end

function EncounterSelectScene:_enemySummary(enc)
  if not enc.enemies or type(enc.enemies) ~= "table" then
    return nil
  end

  local names = {}
  for _, enemyRef in ipairs(enc.enemies) do
    local enemyId = type(enemyRef) == "string" and enemyRef or enemyRef.id or enemyRef
    local enemyData = enemies.get(enemyId)
    local label = (enemyData and enemyData.name) or tostring(enemyId)
    table.insert(names, label)
  end

  local count = #names
  if count == 0 then
    return "No enemies"
  elseif count == 1 then
    return "Enemy: " .. names[1]
  elseif count == 2 then
    return "Enemies: " .. names[1] .. ", " .. names[2]
  else
    return string.format("Enemies: %s, %s (+%d)", names[1], names[2], count - 2)
  end
end

function EncounterSelectScene:_onSelectionChanged(immediate)
  if self.layoutCache then
    self:_scrollSelectionIntoView(self.layoutCache, immediate)
  else
    self._deferScrollToSelection = true
  end
end

return EncounterSelectScene

