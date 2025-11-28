local config = require("config")
local theme = require("theme")
local encounters = require("data.encounters")
local enemies = require("data.enemies")
local EncounterManager = require("core.EncounterManager")
local Progress = require("core.Progress")

local EncounterSelectScene = {}
EncounterSelectScene.__index = EncounterSelectScene

local MIN_SCROLLBAR_HEIGHT = 32
local DIFFICULTY_FILTER_MODES = {
  { key = "all", label = "All" },
  { key = "1", label = "Difficulty 1" },
  { key = "2", label = "Difficulty 2" },
  { key = "3", label = "Difficulty 3" },
}
local DIFFICULTY_FILTER_LOOKUP = {}
for _, mode in ipairs(DIFFICULTY_FILTER_MODES) do
  DIFFICULTY_FILTER_LOOKUP[mode.key] = true
end

function EncounterSelectScene.new()
  return setmetatable({
    encounters = {},
    selectedIndex = 0,
    hoveredIndex = nil,
    previousScene = nil,

    layoutCache = nil,
    _deferScrollToSelection = true,
    difficultyFilterMode = "all",
    _difficultyFilterChipBounds = {},
    _difficultyFilterHoverKey = nil,

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
  self:_reloadEncounters(false)
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

  -- Layout
  local layout = self:_computeLayout(w, h)
  self.layoutCache = layout

  if self._deferScrollToSelection then
    self:_scrollSelectionIntoView(layout, true)
    self._deferScrollToSelection = false
  end

  self:_drawFilterControls(layout)

  -- List container
  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", layout.x, layout.y, layout.w, layout.h, layout.cornerRadius, layout.cornerRadius)

  if #self.encounters == 0 then
    self:_drawEmptyState(layout)
    return
  end

  self:_drawEncounters(layout)
  self:_drawScrollBar(layout)
end

function EncounterSelectScene:_drawFilterControls(layout)
  local font = theme.fonts.small or theme.fonts.base
  local paddingX = 18
  local paddingY = 7
  local chipWidth = math.max(140, font:getWidth("Difficulty 3") + paddingX * 2)
  local chipHeight = font:getHeight() + paddingY * 2
  local spacingY = 10
  local startX = math.max(20, layout.x - 200)
  local startY = 70

  -- Draw difficulty filters
  self._difficultyFilterChipBounds = {}
  for index, mode in ipairs(DIFFICULTY_FILTER_MODES) do
    local isActive = (self.difficultyFilterMode == mode.key)
    local isHovered = (self._difficultyFilterHoverKey == mode.key)
    local baseFill = isActive and { 0.32, 0.58, 0.96, 0.95 } or { 0.12, 0.16, 0.24, isHovered and 0.92 or 0.78 }
    local outline = isActive and { 1, 1, 1, 0.85 } or { 1, 1, 1, isHovered and 0.45 or 0.25 }

    local x = startX
    local y = startY + (index - 1) * (chipHeight + spacingY)

    love.graphics.setColor(baseFill[1], baseFill[2], baseFill[3], baseFill[4])
    love.graphics.rectangle("fill", x, y, chipWidth, chipHeight, chipHeight * 0.5, chipHeight * 0.5)

    love.graphics.setLineWidth(1)
    love.graphics.setColor(outline[1], outline[2], outline[3], outline[4])
    love.graphics.rectangle("line", x, y, chipWidth, chipHeight, chipHeight * 0.5, chipHeight * 0.5)

    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1, isActive and 1 or (isHovered and 0.9 or 0.75))
    local textW = font:getWidth(mode.label)
    local textX = x + (chipWidth - textW) * 0.5
    local textY = y + (chipHeight - font:getHeight()) * 0.5
    love.graphics.print(mode.label, textX, textY)

    table.insert(self._difficultyFilterChipBounds, { key = mode.key, x = x, y = y, w = chipWidth, h = chipHeight })
  end
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
  local secondaryFont = theme.fonts.tiny or theme.fonts.small or theme.fonts.base
  local statusFont = theme.fonts.tiny or theme.fonts.small or theme.fonts.base
  local rowHeight = layout.rowHeight
  local spacing = layout.rowSpacing
  local radius = layout.cornerRadius
  local innerPadding = 16
  local innerX = layout.x + innerPadding
  local innerWidth = layout.w - innerPadding * 2
  local shadowOffset = 3

  for index, enc in ipairs(self.encounters) do
    local itemY = layout.y + (index - 1) * (rowHeight + spacing) - self.scroll.y
    local itemBottom = itemY + rowHeight

    if itemBottom >= layout.y - rowHeight and itemY <= layout.y + layout.h then
      local isSelected = (index == self.selectedIndex)
      local isHovered = (index == self.hoveredIndex)

      local fillAlpha = isSelected and 0.95 or (isHovered and 0.78 or 0.58)
      love.graphics.setColor(0, 0, 0, fillAlpha * 0.35)
      love.graphics.rectangle("fill", innerX, itemY + shadowOffset, innerWidth, rowHeight, radius, radius)

      love.graphics.setColor(0.12, 0.16, 0.24, fillAlpha)
      love.graphics.rectangle("fill", innerX, itemY, innerWidth, rowHeight, radius, radius)

      if isSelected or isHovered then
        local outlineAlpha = isSelected and 0.95 or 0.6
        love.graphics.setColor(0.45, 0.65, 0.95, outlineAlpha)
        love.graphics.setLineWidth(isSelected and 2 or 1)
        love.graphics.rectangle("line", innerX, itemY, innerWidth, rowHeight, radius, radius)
      end

      local textX = innerX + 18
      local textY = itemY + 12

      love.graphics.setFont(primaryFont)
      love.graphics.setColor(1, 1, 1, isSelected and 1 or 0.9)

      local label = enc.name or enc.id or ("Encounter " .. index)
      love.graphics.print(label, textX, textY)

      local statusText, statusDescription, statusFill, statusOutline = self:_encounterStatus(enc)
      if statusText then
        love.graphics.setFont(statusFont)

        local pillPaddingX, pillPaddingY = 12, 4
        local statusW = statusFont:getWidth(statusText)
        local statusH = statusFont:getHeight()
        local pillW = statusW + pillPaddingX * 2
        local pillH = statusH + pillPaddingY * 2
        local pillRadius = pillH * 0.5
        local pillX = innerX + innerWidth - pillW - 14
        local pillY = textY - 4

        love.graphics.setColor(statusFill[1], statusFill[2], statusFill[3], statusFill[4])
        love.graphics.rectangle("fill", pillX, pillY, pillW, pillH, pillRadius, pillRadius)

        if statusOutline then
          love.graphics.setLineWidth(1)
          love.graphics.setColor(statusOutline[1], statusOutline[2], statusOutline[3], statusOutline[4])
          love.graphics.rectangle("line", pillX, pillY, pillW, pillH, pillRadius, pillRadius)
        end

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(statusText, pillX + pillPaddingX, pillY + pillPaddingY)
      end

      local metaParts = {}
      if statusDescription then
        table.insert(metaParts, statusDescription)
      end

      local encounterDifficulty = enc.difficulty or 1
      table.insert(metaParts, "Difficulty: " .. tostring(encounterDifficulty))

      local enemySummary = self:_enemySummary(enc)
      if enemySummary then
        table.insert(metaParts, enemySummary)
      end

      if #metaParts > 0 then
        love.graphics.setFont(secondaryFont)
        love.graphics.setColor(1, 1, 1, isSelected and 0.88 or 0.68)
        local metaText = table.concat(metaParts, "  |  ")
        love.graphics.print(metaText, textX, textY + primaryFont:getHeight() + 6)
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
  self:_updateDifficultyFilterHover(x, y)
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
    self:_setScrollTarget(layout, self.drag.startScroll + delta, true)
    self.scroll.y = self.scroll.target
    return
  end

  self:_updateHover()
end

function EncounterSelectScene:wheelmoved(dx, dy)
  if dy == 0 or #self.encounters == 0 then return end

  local layout = self:_ensureLayout()
  local step = (layout.rowHeight + layout.rowSpacing) * 0.6
  self:_setScrollTarget(layout, self.scroll.target - dy * step, false)

  local hovered = self:_positionToIndex(self.mouse.x, self.mouse.y)
  if hovered then
    self.selectedIndex = hovered
    self:_onSelectionChanged(false)
  end
end

function EncounterSelectScene:mousepressed(x, y, button, isTouch, presses)
  if button ~= 1 then return nil end

  self.mouse.x, self.mouse.y = x, y
  self:_updateDifficultyFilterHover(x, y)

  local difficultyFilterKey = self:_difficultyFilterChipAt(x, y)
  if difficultyFilterKey then
    self:_setDifficultyFilterMode(difficultyFilterKey, true)
    return nil
  end

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
  -- Elite filters removed; this function kept for compatibility but does nothing
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

function EncounterSelectScene:_reloadEncounters(preserveSelection)
  local previousId = nil
  if preserveSelection and self.selectedIndex > 0 then
    local current = self.encounters[self.selectedIndex]
    previousId = current and current.id or nil
  end

  local allEncounters = encounters.list() or {}
  local filtered = {}
  local difficultyFilter = self.difficultyFilterMode

  for _, enc in ipairs(allEncounters) do
    local includeDifficulty = false
    if difficultyFilter == "all" then
      includeDifficulty = true
    else
      local encDifficulty = enc.difficulty or 1
      includeDifficulty = (tostring(encDifficulty) == difficultyFilter)
    end

    if includeDifficulty then
      table.insert(filtered, enc)
    end
  end

  self.encounters = filtered

  if #filtered == 0 then
    self.selectedIndex = 0
  else
    local newIndex = 0
    if previousId then
      for idx, enc in ipairs(filtered) do
        if enc.id == previousId then
          newIndex = idx
          break
        end
      end
    else
      -- Don't auto-select when reloading
      newIndex = 0
    end
    self.selectedIndex = newIndex
  end

  self.hoveredIndex = nil
  self._difficultyFilterHoverKey = nil

  if not preserveSelection then
    self.scroll.y = 0
    self.scroll.target = 0
    self._deferScrollToSelection = true
  else
    self._deferScrollToSelection = true
  end
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

function EncounterSelectScene:_updateDifficultyFilterHover(x, y)
  if not self._difficultyFilterChipBounds or #self._difficultyFilterChipBounds == 0 then
    self._difficultyFilterHoverKey = nil
    return
  end

  for _, bounds in ipairs(self._difficultyFilterChipBounds) do
    if x >= bounds.x and x <= bounds.x + bounds.w and y >= bounds.y and y <= bounds.y + bounds.h then
      self._difficultyFilterHoverKey = bounds.key
      return
    end
  end

  self._difficultyFilterHoverKey = nil
end

function EncounterSelectScene:_difficultyFilterChipAt(x, y)
  if not self._difficultyFilterChipBounds or #self._difficultyFilterChipBounds == 0 then
    return nil
  end

  for _, bounds in ipairs(self._difficultyFilterChipBounds) do
    if x >= bounds.x and x <= bounds.x + bounds.w and y >= bounds.y and y <= bounds.y + bounds.h then
      return bounds.key
    end
  end

  return nil
end

function EncounterSelectScene:_setDifficultyFilterMode(mode, preserveSelection)
  if not DIFFICULTY_FILTER_LOOKUP[mode] then
    mode = "all"
  end

  if self.difficultyFilterMode == mode then
    return
  end

  self.difficultyFilterMode = mode

  local keepSelection = preserveSelection
  if keepSelection == nil then
    keepSelection = true
  end

  self:_reloadEncounters(keepSelection)
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

function EncounterSelectScene:_encounterStatus(enc)
  local isElite = enc and enc.elite == true
  if isElite then
    return "ELITE", "Elite encounter", { 0.94, 0.36, 0.22, 0.95 }, { 1, 1, 1, 0.65 }
  end

  return "NORMAL", "Normal encounter", { 0.24, 0.65, 0.48, 0.92 }, { 1, 1, 1, 0.35 }
end

function EncounterSelectScene:_onSelectionChanged(immediate)
  if self.layoutCache then
    self:_scrollSelectionIntoView(self.layoutCache, immediate)
  else
    self._deferScrollToSelection = true
  end
end

return EncounterSelectScene

