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
    -- Orb notification tooltip
    _orbTooltip = nil, -- Orb projectile data for tooltip
    _orbTooltipTime = 0, -- Time since tooltip appeared
    _orbTooltipFadeInDuration = 0.2, -- Fade in duration (also moves up)
    _orbTooltipHoldDuration = 0.5, -- Hold duration (stays in place)
    _orbTooltipFadeOutDuration = 0.2, -- Fade out duration (also moves up)
    _orbTooltipMoveDistance = 80, -- Distance to move up during animation
    -- Wheel event state
    _isWheelEvent = false,
    _wheelSegments = nil,
    _wheelAngle = 0,
    _wheelAnglePerSegment = 0,
    _wheelBaseStart = -math.pi * 0.5,
    _wheelPointerAngle = -math.pi * 0.5,
    _wheelSpinning = false,
    _wheelSpinStartAngle = 0,
    _wheelSpinTargetAngle = 0,
    _wheelSpinTimer = 0,
    _wheelSpinDuration = 0,
    _wheelHasSpun = false,
    _wheelPendingResult = nil,
    _wheelResult = nil,
    _wheelResultMeta = nil,
    _wheelResultBox = nil,
    _wheelResultBoxHeight = 130,
    _wheelCenterX = 0,
    _wheelCenterY = 0,
    _wheelRadius = 0,
    _wheelStatusText = nil,
    _wheelContinueButton = nil,
    _wheelClickPulse = 0,
    _wheelHeaderFont = theme.newFont and theme.newFont(28) or theme.fonts.base,
    _wheelBodyFont = theme.newFont and theme.newFont(18, "assets/fonts/BarlowCondensed-Regular.ttf") or theme.fonts.small,
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
  
  -- Determine if this event uses the wheel UI
  self._isWheelEvent = self.event and self.event.wheelSegments and #self.event.wheelSegments > 0
  
  -- Create choice buttons (styled like reward buttons)
  self.choiceButtons = {}
  if self._isWheelEvent then
    self:_initializeWheelEvent()
    if self._isWheelEvent then
      return
    end
  end
  
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
    
    -- Check if choice requires transforming an orb and player has no orbs
    local requiresTransformOrb = choice.effects and choice.effects.transformRandomOrb == true
    local hasOrbs = false
    if requiresTransformOrb then
      local equipped = (config.player and config.player.equippedProjectiles) or {}
      hasOrbs = (#equipped > 0)
    end
    
    -- Determine if button should be disabled
    local isDisabled = (requiresGold and not hasEnoughGold) or (requiresRelic and not canGetRelic) or (requiresTransformOrb and not hasOrbs)
    
    -- Modify button text if disabled
    local buttonText = choice.text
    if isDisabled then
      if requiresGold and not hasEnoughGold then
        buttonText = buttonText .. " (Requires " .. goldRequired .. " Gold)"
      elseif requiresRelic and not canGetRelic then
        buttonText = buttonText .. " (No relics available)"
      elseif requiresTransformOrb and not hasOrbs then
        buttonText = buttonText .. " (No orbs equipped)"
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
  local metadata = {}
  
  if effects.hp then
    local currentHP = playerState:getHealth()
    local maxHP = playerState:getMaxHealth()
    local newHP = math.max(0, math.min(currentHP + effects.hp, maxHP))
    playerState:setHealth(newHP)
    metadata.hpDelta = (metadata.hpDelta or 0) + (newHP - currentHP)
  end
  
  -- Percentage-based HP damage/healing
  if effects.hpPercent then
    local maxHP = playerState:getMaxHealth()
    local hpChange = math.floor(maxHP * (effects.hpPercent / 100))
    local currentHP = playerState:getHealth()
    local newHP = math.max(0, math.min(currentHP + hpChange, playerState:getMaxHealth()))
    playerState:setHealth(newHP)
    metadata.hpDelta = (metadata.hpDelta or 0) + (newHP - currentHP)
  end
  
  -- Increase max HP
  if effects.maxHp then
    local currentMaxHP = playerState:getMaxHealth()
    local newMaxHP = currentMaxHP + effects.maxHp
    playerState:setMaxHealth(newMaxHP)
    local currentHP = playerState:getHealth()
    local newHP = math.min(newMaxHP, currentHP + effects.maxHp)
    playerState:setHealth(newHP)
    metadata.maxHpDelta = effects.maxHp
    metadata.hpDelta = (metadata.hpDelta or 0) + (newHP - currentHP)
  end
  
  if effects.healFull then
    local currentHP = playerState:getHealth()
    local maxHP = playerState:getMaxHealth()
    playerState:setHealth(maxHP)
    metadata.healToFull = true
    metadata.healedAmount = math.max(0, maxHP - currentHP)
    metadata.hpDelta = (metadata.hpDelta or 0) + (maxHP - currentHP)
  end
  
  if effects.gold then
    playerState:addGold(effects.gold)
    metadata.goldDelta = (metadata.goldDelta or 0) + effects.gold
  end
  
  -- Grant relic
  if effects.relic == true then
    local relicDef = pickRelicReward()
    if relicDef then
      playerState:addRelic(relicDef.id)
      metadata.grantedRelic = relicDef
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
  
  -- Transform random orb
  if effects.transformRandomOrb == true then
    local equipped = (config.player and config.player.equippedProjectiles) or {}
    if #equipped > 0 then
      local newOrbId = ProjectileManager.transformRandomOrb()
      if newOrbId then
        metadata.transformedOrbId = newOrbId
        -- Get projectile data for tooltip
        local projectileData = ProjectileManager.getProjectile(newOrbId)
        if projectileData then
          -- Show orb notification tooltip
          self._orbTooltip = projectileData
          self._orbTooltipTime = 0
        end
      end
    end
  end
  
  if effects.removeRandomOrb then
    local equipped = (config.player and config.player.equippedProjectiles) or {}
    if equipped and #equipped > 0 then
      local index = love.math.random(#equipped)
      local removedId = equipped[index]
      local removedData = ProjectileManager.getProjectile(removedId)
      ProjectileManager.removeFromEquipped(removedId)
      metadata.removedOrbId = removedId
      metadata.removedOrbName = removedData and removedData.name or removedId
    else
      metadata.removeFailed = true
    end
  end
  
  -- Set next encounter enemies to 1 HP
  if effects.nextEncounterEnemies1HP == true then
    playerState:setNextEncounterEnemies1HP(true)
  end
  
  return metadata
end

function EventScene:_initializeWheelEvent()
  self._wheelSegments = {}
  local segments = (self.event and self.event.wheelSegments) or {}
  if #segments == 0 then
    self._isWheelEvent = false
    return
  end
  
  local tau = math.pi * 2
  self._wheelAngle = love.math.random() * tau
  self._wheelSpinTimer = 0
  self._wheelSpinDuration = 0
  self._wheelAnglePerSegment = (math.pi * 2) / #segments
  self._wheelBaseStart = -math.pi * 0.5 - self._wheelAnglePerSegment * 0.5
  self._wheelPointerAngle = -math.pi * 0.5
  self._wheelHasSpun = false
  self._wheelSpinning = false
  self._wheelPendingResult = nil
  self._wheelResult = nil
  self._wheelResultMeta = nil
  self._wheelStatusText = "Select the button to spin."
  
  for _, def in ipairs(segments) do
    local seg = {
      id = def.id or ("segment_" .. tostring(#self._wheelSegments + 1)),
      label = def.label or "Mystery",
      description = def.description or "",
      effects = def.effects or {},
      color = def.color or { 0.6, 0.6, 0.6, 1.0 },
      iconImage = nil,
    }
    if def.icon then
      local ok, img = pcall(love.graphics.newImage, def.icon)
      if ok then
        seg.iconImage = img
      end
    end
    table.insert(self._wheelSegments, seg)
  end
  
  -- Replace default choices with a single button (spin/continue)
  local continueButton = Button.new({
    label = "Spin the wheel",
    font = self.textFont,
    bgColor = { 0, 0, 0, 0.7 },
    align = "left",
    onClick = function()
      if self._choiceMade then return end
      if self._wheelSpinning then return end
      if not self._wheelResult then
        if not self._wheelHasSpun then
          self:_startWheelSpin()
        end
        return
      end
      self._choiceMade = true
      self._exitRequested = true
    end,
  })
  continueButton._scale = 1.0
  continueButton._disabled = false
  table.insert(self.choiceButtons, continueButton)
  self._wheelContinueButton = continueButton
end

function EventScene:_updateWheelLayout(leftPanelWidth, contentY, contentHeight)
  if not self._isWheelEvent then return end
  local centerX = leftPanelWidth * 0.5 + 50
  local centerY = contentY + contentHeight * 0.5
  local radius = math.min(leftPanelWidth * 0.45, contentHeight * 0.45)
  self._wheelCenterX = centerX
  self._wheelCenterY = centerY
  self._wheelRadius = radius
end

function EventScene:_ensureWheelLayout()
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  local topBarHeight = (config.playfield and config.playfield.topBarHeight) or 60
  local leftPanelWidth = vw * 0.35
  local contentY = topBarHeight
  local contentHeight = vh - topBarHeight
  self:_updateWheelLayout(leftPanelWidth, contentY, contentHeight)
end

function EventScene:_updateWheel(dt)
  self._wheelClickPulse = (self._wheelClickPulse or 0) + dt
  if not self._wheelSpinning then
    return
  end
  local duration = (self._wheelSpinDuration and self._wheelSpinDuration > 0) and self._wheelSpinDuration or 1
  self._wheelSpinTimer = self._wheelSpinTimer + dt
  local progress = math.min(1, self._wheelSpinTimer / duration)
  local eased = 1 - math.pow(1 - progress, 3)
  self._wheelAngle = self._wheelSpinStartAngle + (self._wheelSpinTargetAngle - self._wheelSpinStartAngle) * eased
  if progress >= 1 then
    self._wheelSpinning = false
    local tau = math.pi * 2
    self._wheelAngle = (self._wheelAngle % tau + tau) % tau
    self:_completeWheelSpin()
  end
end

function EventScene:_startWheelSpin()
  if not self._isWheelEvent then return end
  if self._wheelSpinning or self._wheelHasSpun then return end
  if not self._wheelSegments or #self._wheelSegments == 0 then return end
  
  self._wheelSpinning = true
  self._wheelHasSpun = true
  self._wheelSpinTimer = 0
  self._wheelSpinDuration = 4 + love.math.random() * 0.8
  self._wheelSpinStartAngle = self._wheelAngle
  
  local targetIndex = love.math.random(#self._wheelSegments)
  self._wheelPendingResult = self._wheelSegments[targetIndex]
  
  local tau = math.pi * 2
  local rotations = 3 + love.math.random(0, 2)
  local afterSpins = self._wheelSpinStartAngle + rotations * tau
  local baseAlignment = self._wheelPointerAngle - (self._wheelBaseStart + (targetIndex - 0.5) * self._wheelAnglePerSegment)
  local delta = (baseAlignment - afterSpins) % tau
  self._wheelSpinTargetAngle = afterSpins + delta
  
  self._wheelStatusText = "Spinning..."
  if self._wheelContinueButton then
    self._wheelContinueButton.label = "Spinning..."
    self._wheelContinueButton._disabled = true
  end
end

function EventScene:_completeWheelSpin()
  local result = self._wheelPendingResult or self:_determineWheelResultFromAngle()
  self._wheelPendingResult = nil
  if not result then
    self._wheelStatusText = "The wheel jammed. Try again."
    self._wheelHasSpun = false
    return
  end
  
  self._wheelResult = result
  self._wheelStatusText = "The masks have chosen."
  local effects = result.effects or {}
  local metadata = {}
  
  if effects.gold and effects.gold > 0 then
    local ps = PlayerState.getInstance()
    self._goldDisplayStart = ps:getGold()
    self._goldAmount = effects.gold
    self._goldDisplayTarget = self._goldDisplayStart + self._goldAmount
    self._goldAnimationStarted = true
    if self.topBar then
      self.topBar.overrideGold = self._goldDisplayStart
    end
    local otherEffects = {}
    for k, v in pairs(effects) do
      if k ~= "gold" then
        otherEffects[k] = v
      end
    end
    if next(otherEffects) then
      metadata = self:_applyChoiceEffects(otherEffects) or {}
    end
  else
    metadata = self:_applyChoiceEffects(effects) or {}
  end
  
  self._wheelResultMeta = metadata
  if self._wheelContinueButton then
    self._wheelContinueButton.label = "Continue"
    self._wheelContinueButton._disabled = false
  end
end

function EventScene:_determineWheelResultFromAngle()
  if not self._wheelSegments or #self._wheelSegments == 0 then
    return nil
  end
  local tau = math.pi * 2
  local relative = (self._wheelPointerAngle - (self._wheelBaseStart + self._wheelAngle)) % tau
  local index = math.floor(relative / self._wheelAnglePerSegment) + 1
  index = math.max(1, math.min(#self._wheelSegments, index))
  return self._wheelSegments[index]
end

function EventScene:_isPointInsideWheel(x, y)
  if not self._wheelRadius or self._wheelRadius <= 0 then
    self:_ensureWheelLayout()
  end
  if not self._wheelRadius or self._wheelRadius <= 0 then
    return false
  end
  local dx = x - (self._wheelCenterX or 0)
  local dy = y - (self._wheelCenterY or 0)
  return (dx * dx + dy * dy) <= (self._wheelRadius * self._wheelRadius)
end

function EventScene:_drawWheel(contentY, contentHeight, leftPanelWidth, fadeAlpha)
  if not self._isWheelEvent then return end
  self:_updateWheelLayout(leftPanelWidth, contentY, contentHeight)
  if not self._wheelRadius or self._wheelRadius <= 0 then return end
  
  local cx = self._wheelCenterX
  local cy = self._wheelCenterY
  local radius = self._wheelRadius
  local tau = math.pi * 2
  local drawAngle = (self._wheelAngle % tau + tau) % tau
  local anglePer = self._wheelAnglePerSegment
  local baseStart = self._wheelBaseStart + drawAngle
  
  -- Backing plate
  love.graphics.setColor(0.05, 0.05, 0.08, 0.95 * fadeAlpha)
  love.graphics.circle("fill", cx, cy, radius + 42)
  
  if self._wheelSegments then
    for i, segment in ipairs(self._wheelSegments) do
      local startAngle = baseStart + (i - 1) * anglePer
      local endAngle = startAngle + anglePer
      local color = segment.color or { 0.6, 0.6, 0.6, 1.0 }
      local alpha = fadeAlpha
      if self._wheelResult == segment and not self._wheelSpinning then
        alpha = alpha * 1.2
      end
      love.graphics.setColor(color[1] or 1, color[2] or 1, color[3] or 1, (color[4] or 1) * alpha)
      love.graphics.arc("fill", cx, cy, radius, startAngle, endAngle, 40)
      love.graphics.setColor(0, 0, 0, 0.3 * fadeAlpha)
      love.graphics.arc("line", cx, cy, radius, startAngle, endAngle, 40)
      
      if segment.iconImage then
        local midAngle = (startAngle + endAngle) * 0.5
        local iconDistance = radius * 0.58
        local iconX = cx + math.cos(midAngle) * iconDistance
        local iconY = cy + math.sin(midAngle) * iconDistance
        local imgW, imgH = segment.iconImage:getWidth(), segment.iconImage:getHeight()
        local targetSize = radius * 0.28
        local scale = targetSize / math.max(imgW, imgH)
        love.graphics.setColor(1, 1, 1, fadeAlpha)
        love.graphics.draw(segment.iconImage, iconX - (imgW * scale * 0.5), iconY - (imgH * scale * 0.5), 0, scale, scale)
      end
    end
  end
  
  -- Center hub
  love.graphics.setColor(0.1, 0.1, 0.16, fadeAlpha)
  love.graphics.circle("fill", cx, cy, radius * 0.28)
  love.graphics.setColor(1, 1, 1, 0.25 * fadeAlpha)
  love.graphics.circle("line", cx, cy, radius)
  
  -- Pointer
  local pointerWidth = 30
  local pointerHeight = 38
  local pointerY = cy - radius - 6
  love.graphics.setColor(1, 1, 1, fadeAlpha)
  love.graphics.polygon("fill",
    cx, pointerY - pointerHeight,
    cx - pointerWidth * 0.5, pointerY,
    cx + pointerWidth * 0.5, pointerY
  )
  love.graphics.setColor(0, 0, 0, 0.4 * fadeAlpha)
  love.graphics.polygon("line",
    cx, pointerY - pointerHeight,
    cx - pointerWidth * 0.5, pointerY,
    cx + pointerWidth * 0.5, pointerY
  )
  
  -- Instruction text
  local instruction = self._wheelStatusText or (self._wheelSpinning and "Spinning..." or "Click to spin")
  love.graphics.setFont(self.textFont)
  local pulse = 0.6 + 0.4 * math.sin((self._wheelClickPulse or 0) * 3.0)
  love.graphics.setColor(1, 1, 1, fadeAlpha * pulse)
  love.graphics.printf(instruction, cx - radius, cy + radius + 20, radius * 2, "center")
end

function EventScene:_drawWheelResultBox(fadeAlpha)
  if not self._wheelResultBox then return end
  local box = self._wheelResultBox
  love.graphics.setColor(0, 0, 0, 0.55 * fadeAlpha)
  love.graphics.rectangle("fill", box.x, box.y, box.w, box.h, 18, 18)
  love.graphics.setColor(1, 1, 1, 0.08 * fadeAlpha)
  love.graphics.rectangle("line", box.x, box.y, box.w, box.h, 18, 18)
  
  local inset = 20
  local iconSize = 72
  local iconX = box.x + inset + iconSize * 0.5
  local iconY = box.y + box.h * 0.5
  
  local header
  local bodyLines = {}
  
  if self._wheelSpinning then
    header = "Wheel spinning..."
    table.insert(bodyLines, "Hold steady while the masks decide your fate.")
  elseif self._wheelResult then
    header = self._wheelResult.label or "Outcome"
    if self._wheelResult.description and self._wheelResult.description ~= "" then
      table.insert(bodyLines, self._wheelResult.description)
    end
    local effects = self._wheelResult.effects or {}
    -- No extra stat line; rely on description for details
    if self._wheelResultMeta then
      if self._wheelResultMeta.removedOrbName then
        table.insert(bodyLines, "Lost orb: " .. self._wheelResultMeta.removedOrbName)
      elseif self._wheelResultMeta.removeFailed then
        table.insert(bodyLines, "No orb was removed.")
      end
      if self._wheelResultMeta.healedAmount and self._wheelResultMeta.healedAmount > 0 then
        table.insert(bodyLines, "Recovered " .. self._wheelResultMeta.healedAmount .. " HP.")
      end
      if self._wheelResultMeta.grantedRelic and self._wheelResultMeta.grantedRelic.name then
        table.insert(bodyLines, "Gained relic: " .. self._wheelResultMeta.grantedRelic.name)
      end
    end
  else
    header = "Awaiting spin"
    local labels = {}
    for _, seg in ipairs(self._wheelSegments or {}) do
      table.insert(labels, seg.label)
    end
    table.insert(bodyLines, "Possible results: " .. table.concat(labels, " • "))
  end
  
  local iconImage = (self._wheelResult and self._wheelResult.iconImage) or nil
  if iconImage then
    local imgW, imgH = iconImage:getWidth(), iconImage:getHeight()
    local scale = iconSize / math.max(imgW, imgH)
    love.graphics.setColor(1, 1, 1, fadeAlpha)
    love.graphics.draw(iconImage, iconX - (imgW * scale * 0.5), iconY - (imgH * scale * 0.5), 0, scale, scale)
  else
    local questionFont = self.titleFont or theme.fonts.base
    love.graphics.setColor(1, 1, 1, 0.15 * fadeAlpha)
    love.graphics.circle("fill", iconX, iconY, iconSize * 0.4)
    love.graphics.setColor(1, 1, 1, fadeAlpha)
    love.graphics.setFont(questionFont)
    love.graphics.printf("?", iconX - iconSize * 0.4, iconY - (questionFont:getHeight() * 0.5), iconSize * 0.8, "center")
  end
  
  local headerFont = self._wheelHeaderFont or theme.fonts.base or self.titleFont or theme.fonts.base
  local bodyFont = self._wheelBodyFont or theme.fonts.small or self.textFont or theme.fonts.base
  love.graphics.setFont(headerFont)
  love.graphics.setColor(1, 1, 1, fadeAlpha)
  local textStartX = box.x + inset + iconSize + 16
  local headerHeight = headerFont:getHeight()
  
  love.graphics.setFont(bodyFont)
  local bodyText = table.concat(bodyLines, "\n")
  local textWidth = box.w - (textStartX - box.x) - inset
  local _, wrappedLines = bodyFont:getWrap(bodyText, textWidth)
  local bodyHeight = #wrappedLines * bodyFont:getHeight()
  local totalHeight = headerHeight + 8 + bodyHeight
  local textTop = box.y + (box.h - totalHeight) * 0.5
  
  love.graphics.setFont(headerFont)
  love.graphics.printf(header, textStartX, textTop, textWidth, "left")
  
  love.graphics.setFont(bodyFont)
  love.graphics.setColor(0.9, 0.9, 0.9, fadeAlpha)
  local bodyY = textTop + headerHeight + 8
  love.graphics.printf(bodyText, textStartX, bodyY, textWidth, "left")
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
  
  if self._isWheelEvent then
    self:_updateWheel(dt)
  end
  
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
  
  -- Update orb tooltip animation
  if self._orbTooltip then
    self._orbTooltipTime = self._orbTooltipTime + dt
    -- Calculate total duration
    local totalDuration = self._orbTooltipFadeInDuration + self._orbTooltipHoldDuration + self._orbTooltipFadeOutDuration
    -- Remove tooltip after animation completes
    if self._orbTooltipTime >= totalDuration then
      self._orbTooltip = nil
      self._orbTooltipTime = 0
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
  local contentY = topBarHeight
  local contentHeight = vh - topBarHeight
  local buttonWidth = (rightPanelWidth - padding) * 0.9
  local buttonHeight = 50
  local buttonSpacing = 15
  
  if self._isWheelEvent then
    self:_updateWheelLayout(leftPanelWidth, contentY, contentHeight)
  end
  
  -- Calculate starting Y position for buttons
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
  
  if self._isWheelEvent then
    local boxWidth = (rightPanelWidth - padding) * 0.9
    local boxHeight = self._wheelResultBoxHeight or 160
    self._wheelResultBox = {
      x = rightPanelX,
      y = currentY,
      w = boxWidth,
      h = boxHeight,
    }
    currentY = currentY + boxHeight + 40
  else
    self._wheelResultBox = nil
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
      -- Exit after counting animation unless this is a wheel event (wheel events wait for user input)
      if not self._isWheelEvent then
      self._exitRequested = true
      end
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
  
  if self._wheelContinueButton then
    if self._wheelSpinning then
      self._wheelContinueButton.label = "Spinning..."
      self._wheelContinueButton._disabled = true
    elseif self._wheelResult then
      self._wheelContinueButton.label = "Continue"
      self._wheelContinueButton._disabled = self._choiceMade
    else
      self._wheelContinueButton.label = "Spin the wheel"
      self._wheelContinueButton._disabled = self._choiceMade
    end
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
    -- If orb tooltip is showing, wait for it to complete
    if self._orbTooltip then
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
  
  -- Draw left panel (event image or wheel)
  love.graphics.setColor(1, 1, 1, fadeAlpha)
  if self._isWheelEvent then
    self:_drawWheel(contentY, contentHeight, leftPanelWidth, fadeAlpha)
  elseif self.eventImage then
    local imgW, imgH = self.eventImage:getDimensions()
    local scale = contentHeight / imgH
    local imgX = 0
    local imgY = contentY
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
  
  if self._isWheelEvent then
    self:_drawWheelResultBox(fadeAlpha)
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
  
  -- Draw orb notification tooltip (on top of everything)
  self:_drawOrbTooltip(fadeAlpha)
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
    { pattern = "Next encounter enemies spawn with 1 HP%.", color = { 195/255, 235/255, 139/255 } },  -- green for 1 HP next encounter
    { pattern = "Transform a random Orb into another Orb%.", color = { 195/255, 235/255, 139/255 } },  -- green (#C3EB8B) for orb transformation
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
  
  if self._isWheelEvent and not self._wheelSpinning and not self._wheelHasSpun and not self._choiceMade then
    self:_ensureWheelLayout()
    if self:_isPointInsideWheel(x, y) then
      self:_startWheelSpin()
      return nil
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

function EventScene:_drawOrbTooltip(fadeAlpha)
  if not self._orbTooltip then return end
  
  local orbDef = self._orbTooltip
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
  if orbDef.icon then
    local ok, img = pcall(love.graphics.newImage, orbDef.icon)
    if ok then iconImg = img end
  end
  
  -- Build tooltip text (name + description)
  local tooltipText = ""
  if orbDef.name then
    tooltipText = tooltipText .. orbDef.name
  end
  if orbDef.description then
    if tooltipText ~= "" then
      tooltipText = tooltipText .. "\n" .. orbDef.description
    else
      tooltipText = orbDef.description
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
  
  -- Calculate position (top right, offset below relic tooltip if both are showing)
  local topBarHeight = (config.playfield and config.playfield.topBarHeight) or 60
  local startY = topBarHeight + 20 -- Below top bar
  
  -- Offset down if relic tooltip is also showing
  if self._relicTooltip then
    startY = startY + 100 -- Add offset for relic tooltip
  end
  
  -- Calculate total duration and phases
  local totalDuration = self._orbTooltipFadeInDuration + self._orbTooltipHoldDuration + self._orbTooltipFadeOutDuration
  
  -- Phase 1: Fade in + move up (0.2s)
  local fadeInProgress = 1.0
  local moveProgress = 0.0
  if self._orbTooltipTime < self._orbTooltipFadeInDuration then
    local phaseT = self._orbTooltipTime / self._orbTooltipFadeInDuration
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
  local holdStart = self._orbTooltipFadeInDuration
  local holdEnd = holdStart + self._orbTooltipHoldDuration
  if self._orbTooltipTime >= holdStart and self._orbTooltipTime <= holdEnd then
    moveProgress = 0.5
  end
  
  -- Phase 3: Fade out + move up more (0.2s)
  local fadeOutStart = self._orbTooltipFadeInDuration + self._orbTooltipHoldDuration
  local fadeOutProgress = 1.0
  if self._orbTooltipTime > fadeOutStart then
    local phaseT = (self._orbTooltipTime - fadeOutStart) / self._orbTooltipFadeOutDuration
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
  local tooltipY = startY - (moveProgress * self._orbTooltipMoveDistance)
  
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

