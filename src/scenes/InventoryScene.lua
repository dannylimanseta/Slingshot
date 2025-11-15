local config = require("config")
local theme = require("theme")
local relics = require("data.relics")
local PlayerState = require("core.PlayerState")

local InventoryScene = {}
InventoryScene.__index = InventoryScene

local RARITY_COLORS = {
  common = { 0.75, 0.75, 0.75, 1.0 },
  uncommon = { 0.38, 0.78, 0.48, 1.0 },
  rare = { 0.35, 0.58, 0.94, 1.0 },
  epic = { 0.74, 0.46, 0.94, 1.0 },
  legendary = { 0.98, 0.76, 0.32, 1.0 },
}

local function virtualSize()
  local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
  local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
  return vw, vh
end

function InventoryScene.new()
  return setmetatable({
    time = 0,
    previousScene = nil,
    selectedIndex = 1,
    scroll = {
      y = 0,
      target = 0,
      smoothing = 12,
    },
    mouse = { x = 0, y = 0 },
    hoveredIndex = nil,
    fadeInAlpha = 0,
    sidebarImage = nil,
    titleFont = nil,
    closeFont = nil,
    nameFont = nil,
    rarityFont = nil,
    descFont = nil,
    flavorFont = nil,
    -- Layout constants (matching mockup proportions)
    gridIconSize = 96,
    gridIconSpacing = 24,
    gridColumns = 4,
    gridPadding = 60,
    detailPanelWidth = 600, -- Increased width to prevent squashing
  }, InventoryScene)
end

function InventoryScene:setPreviousScene(scene)
  self.previousScene = scene
end

function InventoryScene:load()
  self.time = 0
  self.fadeInAlpha = 0
  self.scroll.y = 0
  self.scroll.target = 0
  self.selectedIndex = 1
  self.hoveredIndex = nil
  
  -- Load sidebar image
  local sidebarPath = "assets/images/relics/inventory_side_bar.png"
  local ok, img = pcall(love.graphics.newImage, sidebarPath)
  if ok and img then
    self.sidebarImage = img
  end
  
  -- Create fonts matching mockup
  self.titleFont = theme.newFont(48) -- "INVENTORY" title (large, bold)
  self.closeFont = theme.newFont(18) -- "X CLOSE" button
  self.nameFont = theme.newFont(32) -- Detail panel item name (bold)
  self.rarityFont = theme.newFont(14) -- Rarity badge
  
  -- Create regular (non-bold) fonts for description and flavor text
  local regularFontPath = "assets/fonts/BarlowCondensed-Regular.ttf"
  local supersamplingFactor = _G.supersamplingFactor or 1
  
  -- Helper to wrap font (same as theme.lua)
  local function wrapFont(font, scale)
    if scale <= 1 then return font end
    local wrapper = {
      _font = font,
      _scale = scale,
      _invScale = 1 / scale
    }
    setmetatable(wrapper, {
      __index = function(t, k)
        local fontMethod = font[k]
        if type(fontMethod) == "function" then
          if k == "getWidth" or k == "getHeight" or k == "getAscent" or k == "getDescent" or k == "getBaseline" or k == "getLineHeight" then
            return function(self, ...)
              local result = fontMethod(font, ...)
              return result * wrapper._invScale
            end
          elseif k == "getWrap" then
            return function(self, text, width)
              return fontMethod(font, text, width * scale)
            end
          else
            return fontMethod
          end
        else
          return fontMethod
        end
      end
    })
    return wrapper
  end
  
  -- Description and flavor fonts (22px, regular weight, same size)
  local textSize = 22 -- Increased size, same for both description and flavor
  local okDesc, descFont = pcall(love.graphics.newFont, regularFontPath, textSize * supersamplingFactor)
  if okDesc and descFont then
    self.descFont = wrapFont(descFont, supersamplingFactor)
  else
    self.descFont = theme.fonts.base -- Fallback
  end
  
  -- Flavor font (same size as description)
  local okFlavor, flavorFont = pcall(love.graphics.newFont, regularFontPath, textSize * supersamplingFactor)
  if okFlavor and flavorFont then
    self.flavorFont = wrapFont(flavorFont, supersamplingFactor)
  else
    self.flavorFont = self.descFont -- Use same font as description if creation fails
  end
