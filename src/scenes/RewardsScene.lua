local config = require("config")
local theme = require("theme")
local RewardsBackdropShader = require("utils.RewardsBackdropShader")
local Button = require("ui.Button")
local TopBar = require("ui.TopBar")
local relics = require("data.relics")

local RewardsScene = {}
RewardsScene.__index = RewardsScene

-- Rarity colors for tooltips
local RARITY_COLORS = {
  common = { 0.75, 0.75, 0.75, 1.0 },
  uncommon = { 0.38, 0.78, 0.48, 1.0 },
  rare = { 0.35, 0.58, 0.94, 1.0 },
  epic = { 0.74, 0.46, 0.94, 1.0 },
  legendary = { 0.98, 0.76, 0.32, 1.0 },
}

-- Reward option types
RewardsScene.OptionType = {
  ORB = "orb",
  RELIC = "relic",
  GOLD = "gold",
  SKIP = "skip",
}

function RewardsScene.new(params)
  return setmetatable({
    time = 0,
    shader = RewardsBackdropShader.getShader(),
    params = params or {},
    decorImage = nil,
    _mouseX = 0,
    _mouseY = 0,
    topBar = TopBar.new(),
    
    -- Dynamic reward options system
    _rewardOptions = {}, -- Array of { type, button, state, ... }
    
    -- Icons
    orbsIcon = nil,
    goldIcon = nil,
    
    -- Coin animation state
    _coinAnimations = {},
    _goldDisplayStart = 0,
    _goldDisplayTarget = 0,
    _goldCounting = false,
    _goldCountTime = 0,
    _goldCountDuration = 0.6,
    _goldAnimationComplete = false,
    
    -- Keyboard navigation
    _selectedIndex = 1,
    _prevSelectedIndex = 1,
    
    -- Glow animation
    _glowTime = 0,
    _glowFadeAlpha = 1.0,
    _prevGlowFadeAlpha = 0.0,
    _glowFadeSpeed = 8.0,
    
    -- UI fade-in
    _uiFadeTimer = 0,
    _fadeInDuration = 0.65,
    _fadeInDelayStep = 0.25,
    _fadeStartDelay = 0.3,
    
    -- Scene entry animation
    _enterPulseTimer = 0,
    _enterPulseDuration = (config.transition and config.transition.duration) or 0.6,
    _enterPulsePhase = "rising",
    _enterFalloffTimer = 0,
    _enterFalloffDuration = 0.4,
    
    -- Relic reward state
    _pendingRelicReward = nil,
    _relicClaimedTimer = 0,
    _relicClaimedName = nil,
    _relicDescription = nil,
    _relicFlavor = nil,
    _relicButtonClaimed = false,
    
    -- Flags
    _exitRequested = false,
    _selectedOrb = false,
    _removeOrbButtonOnReturn = nil,
    _removeRelicButtonOnReturn = nil,
    -- Tooltip state
    _tooltipRelicId = nil, -- Currently hovered relic ID for tooltip
    _tooltipHoverTime = 0, -- Time hovering over relic
    _tooltipBounds = nil, -- Bounds of hovered button {x, y, w, h}
  }, RewardsScene)
end

-- Helper function to create reward buttons with consistent styling
local TARGET_ICON_SIZE = 32
local function createRewardButton(label, icon, onClick)
  local iconScale = 0.5
  if icon then
    local iconW, iconH = icon:getWidth(), icon:getHeight()
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

local function pickRelicReward()
  local list = relics.list() or {}
  if #list == 0 then return nil end

  local PlayerState = require("core.PlayerState")
  local playerState = PlayerState.getInstance and PlayerState.getInstance()
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

local function loadRelicIcon(relicDef)
  if not relicDef or not relicDef.icon then return nil end
  local ok, img = pcall(love.graphics.newImage, relicDef.icon)
  if ok then
    return img
  end
  return nil
end

