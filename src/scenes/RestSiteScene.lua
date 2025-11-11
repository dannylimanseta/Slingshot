local config = require("config")
local theme = require("theme")
local Button = require("ui.Button")
local TopBar = require("ui.TopBar")
local PlayerState = require("core.PlayerState")
local ProjectileManager = require("managers.ProjectileManager")
local ProjectileCard = require("ui.ProjectileCard")

local RestSiteScene = {}
RestSiteScene.__index = RestSiteScene

function RestSiteScene.new()
  return setmetatable({
    backgroundImage = nil,
    titleFont = nil,
    textFont = nil,
    restButton = nil,
    removeOrbButton = nil,
    topBar = TopBar.new(),
    mouseX = 0,
    mouseY = 0,
    _fadeTimer = 0,
    _fadeInDuration = 0.5,
    _fadeStartDelay = 0.2,
    _exitRequested = false,
    _choiceMade = false,
    -- Orb removal UI state
    _showOrbSelection = false,
    _orbCards = {},
    _orbBounds = {},
    _selectedOrbIndex = nil,
    card = ProjectileCard.new(),
  }, RestSiteScene)
end

function RestSiteScene:load()
  self._fadeTimer = 0
  self._choiceMade = false
  self._exitRequested = false
  self._showOrbSelection = false
  self._selectedOrbIndex = nil
  
  -- Load background image
  local bgPath = "assets/images/rest/rest_bg_1.png"
  local ok, img = pcall(love.graphics.newImage, bgPath)
  if ok then
    self.backgroundImage = img
  end
  
  -- Create fonts
  local boldFontPath = "assets/fonts/BarlowCondensed-Bold.ttf"
  self.titleFont = theme.newFont(50, boldFontPath)
  local regularFontPath = "assets/fonts/BarlowCondensed-Regular.ttf"
  self.textFont = theme.newFont(20, regularFontPath)
  
  -- Create choice buttons
  self.restButton = Button.new({
    label = "Rest. Heal for 20 HP.",
    font = self.textFont,
    bgColor = { 0, 0, 0, 0.7 },
    align = "left",
    onClick = function()
      if self._choiceMade then return end
      self._choiceMade = true
      -- Heal player
      local playerState = PlayerState.getInstance()
      local currentHP = playerState:getHealth()
      local maxHP = playerState:getMaxHealth()
      local newHP = math.min(maxHP, currentHP + 20)
      playerState:setHealth(newHP)
      self._exitRequested = true
    end,
  })
  
  self.removeOrbButton = Button.new({
    label = "Remove an Orb",
    font = self.textFont,
    bgColor = { 0, 0, 0, 0.7 },
    align = "left",
    onClick = function()
      if self._choiceMade then return end
      -- Show orb selection UI
      self._showOrbSelection = true
      self:_buildOrbSelection()
    end,
  })
  
  -- Initialize scale for hover effect
  self.restButton._scale = 1.0
  self.removeOrbButton._scale = 1.0
end

function RestSiteScene:_buildOrbSelection()
  local equipped = (config.player and config.player.equippedProjectiles) or {}
  self._orbCards = {}
  self._orbBounds = {}
  
  for _, id in ipairs(equipped) do
    local p = ProjectileManager.getProjectile(id)
    if p then
      table.insert(self._orbCards, { id = id, projectile = p })
    end
  end
end