end

function InventoryScene:_getOwnedRelics()
  local playerState = PlayerState.getInstance()
  local relicState = playerState and playerState:getRelicState()
  local owned = relicState and relicState.owned or {}
  
  local ownedRelics = {}
  for relicId, _ in pairs(owned) do
    local def = relics.get(relicId)
    if def then
      table.insert(ownedRelics, def)
    end
  end
  
  -- Sort by rarity (legendary first) then by name
  table.sort(ownedRelics, function(a, b)
    local rarityOrder = {
      legendary = 1,
      epic = 2,
      rare = 3,
      uncommon = 4,
      common = 5,
    }
    local aOrder = rarityOrder[a.rarity] or 99
    local bOrder = rarityOrder[b.rarity] or 99
    if aOrder ~= bOrder then
      return aOrder < bOrder
    end
    return (a.name or a.id) < (b.name or b.id)
  end)
  
  return ownedRelics
end

function InventoryScene:update(dt)
  self.time = self.time + dt
  
  -- Fade in animation
  self.fadeInAlpha = math.min(1, self.fadeInAlpha + dt * 3)
  
  -- Smooth scroll
  local diff = self.scroll.target - self.scroll.y
  if math.abs(diff) > 0.25 then
    self.scroll.y = self.scroll.y + diff * math.min(1, dt * self.scroll.smoothing)
  else
    self.scroll.y = self.scroll.target
  end
  
  self:_clampScroll()
  self:_updateHoverFromMouse()
  
  return nil
end

