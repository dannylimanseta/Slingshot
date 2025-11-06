local config = require("config")
local theme = require("theme")
local RewardsBackdropShader = require("utils.RewardsBackdropShader")
local Button = require("ui.Button")

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
  }, RewardsScene)
end

function RewardsScene:load()
  self.time = 0
  -- Load decorative image (same asset as turn indicator)
  local decorPath = "assets/images/decor_1.png"
  local okDecor, imgDecor = pcall(love.graphics.newImage, decorPath)
  if okDecor then self.decorImage = imgDecor end
  -- Create a crisp title font ~50px to avoid scaling blur
  local fontPath = (config.assets and config.assets.fonts and config.assets.fonts.ui) or nil
  if fontPath then
    local ok, f = pcall(love.graphics.newFont, fontPath, 50)
    if ok then self.titleFont = f end
  end
  -- Load orb icon (optional)
  local iconPath = "assets/images/icon_orbs.png"
  local okIcon, imgIcon = pcall(love.graphics.newImage, iconPath)
  if okIcon then self.orbsIcon = imgIcon end
  
  -- Create buttons (layout computed in update/draw each frame)
  self.skipButton = Button.new({
    label = "Skip rewards",
    font = theme.fonts.base,
    align = "center",
    onClick = function()
      self._exitRequested = true
    end,
  })
  self.orbButton = Button.new({
    label = "Select an Orb Reward",
    font = theme.fonts.base,
    icon = self.orbsIcon,
    iconScale = 0.5,
    iconTint = { 1, 1, 1, 0.85 },
    onClick = function()
      -- Placeholder: handle reward selection logic here
      -- For now, do nothing (keeps scene open) or set a flag for future flow
      self._selectedOrb = true
    end,
  })
end

function RewardsScene:update(dt)
  self.time = self.time + dt
  if self.shader then
    local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
    local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
    self.shader:send("u_time", self.time)
    self.shader:send("u_resolution", { vw, vh })
  end
  if self._exitRequested then
    return "return_to_map"
  end
  
  -- Update button layouts and hover states
  local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
  local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
  
  if self.orbButton then
    -- 35% width, height based on font
    local bw = math.floor(vw * 0.35)
    local f = self.orbButton.font or theme.fonts.base
    local th = f:getHeight()
    local bh = math.max(th + Button.defaults.paddingY * 2, 52)
    local bx = math.floor((vw - bw) * 0.5)
    local by = math.floor(vh * 0.42)
    self.orbButton:setLayout(bx, by, bw, bh)
    self.orbButton:update(dt, self._mouseX, self._mouseY)
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
  
  -- Skip button
  if self.skipButton then
    self.skipButton:draw()
  end
end

function RewardsScene:keypressed(key, scancode, isRepeat)
  if key == "space" or key == "return" or key == "escape" then
    return "return_to_map"
  end
end

function RewardsScene:mousepressed(x, y, button)
  if button == 1 then
    if self.orbButton and self.orbButton:mousepressed(x, y, button) then return nil end
    if self.skipButton and self.skipButton:mousepressed(x, y, button) then return nil end
  end
end

function RewardsScene:mousemoved(x, y, dx, dy, isTouch)
  self._mouseX, self._mouseY = x, y
end

return RewardsScene



