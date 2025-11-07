local config = require("config")
local theme = require("theme")
local encounters = require("data.encounters")
local enemies = require("data.enemies")
local EncounterManager = require("core.EncounterManager")

local EncounterSelectScene = {}
EncounterSelectScene.__index = EncounterSelectScene

function EncounterSelectScene.new()
  return setmetatable({
    selectedIndex = 1,
    scrollOffset = 0,
    itemsPerPage = 8, -- Number of visible items
    itemHeight = 60,
    padding = 20,
    previousScene = nil,
    mouseX = 0,
    mouseY = 0,
    hoveredIndex = nil,
  }, EncounterSelectScene)
end

function EncounterSelectScene:load()
  -- Load all encounters
  self.encounters = encounters.list()
  -- Ensure selected index is valid
  if self.selectedIndex > #self.encounters then
    self.selectedIndex = 1
  end
  -- Update scroll offset to keep selected item visible
  self:_updateScrollOffset()
end

function EncounterSelectScene:_updateScrollOffset()
  -- Keep selected item visible
  local maxVisible = self.itemsPerPage
  if self.selectedIndex < self.scrollOffset + 1 then
    self.scrollOffset = math.max(0, self.selectedIndex - 1)
  elseif self.selectedIndex > self.scrollOffset + maxVisible then
    self.scrollOffset = self.selectedIndex - maxVisible
  end
end

function EncounterSelectScene:update(dt)
  -- Update hover based on mouse position
  self:_updateHover()
end

