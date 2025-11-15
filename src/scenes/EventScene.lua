local config = require("config")
local theme = require("theme")
local Button = require("ui.Button")
local TopBar = require("ui.TopBar")
local PlayerState = require("core.PlayerState")
local events = require("data.events")
local ProjectileManager = require("managers.ProjectileManager")
local relics = require("data.relics")

local EventScene = {}
EventScene.__index = EventScene

function EventScene.new(eventId)
  return setmetatable({
    eventId = eventId,
    event = nil,
    eventImage = nil,
    titleFont = nil,
    textFont = nil,
    choiceButtons = {},
    topBar = TopBar.new(),
    mouseX = 0,
    mouseY = 0,
    _fadeTimer = 0,
    _fadeInDuration = 0.5,
    _fadeStartDelay = 0.2,
    _selectedChoice = nil,
    _exitRequested = false,
    _choiceMade = false,  -- Track if a choice has been made to disable buttons
    -- Coin animation state
    _coinAnimations = {},
    goldIcon = nil,
    _goldAmount = 0,
    _goldAnimationStarted = false,
    _goldAnimationComplete = false,
    -- Gold counting animation state
    _goldCounting = false,
    _goldCountTime = 0,
    _goldCountDuration = 0.6, -- seconds to count up
    _goldDisplayStart = 0,
    _goldDisplayTarget = 0,
    -- Keyboard navigation
    _selectedIndex = 1, -- First option is selected by default
    _prevSelectedIndex = 1, -- Track previous selection for fade transitions
    -- Glow animation
    _glowTime = 0, -- Time tracker for glow pulsing animation
    _glowFadeAlpha = 1.0, -- Fade alpha for currently selected glow (0 to 1)
    _prevGlowFadeAlpha = 0.0, -- Fade alpha for previously selected glow (fades out)
    _glowFadeSpeed = 8.0, -- Speed of fade in/out
    -- Relic notification tooltip
    _relicTooltip = nil, -- Relic definition for tooltip
    _relicTooltipTime = 0, -- Time since tooltip appeared
    _relicTooltipFadeInDuration = 0.2, -- Fade in duration (also moves up)
    _relicTooltipHoldDuration = 0.5, -- Hold duration (stays in place)
    _relicTooltipFadeOutDuration = 0.2, -- Fade out duration (also moves up)
    _relicTooltipMoveDistance = 80, -- Distance to move up during animation
  }, EventScene)
end