-- Add a reward option to the dynamic list
function RewardsScene:_addRewardOption(optionType, button, config)
  config = config or {}
  local option = {
    type = optionType,
    button = button,
    state = "active", -- "active" | "claimed" | "removing" | "removed"
    targetY = nil, -- Target Y position (for smooth transitions)
    currentY = nil, -- Current Y position
    fadeOutAlpha = 1.0, -- Alpha multiplier for fade-out
    fadeInAlpha = 0.0, -- Alpha multiplier for fade-in
    fadeInIndex = config.fadeInIndex or 0, -- Index for staggered fade-in
    allowHighlight = config.allowHighlight ~= false,
    onClaim = config.onClaim, -- Callback when claimed
    customLayout = config.customLayout, -- Custom layout function (for skip button)
  }
  table.insert(self._rewardOptions, option)
  return option
end

-- Remove a reward option (triggers fade-out and removal)
function RewardsScene:_removeRewardOption(optionType)
  for i, option in ipairs(self._rewardOptions) do
    if option.type == optionType and option.state == "active" then
      option.state = "removing"
      if option.onClaim then
        option.onClaim()
      end
      return true
    end
  end
  return false
end

-- Get active reward options (for navigation)
function RewardsScene:_getActiveOptions()
  local active = {}
  for _, option in ipairs(self._rewardOptions) do
    if option.state == "active" and option.button then
      table.insert(active, option)
    end
  end
  return active
end

-- Layout configuration
local function getLayoutConfig(vw, vh)
  local f = theme.fonts.base
  local th = f:getHeight()
  local buttonHeight = math.max(th + Button.defaults.paddingY * 2, 52)
  local baseY = vh * 0.26
  local rowGap = 10
  local leftMargin = vw * 0.325
  local buttonWidth = math.floor(vw * 0.35)
  
  -- Skip button layout (centered, bottom)
  local skipButtonWidth = math.floor(vw * 0.175)
  local skipButtonHeight = math.max(th + Button.defaults.paddingY * 2, 44)
  local skipButtonX = math.floor((vw - skipButtonWidth) * 0.5)
  local skipButtonY = math.floor(vh * 0.78)
  
  return {
    baseY = baseY,
    rowGap = rowGap,
    leftMargin = leftMargin,
    buttonWidth = buttonWidth,
    buttonHeight = buttonHeight,
    skipButtonWidth = skipButtonWidth,
    skipButtonHeight = skipButtonHeight,
    skipButtonX = skipButtonX,
    skipButtonY = skipButtonY,
  }
end

