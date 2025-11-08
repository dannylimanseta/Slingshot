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
  self._fadeStartDelay = 1.0
  self._fadeTimer = 0
  -- Circle pulse on scene entry (drives shader u_transitionProgress)
  self._enterPulseTimer = 0
  self._enterPulseDuration = (config.transition and config.transition.duration) or 0.6
  self._enterPulsePhase = "rising"
  self._enterFalloffTimer = 0
  self._enterFalloffDuration = 0.4
  local decorPath = "assets/images/decor_1.png"
  local okDecor, imgDecor = pcall(love.graphics.newImage, decorPath)
  if okDecor then self.decorImage = imgDecor end
  -- Load arrow icon
  local okArrow, imgArrow = pcall(love.graphics.newImage, "assets/images/icon_arrow.png")
  if okArrow then self.arrowIcon = imgArrow end

  -- Fonts (same size as Rewards title ~50px)
  local fontPath = (config.assets and config.assets.fonts and config.assets.fonts.ui) or nil
  if fontPath then
    local ok, f = pcall(love.graphics.newFont, fontPath, 50)
    if ok then self.titleFont = f end
  end

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
    bgColor = { 1, 1, 1, 0.1 },
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
    self.shader:send("u_time", self.time)
    self.shader:send("u_resolution", { vw, vh })
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
  -- Layout skip button and update hover tween targets
  local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
  local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
  if self.skipButton then
    local f = self.skipButton.font or theme.fonts.base
    local th = f:getHeight()
    local bw = math.floor(vw * 0.175)
    local bh = math.max(th + Button.defaults.paddingY * 2, 44)
    local bx = math.floor((vw - bw) * 0.5)
    local by = math.floor(vh * 0.78)
    self.skipButton:setLayout(bx, by, bw, bh)
    self.skipButton:update(dt, self.mouseX, self.mouseY)
  end

  -- Tween per-option scales based on hover state using existing bounds
  if self.bounds then
    for i, r in ipairs(self.bounds) do
      local hovered = (self.mouseX >= r.x and self.mouseX <= r.x + r.w and self.mouseY >= r.y and self.mouseY <= r.y + r.h)
      local target = hovered and 1.05 or 1.0
      local s = self.scales[i] or 1.0
      local k = math.min(1, (12 * dt))
      self.scales[i] = s + (target - s) * k
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
    local headerCol = (opt.kind == "upgrade") and {1,1,1,0.8 * a} or {0.6,1.0,0.6,0.9 * a}
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
      love.graphics.setColor(1, 1, 1, a)
      love.graphics.print(leftText, startX, baselineY)
      if self.arrowIcon then
        local ax = startX + lw + spacing
        local ay = baselineY + (font:getAscent() - ih * scale) * 0.5 + 2
        love.graphics.setColor(1, 1, 1, a)
        love.graphics.draw(self.arrowIcon, ax, ay, 0, scale, scale)
      end
      local rx = startX + lw + spacing + (iw * scale) + spacing
      love.graphics.setColor(1, 1, 1, a)
      love.graphics.print(rightText, rx, baselineY)
    end

    -- Card with hover scale (+5%)
    local oldLevel = p and p.level
    if p then p.level = opt.targetLevel end
    local cardH = self.card:calculateHeight(p or {})
    if p then p.level = oldLevel end
    local scale = self.scales[i] or 1.0
    love.graphics.push()
    local cx = x + cardW * 0.5
    local cy = y + cardH * 0.5
    love.graphics.translate(cx, cy)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-cx, -cy)
    drawCardWithLevel(self.card, opt.id, opt.targetLevel, x, y, a)
    love.graphics.pop()
    -- Update clickable bounds to match scaled size
    local bw = cardW * scale
    local bh = cardH * scale
    self.bounds[i] = { x = cx - bw * 0.5, y = cy - bh * 0.5, w = bw, h = bh }
  end

  -- Draw Skip button
  if self.skipButton then
    self.skipButton:draw()
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
  for i, r in ipairs(self.bounds or {}) do
    local a = self.optionAlphas and self.optionAlphas[i] or 1.0
    if a > 0.85 and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
      self.choice = self.options[i]
      return
    end
  end
  if self.skipButton and self.skipButton:mousepressed(x, y, button) then return end
end

function OrbRewardScene:keypressed(key)
  if key == "escape" then
    return "return_to_map"
  end
end

return OrbRewardScene