-- Helper function to pick a random unowned relic
local function pickRelicReward()
  local list = relics.list() or {}
  if #list == 0 then return nil end

  local playerState = PlayerState.getInstance()
  local owned = {}
  if playerState and playerState.getRelicState then
    local relicState = playerState:getRelicState()
    owned = relicState and relicState.owned or {}
  end

  local candidates = {}
  for _, relicDef in ipairs(list) do
    if not owned or owned[relicDef.id] ~= true then
      table.insert(candidates, relicDef)
    end
  end

  if #candidates == 0 then
    return nil
  end

  local idx = love.math.random(1, #candidates)
  return candidates[idx]
end

function EventScene:load()
  self._fadeTimer = 0
  self._selectedIndex = 1 -- Reset to first option
  -- Grey out orbs icon on event screens
  if self.topBar then 
    self.topBar.disableOrbsIcon = true
    self.topBar.disableInventoryIcon = true
  end
  
  -- Load event data
	self.event = events.get(self.eventId)
  if not self.event then
    -- Fallback to placeholder event if not found
    self.event = {
      id = "unknown",
      title = "Unknown Event",
      image = "event_placeholder.png",
      text = "An unknown event has occurred.",
      choices = {
        { text = "Continue", effects = {} }
      }
    }
  end
	if self.event and self.event.id then
	else
	end
  
  -- Load event image
  local imagePath = "assets/images/events/" .. self.event.image
  local ok, img = pcall(love.graphics.newImage, imagePath)
  if ok then
    self.eventImage = img
  else
    -- Try fallback placeholder
    local fallbackPath = "assets/images/events/event_placeholder.png"
    local ok2, img2 = pcall(love.graphics.newImage, fallbackPath)
    if ok2 then
      self.eventImage = img2
    end
  end
  
  -- Create fonts
  -- Use semi-bold (Bold) for title since SemiBold variant not available
  local boldFontPath = "assets/fonts/BarlowCondensed-Bold.ttf"
  self.titleFont = theme.newFont(50, boldFontPath)
  -- Use regular (non-bold) font for description
  local regularFontPath = "assets/fonts/BarlowCondensed-Regular.ttf"
  local baseSize = 20  -- Reduced from 24 to 20
  self.textFont = theme.newFont(baseSize, regularFontPath)
  
  -- Load gold icon for coin animations
  local goldIconPath = (config.assets and config.assets.images and config.assets.images.icon_gold) or nil
  if goldIconPath then
    local okGoldIcon, goldImg = pcall(love.graphics.newImage, goldIconPath)
    if okGoldIcon then self.goldIcon = goldImg end
  end
  
  -- Get player state for validation
  local playerState = PlayerState.getInstance()
  local playerGold = playerState:getGold()
  
  -- Create choice buttons (styled like reward buttons)
  self.choiceButtons = {}
  for i, choice in ipairs(self.event.choices or {}) do
    -- Check if choice requires gold and player doesn't have enough
    local requiresGold = choice.effects and choice.effects.gold and choice.effects.gold < 0
    local goldRequired = requiresGold and math.abs(choice.effects.gold) or 0
    local hasEnoughGold = playerGold >= goldRequired
    
    -- Check if choice requires relic and all relics are owned
    local requiresRelic = choice.effects and choice.effects.relic == true
    local canGetRelic = true
    if requiresRelic then
      local availableRelic = pickRelicReward()
      canGetRelic = (availableRelic ~= nil)
    end
    
    -- Determine if button should be disabled
    local isDisabled = (requiresGold and not hasEnoughGold) or (requiresRelic and not canGetRelic)
    
    -- Modify button text if disabled
    local buttonText = choice.text
    if isDisabled then
      if requiresGold and not hasEnoughGold then
        buttonText = buttonText .. " (Requires " .. goldRequired .. " Gold)"
      elseif requiresRelic and not canGetRelic then
        buttonText = buttonText .. " (No relics available)"
      end
    end
    local button = Button.new({
      label = buttonText,
      font = self.textFont,
      bgColor = { 0, 0, 0, 0.7 },  -- Same style as reward buttons
      align = "left",
      onClick = function()
        -- Prevent multiple clicks or disabled button clicks
        if self._choiceMade or isDisabled then
          return
        end
        
        self._choiceMade = true  -- Disable all buttons
        self._selectedChoice = choice
        self._clickedButtonIndex = i  -- Store which button was clicked for coin animation
        -- Check if choice gives gold (positive) - if so, animate coins instead of immediately applying
        if choice.effects and choice.effects.gold and choice.effects.gold > 0 then
          -- Store gold amounts for counting animation
          local PlayerState = require("core.PlayerState")
          local playerState = PlayerState.getInstance()
          self._goldDisplayStart = playerState:getGold()
          self._goldAmount = choice.effects.gold
          self._goldDisplayTarget = self._goldDisplayStart + self._goldAmount
          self._goldAnimationStarted = true
          -- Set initial override to start value
          if self.topBar then
            self.topBar.overrideGold = self._goldDisplayStart
          end
          -- Apply other effects immediately (like HP, relic)
          local otherEffects = {}
          for k, v in pairs(choice.effects) do
            if k ~= "gold" then
              otherEffects[k] = v
            end
          end
          if next(otherEffects) then
            self:_applyChoiceEffects(otherEffects)
          end
        else
          -- No gold gain, apply all effects immediately (including negative gold)
          self:_applyChoiceEffects(choice.effects or {})
          -- Set exit requested, but if relic was granted, wait for tooltip animation
          self._exitRequested = true
        end
      end,
    })
    -- Initialize scale for hover effect
    button._scale = 1.0
    -- Store disabled state for visual feedback
    button._disabled = isDisabled
    table.insert(self.choiceButtons, button)
  end
end

function EventScene:_applyChoiceEffects(effects)
  local playerState = PlayerState.getInstance()
  
  if effects.hp then
    local currentHP = playerState:getHealth()
    local newHP = math.max(0, math.min(currentHP + effects.hp, playerState:getMaxHealth()))
    playerState:setHealth(newHP)
  end
  
  -- Percentage-based HP damage/healing
  if effects.hpPercent then
    local maxHP = playerState:getMaxHealth()
    local hpChange = math.floor(maxHP * (effects.hpPercent / 100))
    local currentHP = playerState:getHealth()
    local newHP = math.max(0, math.min(currentHP + hpChange, playerState:getMaxHealth()))
    playerState:setHealth(newHP)
  end
  
  -- Increase max HP
  if effects.maxHp then
    local currentMaxHP = playerState:getMaxHealth()
    local newMaxHP = currentMaxHP + effects.maxHp
    playerState:setMaxHealth(newMaxHP)
    -- Also heal by the same amount (common pattern in roguelikes)
    local currentHP = playerState:getHealth()
    local newHP = currentHP + effects.maxHp
    playerState:setHealth(newHP)
  end
  
  if effects.gold then
    playerState:addGold(effects.gold)
  end
  
  -- Grant relic
  if effects.relic == true then
    local relicDef = pickRelicReward()
    if relicDef then
      playerState:addRelic(relicDef.id)
      -- Show relic notification tooltip
      self._relicTooltip = relicDef
      self._relicTooltipTime = 0
    end
  end
  
  -- Upgrade random orbs
  if effects.upgradeRandomOrbs and effects.upgradeRandomOrbs > 0 then
    local equipped = (config.player and config.player.equippedProjectiles) or {}
    if #equipped > 0 then
      -- Filter to only upgradable orbs (level < 5)
      local upgradable = {}
      for _, id in ipairs(equipped) do
        local p = ProjectileManager.getProjectile(id)
        if p and (p.level or 1) < 5 then
          table.insert(upgradable, id)
        end
      end
      
      -- Shuffle and select up to the requested number
      local numToUpgrade = math.min(effects.upgradeRandomOrbs, #upgradable)
      if numToUpgrade > 0 then
        -- Shuffle array
        for i = #upgradable, 2, -1 do
          local j = love.math.random(i)
          upgradable[i], upgradable[j] = upgradable[j], upgradable[i]
        end
        
        -- Upgrade selected orbs
        for i = 1, numToUpgrade do
          ProjectileManager.upgradeLevel(upgradable[i])
        end
      end
    end
  end
  
  -- Add more effect types here as needed
end

function EventScene:update(dt, mouseX, mouseY)
  -- Get mouse position (from parameters or love.mouse if available)
  if mouseX and mouseY then
    self.mouseX = mouseX
    self.mouseY = mouseY
  else
    -- Fallback: get from love.mouse (will be in screen coordinates, need to convert)
    local mx, my = love.mouse.getPosition()
    if mx and my then
      -- Convert to virtual coordinates (same as main.lua does)
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
  self._glowTime = (self._glowTime or 0) + dt
  
  -- Update relic tooltip animation
  if self._relicTooltip then
    self._relicTooltipTime = self._relicTooltipTime + dt
    -- Calculate total duration
    local totalDuration = self._relicTooltipFadeInDuration + self._relicTooltipHoldDuration + self._relicTooltipFadeOutDuration
    -- Remove tooltip after animation completes
    if self._relicTooltipTime >= totalDuration then
      self._relicTooltip = nil
      self._relicTooltipTime = 0
      -- Exit scene after tooltip finishes if exit was requested
      if self._exitRequested then
        -- Exit will be handled in the check below
      end
    end
  end
  
  -- Calculate button layout first (needed for coin animation source position)
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  local topBarHeight = (config.playfield and config.playfield.topBarHeight) or 60
  local padding = 40
  local leftPanelWidth = vw * 0.35
  local rightPanelWidth = vw * 0.65 - padding * 2
  local rightPanelX = leftPanelWidth + padding + 50
  local buttonWidth = (rightPanelWidth - padding) * 0.9
  local buttonHeight = 50
  local buttonSpacing = 15
  
  -- Calculate starting Y position for buttons
  local contentY = topBarHeight
  local currentY = contentY + 15  -- Account for title shift
  if self.titleFont and self.event.title then
    currentY = currentY + self.titleFont:getHeight() + 30
  end
  if self.textFont and self.event.text then
    local textWidth = (rightPanelWidth - padding) * 0.9
    local lines = self:_wordWrap(self.event.text, textWidth, self.textFont)
    for _, line in ipairs(lines) do
      if line == "" then
        currentY = currentY + self.textFont:getHeight() * 0.5
      else
        currentY = currentY + self.textFont:getHeight() + 8
      end
    end
    currentY = currentY + 30
  end
  
  -- Set button layouts (needed for coin animation)
  for i, button in ipairs(self.choiceButtons) do
    local buttonY = currentY + (i - 1) * (buttonHeight + buttonSpacing)
    button:setLayout(rightPanelX, buttonY, buttonWidth, buttonHeight)
    
    -- Calculate hitRect for hover detection
    if not button._hitRect then
      button._hitRect = {}
    end
    local cx = button.x + button.w * 0.5
    local cy = button.y + button.h * 0.5
    local s = button._scale or 1.0
    button._hitRect.x = math.floor(cx - button.w * s * 0.5)
    button._hitRect.y = math.floor(cy - button.h * s * 0.5)
    button._hitRect.w = math.floor(button.w * s)
    button._hitRect.h = math.floor(button.h * s)
  end
  
  -- Start coin animation if gold was gained (after layout is set)
  if self._goldAnimationStarted and not self._goldAnimationComplete then
    self:_startCoinAnimation(self._goldAmount, vw, vh)
    self._goldAnimationStarted = false
  end
  
  -- Update coin animations
  self:_updateCoinAnimations(dt)
  
  -- Check if coin animation is complete
  if not self._goldAnimationComplete and #self._coinAnimations == 0 and self._goldAmount > 0 then
    self._goldAnimationComplete = true
    -- Start gold counting animation
    if not self._goldCounting then
      self._goldCounting = true
      self._goldCountTime = 0
      -- Ensure override starts at start value
      if self.topBar then
        self.topBar.overrideGold = self._goldDisplayStart
      end
    end
  end
  
  -- Animate gold number increase in top bar after coins finish
  if self._goldCounting and self.topBar then
    self._goldCountTime = self._goldCountTime + dt
    local t = math.min(1, self._goldCountTime / self._goldCountDuration)
    -- Ease-out
    local eased = 1 - (1 - t) * (1 - t)
    local value = math.floor(self._goldDisplayStart + (self._goldDisplayTarget - self._goldDisplayStart) * eased + 0.5)
    self.topBar.overrideGold = value
    if t >= 1 then
      -- Counting done; apply gold and clear override to use real PlayerState gold
      local playerState = PlayerState.getInstance()
      playerState:addGold(self._goldAmount)
      self._goldAmount = 0
      self.topBar.overrideGold = nil
      self._goldCounting = false
      -- Exit after counting animation
      self._exitRequested = true
    end
  end
  
  -- Clamp selected index to valid range
  if #self.choiceButtons > 0 then
    self._selectedIndex = math.max(1, math.min(self._selectedIndex, #self.choiceButtons))
    
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
  end
  
  -- Detect if any button is mouse hovered (for suppressing default selected highlight)
  local anyMouseHovered = false
  do
    local mx, my = self.mouseX or 0, self.mouseY or 0
    for _, b in ipairs(self.choiceButtons) do
      if mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h then
        anyMouseHovered = true
        break
      end
    end
  end
    -- Update buttons (hover effects) - disable if choice already made or button disabled
  for i, button in ipairs(self.choiceButtons) do
    -- Initialize scale if not set
    if not button._scale then
      button._scale = 1.0
    end
    
    -- Update button (this will use hitRect to determine hover and update scale)
    -- Disable hover if choice already made or button is disabled
    if self._choiceMade or button._disabled then
      -- Reset hover state and scale
      button._hovered = false
      button._scale = 1.0
    else
      button:update(dt, self.mouseX, self.mouseY)
      -- Merge mouse hover with keyboard selection; suppress selected highlight when any button hovered
      local wasSelected = (self._prevSelectedIndex == i and self._selectedIndex ~= i)
      local mouseHovered = button._hovered
      button._keySelected = (self._selectedIndex == i)
      button._wasSelected = wasSelected -- Track if this was the previous selection
      button._hovered = (mouseHovered or (button._keySelected and not anyMouseHovered)) and not self._choiceMade
      -- Tween hover progress
      local hp = button._hoverProgress or 0
      local target = button._hovered and 1 or 0
      button._hoverProgress = hp + (target - hp) * math.min(1, 10 * dt)
      -- Scale with tweened hover
      button._scale = 1.0 + 0.05 * (button._hoverProgress or 0)
    end
  end
  
  -- Check for exit (but wait for coin animations, counting, or relic tooltip to complete)
  if self._exitRequested then
    -- If gold counting is in progress, wait for it to complete
    if self._goldCounting then
      -- Still counting, don't exit yet
      return nil
    end
    -- If relic tooltip is showing, wait for it to complete
    if self._relicTooltip then
      -- Still showing tooltip, don't exit yet
      return nil
    end
    -- All animations complete, safe to exit with shader transition
    return { type = "return_to_map", skipTransition = false }
  end
  
  return nil
end

function EventScene:keypressed(key, scancode, isRepeat)
  if self._choiceMade then return nil end
  
  if #self.choiceButtons == 0 then return nil end
  
  -- Helper function to find next enabled button
  local function findNextEnabled(startIndex, direction)
    local current = startIndex
    local attempts = 0
    while attempts < #self.choiceButtons do
      current = current + direction
      if current < 1 then
        current = #self.choiceButtons
      elseif current > #self.choiceButtons then
        current = 1
      end
      if not self.choiceButtons[current]._disabled then
        return current
      end
      attempts = attempts + 1
    end
    return startIndex -- Fallback if all disabled
  end
  
  -- Clamp selected index to valid range and ensure it's not disabled
  self._selectedIndex = math.max(1, math.min(self._selectedIndex, #self.choiceButtons))
  if self.choiceButtons[self._selectedIndex]._disabled then
    -- Find first enabled button
    for i = 1, #self.choiceButtons do
      if not self.choiceButtons[i]._disabled then
        self._selectedIndex = i
        break
      end
    end
  end
  
  -- Handle navigation keys
  if key == "w" or key == "up" then
    self._selectedIndex = findNextEnabled(self._selectedIndex, -1)
    return nil
  elseif key == "s" or key == "down" then
    self._selectedIndex = findNextEnabled(self._selectedIndex, 1)
    return nil
  elseif key == "space" or key == "return" then
    -- Activate selected button (only if not disabled)
    local selectedButton = self.choiceButtons[self._selectedIndex]
    if selectedButton and not selectedButton._disabled and selectedButton.onClick then
      selectedButton.onClick()
    end
    return nil
  end
  
  return nil
end

function EventScene:draw()
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
  
  -- Draw background
  love.graphics.setColor(theme.colors.background[1], theme.colors.background[2], theme.colors.background[3], fadeAlpha)
  love.graphics.rectangle("fill", 0, 0, vw, vh)
  
  -- Draw top bar
  if self.topBar then
    love.graphics.setColor(1, 1, 1, fadeAlpha)
    self.topBar:draw()
  end
  
  -- Calculate layout
  local topBarHeight = (config.playfield and config.playfield.topBarHeight) or 60
  local padding = 40
  local leftPanelWidth = vw * 0.35  -- 35% for image
  local rightPanelWidth = vw * 0.65 - padding * 2  -- 65% for text/choices
  local contentY = topBarHeight
  local contentHeight = vh - topBarHeight  -- Full height from top bar to bottom
  
  -- Draw left panel (event image) - aligned left, fills height
  love.graphics.setColor(1, 1, 1, fadeAlpha)
  if self.eventImage then
    local imgW, imgH = self.eventImage:getDimensions()
    -- Scale to fill height (touching top and bottom edges)
    local scale = contentHeight / imgH
    local scaledW = imgW * scale
    local scaledH = imgH * scale
    local imgX = 0  -- Aligned to left edge
    local imgY = contentY  -- Aligned to top (below top bar)
    
    love.graphics.draw(self.eventImage, imgX, imgY, 0, scale, scale)
  end
  
  -- Draw right panel (title, text, choices)
  local rightPanelX = leftPanelWidth + padding + 50  -- Shift right by 50px
  local rightPanelY = contentY
  local currentY = rightPanelY
  
  -- Draw title (without border/outline) - shifted down slightly
  if self.titleFont and self.event.title then
    love.graphics.setFont(self.titleFont)
    love.graphics.setColor(1, 1, 1, fadeAlpha)
    currentY = currentY + 15  -- Shift down by 15px
    love.graphics.print(self.event.title, rightPanelX, currentY)
    currentY = currentY + self.titleFont:getHeight() + 30
  end
  
  -- Draw event text
  if self.textFont and self.event.text then
    love.graphics.setFont(self.textFont)
    love.graphics.setColor(0.9, 0.9, 0.9, fadeAlpha)
    
    -- Word wrap text
    local textX = rightPanelX
    local textWidth = (rightPanelWidth - padding) * 0.9  -- Reduce width by 10%
    local lines = self:_wordWrap(self.event.text, textWidth, self.textFont)
    
    for i, line in ipairs(lines) do
      -- Handle empty lines (paragraph breaks)
      if line == "" then
        currentY = currentY + self.textFont:getHeight() * 0.5  -- Half line spacing for paragraph breaks
      else
        love.graphics.print(line, textX, currentY)
        currentY = currentY + self.textFont:getHeight() + 8
      end
    end
    
    currentY = currentY + 30
  end
  
  -- Draw choice buttons
  local buttonSpacing = 15
  local buttonWidth = (rightPanelWidth - padding) * 0.9  -- Reduce width by 10%
  local buttonHeight = 50
  
  -- Calculate button start Y position (same calculation as in update)
  local buttonStartY = currentY
  
  for i, button in ipairs(self.choiceButtons) do
    -- Layout is already set in update(), set alpha (reduce if choice made or disabled)
    local buttonAlpha = fadeAlpha
    if self._choiceMade then
      buttonAlpha = fadeAlpha * 0.5  -- Reduce opacity when disabled
    elseif button._disabled then
      buttonAlpha = fadeAlpha * 0.5  -- Reduce opacity for disabled buttons
    end
    button.alpha = buttonAlpha
    
    -- Draw button background with hover effect (scale is applied in button:draw())
    -- We need to draw the background manually to preserve hover scale, then draw text separately
    local cx = button.x + button.w * 0.5
    local cy = button.y + button.h * 0.5
    local hoverScale = button._scale or 1.0
    if self._choiceMade or button._disabled then
      hoverScale = 1.0  -- No hover scale when disabled
    end
    
    -- Draw button background with hover scale
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(hoverScale, hoverScale)
    
    -- Background
    local bg = button.bgColor or { 0, 0, 0, 0.7 }
    love.graphics.setColor(bg[1], bg[2], bg[3], (bg[4] or 1) * fadeAlpha)
    love.graphics.rectangle("fill", -button.w * 0.5, -button.h * 0.5, button.w, button.h, Button.defaults.cornerRadius, Button.defaults.cornerRadius)
    
    -- Border
    local bc = Button.defaults.borderColor
    love.graphics.setColor(bc[1], bc[2], bc[3], (bc[4] or 1) * fadeAlpha)
    local oldLW = love.graphics.getLineWidth()
    love.graphics.setLineWidth(Button.defaults.borderWidth)
    love.graphics.rectangle("line", -button.w * 0.5, -button.h * 0.5, button.w, button.h, Button.defaults.cornerRadius, Button.defaults.cornerRadius)
    love.graphics.setLineWidth(oldLW or 1)
    
    -- Draw multi-layer faint white glow when hovered/highlighted or fading out
    if button._hovered or (button._wasSelected and self._prevGlowFadeAlpha > 0) then
      love.graphics.setBlendMode("add")
      
      -- Pulsing animation (sine wave) - slowed down
      local pulseSpeed = 1.0 -- cycles per second (slowed from 2.0)
      local pulseAmount = 0.15 -- pulse variation (15%)
      local pulse = 1.0 + math.sin(self._glowTime * pulseSpeed * math.pi * 2) * pulseAmount
      
      -- Draw multiple glow layers - smaller sizes
      local glowFadeAlpha = button._wasSelected and self._prevGlowFadeAlpha or (self._glowFadeAlpha * (button._hoverProgress or 0))
      local baseAlpha = 0.12 * fadeAlpha * glowFadeAlpha -- Reduced opacity with fade
      local layers = { { width = 4, alpha = 0.4 }, { width = 7, alpha = 0.25 }, { width = 10, alpha = 0.15 } } -- Smaller glow (was 6, 10, 14)
      
      for _, layer in ipairs(layers) do
        local glowAlpha = baseAlpha * layer.alpha * pulse
        local glowWidth = layer.width * pulse
        love.graphics.setColor(1, 1, 1, glowAlpha)
        love.graphics.setLineWidth(glowWidth)
        love.graphics.rectangle("line", -button.w * 0.5 - glowWidth * 0.5, -button.h * 0.5 - glowWidth * 0.5, 
                               button.w + glowWidth, button.h + glowWidth, 
                               Button.defaults.cornerRadius + glowWidth * 0.5, Button.defaults.cornerRadius + glowWidth * 0.5)
      end
      
      love.graphics.setBlendMode("alpha")
      love.graphics.setLineWidth(oldLW or 1)
    end
    
    love.graphics.pop()
    
    -- Draw choice text with color parsing on top (at scaled position)
    local textAlpha = fadeAlpha
    if self._choiceMade then
      textAlpha = fadeAlpha * 0.5  -- Reduce text opacity when disabled
    elseif button._disabled then
      textAlpha = fadeAlpha * 0.5  -- Reduce text opacity for disabled buttons
    end
    self:_drawChoiceText(button, textAlpha, hoverScale)
    
    currentY = currentY + buttonHeight + buttonSpacing
  end
  
  -- Draw coin animations above everything (z-order)
  self:_drawCoinAnimations()
  
  -- Draw relic notification tooltip (on top of everything)
  self:_drawRelicTooltip(fadeAlpha)
end

function EventScene:_wordWrap(text, maxWidth, font)
  local lines = {}
  
  -- Split by explicit line breaks first (\n)
  local paragraphs = {}
  for paragraph in text:gmatch("([^\n]+)") do
    table.insert(paragraphs, paragraph)
  end
  -- If no \n found, use entire text
  if #paragraphs == 0 then
    paragraphs = { text }
  end
  
  -- Process each paragraph
  for paraIdx, paragraph in ipairs(paragraphs) do
    -- Split paragraph into words
    local words = {}
    for word in paragraph:gmatch("%S+") do
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
    
    -- Add blank line between paragraphs (except after last paragraph)
    if paraIdx < #paragraphs then
      table.insert(lines, "")  -- Empty line for paragraph break
    end
  end
  
  return lines
end

function EventScene:_drawChoiceText(button, alpha, hoverScale)
  hoverScale = hoverScale or 1.0
  love.graphics.setFont(button.font)
  
  local text = button.label
  local paddingX = 20
  -- Account for hover scale in positioning and drawing
  local cx = button.x + button.w * 0.5
  local cy = button.y + button.h * 0.5
  
  -- Parse text for color markers - look for patterns like "Lose X HP." and "Gain X Gold."
  local parts = {}
  local defaultColor = { 0.9, 0.9, 0.9 }  -- default white
  
  -- Patterns to match (order matters - more specific first)
  local patterns = {
    { pattern = "Upgrade (%d+) random orbs by 1 level%.", color = { 195/255, 235/255, 139/255 } },  -- green (#C3EB8B) for orb upgrades
    { pattern = "Upgrade a random Orb%.", color = { 195/255, 235/255, 139/255 } },  -- green (#C3EB8B) for single orb upgrade
    { pattern = "Gain (%d+) Max HP%.", color = { 195/255, 235/255, 139/255 } },  -- green (#C3EB8B) for max HP gain
    { pattern = "Lose (%d+)%% Max HP%.", color = { 224/255, 112/255, 126/255 } },  -- red (#E0707E) for percentage HP loss
    { pattern = "Lose (%d+) HP%.", color = { 224/255, 112/255, 126/255 } },  -- red (#E0707E) for HP loss
    { pattern = "Gain (%d+) Gold%.", color = { 195/255, 235/255, 139/255 } },  -- green (#C3EB8B) for gold gain
    { pattern = "Gain a Relic%.", color = { 195/255, 235/255, 139/255 } },  -- green (#C3EB8B) for relic gain
    { pattern = "Pay (%d+) Gold%.", color = { 224/255, 112/255, 126/255 } },  -- red (#E0707E) for gold loss
  }
  
  local lastPos = 1
  local textToProcess = text
  
  -- Find all pattern matches
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
      -- No more matches, add remaining text
      if lastPos <= #textToProcess then
        table.insert(parts, { text = textToProcess:sub(lastPos), color = defaultColor })
      end
      break
    end
    
    -- Add text before match
    if bestStart > lastPos then
      table.insert(parts, { text = textToProcess:sub(lastPos, bestStart - 1), color = defaultColor })
    end
    
    -- Add matched text with special color
    table.insert(parts, { text = textToProcess:sub(bestStart, bestEnd), color = bestMatch.color })
    lastPos = bestEnd + 1
  end
  
  -- Draw text parts with hover scale applied
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

function EventScene:mousemoved(x, y, dx, dy, isTouch)
  self.mouseX = x or 0
  self.mouseY = y or 0
end

-- Start coin animation from clicked button to topbar
function EventScene:_startCoinAnimation(goldAmount, vw, vh)
  if not self.goldIcon or not self._clickedButtonIndex then return end
  
  local clickedButton = self.choiceButtons[self._clickedButtonIndex]
  if not clickedButton or not clickedButton._hitRect then return end
  
  -- Calculate source position (center of clicked button)
  local buttonRect = clickedButton._hitRect
  local sourceX = buttonRect.x + buttonRect.w * 0.5
  local sourceY = buttonRect.y + buttonRect.h * 0.5
  
  -- Calculate target position (topbar's gold icon position)
  local topBarHeight = (config.playfield and config.playfield.topBarHeight) or 60
  local topBarIconSize = 32
  local topBarTopPadding = (topBarHeight - topBarIconSize) * 0.5
  local topBarLeftPadding = 24
  local topBarIconSpacing = 12
  
  -- Calculate gold icon position in topbar (match TopBar.lua calculation)
  local PlayerState = require("core.PlayerState")
  local playerState = PlayerState.getInstance()
  local health = playerState:getHealth()
  local maxHealth = playerState:getMaxHealth()
  local healthText = string.format("%d / %d", math.floor(health), math.floor(maxHealth))
  local healthTextWidth = theme.fonts.base:getWidth(healthText)
  local afterHealthX = topBarLeftPadding + topBarIconSize + topBarIconSpacing + healthTextWidth + 40
  local targetX = afterHealthX + topBarIconSize * 0.5
  local targetY = topBarTopPadding + topBarIconSize * 0.5
  
  -- Determine number of coins based on gold amount
  local coinCount = math.min(math.max(5, math.floor(goldAmount / 5)), 30)
  
  -- Create coin animations
  for i = 1, coinCount do
    local delay = (i - 1) * 0.02 -- Stagger coins slightly
    local angle = love.math.random() * math.pi * 2 -- Random initial angle
    local speed = 200 + love.math.random() * 100 -- Random speed variation
    local rotationSpeed = (love.math.random() * 2 - 1) * 5 -- Random rotation speed
    
    table.insert(self._coinAnimations, {
      x = sourceX,
      y = sourceY,
      startX = sourceX,
      startY = sourceY,
      targetX = targetX,
      targetY = targetY,
      progress = 0,
      delay = delay,
      duration = 0.5, -- Animation duration
      angle = angle,
      speed = speed,
      rotation = love.math.random() * math.pi * 2,
      rotationSpeed = rotationSpeed,
      scale = (0.4 + love.math.random() * 0.2) * 2, -- Random scale variation, doubled
      alpha = 1.0,
    })
  end
end

-- Update coin animations
function EventScene:_updateCoinAnimations(dt)
  local alive = {}
  
  for i, coin in ipairs(self._coinAnimations) do
    -- Handle delay
    if coin.delay > 0 then
      coin.delay = coin.delay - dt
      table.insert(alive, coin)
    else
      -- Update progress
      coin.progress = coin.progress + dt / coin.duration
      
      if coin.progress < 1 then
        -- Ease-out cubic for smooth deceleration
        local t = coin.progress
        local eased = 1 - math.pow(1 - t, 3)
        
        -- Update position with slight arc
        local arcHeight = 30 * math.sin(t * math.pi) -- Arc motion
        coin.x = coin.startX + (coin.targetX - coin.startX) * eased
        coin.y = coin.startY + (coin.targetY - coin.startY) * eased - arcHeight
        
        -- Update rotation
        coin.rotation = coin.rotation + coin.rotationSpeed * dt
        
        -- Fade out near the end
        local fadeStartProgress = 1.0 - (0.3 / coin.duration)
        if coin.progress > fadeStartProgress then
          coin.alpha = 1 - ((coin.progress - fadeStartProgress) / (1.0 - fadeStartProgress))
        end
        
        table.insert(alive, coin)
      end
      -- Coin reached target - don't add to alive list
    end
  end
  
  self._coinAnimations = alive
end

-- Draw coin animations
function EventScene:_drawCoinAnimations()
  if not self.goldIcon then return end
  
  local TARGET_ICON_SIZE = 32
  
  for _, coin in ipairs(self._coinAnimations) do
    if coin.delay <= 0 and coin.alpha > 0 then
      love.graphics.push()
      love.graphics.translate(coin.x, coin.y)
      love.graphics.rotate(coin.rotation)
      love.graphics.setColor(1, 1, 1, coin.alpha)
      local iconW, iconH = self.goldIcon:getWidth(), self.goldIcon:getHeight()
      local scale = coin.scale * (TARGET_ICON_SIZE / math.max(iconW, iconH))
      love.graphics.draw(self.goldIcon, -iconW * 0.5 * scale, -iconH * 0.5 * scale, 0, scale, scale)
      love.graphics.pop()
    end
  end
  
  love.graphics.setColor(1, 1, 1, 1)
end

function EventScene:mousepressed(x, y, button)
  if button ~= 1 then return nil end  -- Only handle left mouse button
  
  -- Prevent clicking if a choice has already been made
  if self._choiceMade then
    return nil
  end
  
  -- Check if any button was clicked
  for _, buttonWidget in ipairs(self.choiceButtons) do
    if buttonWidget:mousepressed(x, y, button) then
      return nil  -- Button handles its own onClick
    end
  end
  
  return nil
end

function EventScene:_drawRelicTooltip(fadeAlpha)
  if not self._relicTooltip then return end
  
  local relicDef = self._relicTooltip
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  
  local font = theme.fonts.base
  love.graphics.setFont(font)
  
  -- Icon size and padding
  local iconSize = 48
  local iconPadding = 8
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
  
  -- Calculate size
  local textLines = {}
  for line in tooltipText:gmatch("[^\n]+") do
    table.insert(textLines, line)
  end
  
  local textScale = 0.75
  local maxTextW = 0
  for _, line in ipairs(textLines) do
    local w = font:getWidth(line) * textScale
    if w > maxTextW then maxTextW = w end
  end
  
  local baseTextH = font:getHeight() * #textLines
  local textW = maxTextW
  local textH = baseTextH * textScale
  
  -- Limit text width
  local maxTextWidth = 200
  if textW > maxTextWidth then
    textW = maxTextWidth
  end
  
  -- Calculate tooltip dimensions
  local tooltipW = padding * 2
  if iconImg then
    tooltipW = tooltipW + iconSize + iconPadding
  end
  tooltipW = tooltipW + textW
  
  -- Calculate text wrap width
  local availableTextWidth = tooltipW - padding * 2
  if iconImg then
    availableTextWidth = availableTextWidth - iconSize - iconPadding
  end
  local textWrapWidth = availableTextWidth / textScale
  
  -- Word wrap text
  local wrappedLines = {}
  for _, line in ipairs(textLines) do
    local words = {}
    for word in line:gmatch("%S+") do
      table.insert(words, word)
    end
    
    local currentLine = ""
    for _, word in ipairs(words) do
      local testLine = currentLine == "" and word or currentLine .. " " .. word
      local testW = font:getWidth(testLine)
      if testW > textWrapWidth and currentLine ~= "" then
        table.insert(wrappedLines, currentLine)
        currentLine = word
      else
        currentLine = testLine
      end
    end
    if currentLine ~= "" then
      table.insert(wrappedLines, currentLine)
    end
  end
  
  local actualTextH = font:getHeight() * #wrappedLines * textScale
  local tooltipH = padding * 2 + math.max(iconSize, actualTextH)
  
  -- Calculate position (top right)
  local topBarHeight = (config.playfield and config.playfield.topBarHeight) or 60
  local startY = topBarHeight + 20 -- Below top bar
  
  -- Calculate total duration and phases
  local totalDuration = self._relicTooltipFadeInDuration + self._relicTooltipHoldDuration + self._relicTooltipFadeOutDuration
  
  -- Phase 1: Fade in + move up (0.2s)
  local fadeInProgress = 1.0
  local moveProgress = 0.0
  if self._relicTooltipTime < self._relicTooltipFadeInDuration then
    local phaseT = self._relicTooltipTime / self._relicTooltipFadeInDuration
    fadeInProgress = phaseT
    -- Ease-in-out for movement during fade in
    -- Ease-in-out cubic: t < 0.5 ? 4t³ : 1 - pow(-2t + 2, 3) / 2
    if phaseT < 0.5 then
      moveProgress = 4 * phaseT * phaseT * phaseT
    else
      moveProgress = 1 - math.pow(-2 * phaseT + 2, 3) / 2
    end
    -- Scale to 50% of total movement during fade in
    moveProgress = moveProgress * 0.5
  end
  
  -- Phase 2: Hold (0.5s) - movement stays at 50%
  local holdStart = self._relicTooltipFadeInDuration
  local holdEnd = holdStart + self._relicTooltipHoldDuration
  if self._relicTooltipTime >= holdStart and self._relicTooltipTime <= holdEnd then
    moveProgress = 0.5
  end
  
  -- Phase 3: Fade out + move up more (0.2s)
  local fadeOutStart = self._relicTooltipFadeInDuration + self._relicTooltipHoldDuration
  local fadeOutProgress = 1.0
  if self._relicTooltipTime > fadeOutStart then
    local phaseT = (self._relicTooltipTime - fadeOutStart) / self._relicTooltipFadeOutDuration
    fadeOutProgress = 1.0 - phaseT
    -- Ease-in-out for movement during fade out (from 50% to 100%)
    local moveOutT = phaseT
    local moveOutEased = 0.0
    if moveOutT < 0.5 then
      moveOutEased = 4 * moveOutT * moveOutT * moveOutT
    else
      moveOutEased = 1 - math.pow(-2 * moveOutT + 2, 3) / 2
    end
    -- Scale from 0.5 to 1.0
    moveProgress = 0.5 + (moveOutEased * 0.5)
  end
  
  -- Apply movement
  local tooltipY = startY - (moveProgress * self._relicTooltipMoveDistance)
  
  -- Position at top right
  local tooltipX = vw - tooltipW - 20 -- 20px from right edge
  
  -- Calculate alpha (combine fade in, fade out, and scene fade)
  local alpha = fadeInProgress * fadeOutProgress * fadeAlpha
  
  -- Draw background
  love.graphics.setColor(0, 0, 0, 0.85 * alpha)
  love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipW, tooltipH, 4, 4)
  
  -- Draw border
  love.graphics.setColor(1, 1, 1, 0.3 * alpha)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", tooltipX, tooltipY, tooltipW, tooltipH, 4, 4)
  
  -- Draw icon (top left)
  if iconImg then
    local iconX = tooltipX + padding
    local iconY = tooltipY + padding
    local iconScale = iconSize / math.max(iconImg:getWidth(), iconImg:getHeight())
    love.graphics.setColor(1, 1, 1, alpha)
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
  for i, line in ipairs(wrappedLines) do
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.print(line, 0, currentY)
    currentY = currentY + font:getHeight()
  end
  love.graphics.pop()
end

function EventScene:unload()
  -- Cleanup if needed
end

return EventScene