function InventoryScene:_clampScroll()
  local vw, vh = virtualSize()
  local ownedRelics = self:_getOwnedRelics()
  
  local gridStartY = 140
  local gridEndY = vh - 40
  local gridHeight = gridEndY - gridStartY
  
  local rows = math.ceil(#ownedRelics / self.gridColumns)
  local nameFont = theme.fonts.small or theme.fonts.base
  local itemHeight = self.gridIconSize + 10 + nameFont:getHeight()
  local contentHeight = rows * (itemHeight + self.gridIconSpacing)
  local maxScroll = math.max(0, contentHeight - gridHeight)
  
  self.scroll.target = math.max(0, math.min(maxScroll, self.scroll.target))
  self.scroll.y = math.max(0, math.min(maxScroll, self.scroll.y))
end

function InventoryScene:_updateHoverFromMouse()
  local vw, vh = virtualSize()
  local ownedRelics = self:_getOwnedRelics()
  
  local gridStartX = self.gridPadding
  local gridStartY = 140
  
  self.hoveredIndex = nil
  
  for i, relicDef in ipairs(ownedRelics) do
    local col = ((i - 1) % self.gridColumns)
    local row = math.floor((i - 1) / self.gridColumns)
    local nameFont = theme.fonts.small or theme.fonts.base
    local itemHeight = self.gridIconSize + 10 + nameFont:getHeight()
    local x = gridStartX + col * (self.gridIconSize + self.gridIconSpacing)
    local y = gridStartY + row * (itemHeight + self.gridIconSpacing) - self.scroll.y
    
    local iconX = x
    local iconY = y
    local iconW = self.gridIconSize
    local iconH = itemHeight
    
    if self.mouse.x >= iconX and self.mouse.x <= iconX + iconW and
       self.mouse.y >= iconY and self.mouse.y <= iconY + iconH then
      self.hoveredIndex = i
      break
    end
  end
end

function InventoryScene:draw()
  local vw, vh = virtualSize()
  local alpha = self.fadeInAlpha
  
  -- Background
  love.graphics.setColor(0.08, 0.10, 0.12, 0.95 * alpha)
  love.graphics.rectangle("fill", 0, 0, vw, vh)
  
  local ownedRelics = self:_getOwnedRelics()
  
  -- Clamp selected index
  if #ownedRelics > 0 then
    self.selectedIndex = math.max(1, math.min(self.selectedIndex, #ownedRelics))
  else
    self.selectedIndex = 0
  end
  
  -- Draw left side grid
  self:_drawGrid(ownedRelics, alpha)
  
  -- Draw right side detail panel
  if #ownedRelics > 0 and self.selectedIndex > 0 then
    self:_drawDetailPanel(ownedRelics[self.selectedIndex], alpha)
  end
  
  -- Draw close button (top-right, white X with "CLOSE" text)
  self:_drawCloseButton(alpha)
end

function InventoryScene:_drawGrid(ownedRelics, alpha)
  local vw, vh = virtualSize()
  
  -- Title (top-left, uppercase, large)
  local titleFont = self.titleFont or theme.fonts.large or theme.fonts.base
  love.graphics.setFont(titleFont)
  love.graphics.setColor(1, 1, 1, alpha)
  local title = "INVENTORY"
  love.graphics.print(title, self.gridPadding, 48)
  
  if #ownedRelics == 0 then
    -- Empty state
    love.graphics.setFont(theme.fonts.base)
    love.graphics.setColor(1, 1, 1, 0.5 * alpha)
    local emptyText = "No relics collected yet"
    love.graphics.print(emptyText, self.gridPadding, 120)
    return
  end
  
  local gridStartX = self.gridPadding
  local gridStartY = 140
  local nameFont = theme.fonts.small or theme.fonts.base
  local itemHeight = self.gridIconSize + 10 + nameFont:getHeight()
  
  for i, relicDef in ipairs(ownedRelics) do
    local col = ((i - 1) % self.gridColumns)
    local row = math.floor((i - 1) / self.gridColumns)
    local x = gridStartX + col * (self.gridIconSize + self.gridIconSpacing)
    local y = gridStartY + row * (itemHeight + self.gridIconSpacing) - self.scroll.y
    
    -- Only draw if visible
    if y + itemHeight >= gridStartY - 50 and y <= vh + 50 then
      local isSelected = (i == self.selectedIndex)
      local isHovered = (i == self.hoveredIndex)
      
      -- Draw background for selected item (darker background)
      if isSelected then
        love.graphics.setColor(0.15, 0.15, 0.18, alpha * 0.8)
        love.graphics.rectangle("fill", x - 4, y - 4, self.gridIconSize + 8, itemHeight + 8, 4, 4)
      end
      
      -- Draw selection border (white, thicker)
      if isSelected then
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 2, y - 2, self.gridIconSize + 4, self.gridIconSize + 4, 2, 2)
        love.graphics.setLineWidth(1)
      end
      
      -- Draw icon
      if relicDef.icon then
        local ok, iconImg = pcall(love.graphics.newImage, relicDef.icon)
        if ok and iconImg then
          local iconScale = self.gridIconSize / math.max(iconImg:getWidth(), iconImg:getHeight())
          local iconAlpha = alpha
          if isHovered and not isSelected then
            iconAlpha = alpha * 0.85
          end
          love.graphics.setColor(1, 1, 1, iconAlpha)
          love.graphics.draw(iconImg, x, y, 0, iconScale, iconScale)
        end
      end
      
      -- Draw name below icon (small font, white)
      local nameFont = theme.fonts.small or theme.fonts.base
      love.graphics.setFont(nameFont)
      local name = relicDef.name or relicDef.id
      local nameW = nameFont:getWidth(name)
      local nameX = x + (self.gridIconSize - nameW) * 0.5
      local nameY = y + self.gridIconSize + 6
      local nameAlpha = isSelected and alpha or alpha * 0.75
      love.graphics.setColor(1, 1, 1, nameAlpha)
      love.graphics.print(name, nameX, nameY)
    end
  end
end

function InventoryScene:_drawDetailPanel(relicDef, alpha)
  local vw, vh = virtualSize()
  local panelX = vw - self.detailPanelWidth
  local panelY = 0
  local panelW = self.detailPanelWidth
  local panelH = vh
  
  -- Draw sidebar image as background (maintain aspect ratio to prevent squashing)
  if self.sidebarImage then
    love.graphics.setColor(1, 1, 1, alpha)
    local imgW = self.sidebarImage:getWidth()
    local imgH = self.sidebarImage:getHeight()
    
    -- Scale uniformly to fit panel height, maintaining aspect ratio
    local scale = panelH / imgH
    local scaledW = imgW * scale
    local scaledH = imgH * scale
    
    -- Draw at panel position (image will extend to natural width)
    love.graphics.draw(self.sidebarImage, panelX, panelY, 0, scale, scale)
  else
    -- Fallback background
    love.graphics.setColor(0.05, 0.06, 0.08, alpha)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
  end
  
  local textX = panelX + 32 -- Left-aligned X position for all text
  local centerX = panelX + panelW * 0.5
  local descX = textX + 80 -- Shifted right by 80px for all text elements
  local currentY = 160
  
  -- Large icon (centered, 50% larger)
  if relicDef.icon then
    local ok, iconImg = pcall(love.graphics.newImage, relicDef.icon)
    if ok and iconImg then
      local largeIconSize = 270 -- Increased from 180 to 270 (50% larger)
      local iconScale = largeIconSize / math.max(iconImg:getWidth(), iconImg:getHeight())
      local iconW = iconImg:getWidth() * iconScale
      local iconH = iconImg:getHeight() * iconScale
      love.graphics.setColor(1, 1, 1, alpha)
      love.graphics.draw(iconImg, centerX - iconW * 0.5, currentY, 0, iconScale, iconScale)
      currentY = currentY + iconH + 36
    end
  end
  
  -- Rarity badge (uppercase, colored, smaller font, left-aligned, shifted right by 80px)
  local rarityColor = RARITY_COLORS[relicDef.rarity] or RARITY_COLORS.common
  local rarityText = string.upper(relicDef.rarity or "common")
  local rarityFont = self.rarityFont or theme.fonts.small or theme.fonts.base
  love.graphics.setFont(rarityFont)
  love.graphics.setColor(rarityColor[1], rarityColor[2], rarityColor[3], alpha)
  love.graphics.print(rarityText, descX, currentY)
  currentY = currentY + rarityFont:getHeight() + 8
  
  -- Item name (large white text, bold, left-aligned, shifted right by 80px)
  local nameFont = self.nameFont or theme.fonts.large or theme.fonts.base
  love.graphics.setFont(nameFont)
  local name = relicDef.name or relicDef.id
  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.print(name, descX, currentY)
  currentY = currentY + nameFont:getHeight() + 16
  
  -- Description (white, regular weight, left-aligned, shifted right by 80px)
  local descFont = self.descFont or theme.fonts.base
  love.graphics.setFont(descFont)
  local desc = relicDef.description or ""
  local descW = (panelW - 64) * 0.8 -- Reduced by 20%
  love.graphics.setColor(1, 1, 1, 0.95 * alpha)
  love.graphics.printf(desc, descX, currentY, descW, "left")
  -- Calculate height
  local descHeight = self:_calculateWrappedTextHeight(descFont, desc, descW)
  currentY = currentY + descHeight + 12
  
  -- Flavor text (regular weight, lighter gray, smaller, left-aligned, shifted right by 80px)
  if relicDef.flavor and relicDef.flavor ~= "" then
    local flavorFont = self.flavorFont or theme.fonts.small or theme.fonts.base
    love.graphics.setFont(flavorFont)
    love.graphics.setColor(0.65, 0.65, 0.65, alpha * 0.9)
    love.graphics.printf(relicDef.flavor, descX, currentY, descW, "left")
  end
end

function InventoryScene:_calculateWrappedTextHeight(font, text, width)
  if not text or text == "" then return 0 end
  
  -- Estimate height based on text width
  local textWidth = font:getWidth(text)
  if textWidth <= width then
    return font:getHeight()
  else
    local lines = math.ceil(textWidth / width) + 1
    return lines * font:getHeight()
  end
end

function InventoryScene:_drawCloseButton(alpha)
  local vw, vh = virtualSize()
  
  -- Draw "X CLOSE" text in top-right corner (matches mockup style)
  local font = self.closeFont or theme.fonts.base
  love.graphics.setFont(font)
  local closeText = "X CLOSE"
  local textW = font:getWidth(closeText)
  local textH = font:getHeight()
  local x = vw - textW - 36
  local y = 36
  
  -- Check if mouse is hovering
  local isHovering = self.mouse.x >= x - 10 and self.mouse.x <= x + textW + 10 and
                     self.mouse.y >= y - 5 and self.mouse.y <= y + textH + 5
  
  local textAlpha = isHovering and alpha or alpha * 0.8
  love.graphics.setColor(1, 1, 1, textAlpha)
  love.graphics.print(closeText, x, y)
  
  -- Store bounds for click detection
  self._closeButtonBounds = { x = x - 10, y = y - 5, w = textW + 20, h = textH + 10 }
end

function InventoryScene:keypressed(key, scancode, isRepeat)
  if isRepeat then return nil end
  
  local ownedRelics = self:_getOwnedRelics()
  
  if key == "escape" or key == "x" then
    return "return_to_previous"
  end
  
  if #ownedRelics == 0 then return nil end
  
  -- Arrow key navigation
  if key == "up" or key == "w" then
    self.selectedIndex = self.selectedIndex - self.gridColumns
    if self.selectedIndex < 1 then
      self.selectedIndex = math.max(1, #ownedRelics - (self.gridColumns - 1))
    end
    self:_ensureSelectedVisible()
    return nil
  elseif key == "down" or key == "s" then
    self.selectedIndex = self.selectedIndex + self.gridColumns
    if self.selectedIndex > #ownedRelics then
      self.selectedIndex = math.min(self.gridColumns, #ownedRelics)
    end
    self:_ensureSelectedVisible()
    return nil
  elseif key == "left" or key == "a" then
    self.selectedIndex = math.max(1, self.selectedIndex - 1)
    self:_ensureSelectedVisible()
    return nil
  elseif key == "right" or key == "d" then
    self.selectedIndex = math.min(#ownedRelics, self.selectedIndex + 1)
    self:_ensureSelectedVisible()
    return nil
  end
  
  return nil
end

function InventoryScene:_ensureSelectedVisible()
  local vw, vh = virtualSize()
  local gridStartY = 140
  local gridEndY = vh - 40
  local nameFont = theme.fonts.small or theme.fonts.base
  local itemHeight = self.gridIconSize + 10 + nameFont:getHeight()
  
  local row = math.floor((self.selectedIndex - 1) / self.gridColumns)
  local itemY = gridStartY + row * (itemHeight + self.gridIconSpacing) - self.scroll.y
  
  if itemY < gridStartY then
    self.scroll.target = self.scroll.target - (gridStartY - itemY)
  elseif itemY + itemHeight > gridEndY then
    self.scroll.target = self.scroll.target + (itemY + itemHeight - gridEndY)
  end
end

function InventoryScene:mousepressed(x, y, button)
  if button == 1 then
    -- Check close button
    if self._closeButtonBounds then
      local bounds = self._closeButtonBounds
      if x >= bounds.x and x <= bounds.x + bounds.w and
         y >= bounds.y and y <= bounds.y + bounds.h then
        return "return_to_previous"
      end
    end
    
    -- Check grid items
    local ownedRelics = self:_getOwnedRelics()
    local vw, vh = virtualSize()
    local gridStartX = self.gridPadding
    local gridStartY = 140
    local nameFont = theme.fonts.small or theme.fonts.base
    local itemHeight = self.gridIconSize + 10 + nameFont:getHeight()
    
    for i, relicDef in ipairs(ownedRelics) do
      local col = ((i - 1) % self.gridColumns)
      local row = math.floor((i - 1) / self.gridColumns)
      local itemX = gridStartX + col * (self.gridIconSize + self.gridIconSpacing)
      local itemY = gridStartY + row * (itemHeight + self.gridIconSpacing) - self.scroll.y
      
      if x >= itemX and x <= itemX + self.gridIconSize and
         y >= itemY and y <= itemY + itemHeight then
        self.selectedIndex = i
        self:_ensureSelectedVisible()
        return nil
      end
    end
  end
  
  return nil
end

function InventoryScene:mousemoved(x, y, dx, dy, isTouch)
  self.mouse.x = x
  self.mouse.y = y
end

function InventoryScene:wheelmoved(x, y)
  if y ~= 0 then
    local scrollSpeed = 150
    self.scroll.target = self.scroll.target - y * scrollSpeed
    self:_clampScroll()
  end
end

return InventoryScene