function RewardsScene:load()
  self.time = 0
  self._uiFadeTimer = 0
  self._selectedIndex = 1
  self._prevSelectedIndex = 1
  self._glowFadeAlpha = 1.0
  self._prevGlowFadeAlpha = 0.0
  
  -- Load decorative image
  local decorPath = "assets/images/decor_1.png"
  local okDecor, imgDecor = pcall(love.graphics.newImage, decorPath)
  if okDecor then self.decorImage = imgDecor end
  
  -- Create title font
  self.titleFont = theme.newFont(50)
  
  -- Top bar should show PlayerState HP (post-battle healing), not BattleState
  if self.topBar then
    self.topBar.preferPlayerState = true
  end
  
  -- Load icons
  local iconPath = "assets/images/icon_orbs.png"
  local okIcon, imgIcon = pcall(love.graphics.newImage, iconPath)
  if okIcon then self.orbsIcon = imgIcon end
  
  local goldIconPath = (config.assets and config.assets.images and config.assets.images.icon_gold) or nil
  if goldIconPath then
    local okGoldIcon, goldImg = pcall(love.graphics.newImage, goldIconPath)
    if okGoldIcon then self.goldIcon = goldImg end
  end
  
  -- Grey out orbs icon in top bar
  if self.topBar then 
    self.topBar.disableOrbsIcon = true
    self.topBar.disableInventoryIcon = true
  end
  
  -- Initialize gold display
  do
    local PlayerState = require("core.PlayerState")
    local playerState = PlayerState.getInstance()
    local currentGold = playerState:getGold()
    self._goldDisplayStart = currentGold
    self._goldDisplayTarget = currentGold
    self._goldCounting = false
    self._goldCountTime = 0
    if self.topBar then self.topBar.overrideGold = nil end
  end
  
  -- Build reward options dynamically
  self._rewardOptions = {}
  
  -- Orb option
  local orbButton = createRewardButton(
    "Select an Orb Reward",
    self.orbsIcon,
    function()
      self._selectedOrb = true
    end
  )
  self:_addRewardOption(RewardsScene.OptionType.ORB, orbButton, {
    fadeInIndex = 0,
    allowHighlight = true,
  })
  
  -- Relic option (if eligible)
  self._relicRewardEligible = (self.params and self.params.relicRewardEligible == true) or false
  if self._relicRewardEligible then
    local relicDef = pickRelicReward()
    if relicDef then
      self._pendingRelicReward = relicDef
      self._relicDescription = relicDef.description or ""
      self._relicFlavor = relicDef.flavor or ""
      local relicIcon = loadRelicIcon(relicDef)
      local buttonLabel = relicDef.name or relicDef.id
      local relicButton = createRewardButton(
        buttonLabel,
        relicIcon,
        function()
          self:_claimRelicReward()
        end
      )
      self:_addRewardOption(RewardsScene.OptionType.RELIC, relicButton, {
        fadeInIndex = 1,
        allowHighlight = true,
        onClaim = function()
          self:_claimRelicReward()
        end,
      })
    else
      self._relicRewardEligible = false
    end
  end
  
  -- Gold option (if available)
  local goldReward = (self.params and self.params.goldReward) or 0
  if goldReward > 0 then
    local goldText = tostring(goldReward) .. " Gold"
    local goldButton = createRewardButton(goldText, self.goldIcon, function()
      self:_claimGoldReward(goldReward)
    end)
    self:_addRewardOption(RewardsScene.OptionType.GOLD, goldButton, {
      fadeInIndex = 2,
      allowHighlight = true,
      onClaim = function()
        self:_claimGoldReward(goldReward)
      end,
    })
  end
  
  -- Skip option (always last, custom layout)
  local skipButton = Button.new({
    label = "Skip rewards",
    font = theme.fonts.base,
    bgColor = { 0, 0, 0, 0.7 },
    align = "center",
    onClick = function()
      self._exitRequested = true
    end,
  })
  self:_addRewardOption(RewardsScene.OptionType.SKIP, skipButton, {
    fadeInIndex = 3,
    allowHighlight = true,
    customLayout = true, -- Uses special bottom-center layout
  })
end

function RewardsScene:_claimRelicReward()
  local relicOption = nil
  for _, option in ipairs(self._rewardOptions) do
    if option.type == RewardsScene.OptionType.RELIC and option.state == "active" then
      relicOption = option
      break
    end
  end
  
  if not relicOption or not self._pendingRelicReward then return end
  
    local PlayerState = require("core.PlayerState")
    local playerState = PlayerState.getInstance()
  if playerState and playerState.addRelic then
    playerState:addRelic(self._pendingRelicReward.id)
  end
  
  self._relicClaimedName = self._pendingRelicReward.name or self._pendingRelicReward.id
  self._relicClaimedTimer = 3.0
  self._relicButtonClaimed = true -- For compatibility with SceneTransitionHandler
  
  if relicOption.button then
    relicOption.button.onClick = nil
    relicOption.button.label = self._relicClaimedName or "Relic Claimed"
  end
  
  relicOption.state = "removing"
  self._pendingRelicReward = nil
end

function RewardsScene:_claimGoldReward(amount)
  local goldOption = nil
  for _, option in ipairs(self._rewardOptions) do
    if option.type == RewardsScene.OptionType.GOLD and option.state == "active" then
      goldOption = option
      break
    end
  end
  
  if not goldOption then return end
  
  local PlayerState = require("core.PlayerState")
  local playerState = PlayerState.getInstance()
  local preGold = playerState:getGold()
  self._goldDisplayStart = preGold
  if self.topBar then self.topBar.overrideGold = preGold end
  playerState:addGold(amount)
  self._goldDisplayTarget = playerState:getGold()
  
  local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
  local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
  self:_startCoinAnimation(amount, vw, vh)
  
  goldOption.state = "claimed" -- Special state for gold (waits for coin animation)
