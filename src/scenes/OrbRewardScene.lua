local config = require("config")
local theme = require("theme")
local ProjectileManager = require("managers.ProjectileManager")
local Button = require("ui.Button")
local RewardsBackdropShader = require("utils.RewardsBackdropShader")
local ProjectileCard = require("ui.ProjectileCard")
local TopBar = require("ui.TopBar")

local OrbRewardScene = {}
OrbRewardScene.__index = OrbRewardScene

-- Build candidate lists
local function getEquipped()
  local equipped = (config.player and config.player.equippedProjectiles) or {}
  local set = {}
  for _, id in ipairs(equipped) do set[id] = true end
  return equipped, set
end

local function shuffle(t)
  for i = #t, 2, -1 do
    local j = love.math.random(i)
    t[i], t[j] = t[j], t[i]
  end
end

function OrbRewardScene.new(params)
  params = params or {}
  return setmetatable({
    time = params.shaderTime or 0,
    _fadeTimer = 0,
    -- Keyboard selection and glow
    _selectedIndex = 1, -- default to first option
    _prevSelectedIndex = 1,
    _glowTime = 0,
    _glowFadeAlpha = 1.0,
    _prevGlowFadeAlpha = 0.0,
    _glowFadeSpeed = 8.0,
		-- Selection animation state
		selectedIndex = nil,         -- which option is selected (1..n)
		selectionTimer = 0,          -- elapsed time for selection anim
		selectionDuration = 0.4,     -- how long the bounce/fade takes
		pendingChoice = nil,         -- store choice to apply after anim
    shader = nil,
    decorImage = nil,
    arrowIcon = nil,
    titleFont = nil,
    card = ProjectileCard.new(),
    options = {}, -- { { kind="upgrade"|"new", id, targetLevel }, ... }
    choice = nil,
    mouseX = 0,
    mouseY = 0,
    bounds = {}, -- clickable bounds per option
    _hoverProgress = {}, -- per-option hover/selection tween 0..1
    scales = {}, -- per-option hover scale
    optionAlphas = {}, -- per-option fade-in alpha
    skipButton = nil,
    topBar = TopBar.new(),
    returnToPreviousOnExit = not not params.returnToPreviousOnExit,
  }, OrbRewardScene)
end

function OrbRewardScene:load()
  -- Shader and decor image (match RewardsScene)
  self.shader = RewardsBackdropShader.getShader()
  -- Fade-in timings for options
  self._fadeInDuration = 0.65
  self._fadeInDelayStep = 0.25
  self._fadeStartDelay = 0.6
  self._fadeTimer = 0
  -- Circle pulse on scene entry (drives shader u_transitionProgress)
  self._enterPulseTimer = 0
  self._enterPulseDuration = ((config.transition and config.transition.duration) or 0.6) * 0.2
  self._enterPulsePhase = "rising" -- Start entry transition
  self._enterFalloffTimer = 0
  self._enterFalloffDuration = 0.2 -- 2x faster (was 0.4)
  self._entryTransitionComplete = false -- Track when entry transition finishes
  self._exitTransitionStarted = false -- Flag to track when exit shader transition should start
  local decorPath = "assets/images/decor_1.png"
  local okDecor, imgDecor = pcall(love.graphics.newImage, decorPath)
  if okDecor then self.decorImage = imgDecor end
  -- Load arrow icon
  local okArrow, imgArrow = pcall(love.graphics.newImage, "assets/images/icon_arrow.png")
  if okArrow then self.arrowIcon = imgArrow end

  -- Fonts (same size as Rewards title ~50px, scaled for crisp rendering)
  self.titleFont = theme.newFont(50)
  -- Grey out orbs icon on orb reward screen
  if self.topBar then self.topBar.disableOrbsIcon = true end

  -- Build options
  local equipped, equippedSet = getEquipped()
  local upgrades = {}
  for _, id in ipairs(equipped) do
    local p = ProjectileManager.getProjectile(id)
    if p and (p.level or 1) < 5 then
      table.insert(upgrades, { kind = "upgrade", id = id, targetLevel = math.min(5, (p.level or 1) + 1) })
    end
  end
  local news = {}
  for _, p in ipairs(ProjectileManager.getAllProjectiles()) do
    if not equippedSet[p.id] then
      table.insert(news, { kind = "new", id = p.id, targetLevel = 1 })
    end
  end

  shuffle(upgrades)
  shuffle(news)

  -- Build 3 mixed options (prefer mix, fallback to whatever available)
  local picks = {}
  for i = 1, 3 do
    local chooseUpgrade = (love.math.random() < 0.5)
    local opt
    if chooseUpgrade and #upgrades > 0 then
      opt = table.remove(upgrades)
    elseif #news > 0 then
      opt = table.remove(news)
    elseif #upgrades > 0 then
      opt = table.remove(upgrades)
    end
    if opt then table.insert(picks, opt) end
  end
  self.options = picks
  -- Init per-option scales
  self.scales = {}
  for i = 1, #self.options do self.scales[i] = 1.0 end
  self.optionAlphas = {}
  for i = 1, #self.options do self.optionAlphas[i] = 0.0 end

  -- Create Skip button (same sizing as Rewards skip)
  self.skipButton = Button.new({
    label = "Skip",
    font = theme.fonts.base,
    bgColor = { 0, 0, 0, 0.7 },
    align = "center",
    onClick = function()
      self.choice = { kind = "skip" }
    end,
  })
