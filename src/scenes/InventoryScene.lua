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
    _itemHoverProgress = {}, -- Track hover progress for each item
    _itemScale = {}, -- Track scale for each item
    _glowTime = 0, -- For pulsing glow animation
    -- Tooltip state
    _tooltipRelicId = nil, -- Currently hovered relic ID for tooltip
    _tooltipHoverTime = 0, -- Time hovering over relic
    _tooltipBounds = nil, -- Bounds of hovered element {x, y, w, h}
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
  
  -- Description font (22px, regular weight)
  local textSize = 22
  local okDesc, descFont = pcall(love.graphics.newFont, regularFontPath, textSize * supersamplingFactor)
  if okDesc and descFont then
    self.descFont = wrapFont(descFont, supersamplingFactor)
  else
    self.descFont = theme.fonts.base -- Fallback
  end
  
  -- Flavor font (22px, italic)
  local italicFontPath = "assets/fonts/BarlowCondensed-Italic.ttf"
  local okFlavor, flavorFont = pcall(love.graphics.newFont, italicFontPath, textSize * supersamplingFactor)
  if okFlavor and flavorFont then
    self.flavorFont = wrapFont(flavorFont, supersamplingFactor)
  else
    self.flavorFont = self.descFont -- Fallback to description font if italic font fails
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
  self._glowTime = (self._glowTime or 0) + dt
  
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
  self:_updateItemHoverStates(dt)
  -- Tooltip disabled - detail panel already shows relic information
  -- self:_updateTooltip(dt)
  
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
  local paddingTop = 12
  local paddingBottom = 12
  local iconNameSpacing = 12
  local itemHeight = paddingTop + self.gridIconSize + iconNameSpacing + nameFont:getHeight() + paddingBottom
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
    local paddingTop = 12
    local paddingBottom = 12
    local iconNameSpacing = 12
    local itemHeight = paddingTop + self.gridIconSize + iconNameSpacing + nameFont:getHeight() + paddingBottom
    local itemW = self.gridIconSize * 1.5 -- Increased width by 50%
    local baseX = gridStartX + col * (itemW + self.gridIconSpacing) -- Use wider box width for spacing
    local x = baseX
    local y = gridStartY + row * (itemHeight + self.gridIconSpacing) - self.scroll.y
    
    local itemH = itemHeight
    
    if self.mouse.x >= x and self.mouse.x <= x + itemW and
       self.mouse.y >= y and self.mouse.y <= y + itemH then
      self.hoveredIndex = i
      break
    end
  end
end

function InventoryScene:_updateItemHoverStates(dt)
  local ownedRelics = self:_getOwnedRelics()
  
  for i = 1, #ownedRelics do
    local isHovered = (i == self.hoveredIndex)
    local isSelected = (i == self.selectedIndex)
    
    -- Initialize hover progress if needed
    if not self._itemHoverProgress[i] then
      self._itemHoverProgress[i] = 0
    end
    if not self._itemScale[i] then
      self._itemScale[i] = 1.0
    end
    
    -- Update hover progress (smooth tween)
    local targetProgress = (isHovered or isSelected) and 1.0 or 0.0
    local currentProgress = self._itemHoverProgress[i]
    local diff = targetProgress - currentProgress
    self._itemHoverProgress[i] = currentProgress + diff * math.min(1, 10 * dt)
    
    -- Update scale (expand on hover/select)
    local targetScale = (isHovered or isSelected) and 1.05 or 1.0
    local currentScale = self._itemScale[i]
    local scaleDiff = targetScale - currentScale
    self._itemScale[i] = currentScale + scaleDiff * math.min(1, 10 * dt)
  end
end

