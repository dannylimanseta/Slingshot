local theme = require("theme")
local config = require("config")
local PlayerState = require("core.PlayerState")
local BattleState = require("core.BattleState")

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
  
  -- Load orbs icon
  local orbsIconPath = "assets/images/icon_orbs.png"
  local ok, img = pcall(love.graphics.newImage, orbsIconPath)
  if ok then self.orbsIcon = img end
  
  -- Load inventory icon (try both possible names)
  local inventoryIconPath = "assets/images/icon_backpack.png"
  local okInv, imgInv = pcall(love.graphics.newImage, inventoryIconPath)
  if not okInv or not imgInv then
    -- Fallback to icon_inventory.png
    inventoryIconPath = "assets/images/icon_inventory.png"
    okInv, imgInv = pcall(love.graphics.newImage, inventoryIconPath)
  end
  if okInv and imgInv then
    self.inventoryIcon = imgInv
  end
  
  -- Step fade state
  self._stepAlpha = {}
  self._lastTime = (love.timer and love.timer.getTime()) or 0
  return self
end

function TopBar:draw()
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  local barHeight = (config.playfield and config.playfield.topBarHeight) or 60
  
  -- Get player state
  local playerState = PlayerState.getInstance()
  local battleState = BattleState.get and BattleState.get()
  local health
  local maxHealth
  if battleState and battleState.player then
    health = battleState.player.hp or battleState.player.displayHP or 0
    maxHealth = battleState.player.maxHP or health
  else
    health = playerState:getHealth()
    maxHealth = playerState:getMaxHealth()
  end
  local gold = (self.overrideGold ~= nil) and self.overrideGold or playerState:getGold()
  
  -- Draw top bar background (darkened, 0.8 alpha)
  do
    local c = theme.colors.topbar or { 14/255, 16/255, 20/255, 1 }
    local r = (c[1] or 0.055) * 0.7
    local g = (c[2] or 0.063) * 0.7
    local b = (c[3] or 0.078) * 0.7
    love.graphics.setColor(r, g, b, 0.8)
  end
  love.graphics.rectangle("fill", 0, 0, vw, barHeight)
  -- Bottom divider line
  do
    local c = theme.colors.topbarDivider or {0, 0, 0, 1}
    love.graphics.setColor(c[1] or 0, c[2] or 0, c[3] or 0, 0.8)
  end
  love.graphics.rectangle("fill", 0, barHeight, vw, 2)
  
  -- Draw health section (left side)
  local iconSize = 24
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
  
  -- Draw gold section (to the right of health)
  local goldText = tostring(math.floor(gold))
  local goldTextWidth = theme.fonts.base:getWidth(goldText)
  local rightPadding = 24
  local afterHealthX = healthTextX + theme.fonts.base:getWidth(healthText) + 40 -- space between health and gold cluster
  local goldEndX
  if self.goldIcon then
    local goldIconX = afterHealthX
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.goldIcon, goldIconX, topPadding, 0, iconSize / self.goldIcon:getWidth(), iconSize / self.goldIcon:getHeight())
    local goldTextX = goldIconX + iconSize + iconSpacing
    local goldTextY = topPadding + (iconSize - theme.fonts.base:getHeight()) * 0.5
    theme.drawTextWithOutline(goldText, goldTextX, goldTextY, 1, 1, 1, 1, 2)
    goldEndX = goldTextX + goldTextWidth
  else
    local goldTextX = afterHealthX
    local goldTextY = topPadding + (iconSize - theme.fonts.base:getHeight()) * 0.5
    theme.drawTextWithOutline(goldText, goldTextX, goldTextY, 1, 1, 1, 1, 2)
    goldEndX = goldTextX + goldTextWidth
  end

  -- Draw Day + Steps centered across the full top bar
  self:_drawDayAndSteps(0, vw, topPadding, iconSize)
  
  -- Draw inventory icon (to the left of orbs icon)
  if self.inventoryIcon then
    local iconPadding = 24
    local iconSpacing = 32 -- Increased spacing between inventory and orbs icons
    -- Calculate position: orbs icon is at vw - iconPadding - iconSize
    -- Inventory icon is to the left of orbs icon
    local orbsIconX = vw - iconPadding - iconSize
    local inventoryIconX = orbsIconX - iconSize - iconSpacing
    local inventoryIconY = topPadding
    
    -- Grey out when disabled (similar to orbs icon logic)
    if self.disableInventoryIcon then
      love.graphics.setColor(1, 1, 1, 0.35)
      love.graphics.draw(self.inventoryIcon, inventoryIconX, inventoryIconY, 0, iconSize / self.inventoryIcon:getWidth(), iconSize / self.inventoryIcon:getHeight())
      -- Do not expose clickable bounds when disabled
      self.inventoryIconBounds = nil
    else
      -- Ensure we have valid coordinates
      if inventoryIconX and inventoryIconY then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.inventoryIcon, inventoryIconX, inventoryIconY, 0, iconSize / self.inventoryIcon:getWidth(), iconSize / self.inventoryIcon:getHeight())
        -- Store clickable bounds for MapScene
        self.inventoryIconBounds = {
          x = inventoryIconX,
          y = inventoryIconY,
          w = iconSize,
          h = iconSize
        }
      else
        self.inventoryIconBounds = nil
      end
    end
  else
    self.inventoryIconBounds = nil
  end
  
  -- Draw orbs icon on the right side
  if self.orbsIcon then
    local orbsIconPadding = 24
    local orbsIconX = vw - orbsIconPadding - iconSize
    local orbsIconY = topPadding
    -- Grey out when disabled
    if self.disableOrbsIcon then
      love.graphics.setColor(1, 1, 1, 0.35)
      love.graphics.draw(self.orbsIcon, orbsIconX, orbsIconY, 0, iconSize / self.orbsIcon:getWidth(), iconSize / self.orbsIcon:getHeight())
      -- Do not expose clickable bounds when disabled
      self.orbsIconBounds = nil
    else
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(self.orbsIcon, orbsIconX, orbsIconY, 0, iconSize / self.orbsIcon:getWidth(), iconSize / self.orbsIcon:getHeight())
      -- Store clickable bounds for MapScene
      self.orbsIconBounds = {
        x = orbsIconX,
        y = orbsIconY,
        w = iconSize,
        h = iconSize
      }
    end
  else
    self.orbsIconBounds = nil
  end
  
  love.graphics.setColor(1, 1, 1, 1)