end

function RewardsScene:update(dt)
  self.time = self.time + dt
  self._uiFadeTimer = self._uiFadeTimer + dt
  self._glowTime = (self._glowTime or 0) + dt
  
  -- Update relic claimed timer
  if self._relicClaimedTimer and self._relicClaimedTimer > 0 then
    self._relicClaimedTimer = math.max(0, self._relicClaimedTimer - dt)
  end
  
  -- Update shader
  if self.shader then
    local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
    local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
    local supersamplingFactor = _G.supersamplingFactor or 1
    self.shader:send("u_time", self.time)
    self.shader:send("u_resolution", { vw * supersamplingFactor, vh * supersamplingFactor })
    
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
    end
    self.shader:send("u_transitionProgress", p)
  end
  
  if self._exitRequested then
    return "return_to_map"
  end
  
  if self._selectedOrb then
    self._selectedOrb = false
    local activeOptions = self:_getActiveOptions()
    local hasGold = false
    for _, opt in ipairs(activeOptions) do
      if opt.type == RewardsScene.OptionType.GOLD then
        hasGold = true
        break
      end
    end
    return { type = "open_orb_reward", returnToRewards = hasGold, shaderTime = self.time }
  end
  
  -- Handle button removal on return (for compatibility)
  if self._removeOrbButtonOnReturn then
    self:_removeRewardOption(RewardsScene.OptionType.ORB)
    self._removeOrbButtonOnReturn = nil
  end
  
  if self._removeRelicButtonOnReturn then
    self:_removeRewardOption(RewardsScene.OptionType.RELIC)
    self._removeRelicButtonOnReturn = nil
  end
  
  local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
  local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
  local layout = getLayoutConfig(vw, vh)
  
  -- Update reward options
  local activeOptions = self:_getActiveOptions()
  local rowIndex = 0
  
  -- Process each option
  for i, option in ipairs(self._rewardOptions) do
    if not option.button then
      option.state = "removed"
      goto continue
    end
    
    -- Handle state transitions
    if option.state == "removing" then
      option.fadeOutAlpha = math.max(0, option.fadeOutAlpha - dt * 3)
      if option.fadeOutAlpha <= 0 then
        option.state = "removed"
      end
    elseif option.state == "claimed" and option.type == RewardsScene.OptionType.GOLD then
      -- Gold: wait for coin animation to complete
      if #self._coinAnimations == 0 and not self._goldCounting then
        self._goldAnimationComplete = true
        if not self._goldCounting then
          self._goldCounting = true
          self._goldCountTime = 0
          if self.topBar then self.topBar.overrideGold = self._goldDisplayStart end
        end
      end
      
      if self._goldAnimationComplete then
        option.fadeOutAlpha = math.max(0, option.fadeOutAlpha - dt * 6)
        if option.fadeOutAlpha <= 0 then
          option.state = "removed"
        end
      end
    end
    
    -- Skip removed options
    if option.state == "removed" then
      goto continue
    end
    
    -- Layout button
    if option.customLayout then
      -- Skip button: special bottom-center layout
      option.button:setLayout(layout.skipButtonX, layout.skipButtonY, layout.skipButtonWidth, layout.skipButtonHeight)
    else
      -- Regular buttons: stacked from top
      local targetY = layout.baseY + rowIndex * (layout.buttonHeight + layout.rowGap)
      option.targetY = targetY
      if option.currentY == nil then
        option.currentY = targetY
      else
        -- Smooth transition to target Y
        local diff = targetY - option.currentY
        option.currentY = option.currentY + diff * math.min(1, dt * 12)
      end
      option.button:setLayout(layout.leftMargin, math.floor(option.currentY), layout.buttonWidth, layout.buttonHeight)
      rowIndex = rowIndex + 1
    end
  
    -- Update button
    option.button:update(dt, self._mouseX, self._mouseY)
    
    ::continue::
  end
  
  -- Update navigation
  if #activeOptions > 0 then
    self._selectedIndex = math.max(1, math.min(self._selectedIndex, #activeOptions))
    
    -- Detect selection change
    if self._selectedIndex ~= self._prevSelectedIndex then
      self._prevGlowFadeAlpha = self._glowFadeAlpha
      self._glowFadeAlpha = 0
      self._prevSelectedIndex = self._selectedIndex
    end
    
    -- Tween glow fade
    local targetAlpha = 1.0
    local diff = targetAlpha - self._glowFadeAlpha
    self._glowFadeAlpha = self._glowFadeAlpha + diff * math.min(1, self._glowFadeSpeed * dt)
    
    local prevDiff = 0.0 - self._prevGlowFadeAlpha
    self._prevGlowFadeAlpha = self._prevGlowFadeAlpha + prevDiff * math.min(1, self._glowFadeSpeed * dt)
  
    -- Update button highlights
      local anyMouseHovered = false
    for _, opt in ipairs(activeOptions) do
      if opt.button and opt.button._hovered == true then
        anyMouseHovered = true
        break
      end
    end
    
    for idx, opt in ipairs(activeOptions) do
      if not opt.button or not opt.allowHighlight then
        if opt.button then
          opt.button._keySelected = false
          opt.button._hovered = false
          opt.button._hoverProgress = 0
          opt.button._scale = 1.0
        end
      else
        local wasSelected = (self._prevSelectedIndex == idx and self._selectedIndex ~= idx)
        local mouseHovered = opt.button._hovered
        opt.button._keySelected = (self._selectedIndex == idx)
        opt.button._wasSelected = wasSelected
        opt.button._hovered = mouseHovered or (opt.button._keySelected and not anyMouseHovered)
        
        local hp = opt.button._hoverProgress or 0
        local target = opt.button._hovered and 1 or 0
        opt.button._hoverProgress = hp + (target - hp) * math.min(1, 10 * dt)
        opt.button._scale = 1.0 + 0.05 * (opt.button._hoverProgress or 0)
    end
    end
  end
  
  -- Update fade-in alphas
  do
    local function easeOut(a)
      return a * a * (3 - 2 * a)
    end
    local function alphaFor(index)
      local t = (self._uiFadeTimer - self._fadeStartDelay - index * self._fadeInDelayStep) / self._fadeInDuration
      t = math.max(0, math.min(1, t))
      return easeOut(t)
    end
    
    for _, option in ipairs(self._rewardOptions) do
      if option.button and option.state ~= "removed" then
        option.fadeInAlpha = alphaFor(option.fadeInIndex)
        local combinedAlpha = option.fadeInAlpha * option.fadeOutAlpha
        option.button.alpha = combinedAlpha
      end
    end
  end
  
  -- Update coin animations
  self:_updateCoinAnimations(dt)
  
  -- Update tooltip
  self:_updateTooltip(dt)
  
  -- Update gold counting
  if self._goldCounting and self.topBar then
    self._goldCountTime = self._goldCountTime + dt
    local t = math.min(1, self._goldCountTime / self._goldCountDuration)
    local eased = 1 - (1 - t) * (1 - t)
    local value = math.floor(self._goldDisplayStart + (self._goldDisplayTarget - self._goldDisplayStart) * eased + 0.5)
    self.topBar.overrideGold = value
    if t >= 1 then
      self.topBar.overrideGold = nil
      self._goldCounting = false
    end
  end

  -- Check if should return to map (exclude skip button from check)
  local hasActiveRewardOptions = false
  for _, option in ipairs(self._rewardOptions) do
    -- Skip button doesn't count as a "reward" option
    if option.type ~= RewardsScene.OptionType.SKIP then
      if option.state == "active" or (option.state == "claimed" and option.fadeOutAlpha > 0.01) then
        hasActiveRewardOptions = true
        break
      end
    end
  end
  
  -- If no reward options remain, hide skip button and exit
  if not hasActiveRewardOptions and not self._goldCounting then
    -- Hide/remove skip button
    for _, option in ipairs(self._rewardOptions) do
      if option.type == RewardsScene.OptionType.SKIP and option.state == "active" then
        option.state = "removing"
        option.fadeOutAlpha = 1.0 -- Start fade out
      end
    end
    
    -- Wait a moment for skip button to fade, then exit
    -- Check if skip button is fully faded out
    local skipButtonVisible = false
    for _, option in ipairs(self._rewardOptions) do
      if option.type == RewardsScene.OptionType.SKIP then
        if option.state ~= "removed" and (option.fadeOutAlpha or 1) > 0.01 then
          skipButtonVisible = true
          break
        end
      end
    end
    
    if not skipButtonVisible then
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

  -- Title with side decor
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
    local leftCenterX = -textW * 0.5 - decorSpacing - scaledW * 0.5
    local rightCenterX = textW * 0.5 + decorSpacing + scaledW * 0.5
    love.graphics.setColor(1, 1, 1, alpha)

    love.graphics.push()
    love.graphics.translate(leftCenterX, 0)
    love.graphics.scale(decorScale, decorScale)
    love.graphics.draw(self.decorImage, -decorW * 0.5, -decorH * 0.5)
    love.graphics.pop()

    love.graphics.push()
    love.graphics.translate(rightCenterX, 0)
    love.graphics.scale(-decorScale, decorScale)
    love.graphics.draw(self.decorImage, -decorW * 0.5, -decorH * 0.5)
    love.graphics.pop()
  end

  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.print(title, -textW * 0.5, -font:getHeight() * 0.5)
  love.graphics.pop()
  love.graphics.setFont(theme.fonts.base)
  love.graphics.pop()

  -- Draw reward options
  local activeOptions = self:_getActiveOptions()
  for idx, option in ipairs(self._rewardOptions) do
    if option.button and option.state ~= "removed" then
      -- Draw button
      option.button:draw()
      
      -- Draw glow effect
      if option.allowHighlight and (option.button._hovered or (option.button._wasSelected and self._prevGlowFadeAlpha > 0)) then
        self:_drawButtonGlow(option.button)
      end
    end
  end
  
  -- Draw top bar
  if self.topBar then
    self.topBar:draw()
  end
  
  -- Draw coin animations
  self:_drawCoinAnimations()
    
  -- Draw tooltip (on top of everything)
  self:_drawTooltip()
      end
      
function RewardsScene:_drawButtonGlow(button)
  if not button then return end
  local highlightAlpha = 0
  if button._hovered then
    highlightAlpha = (self._glowFadeAlpha or 1) * (button._hoverProgress or 0)
  elseif button._wasSelected then
    highlightAlpha = self._prevGlowFadeAlpha or 0
  end
  highlightAlpha = highlightAlpha * (button.alpha or 1)
  if highlightAlpha <= 0.001 then return end

      love.graphics.push()
  local cx = button.x + button.w * 0.5
  local cy = button.y + button.h * 0.5
  local s = button._scale or 1.0
      love.graphics.translate(cx, cy)
      love.graphics.scale(s, s)
      love.graphics.setBlendMode("add")
      
  local pulseSpeed = 1.0
  local pulseAmount = 0.15
      local pulse = 1.0 + math.sin(self._glowTime * pulseSpeed * math.pi * 2) * pulseAmount
  local baseAlpha = 0.12 * pulse * highlightAlpha
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
        -button.w * 0.5 - glowWidth * 0.5,
        -button.h * 0.5 - glowWidth * 0.5,
        button.w + glowWidth,
        button.h + glowWidth,
        Button.defaults.cornerRadius + glowWidth * 0.5,
        Button.defaults.cornerRadius + glowWidth * 0.5
      )
    end
      end
      
      love.graphics.setBlendMode("alpha")
      love.graphics.pop()
end

function RewardsScene:keypressed(key, scancode, isRepeat)
  local activeOptions = self:_getActiveOptions()
  
  if #activeOptions == 0 then
  if key == "space" or key == "return" or key == "escape" then
      return "return_to_map"
    end
    return nil
  end
  
  self._selectedIndex = math.max(1, math.min(self._selectedIndex, #activeOptions))
  
  if key == "w" or key == "up" then
    self._selectedIndex = self._selectedIndex - 1
    if self._selectedIndex < 1 then self._selectedIndex = #activeOptions end
    return nil
  elseif key == "s" or key == "down" then
    self._selectedIndex = self._selectedIndex + 1
    if self._selectedIndex > #activeOptions then self._selectedIndex = 1 end
    return nil
  elseif key == "space" or key == "return" then
    local selectedOption = activeOptions[self._selectedIndex]
    if selectedOption and selectedOption.button and selectedOption.button.onClick then
      selectedOption.button.onClick()
    end
    return nil
  elseif key == "escape" then
    return "return_to_map"
  end
  
  return nil
end

function RewardsScene:mousepressed(x, y, button)
  if button == 1 then
    local activeOptions = self:_getActiveOptions()
    for _, option in ipairs(activeOptions) do
      if option.button and option.button:mousepressed(x, y, button) then
        return nil
      end
    end
  end
end

function RewardsScene:mousemoved(x, y, dx, dy, isTouch)
  self._mouseX, self._mouseY = x, y
end

-- Start coin animation from button to topbar
function RewardsScene:_startCoinAnimation(goldAmount, vw, vh)
  local goldOption = nil
  for _, option in ipairs(self._rewardOptions) do
    if option.type == RewardsScene.OptionType.GOLD then
      goldOption = option
      break
    end
  end
  
  if not goldOption or not goldOption.button or not self.goldIcon then return end
  
  local buttonRect = goldOption.button._hitRect
  if not buttonRect then return end
  
  local iconSize = TARGET_ICON_SIZE
  local iconSpacing = 16
  local leftPadding = Button.defaults.paddingX
  local sourceX = buttonRect.x + leftPadding + iconSize * 0.5
  local sourceY = buttonRect.y + buttonRect.h * 0.5
  
  local topBarHeight = (config.playfield and config.playfield.topBarHeight) or 60
  local topBarIconSize = 32
  local topBarTopPadding = (topBarHeight - topBarIconSize) * 0.5
  local topBarLeftPadding = 24
  local topBarIconSpacing = 12
  
  local PlayerState = require("core.PlayerState")
  local playerState = PlayerState.getInstance()
  local health = playerState:getHealth()
  local maxHealth = playerState:getMaxHealth()
  local healthText = string.format("%d / %d", math.floor(health), math.floor(maxHealth))
  local healthTextWidth = theme.fonts.base:getWidth(healthText)
  local afterHealthX = topBarLeftPadding + topBarIconSize + topBarIconSpacing + healthTextWidth + 40
  local targetX = afterHealthX + topBarIconSize * 0.5
  local targetY = topBarTopPadding + topBarIconSize * 0.5
  
  local coinCount = math.min(math.max(5, math.floor(goldAmount / 5)), 30)
  
  for i = 1, coinCount do
    local delay = (i - 1) * 0.02
    local angle = love.math.random() * math.pi * 2
    local speed = 200 + love.math.random() * 100
    local rotationSpeed = (love.math.random() * 2 - 1) * 5
    
    table.insert(self._coinAnimations, {
      x = sourceX,
      y = sourceY,
      startX = sourceX,
      startY = sourceY,
      targetX = targetX,
      targetY = targetY,
      angle = angle,
      speed = speed,
      rotationSpeed = rotationSpeed,
      rotation = 0,
      delay = delay,
      t = 0,
      duration = 0.8,
      image = self.goldIcon,
    })
  end
end

function RewardsScene:_updateCoinAnimations(dt)
  for i = #self._coinAnimations, 1, -1 do
    local coin = self._coinAnimations[i]
    coin.t = coin.t + dt
    
    if coin.t < coin.delay then
      -- Still waiting for delay
    else
      local elapsed = coin.t - coin.delay
      local progress = math.min(1, elapsed / coin.duration)
      
      -- Ease-out curve
      local eased = 1 - (1 - progress) * (1 - progress)
      
        coin.x = coin.startX + (coin.targetX - coin.startX) * eased
      coin.y = coin.startY + (coin.targetY - coin.startY) * eased
        coin.rotation = coin.rotation + coin.rotationSpeed * dt
        
      if progress >= 1 then
        table.remove(self._coinAnimations, i)
      end
    end
    end
  end
  
function RewardsScene:_updateTooltip(dt)
  if not self._pendingRelicReward then
    -- No relic reward available, reset tooltip
    self._tooltipRelicId = nil
    self._tooltipHoverTime = 0
    self._tooltipBounds = nil
    return
  end
  
  -- Find the relic button
  local relicOption = nil
  for _, option in ipairs(self._rewardOptions) do
    if option.type == RewardsScene.OptionType.RELIC and option.state == "active" and option.button then
      relicOption = option
      break
    end
  end
  
  if not relicOption or not relicOption.button then
    self._tooltipRelicId = nil
    self._tooltipHoverTime = 0
    self._tooltipBounds = nil
    return
  end
  
  local relicId = self._pendingRelicReward.id
  local button = relicOption.button
  
  -- Check if hovering over the button
  if button._hovered then
    -- Check if hovering over the same relic
    if self._tooltipRelicId == relicId then
      -- Continue tracking hover time
      self._tooltipHoverTime = self._tooltipHoverTime + dt
      -- Update bounds from button
      self._tooltipBounds = {
        x = button.x,
        y = button.y,
        w = button.w,
        h = button.h
      }
    else
      -- New relic hovered, reset timer
      self._tooltipRelicId = relicId
      self._tooltipHoverTime = 0
      self._tooltipBounds = {
        x = button.x,
        y = button.y,
        w = button.w,
        h = button.h
      }
    end
  else
    -- Not hovering, reset tooltip state
    self._tooltipRelicId = nil
    self._tooltipHoverTime = 0
    self._tooltipBounds = nil
  end
end

function RewardsScene:_drawTooltip()
  -- Only show tooltip after 0.3s hover time
  if not self._tooltipRelicId or self._tooltipHoverTime < 0.3 or not self._tooltipBounds or not self._pendingRelicReward then
    return
  end
  
  local relicDef = self._pendingRelicReward
  if not relicDef then return end
  
  local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
  local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
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
  tooltipH = padding * 2 + math.max(iconSize, actualTextH)
  
  -- Calculate position (to the left of the button)
  local tooltipX = bounds.x - tooltipW - 30 -- 30px gap from button
  local tooltipY = bounds.y + bounds.h * 0.5 - tooltipH * 0.5 -- Vertically centered with button
  
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
  love.graphics.setColor(0, 0, 0, 0.85 * fadeProgress)
  love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipW, tooltipH, 4, 4)
  
  -- Draw border
  love.graphics.setColor(1, 1, 1, 0.3 * fadeProgress)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", tooltipX, tooltipY, tooltipW, tooltipH, 4, 4)
  
  -- Draw icon (top left)
  if iconImg then
    local iconX = tooltipX + padding
    local iconY = tooltipY + padding
    local iconScale = iconSize / math.max(iconImg:getWidth(), iconImg:getHeight())
    love.graphics.setColor(1, 1, 1, fadeProgress)
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
      love.graphics.setColor(rarityColor[1], rarityColor[2], rarityColor[3], fadeProgress)
    else
      love.graphics.setColor(1, 1, 1, fadeProgress)
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

function RewardsScene:_drawCoinAnimations()
  for _, coin in ipairs(self._coinAnimations) do
    if coin.t >= coin.delay and coin.image then
      local progress = math.min(1, (coin.t - coin.delay) / coin.duration)
      local alpha = 1 - progress
      love.graphics.push()
      love.graphics.translate(coin.x, coin.y)
      love.graphics.rotate(coin.rotation)
      love.graphics.setColor(1, 1, 1, alpha)
      local scale = 0.5
      love.graphics.draw(coin.image, 0, 0, 0, scale, scale, coin.image:getWidth() * 0.5, coin.image:getHeight() * 0.5)
      love.graphics.pop()
    end
  end
end

return RewardsScene
