local theme = require("theme")
local config = require("config")
local ProjectileManager = require("managers.ProjectileManager")

local Shooter = {}
Shooter.__index = Shooter

function Shooter.new(x, y, projectileId)
  local r = config.shooter.radius
  local ballSpacing = r * 0.6
  local ballSize = r * 0.7
  local currentBallSize = ballSize * 1.2 -- Current ball is 20% larger
  local rightShift = currentBallSize * 0.5 -- Shift right by half the current ball's radius
  
  local self = setmetatable({ 
    x = x, 
    y = y,
    projectileId = projectileId or "strike", -- Default projectile (for backward compatibility)
    turnManager = nil, -- Reference to TurnManager for turn-based display
    ballSlotsImage = nil, -- Cached ball_slots.png image
    arrowImage = nil, -- Cached arrow_1.png image
    -- Dynamic projectile slots system
    projectileSlots = {}, -- Array of all available projectiles with cached images
    numProjectiles = 0, -- Total number of projectiles
    -- Infinite carousel system
    carousel = {
      offset = 0, -- Current scroll position (continuous float)
      targetOffset = 0, -- Target scroll position (tweened toward)
    },
    -- Slot rendering cache (dynamically sized based on what's visible)
    slotRenderCache = {}, -- { [slotIndex] = {x, size, alpha, depthAlpha, projectileIndex} }
    arrowOffsetX = 0, -- Relative offset from shooter center (tweened)
    lastTurnNumber = 1, -- Track turn number to detect changes
    bobTime = 0, -- Time tracker for bobbing animation
    alpha = 1.0, -- Alpha for fade in/out based on turn phase
    targetAlpha = 1.0, -- Target alpha to tween toward
  }, Shooter)
  
  -- Load all projectiles dynamically
  self:loadProjectiles()
  
  -- Load UI images
  self:loadUIImages()
  
  return self
end

-- Load projectiles from player's equipped inventory
function Shooter:loadProjectiles()
  self.projectileSlots = {}
  self.numProjectiles = 0
  
  -- Get equipped projectiles from player loadout (config)
  local equippedIds = (config.player and config.player.equippedProjectiles) or { "strike" }
  
  for _, projectileId in ipairs(equippedIds) do
    -- Get projectile data from master database
    local projectile = ProjectileManager.getProjectile(projectileId)
    
    if projectile and projectile.id then
      local slot = {
        id = projectile.id,
        icon = projectile.icon,
        image = nil, -- Will be loaded lazily
      }
      
      -- Load image if icon path is provided
      if slot.icon then
        local ok, img = pcall(love.graphics.newImage, slot.icon)
    if ok then
          slot.image = img
        end
      end
      
      table.insert(self.projectileSlots, slot)
      self.numProjectiles = self.numProjectiles + 1
    end
  end
  
  -- Ensure we have at least 1 projectile
  if self.numProjectiles == 0 then
    -- Fallback: add default projectile
    local defaultSlot = {
      id = "strike",
      icon = "assets/images/orb_strike.png",
      image = nil,
    }
    local ok, img = pcall(love.graphics.newImage, defaultSlot.icon)
    if ok then defaultSlot.image = img end
    table.insert(self.projectileSlots, defaultSlot)
    self.numProjectiles = 1
  end
  
  -- Calculate dynamic carousel parameters based on number of projectiles
  self:calculateCarouselParameters()
end

-- Dynamically calculate carousel fade distances based on projectile count
function Shooter:calculateCarouselParameters()
  local carouselCfg = config.shooter.carousel
  
  -- Max visible slots = number of projectiles (show all without repetition)
  self.maxVisibleSlots = self.numProjectiles
  
  -- Calculate fade distances dynamically
  -- Center is at 0, slots are at -2, -1, 0, 1, 2, etc.
  -- For N slots: visible range is roughly from -(N-1)/2 to +(N-1)/2
  local halfRange = (self.numProjectiles - 1) / 2
  
  -- Fade starts just beyond the last visible slot
  self.fadeStart = halfRange + (carouselCfg.fadeStartOffset or 0.4)
  
  -- Fade ends a bit further out
  self.fadeEnd = halfRange + (carouselCfg.fadeEndOffset or 0.8)
end

-- Set TurnManager reference
function Shooter:setTurnManager(turnManager)
  self.turnManager = turnManager
end

-- Load UI images (slots background and arrow)
function Shooter:loadUIImages()
  -- Load ball_slots.png
  local ballSlotsPath = "assets/images/ball_slots.png"
  local ok1, img1 = pcall(love.graphics.newImage, ballSlotsPath)
  if ok1 then self.ballSlotsImage = img1 end
  
  -- Load arrow_1.png
  local arrowPath = "assets/images/arrow_1.png"
  local ok2, img2 = pcall(love.graphics.newImage, arrowPath)
  if ok2 then self.arrowImage = img2 end
end

-- Get projectile for a slot index (wraps around infinitely)
function Shooter:getProjectileAtSlot(slotIndex)
  if self.numProjectiles == 0 then return nil end
  local index = ((slotIndex % self.numProjectiles) + self.numProjectiles) % self.numProjectiles + 1
  return self.projectileSlots[index]
end

-- Calculate edge fade alpha based on distance from center
-- Asymmetric: tighter fade-out on left (duplicates), earlier fade-in on right (incoming)
function Shooter:calculateEdgeFade(relativePosition)
  local carouselCfg = config.shooter.carousel
  local distanceFromCenter = math.abs(relativePosition)
  local halfRange = (self.maxVisibleSlots - 1) / 2
  local isRightSide = relativePosition > 0
  
  if isRightSide then
    -- Right side (incoming ball): fade IN as it approaches visible range
    -- Start fading in earlier (before it reaches halfRange)
    local fadeInStart = halfRange + (carouselCfg.fadeInStartOffset or 0.5)  -- Where fade-in begins (far)
    local fadeInEnd = halfRange - (carouselCfg.fadeInEndOffset or 0.2)      -- Where fully visible (close, within range)
    
    if relativePosition >= fadeInStart then
      return 0 -- Fully transparent (too far right)
    elseif relativePosition <= fadeInEnd then
      return 1 -- Fully visible (within visible range)
    else
      -- Fading in: 0 (transparent) -> 1 (visible) as position decreases
      local fadeProgress = (relativePosition - fadeInEnd) / (fadeInStart - fadeInEnd)
      return 1 - fadeProgress
    end
  else
    -- Left side (duplicate): aggressive fade-out to prevent showing duplicates
    local fadeStart = halfRange + (carouselCfg.fadeStartOffset or 0.3)
    local fadeEnd = halfRange + (carouselCfg.fadeEndOffset or 0.6)
    
    if distanceFromCenter < fadeStart then
      return 1 -- Fully visible
    elseif distanceFromCenter > fadeEnd then
      return 0 -- Fully transparent
    else
      -- Fading out: 1 (visible) -> 0 (transparent) as distance increases
      local fadeProgress = (distanceFromCenter - fadeStart) / (fadeEnd - fadeStart)
      return 1 - fadeProgress
    end
  end
end

-- Calculate depth fade (Option B: dim based on distance)
function Shooter:calculateDepthFade(relativePosition)
  local carouselCfg = config.shooter.carousel
  local distanceFromCenter = math.abs(relativePosition)
  -- Reduce alpha by depthFade amount per unit distance
  return math.max(0, 1 - (distanceFromCenter * carouselCfg.depthFade))
end

-- Calculate slot size based on position (center is larger)
function Shooter:calculateSlotSize(relativePosition)
  local r = config.shooter.radius
  local ballSize = r * 0.7
  -- Increase selected orb size by 10%: 1.2 * 1.2 * 1.1 = 1.584x
  local activeBallSize = ballSize * 1.2 * 1.2 * 1.1
  
  local distanceFromCenter = math.abs(relativePosition)
  
  if distanceFromCenter < 0.5 then
    -- Within half a slot of center = active size
    return activeBallSize
  else
    -- Smoothly interpolate from active to normal size
    local t = math.min(1, (distanceFromCenter - 0.5) / 0.5)
    return activeBallSize * (1 - t) + ballSize * t
  end
end

-- Calculate screen X position for a slot at relative position
function Shooter:calculateSlotScreenX(relativePosition)
  local r = config.shooter.radius
  local carouselCfg = config.shooter.carousel
  local ballSpacing = r * carouselCfg.ballSpacingMultiplier
  
  -- Position is already centered since we render from -halfRange to +halfRange
  return self.x + (relativePosition * ballSpacing)
end

-- Set the projectile ID (for backward compatibility, but doesn't affect rotation)
function Shooter:setProjectile(projectileId)
  self.projectileId = projectileId or "strike"
  -- Note: Rotation is now based on turn number, not projectileId
end

function Shooter:update(dt, bounds)
  -- Update bobbing animation time
  self.bobTime = (self.bobTime or 0) + dt
  
  -- Update alpha based on turn phase (fade out during enemy turn)
  local BattleState = require("core.BattleState")
  local state = BattleState.get()
  if state and state.turn then
    local turnPhase = state.turn.phase
    -- Check if it's enemy turn (any phase that starts with "enemy")
    local isEnemyTurn = turnPhase and (turnPhase:find("enemy") ~= nil)
    self.targetAlpha = isEnemyTurn and 0.0 or 1.0
  else
    self.targetAlpha = 1.0
  end
  
  -- Smoothly tween alpha toward target
  local fadeSpeed = 5.0 -- Speed of fade transition
  local alphaDelta = self.targetAlpha - (self.alpha or 1.0)
  self.alpha = (self.alpha or 1.0) + alphaDelta * math.min(1, fadeSpeed * dt)
  
  local speed = config.shooter.speed
  local move = 0
  if love.keyboard.isDown("a") then move = move - 1 end
  if love.keyboard.isDown("d") then move = move + 1 end
  self.x = self.x + move * speed * dt

  -- Clamp to grid bounds (if provided) or fallback to full width
  local r = config.shooter.radius
  if bounds and bounds.gridStartX and bounds.gridEndX then
    -- Use grid bounds (matching editor)
    self.x = math.max(bounds.gridStartX + r, math.min(bounds.gridEndX - r, self.x))
  else
    -- Fallback to full width bounds
    local w = (bounds and bounds.w) or love.graphics.getWidth()
    self.x = math.max(r, math.min(w - r, self.x))
  end
  
  -- Get current turn number
  local turnNumber = 1
  if self.turnManager and self.turnManager.getTurnNumber then
    turnNumber = self.turnManager:getTurnNumber()
  end
  
  -- Detect turn change and update target offset
  if turnNumber ~= self.lastTurnNumber then
    -- Advance carousel by the difference in turns
    local turnDelta = turnNumber - self.lastTurnNumber
    self.carousel.targetOffset = self.carousel.targetOffset + turnDelta
    self.lastTurnNumber = turnNumber
  end
  
  -- Tween carousel offset toward target (smooth scrolling)
  local carouselCfg = config.shooter.carousel
  local offsetDelta = self.carousel.targetOffset - self.carousel.offset
  if math.abs(offsetDelta) > 0.001 then
    local k = math.min(1, carouselCfg.scrollSpeed * dt)
    self.carousel.offset = self.carousel.offset + offsetDelta * k
  else
    self.carousel.offset = self.carousel.targetOffset
  end
  
  -- Clear render cache for this frame
  self.slotRenderCache = {}
  
  -- Calculate which slots to render CENTERED around the active slot
  -- Render exactly N slots visible, plus 1 buffer on right for smooth fade-in
  local halfRange = (self.maxVisibleSlots - 1) / 2
  
  -- Left side: -ceil(halfRange)-1 (duplicate, will be aggressively faded out)
  -- Right side: floor(halfRange)+1 (incoming ball, will fade in smoothly)
  -- This renders N+1 slots total, but only N will be visible due to fade settings
  local renderMin = math.floor(self.carousel.offset - math.ceil(halfRange) - 1)
  local renderMax = math.floor(self.carousel.offset + math.floor(halfRange) + 1)
  
  local arrowTargetOffsetX = 0 -- Arrow offset relative to shooter center
  
  -- Render all slots in range
  for slotIndex = renderMin, renderMax do
    -- Calculate position relative to carousel offset
    local relativePosition = slotIndex - self.carousel.offset
    
    -- Calculate fade alphas
    local edgeFade = self:calculateEdgeFade(relativePosition)
    local depthFade = self:calculateDepthFade(relativePosition)
    
    -- Skip if fully transparent
    if edgeFade > 0 then
      -- Calculate screen position
      local slotX = self:calculateSlotScreenX(relativePosition)
      
      -- Calculate size
      local slotSize = self:calculateSlotSize(relativePosition)
      
      -- Get projectile for this slot (with infinite wrapping)
      local projectileIndex = ((slotIndex % self.numProjectiles) + self.numProjectiles) % self.numProjectiles + 1
      
      -- Store in render cache
      self.slotRenderCache[slotIndex] = {
        x = slotX,
        size = slotSize,
        edgeFade = edgeFade,
        depthFade = depthFade,
        projectileIndex = projectileIndex,
        relativePosition = relativePosition,
      }
      
      -- Arrow follows the center slot (closest to offset)
      if math.abs(relativePosition) < 0.5 then
        -- Calculate offset relative to shooter center
        local ballSpacing = r * carouselCfg.ballSpacingMultiplier
        arrowTargetOffsetX = relativePosition * ballSpacing
      end
    end
  end
  
  -- Tween arrow offset toward active ball (relative to shooter position)
  local k = math.min(1, carouselCfg.scrollSpeed * dt)
  local arrowDelta = arrowTargetOffsetX - self.arrowOffsetX
  if math.abs(arrowDelta) > 0.01 then
    self.arrowOffsetX = self.arrowOffsetX + arrowDelta * k
  else
    self.arrowOffsetX = arrowTargetOffsetX
  end
end

function Shooter:getMuzzle()
  -- Shoot from the current ball (active slot at carousel center) position
  local r = config.shooter.radius
  
  -- Find the slot closest to center (carousel.offset)
  local centerSlotIndex = math.floor(self.carousel.offset + 0.5)
  local cachedSlot = self.slotRenderCache[centerSlotIndex]
  local currentSlotX = cachedSlot and cachedSlot.x or self.x
  
  -- Account for 20px upward shift in draw
  return currentSlotX, (self.y - 20) - r * 0.5
end

-- Get the current projectile ID based on carousel position
function Shooter:getCurrentProjectileId()
  -- Active projectile is at the carousel center (rounded)
  local centerSlotIndex = math.floor(self.carousel.offset + 0.5)
  local projectileIndex = ((centerSlotIndex % self.numProjectiles) + self.numProjectiles) % self.numProjectiles + 1
  local slot = self.projectileSlots[projectileIndex]
  return slot and slot.id or "strike"
end

function Shooter:draw()
  local alpha = self.alpha or 1.0
  -- Don't draw if fully transparent
  if alpha <= 0 then return end
  
  love.graphics.setColor(1, 1, 1, alpha)
  
  -- Shift entire shooter up by 20px
  local drawY = self.y - 20
  
  -- Draw ball slots background image (optional - can be removed or adapted)
  if self.ballSlotsImage then
    local r = config.shooter.radius
    local carouselCfg = config.shooter.carousel
    local ballSpacing = r * carouselCfg.ballSpacingMultiplier
    
    -- Calculate width to cover a constant number of slots (keep background size constant)
    local baseVisibleSlots = 5
    local slotsWidth = baseVisibleSlots * ballSpacing
    local iw, ih = self.ballSlotsImage:getWidth(), self.ballSlotsImage:getHeight()
    local scale = (slotsWidth / math.max(iw, ih)) * 2
    
    -- Apply alpha to background
    love.graphics.setColor(1, 1, 1, alpha)
    -- Center the background on shooter position
    love.graphics.draw(self.ballSlotsImage, self.x, drawY - 15, 0, scale, scale, iw * 0.5, ih * 0.5)
  end
  
  -- Draw all slots from render cache
  -- Sort by slot index to draw left-to-right
  local sortedSlots = {}
  for slotIndex, slotData in pairs(self.slotRenderCache) do
    table.insert(sortedSlots, {index = slotIndex, data = slotData})
  end
  table.sort(sortedSlots, function(a, b) return a.index < b.index end)
  
  for _, entry in ipairs(sortedSlots) do
    local slotData = entry.data
    local slot = self.projectileSlots[slotData.projectileIndex]
      local slotImage = slot and slot.image or nil
      
    -- Combine edge fade and depth fade
    local finalAlpha = slotData.edgeFade * slotData.depthFade
    
    -- Calculate bobbing effect for selected orb (center slot)
    local bobScale = 1.0
    if math.abs(slotData.relativePosition) < 0.5 then
      -- Selected orb: bob with +/- 5% size variation
      local bobSpeed = 2.0 -- Animation speed (cycles per second)
      local bobAmount = 0.05 -- +/- 5% size variation
      bobScale = 1.0 + math.sin(self.bobTime * bobSpeed * math.pi * 2) * bobAmount
    end
      
      -- Draw projectile image or fallback circle
      -- Apply shooter alpha to final alpha
      local combinedAlpha = finalAlpha * alpha
      if slotImage then
      love.graphics.setColor(1, 1, 1, combinedAlpha)
        local iw, ih = slotImage:getWidth(), slotImage:getHeight()
      local scale = (slotData.size * 2 * bobScale) / math.max(iw, ih)
      love.graphics.draw(slotImage, slotData.x, drawY, 0, scale, scale, iw * 0.5, ih * 0.5)
  else
      -- Fallback circle
      love.graphics.setColor(0.8, 0.8, 0.8, combinedAlpha)
      love.graphics.circle("fill", slotData.x, drawY, slotData.size * bobScale)
    end
      end
      
      -- Reset color
      love.graphics.setColor(1, 1, 1, alpha)
  
  -- Draw arrow below the active ball (center slot)
  if self.arrowImage then
    local r = config.shooter.radius
    
    -- Find center slot for arrow positioning
    local centerSlotIndex = math.floor(self.carousel.offset + 0.5)
    local centerSlot = self.slotRenderCache[centerSlotIndex]
    
    if centerSlot then
      -- Calculate bobbing scale for arrow (matches selected orb)
      local bobScale = 1.0
      if math.abs(centerSlot.relativePosition) < 0.5 then
        local bobSpeed = 2.0
        local bobAmount = 0.05
        bobScale = 1.0 + math.sin(self.bobTime * bobSpeed * math.pi * 2) * bobAmount
      end
      
      local arrowY = drawY + centerSlot.size * bobScale + r * 0.3 + 3
      
      -- Arrow position synced with shooter movement (relative offset)
      local arrowX = self.x + self.arrowOffsetX
    
    -- Scale arrow to match ball size (with bobbing)
    local iw, ih = self.arrowImage:getWidth(), self.arrowImage:getHeight()
      local scale = (centerSlot.size * bobScale * 1.5) / math.max(iw, ih) * 1.5
      -- Apply alpha to arrow
      love.graphics.setColor(1, 1, 1, alpha)
      love.graphics.draw(self.arrowImage, arrowX, arrowY, 0, scale, scale, iw * 0.5, ih * 0.5)
    end
  end
  
  love.graphics.setColor(1, 1, 1, 1)
end

return Shooter


