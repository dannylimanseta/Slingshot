local theme = require("theme")
local config = require("config")
local ProjectileManager = require("managers.ProjectileManager")
local ProjectileCard = require("ui.ProjectileCard")
local Button = require("ui.Button")

local OrbsUI = {}
OrbsUI.__index = OrbsUI

function OrbsUI.new()
  -- Create smaller font for close button (80% of base font size)
  local baseFontSize = 24 -- base font size
  local closeButtonFont = theme.newFont(baseFontSize * 0.8) -- 20% smaller
  
  local self = setmetatable({
    card = ProjectileCard.new(),
    fadeAlpha = 0,
    targetAlpha = 0,
    fadeSpeed = 8,
    scrollOffset = 0, -- Current vertical scroll position
    scrollVelocity = 0, -- Current scroll velocity (for smooth scrolling)
    scrollSpeed = 400, -- Pixels per second scroll speed
    scrollFriction = 8, -- Friction for smooth scrolling
    closeButtonFont = closeButtonFont, -- Store font for button
    closeButton = Button.new({
      label = "CLOSE",
      font = closeButtonFont,
      align = "center", -- Center the text in the button
      onClick = function() end, -- Will be set by parent
    }),
    -- Drag and drop state
    _draggedIndex = nil, -- Index of card being dragged
    _dragStartX = 0, -- Mouse X when drag started
    _dragStartY = 0, -- Mouse Y when drag started
    _dragOffsetX = 0, -- Offset from card center when dragging started
    _dragOffsetY = 0,
    _cardBounds = {}, -- Store card bounds for hit testing { [index] = {x, y, w, h} }
    _mouseX = 0, -- Current mouse X position
    _mouseY = 0, -- Current mouse Y position
  }, OrbsUI)
  return self
end

function OrbsUI:setVisible(visible)
  self.targetAlpha = visible and 1 or 0
  if not visible then
    -- Reset scroll when closing
    self.scrollOffset = 0
    self.scrollVelocity = 0
    -- Reset drag state
    self._draggedIndex = nil
  end
end

function OrbsUI:scroll(delta)
  -- Add scroll velocity (will be smoothed in update)
  self.scrollVelocity = self.scrollVelocity - delta * self.scrollSpeed
end

function OrbsUI:update(dt, mouseX, mouseY)
  -- Store mouse position for drag visualization
  if mouseX and mouseY then
    self._mouseX = mouseX
    self._mouseY = mouseY
  end
  
  -- Smooth fade in/out
  local diff = self.targetAlpha - self.fadeAlpha
  self.fadeAlpha = self.fadeAlpha + diff * math.min(1, self.fadeSpeed * dt)
  
  -- Snap to target when close
  if math.abs(diff) < 0.01 then
    self.fadeAlpha = self.targetAlpha
  end
  
  -- Update scroll with smooth velocity
  if math.abs(self.scrollVelocity) > 0.1 then
    self.scrollOffset = self.scrollOffset + self.scrollVelocity * dt
    -- Apply friction
    self.scrollVelocity = self.scrollVelocity * (1 - self.scrollFriction * dt)
    if math.abs(self.scrollVelocity) < 0.1 then
      self.scrollVelocity = 0
    end
  end
  
  -- Update close button
  if self.closeButton and mouseX and mouseY then
    self.closeButton:update(dt, mouseX, mouseY)
  end
end

function OrbsUI:mousepressed(x, y, button)
  if button == 1 and self.closeButton then
    if self.closeButton:mousepressed(x, y, button) then
      return true -- Close button was clicked
    end
  end
  
  -- Check if clicking on an orb card to start dragging
  if button == 1 and self.fadeAlpha > 0.5 then
    local equippedIds = (config.player and config.player.equippedProjectiles) or {}
    for i, bounds in ipairs(self._cardBounds) do
      if x >= bounds.x and x <= bounds.x + bounds.w and
         y >= bounds.y and y <= bounds.y + bounds.h then
        -- Start dragging this card
        self._draggedIndex = i
        self._dragStartX = x
        self._dragStartY = y
        self._dragOffsetX = x - (bounds.x + bounds.w * 0.5)
        self._dragOffsetY = y - (bounds.y + bounds.h * 0.5)
        return false -- Don't consume event, but mark as dragging
      end
    end
  end
  
  return false
end