end

-- Internal: Draw "DAY X / N" and step squares within horizontal bounds [leftBound, rightBound]
function TopBar:_drawDayAndSteps(leftBound, rightBound, topPadding, iconSize)
  if not self.daySystem then return end
  
  local currentDay = self.daySystem:getCurrentDay()
  local totalDays = (self.daySystem.getTotalDays and self.daySystem:getTotalDays()) or currentDay
  local movesRemaining = self.daySystem:getMovesRemaining()
  local maxMoves = self.daySystem:getMaxMoves()
  
  local text = string.format("DAY %d / %d", currentDay, totalDays)
  love.graphics.setFont(theme.fonts.base)
  local textWidth = theme.fonts.base:getWidth(text)
  local textHeight = theme.fonts.base:getHeight()
  local baselineY = topPadding + (iconSize - textHeight) * 0.5
  
  -- Compute layout
  local containerLeft = leftBound
  local containerRight = rightBound
  local availableWidth = math.max(0, containerRight - containerLeft)
  
  -- Spacing and proportions
  local gap = 16 -- gap between text and steps
  local desiredSize = 22 -- nominal step height
  local minSize = 10
  local spacing = 4 -- tighter spacing between steps
  local widthScale = 0.6 -- reduce width by 40% (rectangles)
  local totalSteps = maxMoves
  
  -- Total width for a given step size
  local function stepsWidth(size)
    if totalSteps <= 0 then return 0 end
    local w = math.floor(size * widthScale + 0.5)
    return totalSteps * w + (totalSteps - 1) * spacing
  end
  local function contentWidth(size)
    return textWidth + gap + stepsWidth(size)
  end
  
  -- Fit within available space
  local stepSize = desiredSize
  while contentWidth(stepSize) > availableWidth and stepSize > minSize do
    stepSize = stepSize - 1
  end
  
  local totalContentW = contentWidth(stepSize)
  local x = containerLeft + math.max(0, (availableWidth - totalContentW) * 0.5)
  x = math.floor(x + 0.5)
  
  -- Draw text (avoid table.unpack for LuaJIT compatibility)
  local c = theme.colors.uiTextStrong or {1,1,1,1}
  theme.drawTextWithOutline(text, x, baselineY, c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1, 2)
  x = x + textWidth + gap
  
  -- Draw steps
  local filledColor = theme.colors.stepFilled
  local emptyColor = theme.colors.stepEmpty
  local rectW = math.floor(stepSize * widthScale + 0.5)
  local rectH = stepSize
  local corner = (theme.metrics and theme.metrics.stepCornerRadius) or 3

  -- Update fade alphas toward target based on movesRemaining
  do
    local now = (love.timer and love.timer.getTime()) or 0
    local dt = math.max(0, math.min(0.1, now - (self._lastTime or now))) -- clamp dt
    self._lastTime = now
    local speed = 12 -- higher = snappier fade
    for i = 1, totalSteps do
      local target = (i <= movesRemaining) and 1 or 0
      local a = self._stepAlpha[i]
      if a == nil then a = target end -- initialize to current state without popping
      a = a + (target - a) * math.min(1, speed * dt)
      -- Snap near edges
      if a > 0.999 then a = 1 end
      if a < 0.001 then a = 0 end
      self._stepAlpha[i] = a
    end
    -- Trim any extra alphas if max decreased
    for i = totalSteps + 1, #self._stepAlpha do
      self._stepAlpha[i] = nil
    end
  end
  for i = 1, totalSteps do
    local rectY = math.floor(topPadding + (iconSize - rectH) * 0.5 + 0.5)
    -- Base empty rectangle
    love.graphics.setColor(emptyColor)
    love.graphics.rectangle("fill", x, rectY, rectW, rectH, corner, corner)
    -- Overlay filled rectangle with fade alpha
    local a = self._stepAlpha[i] or 0
    if a > 0 then
      love.graphics.setColor(filledColor[1], filledColor[2], filledColor[3], a)
      love.graphics.rectangle("fill", x, rectY, rectW, rectH, corner, corner)
    end
    x = x + rectW + spacing
  end
  love.graphics.setColor(1, 1, 1, 1)
end

return TopBar

