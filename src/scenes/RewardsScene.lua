local config = require("config")
local theme = require("theme")
local RewardsBackdropShader = require("utils.RewardsBackdropShader")
local Button = require("ui.Button")
local TopBar = require("ui.TopBar")

local RewardsScene = {}
RewardsScene.__index = RewardsScene

function RewardsScene.new(params)
  return setmetatable({
    time = 0,
    shader = RewardsBackdropShader.getShader(),
    params = params or {},
    decorImage = nil,
    _mouseX = 0,
    _mouseY = 0,
    skipButton = nil,
    orbButton = nil,
    orbsIcon = nil,
    goldButton = nil,
    goldIcon = nil,
    topBar = TopBar.new(),
    -- Coin animation state
    _coinAnimations = {},
    _goldButtonFadeAlpha = 1.0,
    _goldButtonClicked = false,
    _goldAnimationComplete = false,
  }, RewardsScene)
end

-- Helper function to create reward buttons with consistent styling
-- Ensures all icons are displayed at the same visual size
local TARGET_ICON_SIZE = 32 -- Target size in pixels for all icons
local function createRewardButton(label, icon, onClick)
  -- Calculate scale to make icon match target size
  local iconScale = 0.5 -- Default fallback
  if icon then
    local iconW, iconH = icon:getWidth(), icon:getHeight()
    -- Use the larger dimension to ensure icon fits within target size
    local iconMaxDim = math.max(iconW, iconH)
    if iconMaxDim > 0 then
      iconScale = TARGET_ICON_SIZE / iconMaxDim
    end
  end
  
  return Button.new({
    label = label,
    font = theme.fonts.base,
    bgColor = { 0, 0, 0, 0.7 },
    icon = icon,
    iconScale = iconScale,
    iconTint = { 1, 1, 1, 0.85 },
    align = "left",
    onClick = onClick or function() end,
  })
end

-- Helper function to layout reward buttons with consistent positioning
-- Returns layout function that can be called for each button
local function createRewardButtonLayout(vw, vh, rowIndex, dt, mouseX, mouseY)
  -- rowIndex: 0 = first row (orb), 1 = second row (gold), etc.
  local baseY = vh * 0.26 -- First row Y position
  local rowGap = 10 -- Fixed 10px gap between buttons
  local leftMargin = vw * 0.325 -- Left margin (centers 35% width button, then shifts left)
  -- Calculate button height (all buttons use same font and padding)
  local f = theme.fonts.base
  local th = f:getHeight()
  local buttonHeight = math.max(th + Button.defaults.paddingY * 2, 52)
  return function(button)
    if not button then return end
    local bw = math.floor(vw * 0.35) -- 35% width
    local bx = math.floor(leftMargin) -- Left-aligned position
    -- Position each button accounting for previous buttons' height + gap
    local by = math.floor(baseY + rowIndex * (buttonHeight + rowGap))
    button:setLayout(bx, by, bw, buttonHeight)
    button:update(dt, mouseX, mouseY)
  end
end

function RewardsScene:load()
  self.time = 0
  self._uiFadeTimer = 0
  self._fadeInDuration = 0.65
  self._fadeInDelayStep = 0.25
  self._fadeStartDelay = 0.3
  self._goldFadeInAlpha = 0
  -- Circle pulse on scene entry (drives shader u_transitionProgress)
  self._enterPulseTimer = 0
  self._enterPulseDuration = (config.transition and config.transition.duration) or 0.6
  self._enterPulsePhase = "rising" -- "rising" -> "falloff" -> "idle"
  self._enterFalloffTimer = 0
  self._enterFalloffDuration = 0.4
  -- Load decorative image (same asset as turn indicator)
  local decorPath = "assets/images/decor_1.png"
  local okDecor, imgDecor = pcall(love.graphics.newImage, decorPath)
  if okDecor then self.decorImage = imgDecor end
  -- Create a crisp title font ~50px (scaled for crisp rendering)
  self.titleFont = theme.newFont(50)
  -- Load orb icon (optional)
  local iconPath = "assets/images/icon_orbs.png"
  local okIcon, imgIcon = pcall(love.graphics.newImage, iconPath)
  if okIcon then self.orbsIcon = imgIcon end
  
  -- Load gold icon
  local goldIconPath = (config.assets and config.assets.images and config.assets.images.icon_gold) or nil
  if goldIconPath then
    local okGoldIcon, goldImg = pcall(love.graphics.newImage, goldIconPath)
    if okGoldIcon then self.goldIcon = goldImg end
  end
  
  -- Create buttons (layout computed in update/draw each frame)
  self.skipButton = Button.new({
    label = "Skip rewards",
    font = theme.fonts.base,
    bgColor = { 0, 0, 0, 0.7 },
    align = "center",
    onClick = function()
      self._exitRequested = true
    end,
  })
  self.orbButton = createRewardButton(
    "Select an Orb Reward",
    self.orbsIcon,
    function()
      self._selectedOrb = true
    end
  )
  
  -- Initialize top bar gold override to pre-reward amount
  do
    local PlayerState = require("core.PlayerState")
    local playerState = PlayerState.getInstance()
    local currentGold = playerState:getGold()
    -- Reward is not yet applied; start and target are currentGold
    self._goldDisplayStart = currentGold
    self._goldDisplayTarget = currentGold
    self._goldCounting = false
    self._goldCountTime = 0
    self._goldCountDuration = 0.6 -- seconds to count up
    if self.topBar then self.topBar.overrideGold = nil end
  end
  
  -- Gold button (will be created/updated when gold reward is available)
  self.goldButton = nil
