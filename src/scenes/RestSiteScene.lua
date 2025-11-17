local config = require("config")
local theme = require("theme")
local Button = require("ui.Button")
local TopBar = require("ui.TopBar")
local PlayerState = require("core.PlayerState")
local BattleState = require("core.BattleState")
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
    leaveButton = nil,
    backButton = nil,
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
    -- Keyboard navigation
    _selectedIndex = 1, -- First option is selected by default
    _prevSelectedIndex = 1, -- Track previous selection for fade transitions
    -- Glow animation
    _glowTime = 0, -- Time tracker for glow pulsing animation
    _glowFadeAlpha = 1.0, -- Fade alpha for currently selected glow (0 to 1)
    _prevGlowFadeAlpha = 0.0, -- Fade alpha for previously selected glow (fades out)
    _glowFadeSpeed = 8.0, -- Speed of fade in/out
  }, RestSiteScene)
end

function RestSiteScene:load()
  self._fadeTimer = 0
  self._choiceMade = false
  self._exitRequested = false
  self._showOrbSelection = false
  self._selectedOrbIndex = nil
  self._selectedIndex = 1 -- Reset to first option
  -- Grey out orbs icon on rest site screens
  if self.topBar then 
    self.topBar.disableOrbsIcon = true
    self.topBar.disableInventoryIcon = true
  end
  
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
  
  -- Calculate heal amount with relic bonuses
  local baseHealAmount = 20
  local RelicSystem = require("core.RelicSystem")
  local healAmount = baseHealAmount
  if RelicSystem and RelicSystem.applyRestSiteHeal then
    healAmount = RelicSystem.applyRestSiteHeal(baseHealAmount, {
      source = "rest_site",
    })
  end
  
  -- Create choice buttons
  self.restButton = Button.new({
    label = "Rest. Heal for " .. tostring(healAmount) .. " HP.",
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
      
      -- Use the same calculated heal amount
      local finalHealAmount = healAmount
      
      local newHP = math.min(maxHP, currentHP + finalHealAmount)
      playerState:setHealth(newHP)
      
      -- Also update BattleState if it exists (for TopBar display)
      local battleState = BattleState.get and BattleState.get()
      if battleState and battleState.player then
        BattleState.applyPlayerHeal(finalHealAmount)
      end
      
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
  
  self.leaveButton = Button.new({
    label = "Leave the rest site",
    font = self.textFont,
    bgColor = { 0, 0, 0, 0.7 },
    align = "left",
    onClick = function()
      if self._choiceMade then return end
      self._choiceMade = true
      self._exitRequested = true
    end,
  })
  
  -- Create Back button for orb removal screen (match OrbsUI close button style)
  do
    local baseFontSize = 24
    local backFont = theme.newFont(baseFontSize * 0.8)
    self.backButton = Button.new({
      label = "BACK",
      font = backFont,
      align = "center",
      onClick = function()
        -- Return to rest choices
        self._showOrbSelection = false
      end,
    })
  end
  
  -- Initialize scale for hover effect
  self.restButton._scale = 1.0
  self.removeOrbButton._scale = 1.0
  self.leaveButton._scale = 1.0
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
  -- Update glow animation time
  self._glowTime = (self._glowTime or 0) + dt
  
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
    -- Update back button hover
    if self.backButton then
      self.backButton:update(dt, self.mouseX, self.mouseY)
      -- Tween hover progress for back button
      local bhp = self.backButton._hoverProgress or 0
      local btarget = (self.backButton._hovered and 1) or 0
      self.backButton._hoverProgress = bhp + (btarget - bhp) * math.min(1, 10 * dt)
    end
    -- Update orb hover states and tooltip timing
    self._hoveredOrbIndex = nil
    for i, bounds in ipairs(self._orbBounds) do
      if self.mouseX >= bounds.x and self.mouseX <= bounds.x + bounds.w and
         self.mouseY >= bounds.y and self.mouseY <= bounds.y + bounds.h then
        if not bounds._hovered then
          bounds._hovered = true
          bounds._hoverTime = 0
          bounds._scale = 1.0
        end
        bounds._hoverTime = (bounds._hoverTime or 0) + dt
        bounds._scale = math.min(1.1, bounds._scale + dt * 3)
        self._hoveredOrbIndex = i
      else
        bounds._hovered = false
        bounds._hoverTime = 0
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
    buttonY = buttonY + buttonHeight + buttonSpacing
    self.leaveButton:setLayout(rightPanelX, buttonY, buttonWidth, buttonHeight)
    
    -- Clamp selected index to valid range
    self._selectedIndex = math.max(1, math.min(self._selectedIndex, 3))
    
    -- Detect selection change and reset glow fade
    if self._selectedIndex ~= self._prevSelectedIndex then
      -- Transfer current fade to previous fade (for fade out)
      self._prevGlowFadeAlpha = self._glowFadeAlpha
      -- Start new selection fade from 0
      self._glowFadeAlpha = 0
      self._prevSelectedIndex = self._selectedIndex
    end
    
    -- Tween glow fade alpha toward 1.0 (fade in)
    local targetAlpha = 1.0
    local diff = targetAlpha - self._glowFadeAlpha
    self._glowFadeAlpha = self._glowFadeAlpha + diff * math.min(1, self._glowFadeSpeed * dt)
    
    -- Tween previous glow fade alpha toward 0.0 (fade out)
    local prevDiff = 0.0 - self._prevGlowFadeAlpha
    self._prevGlowFadeAlpha = self._prevGlowFadeAlpha + prevDiff * math.min(1, self._glowFadeSpeed * dt)
    
    -- Update buttons (hover effects) - disable if choice already made
    if not self._choiceMade then
      self.restButton:update(dt, self.mouseX, self.mouseY)
      self.removeOrbButton:update(dt, self.mouseX, self.mouseY)
      self.leaveButton:update(dt, self.mouseX, self.mouseY)
      -- Merge mouse hover with keyboard selection
      local restWasSelected = (self._prevSelectedIndex == 1 and self._selectedIndex ~= 1)
      local removeWasSelected = (self._prevSelectedIndex == 2 and self._selectedIndex ~= 2)
      local leaveWasSelected = (self._prevSelectedIndex == 3 and self._selectedIndex ~= 3)
      local restMouseHovered = self.restButton._hovered
      local removeMouseHovered = self.removeOrbButton._hovered
      local leaveMouseHovered = self.leaveButton._hovered
      local anyMouseHovered = (restMouseHovered == true) or (removeMouseHovered == true) or (leaveMouseHovered == true)
      self.restButton._keySelected = (self._selectedIndex == 1)
      self.removeOrbButton._keySelected = (self._selectedIndex == 2)
      self.leaveButton._keySelected = (self._selectedIndex == 3)
      self.restButton._wasSelected = restWasSelected
      self.removeOrbButton._wasSelected = removeWasSelected
      self.leaveButton._wasSelected = leaveWasSelected
      -- Suppress key-selected highlight when any button is mouse-hovered
      self.restButton._hovered = restMouseHovered or (self.restButton._keySelected and not anyMouseHovered)
      self.removeOrbButton._hovered = removeMouseHovered or (self.removeOrbButton._keySelected and not anyMouseHovered)
      self.leaveButton._hovered = leaveMouseHovered or (self.leaveButton._keySelected and not anyMouseHovered)
      -- Tween hover progress
      local rhp = self.restButton._hoverProgress or 0
      local rtarget = self.restButton._hovered and 1 or 0
      self.restButton._hoverProgress = rhp + (rtarget - rhp) * math.min(1, 10 * dt)
      local mhp = self.removeOrbButton._hoverProgress or 0
      local mtarget = self.removeOrbButton._hovered and 1 or 0
      self.removeOrbButton._hoverProgress = mhp + (mtarget - mhp) * math.min(1, 10 * dt)
      self.restButton._scale = 1.0 + 0.05 * (self.restButton._hoverProgress or 0)
      self.removeOrbButton._scale = 1.0 + 0.05 * (self.removeOrbButton._hoverProgress or 0)
      local lhp = self.leaveButton._hoverProgress or 0
      local ltarget = self.leaveButton._hovered and 1 or 0
      self.leaveButton._hoverProgress = lhp + (ltarget - lhp) * math.min(1, 10 * dt)
      self.leaveButton._scale = 1.0 + 0.05 * (self.leaveButton._hoverProgress or 0)
    else
      self.restButton._hovered = false
      self.restButton._scale = 1.0
      self.removeOrbButton._hovered = false
      self.removeOrbButton._scale = 1.0
      self.leaveButton._hovered = false
      self.leaveButton._scale = 1.0
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
    
    local leaveScale = self.leaveButton._scale or 1.0
    local leaveCx = self.leaveButton.x + self.leaveButton.w * 0.5
    local leaveCy = self.leaveButton.y + self.leaveButton.h * 0.5
    self.leaveButton._hitRect = {
      x = math.floor(leaveCx - self.leaveButton.w * leaveScale * 0.5),
      y = math.floor(leaveCy - self.leaveButton.h * leaveScale * 0.5),
      w = math.floor(self.leaveButton.w * leaveScale),
      h = math.floor(self.leaveButton.h * leaveScale),
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
  
  -- Draw multi-layer faint white glow when hovered/highlighted or fading out
  if self.restButton._hovered or (self.restButton._wasSelected and self._prevGlowFadeAlpha > 0) then
    love.graphics.setBlendMode("add")
    
    -- Pulsing animation (sine wave) - slowed down
    local pulseSpeed = 1.0 -- cycles per second (slowed from 2.0)
    local pulseAmount = 0.15 -- pulse variation (15%)
    local pulse = 1.0 + math.sin(self._glowTime * pulseSpeed * math.pi * 2) * pulseAmount
    
    -- Draw multiple glow layers - smaller sizes
    local glowFadeAlpha = self.restButton._wasSelected and self._prevGlowFadeAlpha or (self._glowFadeAlpha * (self.restButton._hoverProgress or 0))
    local baseAlpha = 0.12 * fadeAlpha * glowFadeAlpha -- Reduced opacity with fade
    local layers = { { width = 4, alpha = 0.4 }, { width = 7, alpha = 0.25 }, { width = 10, alpha = 0.15 } }
    
    for _, layer in ipairs(layers) do
      local glowAlpha = baseAlpha * layer.alpha * pulse
      local glowWidth = layer.width * pulse
      love.graphics.setColor(1, 1, 1, glowAlpha)
      love.graphics.setLineWidth(glowWidth)
      love.graphics.rectangle("line", -self.restButton.w * 0.5 - glowWidth * 0.5, -self.restButton.h * 0.5 - glowWidth * 0.5, 
                             self.restButton.w + glowWidth, self.restButton.h + glowWidth, 
                             Button.defaults.cornerRadius + glowWidth * 0.5, Button.defaults.cornerRadius + glowWidth * 0.5)
    end
    
    love.graphics.setBlendMode("alpha")
    love.graphics.setLineWidth(oldLW or 1)
  end
  
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
  
  -- Draw multi-layer faint white glow when hovered/highlighted or fading out
  if self.removeOrbButton._hovered or (self.removeOrbButton._wasSelected and self._prevGlowFadeAlpha > 0) then
    love.graphics.setBlendMode("add")
    
    -- Pulsing animation (sine wave) - slowed down
    local pulseSpeed = 1.0 -- cycles per second (slowed from 2.0)
    local pulseAmount = 0.15 -- pulse variation (15%)
    local pulse = 1.0 + math.sin(self._glowTime * pulseSpeed * math.pi * 2) * pulseAmount
    
    -- Draw multiple glow layers - smaller sizes
    local glowFadeAlpha = self.removeOrbButton._wasSelected and self._prevGlowFadeAlpha or (self._glowFadeAlpha * (self.removeOrbButton._hoverProgress or 0))
    local baseAlpha = 0.12 * fadeAlpha * glowFadeAlpha -- Reduced opacity with fade
    local layers = { { width = 4, alpha = 0.4 }, { width = 7, alpha = 0.25 }, { width = 10, alpha = 0.15 } }
    
    for _, layer in ipairs(layers) do
      local glowAlpha = baseAlpha * layer.alpha * pulse
      local glowWidth = layer.width * pulse
      love.graphics.setColor(1, 1, 1, glowAlpha)
      love.graphics.setLineWidth(glowWidth)
      love.graphics.rectangle("line", -self.removeOrbButton.w * 0.5 - glowWidth * 0.5, -self.removeOrbButton.h * 0.5 - glowWidth * 0.5, 
                             self.removeOrbButton.w + glowWidth, self.removeOrbButton.h + glowWidth, 
                             Button.defaults.cornerRadius + glowWidth * 0.5, Button.defaults.cornerRadius + glowWidth * 0.5)
    end
    
    love.graphics.setBlendMode("alpha")
    love.graphics.setLineWidth(oldLW or 1)
  end
  
  love.graphics.pop()
  
  -- Draw remove orb button text
  self:_drawChoiceText(self.removeOrbButton, buttonAlpha, hoverScale)
  
  -- Draw leave button
  buttonAlpha = fadeAlpha
  if self._choiceMade then
    buttonAlpha = fadeAlpha * 0.5
  end
  self.leaveButton.alpha = buttonAlpha
  
  cx = self.leaveButton.x + self.leaveButton.w * 0.5
  cy = self.leaveButton.y + self.leaveButton.h * 0.5
  hoverScale = self.leaveButton._scale or 1.0
  if self._choiceMade then
    hoverScale = 1.0
  end
  
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(hoverScale, hoverScale)
  
  bg = self.leaveButton.bgColor or { 0, 0, 0, 0.7 }
  love.graphics.setColor(bg[1], bg[2], bg[3], (bg[4] or 1) * fadeAlpha)
  love.graphics.rectangle("fill", -self.leaveButton.w * 0.5, -self.leaveButton.h * 0.5, self.leaveButton.w, self.leaveButton.h, Button.defaults.cornerRadius, Button.defaults.cornerRadius)
  
  love.graphics.setColor(bc[1], bc[2], bc[3], (bc[4] or 1) * fadeAlpha)
  love.graphics.setLineWidth(Button.defaults.borderWidth)
  love.graphics.rectangle("line", -self.leaveButton.w * 0.5, -self.leaveButton.h * 0.5, self.leaveButton.w, self.leaveButton.h, Button.defaults.cornerRadius, Button.defaults.cornerRadius)
  love.graphics.setLineWidth(oldLW or 1)
  
  -- Draw multi-layer faint white glow when hovered/highlighted or fading out
  if self.leaveButton._hovered or (self.leaveButton._wasSelected and self._prevGlowFadeAlpha > 0) then
    love.graphics.setBlendMode("add")
    
    -- Pulsing animation (sine wave)
    local pulseSpeed = 1.0
    local pulseAmount = 0.15
    local pulse = 1.0 + math.sin(self._glowTime * pulseSpeed * math.pi * 2) * pulseAmount
    
    -- Draw multiple glow layers
    local glowFadeAlpha = self.leaveButton._wasSelected and self._prevGlowFadeAlpha or (self._glowFadeAlpha * (self.leaveButton._hoverProgress or 0))
    local baseAlpha = 0.12 * fadeAlpha * glowFadeAlpha
    local layers = { { width = 4, alpha = 0.4 }, { width = 7, alpha = 0.25 }, { width = 10, alpha = 0.15 } }
    
    for _, layer in ipairs(layers) do
      local glowAlpha = baseAlpha * layer.alpha * pulse
      local glowWidth = layer.width * pulse
      love.graphics.setColor(1, 1, 1, glowAlpha)
      love.graphics.setLineWidth(glowWidth)
      love.graphics.rectangle("line", -self.leaveButton.w * 0.5 - glowWidth * 0.5, -self.leaveButton.h * 0.5 - glowWidth * 0.5, 
                             self.leaveButton.w + glowWidth, self.leaveButton.h + glowWidth, 
                             Button.defaults.cornerRadius + glowWidth * 0.5, Button.defaults.cornerRadius + glowWidth * 0.5)
    end
    
    love.graphics.setBlendMode("alpha")
    love.graphics.setLineWidth(oldLW or 1)
  end
  
  love.graphics.pop()
  
  -- Draw leave button text
  self:_drawChoiceText(self.leaveButton, buttonAlpha, hoverScale)
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
  
  -- Draw orb icons with names
  if #self._orbCards > 0 then
    local iconSize = 80
    local spacing = 32
    local rowSpacing = 140
    local maxCardsPerRow = 4
    local nameFont = self.textFont or theme.fonts.base
    
    -- Calculate layout: how many rows needed
    local numRows = math.ceil(#self._orbCards / maxCardsPerRow)
    
    -- Start Y position (shifted up by 80px from original position)
    local startY = vh * 0.4 - 80
    
    -- Draw orbs in rows
    for i, orbData in ipairs(self._orbCards) do
      local rowIndex = math.floor((i - 1) / maxCardsPerRow)
      local colIndex = ((i - 1) % maxCardsPerRow)
      
      -- Calculate how many cards are in this row
      local cardsInRow = math.min(maxCardsPerRow, #self._orbCards - rowIndex * maxCardsPerRow)
      
      -- Calculate row width and starting X position (centered)
      local rowWidth = iconSize * cardsInRow + spacing * math.max(0, cardsInRow - 1)
      local rowStartX = (vw - rowWidth) * 0.5
      
      -- Calculate position for this orb
      local iconX = rowStartX + colIndex * (iconSize + spacing)
      local iconY = startY + rowIndex * rowSpacing
      
      local p = orbData.projectile
      local oldLevel = p.level
      
      -- Get scale for hover effect
      local bounds = self._orbBounds[i] or {}
      local scale = bounds._scale or 1.0
      local hovered = bounds._hovered or false
      
      -- Draw orb icon with hover scale
      love.graphics.push()
      local cx = iconX + iconSize * 0.5
      local cy = iconY + iconSize * 0.5
      love.graphics.translate(cx, cy)
      love.graphics.scale(scale, scale)
      love.graphics.translate(-cx, -cy)
      
      -- Draw icon
      if p and p.icon then
        local ok, iconImg = pcall(love.graphics.newImage, p.icon)
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
      local nameText = (p and p.name) or orbData.id
      local nameW = nameFont:getWidth(nameText)
      local nameX = iconX + (iconSize - nameW) * 0.5
      local nameY = iconY + iconSize + 8
      love.graphics.setColor(1, 1, 1, fadeAlpha)
      love.graphics.print(nameText, nameX, nameY)
      
      -- Update bounds for click detection (include name area)
      -- Use unscaled positions for bounds calculation
      local nameH = nameFont:getHeight()
      local totalH = iconSize + 8 + nameH
      local scaledW = iconSize * scale
      local scaledH = totalH * scale
      local boundsCenterX = iconX + iconSize * 0.5
      local boundsCenterY = iconY + totalH * 0.5
      self._orbBounds[i] = {
        x = boundsCenterX - scaledW * 0.5,
        y = boundsCenterY - scaledH * 0.5,
        w = scaledW,
        h = scaledH,
        _hovered = hovered,
        _hoverTime = bounds._hoverTime or 0,
        _scale = scale,
        _orbData = orbData,
      }
      
      if p then p.level = oldLevel end
    end
    
    -- Draw tooltip on hover
    if self._hoveredOrbIndex and self._orbBounds[self._hoveredOrbIndex] then
      local bounds = self._orbBounds[self._hoveredOrbIndex]
      if bounds._hoverTime and bounds._hoverTime > 0.3 then
        self:_drawOrbTooltip(self._hoveredOrbIndex, bounds, fadeAlpha)
      end
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
  
  -- Draw Back button (top right, same placement as OrbsUI close)
  if self.backButton then
    local vw = config.video.virtualWidth
    local buttonFont = self.backButton.font or theme.fonts.base
    love.graphics.setFont(buttonFont)
    local paddingX = 16
    local paddingY = 6
    local label = "BACK"
    local textW = buttonFont:getWidth(label)
    local textH = buttonFont:getHeight()
    local buttonW = textW + paddingX * 2
    local buttonH = textH + paddingY * 2
    local margin = 20
    local x = vw - buttonW - margin
    local y = margin
    self.backButton:setLayout(x, y, buttonW, buttonH)
    self.backButton.alpha = fadeAlpha
    self.backButton:draw()
    -- Add glow on hover for back button
    if self.backButton._hovered then
      love.graphics.push()
      local cx = self.backButton.x + self.backButton.w * 0.5
      local cy = self.backButton.y + self.backButton.h * 0.5
      local s = (self.backButton._scale or 1.0)
      love.graphics.translate(cx, cy)
      love.graphics.scale(s, s)
      love.graphics.setBlendMode("add")
      -- Pulsing animation (sine wave) - match others
      local pulseSpeed = 1.0
      local pulseAmount = 0.15
      local pulse = 1.0 + math.sin(self._glowTime * pulseSpeed * math.pi * 2) * pulseAmount
      -- Use tweened hover progress for intensity
      local fadeMul = (self.backButton._hoverProgress or 0)
      local baseAlpha = 0.12 * (self.backButton.alpha or fadeAlpha) * fadeMul
      local layers = { { width = 4, alpha = 0.4 }, { width = 7, alpha = 0.25 }, { width = 10, alpha = 0.15 } }
      for _, layer in ipairs(layers) do
        local glowAlpha = baseAlpha * layer.alpha * pulse
        local glowWidth = layer.width * pulse
        love.graphics.setColor(1, 1, 1, glowAlpha)
        love.graphics.setLineWidth(glowWidth)
        love.graphics.rectangle("line", -self.backButton.w * 0.5 - glowWidth * 0.5, -self.backButton.h * 0.5 - glowWidth * 0.5, 
                               self.backButton.w + glowWidth, self.backButton.h + glowWidth, 
                               Button.defaults.cornerRadius + glowWidth * 0.5, Button.defaults.cornerRadius + glowWidth * 0.5)
      end
      love.graphics.setBlendMode("alpha")
      love.graphics.pop()
    end
  end
end

function RestSiteScene:_drawOrbTooltip(orbIndex, bounds, fadeAlpha)
  if not bounds._orbData then return end
  
  local orbData = bounds._orbData
  local projectile = orbData.projectile
  if not projectile then return end
  
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  
  -- Calculate tooltip position (to the right of the orb, or left if too close to right edge)
  local tooltipX = bounds.x + bounds.w + 16
  local tooltipY = bounds.y
  
  -- If tooltip would go off screen, position it to the left instead
  local tooltipW = 274 -- Same as ProjectileCard width (reduced by 5% from 288)
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
    self.card:draw(tooltipX, tooltipY, orbData.id, tooltipAlpha)
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
    -- Back button
    if self.backButton and self.backButton:mousepressed(x, y, button) then
      return nil
    end
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
    if self.leaveButton:mousepressed(x, y, button) then
      return nil
    end
  end
  
  return nil
end

function RestSiteScene:keypressed(key, scancode, isRepeat)
  if self._choiceMade then return nil end
  
  if self._showOrbSelection then
    -- In orb selection mode, don't handle keyboard navigation
    return nil
  end
  
  -- Handle navigation keys
  if key == "w" or key == "up" then
    self._selectedIndex = self._selectedIndex - 1
    if self._selectedIndex < 1 then self._selectedIndex = 2 end
    return nil
  elseif key == "s" or key == "down" then
    self._selectedIndex = self._selectedIndex + 1
    if self._selectedIndex > 3 then self._selectedIndex = 1 end
    return nil
  elseif key == "space" or key == "return" then
    -- Activate selected button
    if self._selectedIndex == 1 and self.restButton and self.restButton.onClick then
      self.restButton.onClick()
    elseif self._selectedIndex == 2 and self.removeOrbButton and self.removeOrbButton.onClick then
      self.removeOrbButton.onClick()
    elseif self._selectedIndex == 3 and self.leaveButton and self.leaveButton.onClick then
      self.leaveButton.onClick()
    end
    return nil
  end
  
  return nil
end

function RestSiteScene:unload()
  -- Cleanup if needed
end

return RestSiteScene