function RestSiteScene:update(dt, mouseX, mouseY)
  -- Get mouse position
  if mouseX and mouseY then
    self.mouseX = mouseX
    self.mouseY = mouseY
  else
    local mx, my = love.mouse.getPosition()
    if mx and my then
      local vw = config.video.virtualWidth
      local vh = config.video.virtualHeight
      local winW, winH = love.graphics.getDimensions()
      local scaleFactor = math.min(winW / vw, winH / vh)
      local offsetX = math.floor((winW - vw * scaleFactor) * 0.5)
      local offsetY = math.floor((winH - vh * scaleFactor) * 0.5)
      self.mouseX = (mx - offsetX) / scaleFactor
      self.mouseY = (my - offsetY) / scaleFactor
    end
  end
  
  -- Update fade timer
  self._fadeTimer = self._fadeTimer + dt
  
  if self._showOrbSelection then
    -- Update orb card hover states
    for i, bounds in ipairs(self._orbBounds) do
      if self.mouseX >= bounds.x and self.mouseX <= bounds.x + bounds.w and
         self.mouseY >= bounds.y and self.mouseY <= bounds.y + bounds.h then
        if not bounds._hovered then
          bounds._hovered = true
          bounds._scale = 1.0
        end
        bounds._scale = math.min(1.1, bounds._scale + dt * 3)
      else
        bounds._hovered = false
        bounds._scale = math.max(1.0, bounds._scale - dt * 3)
      end
    end
  else
    -- Update button layouts and hover effects
    local vw = config.video.virtualWidth
    local vh = config.video.virtualHeight
    local topBarHeight = (config.playfield and config.playfield.topBarHeight) or 60
    local padding = 40
    local rightPanelWidth = vw * 0.65 - padding * 2
    local rightPanelX = vw * 0.35 + padding + 50
    local buttonWidth = (rightPanelWidth - padding) * 0.9
    local buttonHeight = 50
    local buttonSpacing = 15
    
    -- Calculate starting Y position for buttons
    local contentY = topBarHeight + 15
    if self.titleFont then
      contentY = contentY + self.titleFont:getHeight() + 30
    end
    if self.textFont then
      local textWidth = (rightPanelWidth - padding) * 0.9
      local text = "A faint campfire flickers in the dark forest, offering brief warmth amid the creeping fog. What do you want to do?"
      local lines = self:_wordWrap(text, textWidth, self.textFont)
      for _, line in ipairs(lines) do
        if line == "" then
          contentY = contentY + self.textFont:getHeight() * 0.5
        else
          contentY = contentY + self.textFont:getHeight() + 8
        end
      end
      contentY = contentY + 30
    end
    
    -- Set button layouts
    local buttonY = contentY
    self.restButton:setLayout(rightPanelX, buttonY, buttonWidth, buttonHeight)
    buttonY = buttonY + buttonHeight + buttonSpacing
    self.removeOrbButton:setLayout(rightPanelX, buttonY, buttonWidth, buttonHeight)
    
    -- Update buttons (hover effects) - disable if choice already made
    if not self._choiceMade then
      self.restButton:update(dt, self.mouseX, self.mouseY)
      self.removeOrbButton:update(dt, self.mouseX, self.mouseY)
    else
      self.restButton._hovered = false
      self.restButton._scale = 1.0
      self.removeOrbButton._hovered = false
      self.removeOrbButton._scale = 1.0
    end
    
    -- Update hit rects for click detection (needed since we manually draw buttons)
    -- Do this AFTER update() so scale is current
    local restScale = self.restButton._scale or 1.0
    local restCx = self.restButton.x + self.restButton.w * 0.5
    local restCy = self.restButton.y + self.restButton.h * 0.5
    self.restButton._hitRect = {
      x = math.floor(restCx - self.restButton.w * restScale * 0.5),
      y = math.floor(restCy - self.restButton.h * restScale * 0.5),
      w = math.floor(self.restButton.w * restScale),
      h = math.floor(self.restButton.h * restScale),
    }
    
    local removeScale = self.removeOrbButton._scale or 1.0
    local removeCx = self.removeOrbButton.x + self.removeOrbButton.w * 0.5
    local removeCy = self.removeOrbButton.y + self.removeOrbButton.h * 0.5
    self.removeOrbButton._hitRect = {
      x = math.floor(removeCx - self.removeOrbButton.w * removeScale * 0.5),
      y = math.floor(removeCy - self.removeOrbButton.h * removeScale * 0.5),
      w = math.floor(self.removeOrbButton.w * removeScale),
      h = math.floor(self.removeOrbButton.h * removeScale),
    }
  end
  
  -- Check for exit
  if self._exitRequested then
    -- Return to map with shader transition
    return { type = "return_to_map", skipTransition = false }
  end
  
  return nil
end