end

function RewardsScene:update(dt)
  self.time = self.time + dt
  self._uiFadeTimer = self._uiFadeTimer + dt
  if self.shader then
    local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
    local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
    -- Account for supersampling: shader resolution should match canvas size
    local supersamplingFactor = _G.supersamplingFactor or 1
    self.shader:send("u_time", self.time)
    self.shader:send("u_resolution", { vw * supersamplingFactor, vh * supersamplingFactor })
    -- Drive circle growth only during entry pulse window
    local p = 0
    local function easeOutCubic(t) return 1 - math.pow(1 - t, 3) end
    if self._enterPulsePhase == "rising" then
      self._enterPulseTimer = self._enterPulseTimer + dt
      local t = math.min(1, self._enterPulseTimer / self._enterPulseDuration)
      p = easeOutCubic(t)
      if t >= 1 then
        self._enterPulsePhase = "falloff"
        self._enterFalloffTimer = 0
      end
    elseif self._enterPulsePhase == "falloff" then
      self._enterFalloffTimer = self._enterFalloffTimer + dt
      local tf = math.min(1, self._enterFalloffTimer / self._enterFalloffDuration)
      p = 1 - easeOutCubic(tf)
      if tf >= 1 then
        self._enterPulsePhase = "idle"
        p = 0
      end
    else
      p = 0
    end
    self.shader:send("u_transitionProgress", p)
  end
  if self._exitRequested then
    return "return_to_map"
  end
  if self._selectedOrb then
    self._selectedOrb = false
    local shouldReturn = (self.goldButton ~= nil) and (not self._goldButtonClicked)
    return { type = "open_orb_reward", returnToRewards = shouldReturn, shaderTime = self.time }
  end
  
  -- Update button layouts and hover states
  local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
  local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
  
  -- If coming back from OrbRewardScene after a choice/skip, remove the orb button
  if self._removeOrbButtonOnReturn then
    self.orbButton = nil
    self._removeOrbButtonOnReturn = nil
  end
  
  -- Dynamic row index for stacking buttons from top to bottom
  local nextRowIndex = 0
  
  -- Layout orb button if present
  if self.orbButton then
    local layoutRow = createRewardButtonLayout(vw, vh, nextRowIndex, dt, self._mouseX, self._mouseY)
    layoutRow(self.orbButton)
    nextRowIndex = nextRowIndex + 1
  end
  
  if self.skipButton then
    -- 17.5% width, height based on font
    local f = self.skipButton.font or theme.fonts.base
    local th = f:getHeight()
    local bw = math.floor(vw * 0.175)
    local bh = math.max(th + Button.defaults.paddingY * 2, 44)
    local bx = math.floor((vw - bw) * 0.5)
    local by = math.floor(vh * 0.78)
    self.skipButton:setLayout(bx, by, bw, bh)
    self.skipButton:update(dt, self._mouseX, self._mouseY)
  end
  
  -- Update gold button layout if gold reward is available
  local goldReward = (self.params and self.params.goldReward) or 0
  if goldReward > 0 then
    if not self.goldButton then
      local goldText = tostring(goldReward) .. " Gold"
      self.goldButton = createRewardButton(goldText, self.goldIcon, function()
        -- Handle gold button click
        if not self._goldButtonClicked then
          self._goldButtonClicked = true
          -- Apply gold to PlayerState now (so persistent state updates only on click)
          local PlayerState = require("core.PlayerState")
          local playerState = PlayerState.getInstance()
          -- Freeze top bar display at pre-reward amount to avoid instant jump
          local preGold = playerState:getGold()
          self._goldDisplayStart = preGold
          if self.topBar then self.topBar.overrideGold = preGold end
          playerState:addGold(goldReward)
          -- Update target for counting to reflect new total
          self._goldDisplayTarget = playerState:getGold()
          self:_startCoinAnimation(goldReward, vw, vh)
        end
      end)
    end
    
    -- Layout gold button at current row
    local layoutGoldButton = createRewardButtonLayout(vw, vh, nextRowIndex, dt, self._mouseX, self._mouseY)
    layoutGoldButton(self.goldButton)
    nextRowIndex = nextRowIndex + 1
  end
  
  -- Compute staged fade-in alphas (top-to-bottom: orb, gold, skip)
  do
    local idx = 0
    local function easeOut(a)
      -- smoothstep-like ease
      return a * a * (3 - 2 * a)
    end
    local function alphaFor(index)
      local t = (self._uiFadeTimer - (self._fadeStartDelay or 0) - index * self._fadeInDelayStep) / self._fadeInDuration
      t = math.max(0, math.min(1, t))
      return easeOut(t)
    end
    if self.orbButton then
      self.orbButton.alpha = alphaFor(idx); idx = idx + 1
    end
    if self.goldButton then
      self._goldFadeInAlpha = alphaFor(idx); idx = idx + 1
    else
      self._goldFadeInAlpha = 0
    end
    if self.skipButton then
      self.skipButton.alpha = alphaFor(idx)
    end
  end
  
  -- Update coin animations
  self:_updateCoinAnimations(dt)
  
  -- Update gold button fade
  if self._goldButtonClicked and not self._goldAnimationComplete then
    -- Check if all coins have finished
    if #self._coinAnimations == 0 then
      self._goldAnimationComplete = true
      -- Start gold counting animation now
      if not self._goldCounting then
        self._goldCounting = true
        self._goldCountTime = 0
        -- Ensure override starts at start value
        if self.topBar then self.topBar.overrideGold = self._goldDisplayStart end
      end
    end
  end
  
  if self._goldAnimationComplete then
    -- Fade out button
    self._goldButtonFadeAlpha = math.max(0, self._goldButtonFadeAlpha - dt * 6)
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
      -- Counting done; clear override to use real PlayerState gold
      self.topBar.overrideGold = nil
      self._goldCounting = false
    end
  end

  -- If there are no more reward buttons (orb removed AND gold finished and faded or no gold), return to map
  do
    local hasOrb = (self.orbButton ~= nil)
    local hadGold = ((self.params and self.params.goldReward) or 0) > 0
    local goldDone = (not hadGold) or (self._goldAnimationComplete and (self._goldButtonFadeAlpha or 0) <= 0)
    if (not hasOrb) and goldDone then
      return "return_to_map"
    end
  end