end

-- Apply selected option
function OrbRewardScene:applyChoice(opt)
  if not opt then return end
  if opt.kind == "upgrade" then
    ProjectileManager.upgradeLevel(opt.id)
  elseif opt.kind == "new" then
    ProjectileManager.addToEquipped(opt.id)
  end
end

-- Draw a card with a temporary level for preview
local function drawCardWithLevel(card, projectileId, level, x, y, alpha)
  local p = ProjectileManager.getProjectile(projectileId)
  if not p then return end
  local old = p.level
  p.level = level
  card:draw(x, y, projectileId, alpha)
  p.level = old
end

function OrbRewardScene:update(dt)
  -- Advance glow timer
  self._glowTime = (self._glowTime or 0) + dt

	-- Play selection animation if an option was chosen
	if self.selectedIndex and self.pendingChoice then
		self.selectionTimer = self.selectionTimer + dt
		if self.selectionTimer >= (self.selectionDuration or 0.4) then
			-- Selection animation complete, start exit shader transition
			if not self._exitTransitionStarted then
				self._exitTransitionStarted = true
				self._enterPulsePhase = "rising"
				self._enterPulseTimer = 0
			end
			-- Do not reset selection state here; keep it so draw
			-- remains in the faded/offset state during transition.
			self.choice = self.pendingChoice
		end
	end
	if self.choice then
    self:applyChoice(self.choice)
    if self.returnToPreviousOnExit then
      return "return_to_previous"
    else
      return "return_to_map"
    end
  end
  -- Animate shader backdrop
  self.time = self.time + dt
  -- Advance UI fade timer (independent from shader time)
  self._fadeTimer = self._fadeTimer + dt
  if self.shader then
    local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
    local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
    -- Account for supersampling: shader resolution should match canvas size
    local supersamplingFactor = _G.supersamplingFactor or 1
    self.shader:send("u_time", self.time)
    self.shader:send("u_resolution", { vw * supersamplingFactor, vh * supersamplingFactor })
    local p = 0
    local function easeOutCubic(t) return 1 - math.pow(1 - t, 3) end
    
    -- Handle entry transition (runs on scene load)
    if not self._entryTransitionComplete and not self._exitTransitionStarted then
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
          self._entryTransitionComplete = true
          p = 0
        end
      else
        p = 0
      end
    -- Handle exit transition (runs after selection animation completes)
    elseif self._exitTransitionStarted then
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
    else
      -- Idle state (entry complete, exit not started yet)
      p = 0
    end
    self.shader:send("u_transitionProgress", p)
  end
  -- Layout skip button and update hover tween targets
  local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
  local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
  if self.skipButton then
		-- Disable skip while selection animation is playing
		local canInteract = not (self.selectedIndex and self.pendingChoice)
    local f = self.skipButton.font or theme.fonts.base
    local th = f:getHeight()
    local bw = math.floor(vw * 0.175)
    local bh = math.max(th + Button.defaults.paddingY * 2, 44)
    local bx = math.floor((vw - bw) * 0.5)
    local by = math.floor(vh * 0.78)
    self.skipButton:setLayout(bx, by, bw, bh)
		if canInteract then
			self.skipButton:update(dt, self.mouseX, self.mouseY)
		end
    -- Merge keyboard selection with mouse hover for skip
    local numOptions = #self.options
    local mouseHovered = self.skipButton._hovered
    -- Also suppress skip key-selected highlight if any option is mouse-hovered
    local anyMouseHovered = false
    if self.bounds then
      local hoveringAllowed = not (self.selectedIndex and self.pendingChoice)
      for i, r in ipairs(self.bounds) do
        local mh = hoveringAllowed and (self.mouseX >= r.x and self.mouseX <= r.x + r.w and self.mouseY >= r.y and self.mouseY <= r.y + r.h)
        if mh then anyMouseHovered = true; break end
      end
    end
    self.skipButton._keySelected = (self._selectedIndex == (numOptions + 1))
    self.skipButton._hovered = mouseHovered or (self.skipButton._keySelected and not anyMouseHovered)
    -- Tween skip hover progress
    local hp = self.skipButton._hoverProgress or 0
    local target = self.skipButton._hovered and 1 or 0
    self.skipButton._hoverProgress = hp + (target - hp) * math.min(1, 10 * dt)
  end

  -- Tween per-option scales; suppress key-selected highlight when any option is mouse-hovered
	if self.bounds then
    -- First pass: find any mouse hovered option (when interactions allowed)
    local hoveringAllowed = not (self.selectedIndex and self.pendingChoice)
    local anyMouseHovered = false
    local mouseHoveredFlags = {}
    for i, r in ipairs(self.bounds) do
      local mh = hoveringAllowed and (self.mouseX >= r.x and self.mouseX <= r.x + r.w and self.mouseY >= r.y and self.mouseY <= r.y + r.h)
      mouseHoveredFlags[i] = mh
      if mh then anyMouseHovered = true end
    end
    -- Second pass: apply hover/selection with suppression
    for i, r in ipairs(self.bounds) do
      local mouseHovered = mouseHoveredFlags[i]
      local keySelected = (self._selectedIndex == i)
      local hovered = mouseHovered or (keySelected and not anyMouseHovered)
      local target = hovered and 1.05 or 1.0
      local s = self.scales[i] or 1.0
      local k = math.min(1, (12 * dt))
      self.scales[i] = s + (target - s) * k
      -- Tween hover progress for glow
      local hp = self._hoverProgress[i] or 0
      local htarget = hovered and 1 or 0
      self._hoverProgress[i] = hp + (htarget - hp) * math.min(1, 10 * dt)
    end
  end
  
  -- Staggered fade-in for options
  do
    local function easeOut(a) return a * a * (3 - 2 * a) end
    for i = 1, #self.options do
      local delay = (i - 1) * self._fadeInDelayStep
      local t = (self._fadeTimer - (self._fadeStartDelay or 0) - delay) / self._fadeInDuration
      if t < 0 then t = 0 end
      if t > 1 then t = 1 end
      self.optionAlphas[i] = easeOut(t)
    end
  end