function RestSiteScene:_wordWrap(text, maxWidth, font)
  local lines = {}
  local words = {}
  for word in text:gmatch("%S+") do
    table.insert(words, word)
  end
  
  local currentLine = ""
  for _, word in ipairs(words) do
    local testLine = currentLine == "" and word or currentLine .. " " .. word
    local width = font:getWidth(testLine)
    
    if width > maxWidth and currentLine ~= "" then
      table.insert(lines, currentLine)
      currentLine = word
    else
      currentLine = testLine
    end
  end
  
  if currentLine ~= "" then
    table.insert(lines, currentLine)
  end
  
  return lines
end

function RestSiteScene:draw()
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  
  -- Calculate fade alpha
  local fadeAlpha = 1.0
  if self._fadeTimer < self._fadeStartDelay then
    fadeAlpha = 0
  elseif self._fadeTimer < self._fadeStartDelay + self._fadeInDuration then
    local progress = (self._fadeTimer - self._fadeStartDelay) / self._fadeInDuration
    fadeAlpha = progress
  end
  
  -- Draw background (full canvas)
  if self.backgroundImage then
    love.graphics.setColor(1, 1, 1, fadeAlpha)
    local imgW, imgH = self.backgroundImage:getDimensions()
    local scaleX = vw / imgW
    local scaleY = vh / imgH
    local scale = math.max(scaleX, scaleY) -- Cover entire canvas
    local scaledW = imgW * scale
    local scaledH = imgH * scale
    local offsetX = (vw - scaledW) * 0.5
    local offsetY = (vh - scaledH) * 0.5
    love.graphics.draw(self.backgroundImage, offsetX, offsetY, 0, scale, scale)
  else
    -- Fallback background
    love.graphics.setColor(theme.colors.background[1], theme.colors.background[2], theme.colors.background[3], fadeAlpha)
    love.graphics.rectangle("fill", 0, 0, vw, vh)
  end
  
  -- Draw top bar
  if self.topBar then
    love.graphics.setColor(1, 1, 1, fadeAlpha)
    self.topBar:draw()
  end
  
  if self._showOrbSelection then
    self:_drawOrbSelection(fadeAlpha)
  else
    self:_drawMainChoices(fadeAlpha)
  end
end

