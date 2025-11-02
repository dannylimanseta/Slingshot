local theme = require("theme")
local config = require("config")
local PlayerState = require("core.PlayerState")

local TopBar = {}
TopBar.__index = TopBar

function TopBar.new()
  local self = setmetatable({}, TopBar)
  
  -- Load icons
  local healthIconPath = (config.assets and config.assets.images and config.assets.images.icon_health) or nil
  local goldIconPath = (config.assets and config.assets.images and config.assets.images.icon_gold) or nil
  
  if healthIconPath then
    local ok, img = pcall(love.graphics.newImage, healthIconPath)
    if ok then self.healthIcon = img end
  end
  
  if goldIconPath then
    local ok, img = pcall(love.graphics.newImage, goldIconPath)
    if ok then self.goldIcon = img end
  end
  
  return self
end

function TopBar:draw()
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  local barHeight = (config.playfield and config.playfield.topBarHeight) or 60
  
  -- Get player state
  local playerState = PlayerState.getInstance()
  local health = playerState:getHealth()
  local maxHealth = playerState:getMaxHealth()
  local gold = playerState:getGold()
  
  -- Draw top bar background
  love.graphics.setColor(theme.colors.topbar or { 14/255, 16/255, 20/255, 1 })
  love.graphics.rectangle("fill", 0, 0, vw, barHeight)
  
  -- Draw health section (left side)
  local iconSize = 32
  local iconSpacing = 12
  local leftPadding = 24
  local topPadding = (barHeight - iconSize) * 0.5
  
  if self.healthIcon then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.healthIcon, leftPadding, topPadding, 0, iconSize / self.healthIcon:getWidth(), iconSize / self.healthIcon:getHeight())
  end
  
  -- Draw health text
  local healthText = string.format("%d / %d", math.floor(health), math.floor(maxHealth))
  love.graphics.setFont(theme.fonts.base)
  local healthTextX = leftPadding + iconSize + iconSpacing
  local healthTextY = topPadding + (iconSize - theme.fonts.base:getHeight()) * 0.5
  theme.drawTextWithOutline(healthText, healthTextX, healthTextY, 1, 1, 1, 1, 2)
  
  -- Draw gold section (right side)
  local goldText = tostring(math.floor(gold))
  local goldTextWidth = theme.fonts.base:getWidth(goldText)
  local rightPadding = 24
  
  if self.goldIcon then
    local goldIconX = vw - rightPadding - iconSize - iconSpacing - goldTextWidth
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.goldIcon, goldIconX, topPadding, 0, iconSize / self.goldIcon:getWidth(), iconSize / self.goldIcon:getHeight())
    
    -- Draw gold text
    local goldTextX = goldIconX + iconSize + iconSpacing
    local goldTextY = topPadding + (iconSize - theme.fonts.base:getHeight()) * 0.5
    theme.drawTextWithOutline(goldText, goldTextX, goldTextY, 1, 1, 1, 1, 2)
  else
    -- Fallback if icon not loaded
    local goldTextX = vw - rightPadding - goldTextWidth
    local goldTextY = topPadding + (iconSize - theme.fonts.base:getHeight()) * 0.5
    theme.drawTextWithOutline(goldText, goldTextX, goldTextY, 1, 1, 1, 1, 2)
  end
  
  love.graphics.setColor(1, 1, 1, 1)
end

return TopBar