function OrbsUI:mousereleased(x, y, button)
  if button == 1 and self._draggedIndex then
    local equippedIds = (config.player and config.player.equippedProjectiles) or {}
    
    -- Find which card (if any) the mouse was released over
    local targetIndex = nil
    for i, bounds in ipairs(self._cardBounds) do
      if x >= bounds.x and x <= bounds.x + bounds.w and
         y >= bounds.y and y <= bounds.y + bounds.h then
        targetIndex = i
        break
      end
    end
    
    -- If released over a different card, swap them
    if targetIndex and targetIndex ~= self._draggedIndex and targetIndex <= #equippedIds then
      -- Swap the orbs in the equipped list
      local temp = equippedIds[self._draggedIndex]
      equippedIds[self._draggedIndex] = equippedIds[targetIndex]
      equippedIds[targetIndex] = temp
      
      -- Return true to indicate order was changed (so parent can reload shooter)
      self._draggedIndex = nil
      return true
    end
    
    -- End dragging
    self._draggedIndex = nil
  end
  
  return false
end

function OrbsUI:draw()
  if self.fadeAlpha <= 0 then return end
  
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  
  -- Save current transform state
  love.graphics.push()
  
  -- Dark overlay background
  love.graphics.setColor(0, 0, 0, 0.9 * self.fadeAlpha)
  love.graphics.rectangle("fill", 0, 0, vw, vh)
  
  -- Get equipped projectiles
  local equippedIds = (config.player and config.player.equippedProjectiles) or {}
  
  if #equippedIds == 0 then
    -- No orbs message
    love.graphics.setFont(theme.fonts.base)
    local text = "No orbs equipped"
    local textW = theme.fonts.base:getWidth(text)
    local textH = theme.fonts.base:getHeight()
    local textX = (vw - textW) * 0.5
    local textY = (vh - textH) * 0.5
    theme.drawTextWithOutline(text, textX, textY, 1, 1, 1, self.fadeAlpha, 2)
    love.graphics.setColor(1, 1, 1, 1)
    return
  end
  
  -- Card dimensions and spacing
  local baseCardW = 288
  local baseCardSpacing = 40 -- increased spacing between cards horizontally
  local sidePadding = 40 -- padding from screen edges
  
  -- Calculate how many cards fit per row
  local availableWidth = vw - (sidePadding * 2)
  local maxCardsPerRow = math.floor((availableWidth + baseCardSpacing) / (baseCardW + baseCardSpacing))
  maxCardsPerRow = math.max(1, maxCardsPerRow) -- At least 1 card per row
  
  -- Calculate layout: wrap to multiple rows
  local numRows = math.ceil(#equippedIds / maxCardsPerRow)
  
  -- Calculate card height (use first card as reference)
  local cardH = 200 -- fallback height
  if #equippedIds > 0 then
    local firstProjectile = ProjectileManager.getProjectile(equippedIds[1])
    if firstProjectile then
      cardH = self.card:calculateHeight(firstProjectile)
    end
  end
  
  -- Vertical spacing between rows
  local rowSpacing = 48 -- increased spacing between rows vertically
  local totalHeight = cardH * numRows + rowSpacing * math.max(0, numRows - 1)
  
  -- Calculate scrollable area
  local topPadding = 64 -- space for title
  local bottomPadding = 0 -- no padding at bottom edge
  local visibleHeight = vh - topPadding - bottomPadding
  local maxScroll = math.max(0, totalHeight - visibleHeight)
  
  -- Clamp scroll offset
  self.scrollOffset = math.max(0, math.min(maxScroll, self.scrollOffset))
  
  -- Calculate card start position (centered if fits, otherwise scrollable)
  local startY = topPadding
  if totalHeight <= visibleHeight then
    -- Center if all rows fit
    startY = topPadding + (visibleHeight - totalHeight) * 0.5
    self.scrollOffset = 0 -- Reset scroll if everything fits
  else
    -- Scrollable: offset by scroll
    startY = topPadding - self.scrollOffset
  end
  
  -- Draw title (fixed at top)
  love.graphics.setFont(theme.fonts.base)
  local titleText = "EQUIPPED ORBS"
  local titleW = theme.fonts.base:getWidth(titleText)
  local titleX = (vw - titleW) * 0.5
  local titleY = 15 -- shifted down by 6px from 10
  theme.drawTextWithOutline(titleText, titleX, titleY, 1, 1, 1, self.fadeAlpha, 2)
  
  -- Set up scissor for clipping cards to visible area
  -- Account for supersampling: scissor coordinates need to be scaled
  love.graphics.push()
  local supersamplingFactor = _G.supersamplingFactor or 1
  local scissorX = 0 * supersamplingFactor
  local scissorY = topPadding * supersamplingFactor
  local scissorW = vw * supersamplingFactor
  local scissorH = visibleHeight * supersamplingFactor
  love.graphics.setScissor(scissorX, scissorY, scissorW, scissorH)
  
  -- Use stored mouse position for drag visualization
  local virtualMouseX = self._mouseX or 0
  local virtualMouseY = self._mouseY or 0
  
  -- Draw orb cards in rows
  for i, projectileId in ipairs(equippedIds) do
    local rowIndex = math.floor((i - 1) / maxCardsPerRow)
    local colIndex = ((i - 1) % maxCardsPerRow)
    
    -- Calculate position for this card
    local cardsInThisRow = math.min(maxCardsPerRow, #equippedIds - rowIndex * maxCardsPerRow)
    local rowWidth = baseCardW * cardsInThisRow + baseCardSpacing * math.max(0, cardsInThisRow - 1)
    local rowStartX = (vw - rowWidth) * 0.5
    
    local cardX = rowStartX + colIndex * (baseCardW + baseCardSpacing)
    local cardY = startY + rowIndex * (cardH + rowSpacing)
    
    -- Store card bounds for hit testing
    self._cardBounds[i] = {
      x = cardX,
      y = cardY,
      w = baseCardW,
      h = cardH
    }
    
    -- If this card is being dragged, draw it at mouse position with reduced alpha
    if self._draggedIndex == i then
      -- Draw original position with reduced alpha
      love.graphics.setColor(1, 1, 1, self.fadeAlpha * 0.3)
      self.card:draw(cardX, cardY, projectileId, self.fadeAlpha * 0.3)
      
      -- Draw dragged card at mouse position
      local dragX = virtualMouseX - self._dragOffsetX
      local dragY = virtualMouseY - self._dragOffsetY
      love.graphics.setColor(1, 1, 1, self.fadeAlpha)
      love.graphics.push()
      love.graphics.translate(dragX - cardX, dragY - cardY)
      self.card:draw(cardX, cardY, projectileId, self.fadeAlpha)
      love.graphics.pop()
    else
      -- Normal drawing
      love.graphics.setColor(1, 1, 1, self.fadeAlpha)
    self.card:draw(cardX, cardY, projectileId, self.fadeAlpha)
    end
  end
  
  love.graphics.setColor(1, 1, 1, 1)
  
  love.graphics.setScissor()
  love.graphics.pop()
  
  -- Draw scroll indicators (fade gradients at edges when scrollable)
  if maxScroll > 0 then
    local fadeHeight = 60
    local fadeAlpha = 0.4 * self.fadeAlpha
    
    -- Top fade (if scrolled down)
    if self.scrollOffset > 0 then
      local fadeProgress = math.min(1, self.scrollOffset / fadeHeight)
      love.graphics.setColor(0, 0, 0, fadeAlpha * fadeProgress)
      love.graphics.rectangle("fill", 0, topPadding, vw, fadeHeight)
    end
    
    -- Bottom fade (if can scroll down) - extends to bottom edge
    if self.scrollOffset < maxScroll then
      local fadeProgress = math.min(1, (maxScroll - self.scrollOffset) / fadeHeight)
      love.graphics.setColor(0, 0, 0, fadeAlpha * fadeProgress)
      love.graphics.rectangle("fill", 0, vh - bottomPadding - fadeHeight, vw, fadeHeight)
    end
  end
  
  -- Draw close button (top right)
  if self.closeButton then
    local buttonFont = self.closeButtonFont or theme.fonts.base
    love.graphics.setFont(buttonFont)
    local buttonPaddingX = 16 -- horizontal padding inside button
    local buttonPaddingY = 6 -- vertical padding inside button
    local buttonText = "CLOSE"
    local textW = buttonFont:getWidth(buttonText)
    local textH = buttonFont:getHeight()
    local buttonW = textW + buttonPaddingX * 2 -- wrap around text
    local buttonH = textH + buttonPaddingY * 2
    local buttonMargin = 20 -- margin from screen edges
    local buttonX = vw - buttonW - buttonMargin
    local buttonY = buttonMargin
    self.closeButton:setLayout(buttonX, buttonY, buttonW, buttonH)
    self.closeButton.alpha = self.fadeAlpha
    self.closeButton:draw()
  end
  
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.pop() -- Restore transform state
end

return OrbsUI