function RestSiteScene:_drawMainChoices(fadeAlpha)
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  local topBarHeight = (config.playfield and config.playfield.topBarHeight) or 60
  local padding = 40
  local rightPanelWidth = vw * 0.65 - padding * 2
  local rightPanelX = vw * 0.35 + padding + 50
  local currentY = topBarHeight + 15
  
  -- Draw title
  if self.titleFont then
    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(1, 1, 1, fadeAlpha)
    love.graphics.print("Rest site", rightPanelX, currentY)
    currentY = currentY + self.titleFont:getHeight() + 30
  end
  
  -- Draw description text
  if self.textFont then
    love.graphics.setFont(self.textFont)
    love.graphics.setColor(0.9, 0.9, 0.9, fadeAlpha)
    
    local textX = rightPanelX
    local textWidth = (rightPanelWidth - padding) * 0.9
    local text = "A faint campfire flickers in the dark forest, offering brief warmth amid the creeping fog. What do you want to do?"
    local lines = self:_wordWrap(text, textWidth, self.textFont)
    
    for i, line in ipairs(lines) do
      if line == "" then
        currentY = currentY + self.textFont:getHeight() * 0.5
      else
        love.graphics.print(line, textX, currentY)
        currentY = currentY + self.textFont:getHeight() + 8
      end
    end
    
    currentY = currentY + 30
  end
  
  -- Draw choice buttons
  local buttonSpacing = 15
  local buttonWidth = (rightPanelWidth - padding) * 0.9
  local buttonHeight = 50
  
  -- Draw rest button
  local buttonAlpha = fadeAlpha
  if self._choiceMade then
    buttonAlpha = fadeAlpha * 0.5
  end
  self.restButton.alpha = buttonAlpha
  
  local cx = self.restButton.x + self.restButton.w * 0.5
  local cy = self.restButton.y + self.restButton.h * 0.5
  local hoverScale = self.restButton._scale or 1.0
  if self._choiceMade then
    hoverScale = 1.0
  end
  
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(hoverScale, hoverScale)
  
  local bg = self.restButton.bgColor or { 0, 0, 0, 0.7 }
  love.graphics.setColor(bg[1], bg[2], bg[3], (bg[4] or 1) * fadeAlpha)
  love.graphics.rectangle("fill", -self.restButton.w * 0.5, -self.restButton.h * 0.5, self.restButton.w, self.restButton.h, Button.defaults.cornerRadius, Button.defaults.cornerRadius)
  
  local bc = Button.defaults.borderColor
  love.graphics.setColor(bc[1], bc[2], bc[3], (bc[4] or 1) * fadeAlpha)
  local oldLW = love.graphics.getLineWidth()
  love.graphics.setLineWidth(Button.defaults.borderWidth)
  love.graphics.rectangle("line", -self.restButton.w * 0.5, -self.restButton.h * 0.5, self.restButton.w, self.restButton.h, Button.defaults.cornerRadius, Button.defaults.cornerRadius)
  love.graphics.setLineWidth(oldLW or 1)
  
  love.graphics.pop()
  
  -- Draw rest button text with color parsing
  self:_drawChoiceText(self.restButton, buttonAlpha, hoverScale)
  
  -- Draw remove orb button
  buttonAlpha = fadeAlpha
  if self._choiceMade then
    buttonAlpha = fadeAlpha * 0.5
  end
  self.removeOrbButton.alpha = buttonAlpha
  
  cx = self.removeOrbButton.x + self.removeOrbButton.w * 0.5
  cy = self.removeOrbButton.y + self.removeOrbButton.h * 0.5
  hoverScale = self.removeOrbButton._scale or 1.0
  if self._choiceMade then
    hoverScale = 1.0
  end
  
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(hoverScale, hoverScale)
  
  bg = self.removeOrbButton.bgColor or { 0, 0, 0, 0.7 }
  love.graphics.setColor(bg[1], bg[2], bg[3], (bg[4] or 1) * fadeAlpha)
  love.graphics.rectangle("fill", -self.removeOrbButton.w * 0.5, -self.removeOrbButton.h * 0.5, self.removeOrbButton.w, self.removeOrbButton.h, Button.defaults.cornerRadius, Button.defaults.cornerRadius)
  
  love.graphics.setColor(bc[1], bc[2], bc[3], (bc[4] or 1) * fadeAlpha)
  love.graphics.setLineWidth(Button.defaults.borderWidth)
  love.graphics.rectangle("line", -self.removeOrbButton.w * 0.5, -self.removeOrbButton.h * 0.5, self.removeOrbButton.w, self.removeOrbButton.h, Button.defaults.cornerRadius, Button.defaults.cornerRadius)
  love.graphics.setLineWidth(oldLW or 1)
  
  love.graphics.pop()
  
  -- Draw remove orb button text
  self:_drawChoiceText(self.removeOrbButton, buttonAlpha, hoverScale)
end

