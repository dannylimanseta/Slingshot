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
    _glowTime = 0,
    _cardHoverProgress = {}, -- per-card tweened hover
    _selectedIndex = 1, -- default highlighted card index
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
    _dragTweenX = 0, -- Tweened X position for smooth dragging
    _dragTweenY = 0, -- Tweened Y position for smooth dragging
    _dragTweenSpeed = 20, -- Speed of drag tweening (higher = faster)
    _cardBounds = {}, -- Store card bounds for hit testing { [index] = {x, y, w, h} }
    _mouseX = 0, -- Current mouse X position
    _mouseY = 0, -- Current mouse Y position
    _hoveredOrbIndex = nil, -- Index of orb being hovered for tooltip
    _orbHoverTimes = {}, -- Track hover time per orb for tooltip delay
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
    self._dragTweenX = 0
    self._dragTweenY = 0
    -- Reset selection
    self._selectedIndex = 1
  else
    -- When opening, default highlight the first card
    self._selectedIndex = 1
    self._cardHoverProgress[1] = 1
  end
end

function OrbsUI:scroll(delta)
  -- Add scroll velocity (will be smoothed in update)
  self.scrollVelocity = self.scrollVelocity - delta * self.scrollSpeed
end

function OrbsUI:update(dt, mouseX, mouseY)
  -- Store dt for hover timing calculations
  self._lastDt = dt
  
  -- Glow time
  self._glowTime = (self._glowTime or 0) + dt
  -- Clamp selected index to valid range if equipped list changed
  do
    local equippedIds = (config.player and config.player.equippedProjectiles) or {}
    if #equippedIds > 0 then
      if not self._selectedIndex or self._selectedIndex < 1 then self._selectedIndex = 1 end
      if self._selectedIndex > #equippedIds then self._selectedIndex = #equippedIds end
    else
      self._selectedIndex = nil
    end
  end
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
    -- Tween hover progress for close button
    local hp = self.closeButton._hoverProgress or 0
    local target = (self.closeButton._hovered and 1) or 0
    self.closeButton._hoverProgress = hp + (target - hp) * math.min(1, 10 * dt)
  end
  
  -- Update drag tween position
  if self._draggedIndex and mouseX and mouseY then
    local targetX = mouseX
    local targetY = mouseY
    local currentX = self._dragTweenX or targetX
    local currentY = self._dragTweenY or targetY
    local tweenSpeed = self._dragTweenSpeed or 20
    -- Smoothly tween toward target position
    self._dragTweenX = currentX + (targetX - currentX) * math.min(1, tweenSpeed * dt)
    self._dragTweenY = currentY + (targetY - currentY) * math.min(1, tweenSpeed * dt)
  end
  
  -- Update hover times for tooltips (will be set in draw based on actual hover state)
  -- This is just to ensure the table exists
  local equippedIds = (config.player and config.player.equippedProjectiles) or {}
  for i, projectileId in ipairs(equippedIds) do
    if not self._orbHoverTimes[i] then
      self._orbHoverTimes[i] = 0
    end
  end
end
 