end

function RewardsScene:draw()
  local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
  local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()

  -- Backdrop shader
  if self.shader then
    love.graphics.push('all')
    love.graphics.setShader(self.shader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle('fill', 0, 0, vw, vh)
    love.graphics.setShader()
    love.graphics.pop()
  end

  -- Title with side decor (mirroring PLAYER'S TURN style)
  love.graphics.push()
  local title = "REWARDS"
  local font = self.titleFont or theme.fonts.large
  love.graphics.setFont(font)
  local textW = font:getWidth(title)
  local centerX = vw * 0.5
  local centerY = vh * 0.2
  local decorSpacing = 20
  local alpha = 1.0

  love.graphics.push()
  love.graphics.translate(centerX, centerY)

  if self.decorImage then
    local decorW = self.decorImage:getWidth()
    local decorH = self.decorImage:getHeight()
    local decorScale = 0.35
    local scaledW = decorW * decorScale
    -- Center positions of each decor sprite
    local leftCenterX = -textW * 0.5 - decorSpacing - scaledW * 0.5
    local rightCenterX = textW * 0.5 + decorSpacing + scaledW * 0.5
    love.graphics.setColor(1, 1, 1, alpha)

    -- Left decor (normal)
    love.graphics.push()
    love.graphics.translate(leftCenterX, 0)
    love.graphics.scale(decorScale, decorScale)
    love.graphics.draw(self.decorImage, -decorW * 0.5, -decorH * 0.5)
    love.graphics.pop()

    -- Right decor (flipped horizontally)
    love.graphics.push()
    love.graphics.translate(rightCenterX, 0)
    love.graphics.scale(-decorScale, decorScale)
    love.graphics.draw(self.decorImage, -decorW * 0.5, -decorH * 0.5)
    love.graphics.pop()
  end

  -- Title text (no outline to match in-battle indicator style)
  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.print(title, -textW * 0.5, -font:getHeight() * 0.5)
  love.graphics.pop()
  love.graphics.setFont(theme.fonts.base)
  love.graphics.pop()

  -- Reward option button
  if self.orbButton then
    self.orbButton:draw()
  end
  
  -- Gold reward button (matches orb button style)
  if self.goldButton and self._goldButtonFadeAlpha > 0 then
    -- Calculate hitRect first (same logic as Button:draw)
    if not self.goldButton._hitRect then
      self.goldButton._hitRect = {}
    end
    local cx = self.goldButton.x + self.goldButton.w * 0.5
    local cy = self.goldButton.y + self.goldButton.h * 0.5
    local s = self.goldButton._scale or 1.0
    local drawW = self.goldButton.w * s
    local drawH = self.goldButton.h * s
    self.goldButton._hitRect.x = math.floor(cx - drawW * 0.5)
    self.goldButton._hitRect.y = math.floor(cy - drawH * 0.5)
    self.goldButton._hitRect.w = math.floor(drawW)
    self.goldButton._hitRect.h = math.floor(drawH)
    
    -- Draw button with alpha applied
    love.graphics.push()
    local bg = self.goldButton.bgColor or Button.defaults.bgColor
    local combinedAlpha = ((bg[4] or 1) * self._goldButtonFadeAlpha * (self._goldFadeInAlpha or 1))
    love.graphics.setColor(bg[1], bg[2], bg[3], combinedAlpha)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(s, s)
    love.graphics.rectangle("fill", -self.goldButton.w * 0.5, -self.goldButton.h * 0.5, self.goldButton.w, self.goldButton.h, Button.defaults.cornerRadius, Button.defaults.cornerRadius)
    -- Border (white, 0.1 alpha, matches Button default)
    do
      local bc = Button.defaults.borderColor or {1,1,1,0.1}
      local borderAlpha = (bc[4] or 1) * self._goldButtonFadeAlpha * (self._goldFadeInAlpha or 1)
      love.graphics.setColor(bc[1], bc[2], bc[3], borderAlpha)
      local oldLW = love.graphics.getLineWidth()
      love.graphics.setLineWidth(Button.defaults.borderWidth or 2)
      love.graphics.rectangle("line", -self.goldButton.w * 0.5, -self.goldButton.h * 0.5, self.goldButton.w, self.goldButton.h, Button.defaults.cornerRadius, Button.defaults.cornerRadius)
      love.graphics.setLineWidth(oldLW or 1)
    end
    
    -- Draw icon and text with alpha
    love.graphics.setFont(self.goldButton.font or theme.fonts.base)
    local tw = (self.goldButton.font or theme.fonts.base):getWidth(self.goldButton.label)
    local th = (self.goldButton.font or theme.fonts.base):getHeight()
    local iconW, iconH = 0, 0
    if self.goldButton.icon then
      local iw, ih = self.goldButton.icon:getWidth(), self.goldButton.icon:getHeight()
      iconW = iw * (self.goldButton.iconScale or 1.0)
      iconH = ih * (self.goldButton.iconScale or 1.0)
    end
    local spacing = (self.goldButton.icon and 16) or 0
    local startX = -self.goldButton.w * 0.5 + Button.defaults.paddingX
    local centerY = -th * 0.5
    
    if self.goldButton.icon then
      local tint = self.goldButton.iconTint or {1, 1, 1, 0.8}
      love.graphics.setColor(tint[1], tint[2], tint[3], (tint[4] or 1) * self._goldButtonFadeAlpha * (self._goldFadeInAlpha or 1))
      love.graphics.draw(self.goldButton.icon, startX, -iconH * 0.5, 0, (self.goldButton.iconScale or 1.0), (self.goldButton.iconScale or 1.0))
      startX = startX + iconW + spacing
    end
    
    local textColor = Button.defaults.textColor
    love.graphics.setColor(textColor[1], textColor[2], textColor[3], (textColor[4] or 1) * self._goldButtonFadeAlpha * (self._goldFadeInAlpha or 1))
    love.graphics.print(self.goldButton.label, startX, centerY)
    love.graphics.pop()
    love.graphics.pop()
  end
  
  -- Skip button
  if self.skipButton then
    self.skipButton:draw()
  end
  
  -- Draw top bar
  if self.topBar then
    self.topBar:draw()
  end
  
  -- Draw coin animations above topbar (z-order)
  self:_drawCoinAnimations()
end

function RewardsScene:keypressed(key, scancode, isRepeat)
  if key == "space" or key == "return" or key == "escape" then
    return "return_to_map"
  end
end

function RewardsScene:mousepressed(x, y, button)
  if button == 1 then
    -- Handle gold button click first (before other buttons)
    if self.goldButton and not self._goldButtonClicked then
      -- Ensure button has hitRect by calculating it manually if needed
      if not self.goldButton._hitRect or not self.goldButton._hitRect.w then
        local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
        local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
        local layoutGoldButton = createRewardButtonLayout(vw, vh, 1, 0, self._mouseX, self._mouseY)
        layoutGoldButton(self.goldButton)
        -- Manually calculate hitRect (same logic as Button:draw)
        local cx = self.goldButton.x + self.goldButton.w * 0.5
        local cy = self.goldButton.y + self.goldButton.h * 0.5
        local s = self.goldButton._scale or 1.0
        local drawW = self.goldButton.w * s
        local drawH = self.goldButton.h * s
        if not self.goldButton._hitRect then
          self.goldButton._hitRect = {}
        end
        self.goldButton._hitRect.x = math.floor(cx - drawW * 0.5)
        self.goldButton._hitRect.y = math.floor(cy - drawH * 0.5)
        self.goldButton._hitRect.w = math.floor(drawW)
        self.goldButton._hitRect.h = math.floor(drawH)
      end
      
      if self.goldButton:mousepressed(x, y, button) then
        return nil
      end
    end
    if self.orbButton and self.orbButton:mousepressed(x, y, button) then return nil end
    if self.skipButton and self.skipButton:mousepressed(x, y, button) then return nil end
  end
end

function RewardsScene:mousemoved(x, y, dx, dy, isTouch)
  self._mouseX, self._mouseY = x, y
end

-- Start coin animation from button to topbar
function RewardsScene:_startCoinAnimation(goldAmount, vw, vh)
  if not self.goldButton or not self.goldIcon then return end
  
  -- Calculate source position (button's icon position)
  local buttonRect = self.goldButton._hitRect
  if not buttonRect then return end
  
  -- Get button icon position (left side of button with padding)
  local iconSize = TARGET_ICON_SIZE
  local iconSpacing = 16
  local leftPadding = Button.defaults.paddingX
  local sourceX = buttonRect.x + leftPadding + iconSize * 0.5
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
  -- More coins for larger amounts, but cap at reasonable number
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
      duration = 0.5, -- Animation duration (shorter for faster feel)
      angle = angle,
      speed = speed,
      rotation = love.math.random() * math.pi * 2,
      rotationSpeed = rotationSpeed,
      scale = (0.4 + love.math.random() * 0.2) * 2, -- Random scale variation, doubled (2x size)
      alpha = 1.0,
    })
  end
end

-- Update coin animations
function RewardsScene:_updateCoinAnimations(dt)
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
        
        -- Fade out for 0.3 seconds at the end
        -- Animation duration is 0.8s, so fade starts at 0.8 - 0.3 = 0.5s, which is progress 0.5/0.8 = 0.625
        local fadeStartProgress = 1.0 - (0.3 / coin.duration) -- 0.625 for 0.8s duration
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
function RewardsScene:_drawCoinAnimations()
  if not self.goldIcon then return end
  
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

return RewardsScene