function RestSiteScene:_drawChoiceText(button, alpha, hoverScale)
  hoverScale = hoverScale or 1.0
  love.graphics.setFont(button.font)
  
  local text = button.label
  local paddingX = 20
  local cx = button.x + button.w * 0.5
  local cy = button.y + button.h * 0.5
  
  -- Parse text for color markers
  local parts = {}
  local defaultColor = { 0.9, 0.9, 0.9 }
  
  local patterns = {
    { pattern = "Heal for (%d+) HP%.", color = { 195/255, 235/255, 139/255 } },  -- green (#C3EB8B)
  }
  
  local lastPos = 1
  local textToProcess = text
  
  while true do
    local bestMatch = nil
    local bestStart = #textToProcess + 1
    local bestEnd = nil
    
    for _, pat in ipairs(patterns) do
      local s, e = textToProcess:find(pat.pattern, lastPos)
      if s and s < bestStart then
        bestMatch = pat
        bestStart = s
        bestEnd = e
      end
    end
    
    if not bestMatch then
      if lastPos <= #textToProcess then
        table.insert(parts, { text = textToProcess:sub(lastPos), color = defaultColor })
      end
      break
    end
    
    if bestStart > lastPos then
      table.insert(parts, { text = textToProcess:sub(lastPos, bestStart - 1), color = defaultColor })
    end
    
    table.insert(parts, { text = textToProcess:sub(bestStart, bestEnd), color = bestMatch.color })
    lastPos = bestEnd + 1
  end
  
  -- Draw text parts
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(hoverScale, hoverScale)
  
  local startX = -button.w * 0.5 + paddingX
  local centerY = -button.font:getHeight() * 0.5
  local currentX = startX
  
  for _, part in ipairs(parts) do
    love.graphics.setColor(part.color[1], part.color[2], part.color[3], alpha)
    love.graphics.print(part.text, currentX, centerY)
    currentX = currentX + button.font:getWidth(part.text)
  end
  
  love.graphics.pop()
end

function RestSiteScene:_drawOrbSelection(fadeAlpha)
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  
  -- Draw semi-transparent overlay
  love.graphics.setColor(0, 0, 0, 0.8 * fadeAlpha)
  love.graphics.rectangle("fill", 0, 0, vw, vh)
  
  -- Draw title
  if self.titleFont then
    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(1, 1, 1, fadeAlpha)
    local titleText = "Select an Orb to Remove"
    local titleW = self.titleFont:getWidth(titleText)
    love.graphics.print(titleText, (vw - titleW) * 0.5, vh * 0.15)
  end
  
  -- Draw orb cards
  if #self._orbCards > 0 then
    local cardW = 288
    local spacing = 24
    local totalW = cardW * #self._orbCards + spacing * math.max(0, #self._orbCards - 1)
    local startX = (vw - totalW) * 0.5
    local y = vh * 0.4
    
    for i, orbData in ipairs(self._orbCards) do
      local x = startX + (i - 1) * (cardW + spacing)
      local p = orbData.projectile
      local oldLevel = p.level
      
      -- Calculate card height
      local cardH = self.card:calculateHeight(p or {})
      
      -- Get scale for hover effect
      local bounds = self._orbBounds[i] or {}
      local scale = bounds._scale or 1.0
      
      -- Draw card with hover scale
      love.graphics.push()
      local cx = x + cardW * 0.5
      local cy = y + cardH * 0.5
      love.graphics.translate(cx, cy)
      love.graphics.scale(scale, scale)
      love.graphics.translate(-cx, -cy)
      
      self.card:draw(x, y, orbData.id, fadeAlpha)
      
      love.graphics.pop()
      
      -- Update bounds
      local bw = cardW * scale
      local bh = cardH * scale
      self._orbBounds[i] = {
        x = cx - bw * 0.5,
        y = cy - bh * 0.5,
        w = bw,
        h = bh,
        _hovered = bounds._hovered,
        _scale = scale,
      }
      
      if p then p.level = oldLevel end
    end
  else
    -- No orbs to remove
    if self.textFont then
      love.graphics.setFont(self.textFont)
      love.graphics.setColor(0.9, 0.9, 0.9, fadeAlpha)
      local text = "No orbs equipped"
      local textW = self.textFont:getWidth(text)
      love.graphics.print(text, (vw - textW) * 0.5, vh * 0.5)
    end
  end
end

function RestSiteScene:mousemoved(x, y, dx, dy, isTouch)
  self.mouseX = x or 0
  self.mouseY = y or 0
end

function RestSiteScene:mousepressed(x, y, button)
  if button ~= 1 then return nil end
  
  if self._choiceMade then return nil end
  
  if self._showOrbSelection then
    -- Check if an orb card was clicked
    for i, bounds in ipairs(self._orbBounds) do
      if x >= bounds.x and x <= bounds.x + bounds.w and
         y >= bounds.y and y <= bounds.y + bounds.h then
        -- Remove this orb
        local orbData = self._orbCards[i]
        if orbData then
          local equipped = (config.player and config.player.equippedProjectiles) or {}
          for j, id in ipairs(equipped) do
            if id == orbData.id then
              table.remove(equipped, j)
              break
            end
          end
          self._choiceMade = true
          self._exitRequested = true
          return nil
        end
      end
    end
  else
    -- Check if buttons were clicked
    if self.restButton:mousepressed(x, y, button) then
      return nil
    end
    if self.removeOrbButton:mousepressed(x, y, button) then
      return nil
    end
  end
  
  return nil
end

function RestSiteScene:unload()
  -- Cleanup if needed
end

return RestSiteScene