function EncounterSelectScene:_updateHover()
  local w = (config.video and config.video.virtualWidth) or 1280
  local h = (config.video and config.video.virtualHeight) or 720
  local menuX = w * 0.2
  local menuY = 120
  local menuW = w * 0.6
  local itemH = self.itemHeight
  local startIdx = self.scrollOffset + 1
  local endIdx = math.min(#self.encounters, startIdx + self.itemsPerPage - 1)
  
  -- Check if mouse is over menu area
  if self.mouseX >= menuX and self.mouseX <= menuX + menuW and
     self.mouseY >= menuY and self.mouseY <= menuY + (endIdx - startIdx + 1) * itemH then
    -- Calculate which item is hovered
    local relativeY = self.mouseY - menuY
    local itemIdx = math.floor(relativeY / itemH) + 1
    local actualIdx = startIdx + itemIdx - 1
    
    if actualIdx >= startIdx and actualIdx <= endIdx and actualIdx <= #self.encounters then
      self.hoveredIndex = actualIdx
      -- Update selected index to match hover
      if self.selectedIndex ~= actualIdx then
        self.selectedIndex = actualIdx
        self:_updateScrollOffset()
      end
    else
      self.hoveredIndex = nil
    end
  else
    self.hoveredIndex = nil
  end
end

function EncounterSelectScene:draw()
  local w = (config.video and config.video.virtualWidth) or 1280
  local h = (config.video and config.video.virtualHeight) or 720
  
  -- Dark overlay background
  love.graphics.setColor(0, 0, 0, 0.85)
  love.graphics.rectangle("fill", 0, 0, w, h)
  
  -- Title
  love.graphics.setFont(theme.fonts.large or theme.fonts.base)
  love.graphics.setColor(1, 1, 1, 1)
  local title = "Select Encounter"
  local titleW = (theme.fonts.large or theme.fonts.base):getWidth(title)
  love.graphics.print(title, (w - titleW) * 0.5, 40)
  
  -- Instructions
  love.graphics.setFont(theme.fonts.base)
  local instructions = "Arrow Keys/Mouse: Navigate | Enter/Click: Select | ESC: Cancel"
  local instW = theme.fonts.base:getWidth(instructions)
  love.graphics.setColor(0.8, 0.8, 0.8, 1)
  love.graphics.print(instructions, (w - instW) * 0.5, h - 40)
  
  -- Calculate menu area
  local menuX = w * 0.2
  local menuY = 120
  local menuW = w * 0.6
  local menuH = h - menuY - 100
  
  -- Draw visible encounters
  local font = theme.fonts.base
  local itemH = self.itemHeight
  local startIdx = self.scrollOffset + 1
  local endIdx = math.min(#self.encounters, startIdx + self.itemsPerPage - 1)
  
  for i = startIdx, endIdx do
    local enc = self.encounters[i]
    local y = menuY + (i - startIdx) * itemH
    local isSelected = (i == self.selectedIndex)
    local isHovered = (i == self.hoveredIndex)
    
    -- Background for selected/hovered item
    if isSelected then
      love.graphics.setColor(0.2, 0.4, 0.6, 0.8)
      love.graphics.rectangle("fill", menuX, y, menuW, itemH - 4)
      love.graphics.setColor(0.4, 0.6, 0.9, 1)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", menuX, y, menuW, itemH - 4)
    elseif isHovered then
      love.graphics.setColor(0.15, 0.3, 0.5, 0.6)
      love.graphics.rectangle("fill", menuX, y, menuW, itemH - 4)
      love.graphics.setColor(0.3, 0.5, 0.7, 0.8)
      love.graphics.setLineWidth(1)
      love.graphics.rectangle("line", menuX, y, menuW, itemH - 4)
    else
      love.graphics.setColor(0.1, 0.1, 0.1, 0.6)
      love.graphics.rectangle("fill", menuX, y, menuW, itemH - 4)
    end
    
    -- Encounter info
    love.graphics.setColor(1, 1, 1, isSelected and 1.0 or 0.8)
    local textY = y + (itemH - font:getHeight()) * 0.5
    
    -- ID and difficulty
    local idText = enc.id or "Unknown"
    local diffText = "Difficulty: " .. (enc.difficulty or "?")
    
    -- Build enemy names list
    local enemyNames = {}
    if enc.enemies and type(enc.enemies) == "table" then
      for _, enemyRef in ipairs(enc.enemies) do
        local enemyId = (type(enemyRef) == "string") and enemyRef or (enemyRef.id or enemyRef)
        local enemyData = enemies.get(enemyId)
        if enemyData and enemyData.name then
          table.insert(enemyNames, enemyData.name)
        else
          table.insert(enemyNames, enemyId)
        end
      end
    end
    local enemyText = #enemyNames > 0 and table.concat(enemyNames, ", ") or "No enemies"
    
    love.graphics.print(idText, menuX + 20, textY)
    love.graphics.print(diffText, menuX + menuW * 0.35, textY)
    love.graphics.print(enemyText, menuX + menuW * 0.55, textY)
  end
  
  -- Scroll indicators
  if self.scrollOffset > 0 then
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.print("▲", menuX + menuW * 0.5 - 10, menuY - 20)
  end
  if endIdx < #self.encounters then
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.print("▼", menuX + menuW * 0.5 - 10, menuY + menuH + 10)
  end
  
  love.graphics.setColor(1, 1, 1, 1)
end

function EncounterSelectScene:keypressed(key, scancode, isRepeat)
  if isRepeat then return end
  
  if key == "up" then
    if self.selectedIndex > 1 then
      self.selectedIndex = self.selectedIndex - 1
      self:_updateScrollOffset()
    end
  elseif key == "down" then
    if self.selectedIndex < #self.encounters then
      self.selectedIndex = self.selectedIndex + 1
      self:_updateScrollOffset()
    end
  elseif key == "return" or key == "enter" then
    -- Select encounter and start battle
    local enc = self.encounters[self.selectedIndex]
    if enc and enc.id then
      EncounterManager.setEncounterById(enc.id)
      return "start_battle"
    end
  elseif key == "escape" then
    -- Cancel and return to map
    return "cancel"
  end
  
  return nil
end

function EncounterSelectScene:mousemoved(x, y, dx, dy, isTouch)
  self.mouseX = x
  self.mouseY = y
end

function EncounterSelectScene:mousepressed(x, y, button, isTouch, presses)
  if button == 1 then -- Left mouse button
    local w = (config.video and config.video.virtualWidth) or 1280
    local h = (config.video and config.video.virtualHeight) or 720
    local menuX = w * 0.2
    local menuY = 120
    local menuW = w * 0.6
    local itemH = self.itemHeight
    local startIdx = self.scrollOffset + 1
    local endIdx = math.min(#self.encounters, startIdx + self.itemsPerPage - 1)
    
    -- Check if click is over menu area
    if x >= menuX and x <= menuX + menuW and
       y >= menuY and y <= menuY + (endIdx - startIdx + 1) * itemH then
      -- Calculate which item was clicked
      local relativeY = y - menuY
      local itemIdx = math.floor(relativeY / itemH) + 1
      local actualIdx = startIdx + itemIdx - 1
      
      if actualIdx >= startIdx and actualIdx <= endIdx and actualIdx <= #self.encounters then
        -- Select the clicked encounter and start battle
        local enc = self.encounters[actualIdx]
        if enc and enc.id then
          EncounterManager.setEncounterById(enc.id)
          return "start_battle"
        end
      end
    end
  end
  
  return nil
end

function EncounterSelectScene:setPreviousScene(scene)
  self.previousScene = scene
end

return EncounterSelectScene