function InventoryScene:_updateTooltip(dt)
  local ownedRelics = self:_getOwnedRelics()
  local vw, vh = virtualSize()
  local mx, my = self.mouse.x, self.mouse.y
  
  -- Check if hovering over detail panel (name or icon)
  local detailPanelRelicId = nil
  local detailPanelBounds = nil
  
  if #ownedRelics > 0 and self.selectedIndex > 0 then
    local selectedRelic = ownedRelics[self.selectedIndex]
    local panelX = vw - self.detailPanelWidth
    local textX = panelX + 32
    local descX = textX + 80
    local centerX = panelX + self.detailPanelWidth * 0.5
    local currentY = 160
    
    -- Check large icon hover
    if selectedRelic.icon then
      local ok, iconImg = pcall(love.graphics.newImage, selectedRelic.icon)
      if ok and iconImg then
        local largeIconSize = 270
        local iconScale = largeIconSize / math.max(iconImg:getWidth(), iconImg:getHeight())
        local iconW = iconImg:getWidth() * iconScale
        local iconH = iconImg:getHeight() * iconScale
        local iconX = centerX - iconW * 0.5
        local iconY = currentY
        
        if mx >= iconX and mx <= iconX + iconW and my >= iconY and my <= iconY + iconH then
          detailPanelRelicId = selectedRelic.id
          detailPanelBounds = {
            x = iconX,
            y = iconY,
            w = iconW,
            h = iconH
          }
        end
      end
    end
    
    -- Check name hover (if not already hovering icon)
    if not detailPanelRelicId then
      local nameFont = self.nameFont or theme.fonts.large or theme.fonts.base
      local name = selectedRelic.name or selectedRelic.id
      local nameW = nameFont:getWidth(name)
      local nameY = currentY + 270 + 36 + (self.rarityFont or theme.fonts.small or theme.fonts.base):getHeight() + 8
      local nameX = descX
      
      if mx >= nameX and mx <= nameX + nameW and my >= nameY and my <= nameY + nameFont:getHeight() then
        detailPanelRelicId = selectedRelic.id
        detailPanelBounds = {
          x = nameX,
          y = nameY,
          w = nameW,
          h = nameFont:getHeight()
        }
      end
    end
  end
  
  -- Check grid hover
  local gridRelicId = nil
  local gridBounds = nil
  
  if self.hoveredIndex and self.hoveredIndex > 0 and self.hoveredIndex <= #ownedRelics then
    local relicDef = ownedRelics[self.hoveredIndex]
    gridRelicId = relicDef.id
    
    -- Calculate bounds of hovered item
    local gridStartX = self.gridPadding
    local gridStartY = 140
    local nameFont = theme.fonts.small or theme.fonts.base
    local paddingTop = 12
    local paddingBottom = 12
    local iconNameSpacing = 12
    local itemHeight = paddingTop + self.gridIconSize + iconNameSpacing + nameFont:getHeight() + paddingBottom
    local itemW = self.gridIconSize * 1.5
    
    local col = ((self.hoveredIndex - 1) % self.gridColumns)
    local row = math.floor((self.hoveredIndex - 1) / self.gridColumns)
    local baseX = gridStartX + col * (itemW + self.gridIconSpacing)
    local baseY = gridStartY + row * (itemHeight + self.gridIconSpacing) - self.scroll.y
    
    gridBounds = {
      x = baseX,
      y = baseY,
      w = itemW,
      h = itemHeight
    }
  end
  
  -- Prioritize detail panel hover over grid hover
  local activeRelicId = detailPanelRelicId or gridRelicId
  local activeBounds = detailPanelBounds or gridBounds
  
  -- Update tooltip state
  if activeRelicId then
    -- Check if hovering over the same relic
    if self._tooltipRelicId == activeRelicId and self._tooltipBounds then
      -- Continue tracking hover time
      self._tooltipHoverTime = self._tooltipHoverTime + dt
      -- Update bounds in case they changed (e.g., due to scroll)
      if activeBounds then
        self._tooltipBounds = activeBounds
      end
    else
      -- New relic hovered, reset timer
      self._tooltipRelicId = activeRelicId
      self._tooltipHoverTime = 0
      self._tooltipBounds = activeBounds
    end
  else
    -- Not hovering, reset tooltip state
    self._tooltipRelicId = nil
    self._tooltipHoverTime = 0
    self._tooltipBounds = nil
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
  
  -- Tooltip disabled - detail panel already shows relic information
  -- self:_drawTooltip(alpha)
  
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
  local paddingTop = 12
  local paddingBottom = 12
  local iconNameSpacing = 12
  local itemHeight = paddingTop + self.gridIconSize + iconNameSpacing + nameFont:getHeight() + paddingBottom
  local itemW = self.gridIconSize * 1.5 -- Wider box width
  
  for i, relicDef in ipairs(ownedRelics) do
    local col = ((i - 1) % self.gridColumns)
    local row = math.floor((i - 1) / self.gridColumns)
    local baseX = gridStartX + col * (itemW + self.gridIconSpacing) -- Use wider box width for spacing
    local baseY = gridStartY + row * (itemHeight + self.gridIconSpacing) - self.scroll.y
    
    -- Only draw if visible
    if baseY + itemHeight >= gridStartY - 50 and baseY <= vh + 50 then
      local isSelected = (i == self.selectedIndex)
      local isHovered = (i == self.hoveredIndex)
      local hoverProgress = self._itemHoverProgress[i] or 0
      local itemScale = self._itemScale[i] or 1.0
      
      -- Calculate scaled dimensions and position (centered scaling)
      local itemH = itemHeight
      local scaledW = itemW * itemScale
      local scaledH = itemH * itemScale
      local boxX = baseX -- Left edge of the box (already positioned correctly)
      local x = boxX + (itemW - scaledW) * 0.5 -- Scaled box position
      local y = baseY + (itemH - scaledH) * 0.5
      local centerX = boxX + itemW * 0.5 -- Center of the wider box
      local centerY = baseY + itemH * 0.5
      
      -- Draw rounded box background (covers both icon and name)
      local bgAlpha = isSelected and 0.8 or (isHovered and 0.6 or 0.4)
      love.graphics.setColor(0, 0, 0, bgAlpha * alpha)
      love.graphics.rectangle("fill", x, y, scaledW, scaledH, 10, 10)
      
      -- Draw border
      local borderAlpha = isSelected and 1.0 or (isHovered and 0.6 or 0.3)
      love.graphics.setColor(1, 1, 1, borderAlpha * alpha)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", x, y, scaledW, scaledH, 10, 10)
      love.graphics.setLineWidth(1)
      
      -- Draw glow effect (similar to reward buttons)
      if hoverProgress > 0.01 then
        love.graphics.push()
        love.graphics.translate(centerX, centerY)
        love.graphics.scale(itemScale, itemScale)
        love.graphics.setBlendMode("add")
        
        -- Pulsing animation
        local pulseSpeed = 1.0
        local pulseAmount = 0.15
        local pulse = 1.0 + math.sin(self._glowTime * pulseSpeed * math.pi * 2) * pulseAmount
        local baseAlpha = 0.12 * pulse * hoverProgress * alpha
        local layers = {
          { width = 4, alpha = 0.4 },
          { width = 7, alpha = 0.25 },
          { width = 10, alpha = 0.15 },
        }
        
        for _, layer in ipairs(layers) do
          local glowAlpha = baseAlpha * layer.alpha
          if glowAlpha > 0 then
            local glowWidth = layer.width * pulse
            love.graphics.setColor(1, 1, 1, glowAlpha)
            love.graphics.setLineWidth(glowWidth)
            love.graphics.rectangle(
              "line",
              -itemW * 0.5 - glowWidth * 0.5,
              -itemH * 0.5 - glowWidth * 0.5,
              itemW + glowWidth,
              itemH + glowWidth,
              10 + glowWidth * 0.5,
              10 + glowWidth * 0.5
            )
          end
        end
        
        love.graphics.setBlendMode("alpha")
        love.graphics.pop()
      end
      
      -- Draw icon (centered horizontally in the wider box)
      if relicDef.icon then
        local ok, iconImg = pcall(love.graphics.newImage, relicDef.icon)
        if ok and iconImg then
          local iconScale = self.gridIconSize / math.max(iconImg:getWidth(), iconImg:getHeight())
          local iconX = boxX + (itemW - self.gridIconSize) * 0.5 -- Center icon horizontally in wider box
          local iconY = baseY + paddingTop
          love.graphics.setColor(1, 1, 1, alpha)
          love.graphics.draw(iconImg, iconX, iconY, 0, iconScale, iconScale)
        end
      end
      
      -- Draw name below icon (centered horizontally in the wider box)
      local nameFont = theme.fonts.small or theme.fonts.base
      love.graphics.setFont(nameFont)
      local name = relicDef.name or relicDef.id
      local nameW = nameFont:getWidth(name)
      local nameX = boxX + (itemW - nameW) * 0.5 -- Center name horizontally in wider box
      local nameY = baseY + paddingTop + self.gridIconSize + iconNameSpacing
      local nameAlpha = (isSelected or isHovered) and alpha or alpha * 0.8
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
  local currentY = 80
  
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