end

function OrbRewardScene:draw()
  local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
  local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()

  -- Backdrop shader (match RewardsScene)
  if self.shader then
    love.graphics.push('all')
    love.graphics.setShader(self.shader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle('fill', 0, 0, vw, vh)
    love.graphics.setShader()
    love.graphics.pop()
  end

  -- Title with side decor (match RewardsScene positioning/style)
  love.graphics.push()
  local title = "PICK ONE"
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

  -- Title text (no outline to match Rewards indicator style)
  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.print(title, -textW * 0.5, -font:getHeight() * 0.5)
  love.graphics.pop()
  love.graphics.setFont(theme.fonts.base)
  love.graphics.pop()

  -- Layout three options
  local spacing = 24
  local cardW = 288
  local cardH = 120 -- will expand as needed by card itself
  local totalW = cardW * #self.options + spacing * math.max(0, #self.options - 1)
  local startX = math.floor((vw - totalW) * 0.5)
  local y = math.floor(vh * 0.38)
  self.bounds = {}

  for i, opt in ipairs(self.options) do
    local x = startX + (i - 1) * (cardW + spacing)
		local a = self.optionAlphas[i] or 1.0
    -- Clamp
    if a < 0 then a = 0 end
    if a > 1 then a = 1 end
    -- Header label
    local header = (opt.kind == "upgrade") and "UPGRADE" or "NEW ORB!"
    -- Make "NEW ORB!" white as well
		local headerCol = (opt.kind == "upgrade") and {1,1,1,0.8 * a} or {1,1,1,0.9 * a}
		-- Apply selection animation fade
		if self.selectedIndex and self.pendingChoice then
			if self.selectedIndex == i then
				-- Fade selected header as it moves up
				local t = math.min(1, (self.selectionTimer or 0) / (self.selectionDuration or 0.4))
				headerCol[4] = headerCol[4] * (1.0 - t)
			else
				-- Fade non-selected headers to fully transparent
				headerCol[4] = 0.0
			end
		end
    love.graphics.setColor(headerCol[1], headerCol[2], headerCol[3], headerCol[4])
    love.graphics.print(header, x, y - 44)

    -- Level label right
    local p = ProjectileManager.getProjectile(opt.id)
    if opt.kind == "upgrade" then
      local font = theme.fonts.base
      local leftText = "LV " .. tostring((p and p.level) or 1)
      local rightText = "LV " .. tostring(opt.targetLevel)
      local lw = font:getWidth(leftText)
      local rw = font:getWidth(rightText)
      local spacing = 6
      local iw, ih, scale = 0, 0, 1
      if self.arrowIcon then
        iw, ih = self.arrowIcon:getWidth(), self.arrowIcon:getHeight()
        -- Base scale to match font height, then reduce by 40%
        scale = ((font:getHeight() * 0.8) / math.max(1, ih)) * 0.6
      end
      local totalW = lw + spacing + (iw * scale) + spacing + rw
      local startX = x + cardW - totalW
      local baselineY = y - 44
      -- Apply selection animation fade to level labels
      local levelAlpha = a
      if self.selectedIndex and self.pendingChoice then
        if self.selectedIndex == i then
          -- Fade selected level labels as it moves up
          local t = math.min(1, (self.selectionTimer or 0) / (self.selectionDuration or 0.4))
          levelAlpha = a * (1.0 - t)
        else
          -- Fade non-selected level labels to fully transparent
          levelAlpha = 0.0
        end
      end
      love.graphics.setColor(1, 1, 1, levelAlpha)
      love.graphics.print(leftText, startX, baselineY)
      if self.arrowIcon then
        local ax = startX + lw + spacing
        local ay = baselineY + (font:getAscent() - ih * scale) * 0.5 + 2
        love.graphics.setColor(1, 1, 1, levelAlpha)
        love.graphics.draw(self.arrowIcon, ax, ay, 0, scale, scale)
      end
      local rx = startX + lw + spacing + (iw * scale) + spacing
      love.graphics.setColor(1, 1, 1, levelAlpha)
      love.graphics.print(rightText, rx, baselineY)
    end

    -- Card with hover scale (+5%)
    local oldLevel = p and p.level
    if p then p.level = opt.targetLevel end
    local cardH = self.card:calculateHeight(p or {})
    if p then p.level = oldLevel end
		local scale = self.scales[i] or 1.0
		-- Selection animation: bounce slightly and fade upwards
		local yOffset = 0
		local alphaMul = 1.0
		local extraScale = 1.0
		if self.selectedIndex == i and self.pendingChoice then
			local t = math.min(1, (self.selectionTimer or 0) / (self.selectionDuration or 0.4))
			-- Ease-out cubic for upward motion
			local function easeOutCubic(u) return 1 - math.pow(1 - u, 3) end
			-- Increased upward movement: moves up more as it fades (t increases, alphaMul decreases)
			local moveUp = 150 * easeOutCubic(t) -- Increased from 18 to 50 pixels
			-- Small initial bounce on scale (peaks at start, eases to 0)
			local bounceWindow = math.min(1, t / 0.15)
			local bounceEase = 1 - (1 - bounceWindow) * (1 - bounceWindow)
			extraScale = 1.0 + 0.06 * (1 - bounceEase)
			yOffset = -moveUp
			alphaMul = (1.0 - t)
		elseif self.selectedIndex and self.pendingChoice and self.selectedIndex ~= i then
			-- Fade non-selected options to fully transparent during animation
			alphaMul = 0.0
		end
    love.graphics.push()
    local cx = x + cardW * 0.5
    local cy = y + cardH * 0.5
		love.graphics.translate(cx, cy + yOffset)
		love.graphics.scale(scale * extraScale, scale * extraScale)
    love.graphics.translate(-cx, -cy)
		drawCardWithLevel(self.card, opt.id, opt.targetLevel, x, y, a * alphaMul)
    love.graphics.pop()
    -- Update clickable bounds to match scaled size
		local bw = cardW * scale * extraScale
		local bh = cardH * scale * extraScale
		self.bounds[i] = { x = cx - bw * 0.5, y = (cy + yOffset) - bh * 0.5, w = bw, h = bh }
    -- Draw glow for hovered/highlighted option
    local hp = self._hoverProgress[i] or 0
    if hp > 0 then
      love.graphics.push()
      love.graphics.translate(cx, cy + yOffset)
      love.graphics.scale(scale * extraScale, scale * extraScale)
      love.graphics.setBlendMode("add")
      local pulseSpeed = 1.0
      local pulseAmount = 0.15
      local pulse = 1.0 + math.sin((self._glowTime or 0) * pulseSpeed * math.pi * 2) * pulseAmount
      local baseAlpha = 0.12 * a * hp
      local layers = { { width = 4, alpha = 0.4 }, { width = 7, alpha = 0.25 }, { width = 10, alpha = 0.15 } }
      for _, layer in ipairs(layers) do
        local glowAlpha = baseAlpha * layer.alpha * pulse
        local glowWidth = layer.width * pulse
        love.graphics.setColor(1, 1, 1, glowAlpha)
        love.graphics.setLineWidth(glowWidth)
        love.graphics.rectangle("line", -cardW * 0.5 - glowWidth * 0.5, -cardH * 0.5 - glowWidth * 0.5,
                                cardW + glowWidth, cardH + glowWidth,
                                Button.defaults.cornerRadius + glowWidth * 0.5, Button.defaults.cornerRadius + glowWidth * 0.5)
      end
      love.graphics.setBlendMode("alpha")
      love.graphics.pop()
    end
  end

  -- Draw Skip button
  if self.skipButton then
    self.skipButton:draw()
    -- Draw glow for skip when hovered/highlighted
    if self.skipButton._hovered then
      love.graphics.push()
      local cx = self.skipButton.x + self.skipButton.w * 0.5
      local cy = self.skipButton.y + self.skipButton.h * 0.5
      local s = self.skipButton._scale or 1.0
      love.graphics.translate(cx, cy)
      love.graphics.scale(s, s)
      love.graphics.setBlendMode("add")
      local pulseSpeed = 1.0
      local pulseAmount = 0.15
      local pulse = 1.0 + math.sin((self._glowTime or 0) * pulseSpeed * math.pi * 2) * pulseAmount
      local baseAlpha = 0.12 * (self.skipButton.alpha or 1.0) * (self.skipButton._hoverProgress or 0)
      local layers = { { width = 4, alpha = 0.4 }, { width = 7, alpha = 0.25 }, { width = 10, alpha = 0.15 } }
      for _, layer in ipairs(layers) do
        local glowAlpha = baseAlpha * layer.alpha * pulse
        local glowWidth = layer.width * pulse
        love.graphics.setColor(1, 1, 1, glowAlpha)
        love.graphics.setLineWidth(glowWidth)
        love.graphics.rectangle("line", -self.skipButton.w * 0.5 - glowWidth * 0.5, -self.skipButton.h * 0.5 - glowWidth * 0.5,
                                self.skipButton.w + glowWidth, self.skipButton.h + glowWidth,
                                Button.defaults.cornerRadius + glowWidth * 0.5, Button.defaults.cornerRadius + glowWidth * 0.5)
      end
      love.graphics.setBlendMode("alpha")
      love.graphics.pop()
    end
  end
  
  -- Draw top bar on top (z-order)
  if self.topBar then
    self.topBar:draw()
  end
end

function OrbRewardScene:mousemoved(x, y)
  self.mouseX, self.mouseY = x, y
end

function OrbRewardScene:mousepressed(x, y, button)
  if button ~= 1 then return end
	-- Ignore input during selection animation
	if self.selectedIndex and self.pendingChoice then return end
  for i, r in ipairs(self.bounds or {}) do
    local a = self.optionAlphas and self.optionAlphas[i] or 1.0
    if a > 0.85 and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
			self.selectedIndex = i
      self._selectedIndex = i
			self.selectionTimer = 0
			self.pendingChoice = self.options[i]
      return
    end
  end
  if self.skipButton and self.skipButton:mousepressed(x, y, button) then return end
end

function OrbRewardScene:keypressed(key)
  if key == "escape" then
    return "return_to_map"
  end
  -- Ignore navigation during selection animation
  if self.selectedIndex and self.pendingChoice then return end
  local n = #self.options
  if n == 0 then return end
  if key == "a" or key == "left" then
    if self._selectedIndex == n + 1 then
      self._selectedIndex = n
    else
      self._selectedIndex = math.max(1, (self._selectedIndex or 1) - 1)
    end
  elseif key == "d" or key == "right" then
    if self._selectedIndex == n + 1 then
      self._selectedIndex = n
    else
      self._selectedIndex = math.min(n, (self._selectedIndex or 1) + 1)
    end
  elseif key == "s" or key == "down" then
    self._selectedIndex = n + 1 -- skip button
  elseif key == "w" or key == "up" then
    if self._selectedIndex == n + 1 then
      self._selectedIndex = 1
    end
  elseif key == "space" or key == "return" then
    if self._selectedIndex and self._selectedIndex >= 1 and self._selectedIndex <= n then
      -- Select highlighted option
      self.selectedIndex = self._selectedIndex
      self.selectionTimer = 0
      self.pendingChoice = self.options[self.selectedIndex]
    elseif self._selectedIndex == n + 1 and self.skipButton and self.skipButton.onClick then
      self.skipButton.onClick()
    end
  end
end

return OrbRewardScene