-- Keyboard navigation for inventory cards
function OrbsUI:keypressed(key)
  local equippedIds = (config.player and config.player.equippedProjectiles) or {}
  local count = #equippedIds
  if count == 0 then return false end
  -- Recompute layout params to match draw()
  local vw = config.video.virtualWidth
  local baseCardW = 288
  local baseCardSpacing = 40
  local sidePadding = 40
  local availableWidth = vw - (sidePadding * 2)
  local maxCardsPerRow = math.floor((availableWidth + baseCardSpacing) / (baseCardW + baseCardSpacing))
  maxCardsPerRow = math.max(1, maxCardsPerRow)
  local idx = self._selectedIndex or 1
  local consumed = false
  if key == "a" or key == "left" then
    idx = math.max(1, idx - 1); consumed = true
  elseif key == "d" or key == "right" then
    idx = math.min(count, idx + 1); consumed = true
  elseif key == "w" or key == "up" then
    idx = math.max(1, idx - maxCardsPerRow); consumed = true
  elseif key == "s" or key == "down" then
    idx = math.min(count, idx + maxCardsPerRow); consumed = true
  end
  if consumed then
    self._selectedIndex = idx
    -- Boost hover progress for selected card for immediate feedback
    self._cardHoverProgress[idx] = math.max(0.6, self._cardHoverProgress[idx] or 0)
    return true
  end
  return false
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
        -- Initialize tween position to current mouse position for instant start
        self._dragTweenX = x
        self._dragTweenY = y
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
      self._dragTweenX = 0
      self._dragTweenY = 0
      return true
    end
    
    -- End dragging
    self._draggedIndex = nil
    self._dragTweenX = 0
    self._dragTweenY = 0
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
  
  -- Icon dimensions and spacing (matching RestSiteScene layout)
  local iconSize = 80
  local spacing = 32
  local rowSpacing = 20
  local maxCardsPerRow = 4
  local regularFontPath = "assets/fonts/BarlowCondensed-Regular.ttf"
  local nameFont = theme.newFont(20, regularFontPath)
  
  -- Calculate layout: wrap to multiple rows
  local numRows = math.ceil(#equippedIds / maxCardsPerRow)
  
  -- Calculate total height needed
  local nameH = nameFont:getHeight()
  local itemHeight = iconSize + 8 + nameH
  local totalHeight = itemHeight * numRows + rowSpacing * math.max(0, numRows - 1)
  
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
  
  -- Draw instruction text (using regular font, not bold)
  local instructionText = "Drag orbs to reorder"
  local regularFont = theme.newFont(24, "assets/fonts/BarlowCondensed-Regular.ttf")
  love.graphics.setFont(regularFont)
  local instructionW = regularFont:getWidth(instructionText)
  local instructionX = (vw - instructionW) * 0.5
  local instructionY = titleY + theme.fonts.base:getHeight() + 8
  local instructionAlpha = 0.7 * self.fadeAlpha
  theme.drawTextWithOutline(instructionText, instructionX, instructionY, 1, 1, 1, instructionAlpha, 2)
  -- Reset font to base font
  love.graphics.setFont(theme.fonts.base)
  
  -- Set up scissor for clipping cards to visible area
  -- Account for supersampling: scissor coordinates need to be scaled
  love.graphics.push()
  local supersamplingFactor = _G.supersamplingFactor or 1
  local scissorX = 0 * supersamplingFactor
  local scissorY = topPadding * supersamplingFactor
  local scissorW = vw * supersamplingFactor
  local scissorH = visibleHeight * supersamplingFactor
  love.graphics.setScissor(scissorX, scissorY, scissorW, scissorH)
  
  -- Use stored mouse position for drag visualization and hover detection
  local virtualMouseX = self._mouseX or 0
  local virtualMouseY = self._mouseY or 0
  
  -- Update hover states and tooltip timing
  self._hoveredOrbIndex = nil
  for i, projectileId in ipairs(equippedIds) do
    local rowIndex = math.floor((i - 1) / maxCardsPerRow)
    local colIndex = ((i - 1) % maxCardsPerRow)
    
    -- Calculate position for this orb
    local cardsInThisRow = math.min(maxCardsPerRow, #equippedIds - rowIndex * maxCardsPerRow)
    local rowWidth = iconSize * cardsInThisRow + spacing * math.max(0, cardsInThisRow - 1)
    local rowStartX = (vw - rowWidth) * 0.5
    
    local iconX = rowStartX + colIndex * (iconSize + spacing)
    local iconY = startY + rowIndex * (itemHeight + rowSpacing)
    
    local nameH = nameFont:getHeight()
    local totalH = iconSize + 8 + nameH
    local boundsCenterX = iconX + iconSize * 0.5
    local boundsCenterY = iconY + totalH * 0.5
    
    -- Check if mouse is hovering
    local bounds = self._cardBounds[i] or {}
    local scale = bounds._scale or 1.0
    local scaledW = iconSize * scale
    local scaledH = totalH * scale
    local hovered = (virtualMouseX >= boundsCenterX - scaledW * 0.5 and virtualMouseX <= boundsCenterX + scaledW * 0.5 and
                     virtualMouseY >= boundsCenterY - scaledH * 0.5 and virtualMouseY <= boundsCenterY + scaledH * 0.5)
    
    -- Update hover time and scale
    if hovered then
      self._hoveredOrbIndex = i
      local prevHoverTime = self._orbHoverTimes[i] or 0
      -- Increment hover time (dt is stored from update)
      self._orbHoverTimes[i] = prevHoverTime + (self._lastDt or 0.016)
      bounds._scale = math.min(1.1, (bounds._scale or 1.0) + (self._lastDt or 0.016) * 3)
    else
      self._orbHoverTimes[i] = 0
      bounds._scale = math.max(1.0, (bounds._scale or 1.0) - (self._lastDt or 0.016) * 3)
    end
    
    -- Store bounds for hit testing (used for drag and drop)
    self._cardBounds[i] = {
      x = boundsCenterX - scaledW * 0.5,
      y = boundsCenterY - scaledH * 0.5,
      w = scaledW,
      h = scaledH,
      _hovered = hovered,
      _hoverTime = self._orbHoverTimes[i] or 0,
      _scale = bounds._scale or 1.0,
      _projectileId = projectileId,
      _iconX = iconX,
      _iconY = iconY,
    }
  end
  
  -- Draw orb icons with names in rows
  for i, projectileId in ipairs(equippedIds) do
    local rowIndex = math.floor((i - 1) / maxCardsPerRow)
    local colIndex = ((i - 1) % maxCardsPerRow)
    
    -- Calculate position for this orb
    local cardsInThisRow = math.min(maxCardsPerRow, #equippedIds - rowIndex * maxCardsPerRow)
    local rowWidth = iconSize * cardsInThisRow + spacing * math.max(0, cardsInThisRow - 1)
    local rowStartX = (vw - rowWidth) * 0.5
    
    local iconX = rowStartX + colIndex * (iconSize + spacing)
    local iconY = startY + rowIndex * (itemHeight + rowSpacing)
    
    local p = ProjectileManager.getProjectile(projectileId)
    local bounds = self._cardBounds[i] or {}
    local scale = bounds._scale or 1.0
    local hovered = bounds._hovered or false
    
    -- If this orb is being dragged, draw it at mouse position
    if self._draggedIndex == i then
      -- Draw original position with reduced alpha
      local nameH = nameFont:getHeight()
      local totalH = iconSize + 8 + nameH
      local boundsCenterX = iconX + iconSize * 0.5
      local boundsCenterY = iconY + totalH * 0.5
      self:_drawOrbIcon(iconX, iconY, iconSize, p, projectileId, nameFont, self.fadeAlpha * 0.3, 1.0)
      
      -- Draw dragged orb centered at tweened mouse position
      local dragCenterX = self._dragTweenX or virtualMouseX
      local dragCenterY = self._dragTweenY or virtualMouseY
      local dragIconX = dragCenterX - iconSize * 0.5
      local dragIconY = dragCenterY - totalH * 0.5
      self:_drawOrbIcon(dragIconX, dragIconY, iconSize, p, projectileId, nameFont, self.fadeAlpha, 1.0)
    else
      -- Normal drawing with hover scale
      self:_drawOrbIcon(iconX, iconY, iconSize, p, projectileId, nameFont, self.fadeAlpha, scale, hovered)
    end
  end
  
  -- Draw tooltip on hover
  if self._hoveredOrbIndex and self._cardBounds[self._hoveredOrbIndex] then
    local bounds = self._cardBounds[self._hoveredOrbIndex]
    if bounds._hoverTime and bounds._hoverTime > 0.3 then
      self:_drawOrbTooltip(self._hoveredOrbIndex, bounds, self.fadeAlpha)
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
    -- Glow on hover for close button
    if self.closeButton._hovered then
      love.graphics.push()
      local cx = self.closeButton.x + self.closeButton.w * 0.5
      local cy = self.closeButton.y + self.closeButton.h * 0.5
      local s = self.closeButton._scale or 1.0
      love.graphics.translate(cx, cy)
      love.graphics.scale(s, s)
      love.graphics.setBlendMode("add")
      local pulseSpeed = 1.0
      local pulseAmount = 0.15
      local pulse = 1.0 + math.sin((self._glowTime or 0) * pulseSpeed * math.pi * 2) * pulseAmount
      local baseAlpha = 0.12 * (self.closeButton.alpha or 1.0) * (self.closeButton._hoverProgress or 0)
      local layers = { { width = 4, alpha = 0.4 }, { width = 7, alpha = 0.25 }, { width = 10, alpha = 0.15 } }
      for _, layer in ipairs(layers) do
        local glowAlpha = baseAlpha * layer.alpha * pulse
        local glowWidth = layer.width * pulse
        love.graphics.setColor(1, 1, 1, glowAlpha)
        love.graphics.setLineWidth(glowWidth)
        love.graphics.rectangle("line", -self.closeButton.w * 0.5 - glowWidth * 0.5, -self.closeButton.h * 0.5 - glowWidth * 0.5,
                                self.closeButton.w + glowWidth, self.closeButton.h + glowWidth,
                                Button.defaults.cornerRadius + glowWidth * 0.5, Button.defaults.cornerRadius + glowWidth * 0.5)
      end
      love.graphics.setBlendMode("alpha")
      love.graphics.pop()
    end
  end
  
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.pop() -- Restore transform state
end

function OrbsUI:_drawOrbIcon(iconX, iconY, iconSize, projectile, projectileId, nameFont, fadeAlpha, scale, hovered)
  scale = scale or 1.0
  hovered = hovered or false
  
  -- Draw orb icon with hover scale
  love.graphics.push()
  local cx = iconX + iconSize * 0.5
  local cy = iconY + iconSize * 0.5
  love.graphics.translate(cx, cy)
  love.graphics.scale(scale, scale)
  love.graphics.translate(-cx, -cy)
  
  -- Draw icon
  if projectile and projectile.icon then
    local ok, iconImg = pcall(love.graphics.newImage, projectile.icon)
    if ok and iconImg then
      love.graphics.setColor(1, 1, 1, fadeAlpha)
      local iw, ih = iconImg:getWidth(), iconImg:getHeight()
      local iconScale = iconSize / math.max(iw, ih) * 0.8
      local drawX = iconX + (iconSize - iw * iconScale) * 0.5
      local drawY = iconY + (iconSize - ih * iconScale) * 0.5
      love.graphics.draw(iconImg, drawX, drawY, 0, iconScale, iconScale)
    end
  end
  
  love.graphics.pop()
  
  -- Draw name below icon
  love.graphics.setFont(nameFont)
  local nameText = (projectile and projectile.name) or projectileId
  local nameW = nameFont:getWidth(nameText)
  local nameX = iconX + (iconSize - nameW) * 0.5
  local nameY = iconY + iconSize + 8
  love.graphics.setColor(1, 1, 1, fadeAlpha)
  love.graphics.print(nameText, nameX, nameY)
end

function OrbsUI:_drawOrbTooltip(orbIndex, bounds, fadeAlpha)
  if not bounds._projectileId then return end
  
  local projectileId = bounds._projectileId
  local projectile = ProjectileManager.getProjectile(projectileId)
  if not projectile then return end
  
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  
  -- Calculate tooltip position (to the right of the orb, or left if too close to right edge)
  local tooltipX = bounds.x + bounds.w + 16
  local tooltipY = bounds.y
  
  -- If tooltip would go off screen, position it to the left instead
  local tooltipW = 288 -- Same as ProjectileCard width
  if tooltipX + tooltipW > vw - 20 then
    tooltipX = bounds.x - tooltipW - 16
  end
  
  -- Clamp vertically
  local tooltipH = self.card:calculateHeight(projectile)
  if tooltipY + tooltipH > vh - 20 then
    tooltipY = vh - tooltipH - 20
  end
  if tooltipY < 20 then
    tooltipY = 20
  end
  
  -- Fade in based on hover time
  local hoverTime = bounds._hoverTime or 0
  local fadeProgress = math.min(1.0, (hoverTime - 0.3) / 0.3)
  local tooltipAlpha = fadeAlpha * fadeProgress
  
  -- Draw the full card as tooltip
  if tooltipAlpha > 0 then
    self.card:draw(tooltipX, tooltipY, projectileId, tooltipAlpha)
  end
end

return OrbsUI