function InventoryScene:_drawTooltip(alpha)
  -- Only show tooltip after 0.3s hover time
  if not self._tooltipRelicId or self._tooltipHoverTime < 0.3 or not self._tooltipBounds then
    return
  end
  
  local relicDef = relics.get(self._tooltipRelicId)
  if not relicDef then return end
  
  local vw, vh = virtualSize()
  local bounds = self._tooltipBounds
  
  local font = theme.fonts.base
  love.graphics.setFont(font)
  
  -- Icon size and padding
  local iconSize = 48
  local iconPadding = 8
  local textPadding = 8
  local padding = 8
  
  -- Load icon
  local iconImg = nil
  if relicDef.icon then
    local ok, img = pcall(love.graphics.newImage, relicDef.icon)
    if ok then iconImg = img end
  end
  
  -- Build tooltip text (name + description)
  local tooltipText = ""
  if relicDef.name then
    tooltipText = tooltipText .. relicDef.name
  end
  if relicDef.description then
    if tooltipText ~= "" then
      tooltipText = tooltipText .. "\n" .. relicDef.description
    else
      tooltipText = relicDef.description
    end
  end
  
  if tooltipText == "" then return end
  
  -- Calculate size with increased font size
  local textLines = {}
  for line in tooltipText:gmatch("[^\n]+") do
    table.insert(textLines, line)
  end
  
  local textScale = 0.75 -- Increased from 0.5
  local maxTextW = 0
  for _, line in ipairs(textLines) do
    local w = font:getWidth(line) * textScale
    if w > maxTextW then maxTextW = w end
  end
  
  local baseTextH = font:getHeight() * #textLines
  local textW = maxTextW
  local textH = baseTextH * textScale
  
  -- Calculate tooltip dimensions (accounting for icon)
  -- Limit text width to make tooltip less wide
  local maxTextWidth = 200 -- Maximum text width
  if textW > maxTextWidth then
    textW = maxTextWidth
  end
  
  local tooltipW = padding * 2
  if iconImg then
    tooltipW = tooltipW + iconSize + iconPadding
  end
  tooltipW = tooltipW + textW
  
  -- Calculate text wrap width first (needed for height calculation)
  local availableTextWidth = tooltipW - padding * 2
  if iconImg then
    availableTextWidth = availableTextWidth - iconSize - iconPadding
  end
  local textWrapWidth = availableTextWidth / textScale
  
  -- Calculate actual wrapped text height
  local wrappedTextHeight = 0
  for _, line in ipairs(textLines) do
    local wrappedLines = {}
    local words = {}
    for word in line:gmatch("%S+") do
      table.insert(words, word)
    end
    local currentLine = ""
    for _, word in ipairs(words) do
      local testLine = currentLine == "" and word or currentLine .. " " .. word
      if font:getWidth(testLine) <= textWrapWidth then
        currentLine = testLine
      else
        if currentLine ~= "" then
          table.insert(wrappedLines, currentLine)
        end
        currentLine = word
      end
    end
    if currentLine ~= "" then
      table.insert(wrappedLines, currentLine)
    end
    wrappedTextHeight = wrappedTextHeight + font:getHeight() * math.max(1, #wrappedLines)
  end
  
  -- Recalculate tooltip height based on actual wrapped text
  local actualTextH = wrappedTextHeight * textScale
  local tooltipH = padding * 2 + math.max(iconSize, actualTextH)
  
  -- Calculate position (to the left of the hovered item)
  local tooltipX = bounds.x - tooltipW - 30 -- 30px gap from item left edge
  local tooltipY = bounds.y + bounds.h * 0.5 - tooltipH * 0.5 -- Vertically centered with item
  
  -- Clamp to canvas bounds
  local canvasLeft = 0
  local canvasRight = vw
  local canvasTop = 0
  local canvasBottom = vh
  
  if tooltipX < canvasLeft then
    -- If doesn't fit on left, show on right
    tooltipX = bounds.x + bounds.w + 30
  end
  if tooltipX + tooltipW > canvasRight then
    tooltipX = canvasRight - tooltipW
  end
  if tooltipY < canvasTop then
    tooltipY = canvasTop + padding
  end
  if tooltipY + tooltipH > canvasBottom then
    tooltipY = canvasBottom - tooltipH - padding
  end
  
  -- Fade in
  local fadeProgress = math.min(1.0, (self._tooltipHoverTime - 0.3) / 0.3)
  
  -- Draw background
  love.graphics.setColor(0, 0, 0, 0.85 * fadeProgress * alpha)
  love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipW, tooltipH, 4, 4)
  
  -- Draw border
  love.graphics.setColor(1, 1, 1, 0.3 * fadeProgress * alpha)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", tooltipX, tooltipY, tooltipW, tooltipH, 4, 4)
  
  -- Draw icon (top left)
  if iconImg then
    local iconX = tooltipX + padding
    local iconY = tooltipY + padding
    local iconScale = iconSize / math.max(iconImg:getWidth(), iconImg:getHeight())
    love.graphics.setColor(1, 1, 1, fadeProgress * alpha)
    love.graphics.draw(iconImg, iconX, iconY, 0, iconScale, iconScale)
  end
  
  -- Draw text (to the right of icon, or left if no icon)
  local textX = tooltipX + padding
  if iconImg then
    textX = textX + iconSize + iconPadding
  end
  local textY = tooltipY + padding
  
  love.graphics.push()
  love.graphics.translate(textX, textY)
  love.graphics.scale(textScale, textScale)
  local currentY = 0
  for i, line in ipairs(textLines) do
    -- First line (name) can be colored by rarity
    if i == 1 and relicDef.rarity then
      local rarityColor = RARITY_COLORS[relicDef.rarity] or RARITY_COLORS.common
      love.graphics.setColor(rarityColor[1], rarityColor[2], rarityColor[3], fadeProgress * alpha)
    else
      love.graphics.setColor(1, 1, 1, fadeProgress * alpha)
    end
    -- Use printf for text wrapping
    love.graphics.printf(line, 0, currentY, textWrapWidth, "left")
    -- Calculate wrapped height for this line
    local wrappedLines = {}
    local words = {}
    for word in line:gmatch("%S+") do
      table.insert(words, word)
    end
    local currentLine = ""
    for _, word in ipairs(words) do
      local testLine = currentLine == "" and word or currentLine .. " " .. word
      if font:getWidth(testLine) <= textWrapWidth then
        currentLine = testLine
      else
        if currentLine ~= "" then
          table.insert(wrappedLines, currentLine)
        end
        currentLine = word
      end
    end
    if currentLine ~= "" then
      table.insert(wrappedLines, currentLine)
    end
    currentY = currentY + font:getHeight() * math.max(1, #wrappedLines)
  end
  love.graphics.pop()
  
  love.graphics.setColor(1, 1, 1, 1)
end

function InventoryScene:_ensureSelectedVisible()
  local vw, vh = virtualSize()
  local gridStartY = 140
  local gridEndY = vh - 40
  local nameFont = theme.fonts.small or theme.fonts.base
  local paddingTop = 12
  local paddingBottom = 12
  local iconNameSpacing = 12
  local itemHeight = paddingTop + self.gridIconSize + iconNameSpacing + nameFont:getHeight() + paddingBottom
  
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
    local paddingTop = 12
    local paddingBottom = 12
    local iconNameSpacing = 12
    local itemHeight = paddingTop + self.gridIconSize + iconNameSpacing + nameFont:getHeight() + paddingBottom
    
    for i, relicDef in ipairs(ownedRelics) do
      local col = ((i - 1) % self.gridColumns)
      local row = math.floor((i - 1) / self.gridColumns)
      local itemW = self.gridIconSize * 1.5 -- Increased width by 50%
      local baseX = gridStartX + col * (itemW + self.gridIconSpacing) -- Use wider box width for spacing
      local itemX = baseX
      local itemY = gridStartY + row * (itemHeight + self.gridIconSpacing) - self.scroll.y
      
      if x >= itemX and x <= itemX + itemW and
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
