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
    projectileId = projectileId or "qi_orb", -- Default projectile (for backward compatibility)
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
  }, Shooter)
  
  -- Load all projectiles dynamically
  self:loadProjectiles()
  
  -- Load UI images
  self:loadUIImages()
  
  return self
end

-- Load all projectiles dynamically from ProjectileManager
function Shooter:loadProjectiles()
  local allProjectiles = ProjectileManager.getAllProjectiles()
  self.projectileSlots = {}
  self.numProjectiles = 0
  
  for _, projectile in ipairs(allProjectiles) do
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
      id = "qi_orb",
      icon = "assets/images/ball_1.png",
      image = nil,
    }
    local ok, img = pcall(love.graphics.newImage, defaultSlot.icon)
    if ok then defaultSlot.image = img end
    table.insert(self.projectileSlots, defaultSlot)
    self.numProjectiles = 1
  end
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
function Shooter:calculateEdgeFade(relativePosition)
  local carouselCfg = config.shooter.carousel
  local distanceFromCenter = math.abs(relativePosition)
  
  if distanceFromCenter < carouselCfg.fadeStart then
    return 1 -- Fully visible
  elseif distanceFromCenter > carouselCfg.fadeEnd then
    return 0 -- Fully transparent
  else
    -- Smooth linear fade between fadeStart and fadeEnd
    local fadeProgress = (distanceFromCenter - carouselCfg.fadeStart) / (carouselCfg.fadeEnd - carouselCfg.fadeStart)
    return 1 - fadeProgress
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
  local activeBallSize = ballSize * 1.2
  
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
  return self.x + (relativePosition * ballSpacing)
end

-- Set the projectile ID (for backward compatibility, but doesn't affect rotation)
function Shooter:setProjectile(projectileId)
  self.projectileId = projectileId or "qi_orb"
  -- Note: Rotation is now based on turn number, not projectileId
end

function Shooter:update(dt, bounds)
  local speed = config.shooter.speed
  local move = 0
  if love.keyboard.isDown("a") then move = move - 1 end
  if love.keyboard.isDown("d") then move = move + 1 end
  self.x = self.x + move * speed * dt

  -- Clamp to bounds
  local w = (bounds and bounds.w) or love.graphics.getWidth()
  local r = config.shooter.radius
  self.x = math.max(r, math.min(w - r, self.x))
  
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
  
  -- Calculate which slots to render (extra buffer for smooth scrolling)
  local renderMin = math.floor(self.carousel.offset - carouselCfg.renderBuffer)
  local renderMax = math.ceil(self.carousel.offset + carouselCfg.maxVisibleSlots + carouselCfg.renderBuffer)
  
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
  return slot and slot.id or "qi_orb"
end

function Shooter:draw()
  love.graphics.setColor(1, 1, 1, 1)
  
  -- Shift entire shooter up by 20px
  local drawY = self.y - 20
  
  -- Draw ball slots background image (optional - can be removed or adapted)
  if self.ballSlotsImage then
    local r = config.shooter.radius
    local carouselCfg = config.shooter.carousel
    local ballSpacing = r * carouselCfg.ballSpacingMultiplier
    
    -- Calculate width to cover visible slots
    local slotsWidth = carouselCfg.maxVisibleSlots * ballSpacing
    local iw, ih = self.ballSlotsImage:getWidth(), self.ballSlotsImage:getHeight()
    local scale = (slotsWidth / math.max(iw, ih)) * 2 -- Reduced by 3x (was * 6)
    
    -- Center the background on shooter position
    love.graphics.draw(self.ballSlotsImage, self.x, drawY, 0, scale, scale, iw * 0.5, ih * 0.5)
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
    
    -- Draw projectile image or fallback circle
    if slotImage then
      love.graphics.setColor(1, 1, 1, finalAlpha)
      local iw, ih = slotImage:getWidth(), slotImage:getHeight()
      local scale = (slotData.size * 2) / math.max(iw, ih)
      love.graphics.draw(slotImage, slotData.x, drawY, 0, scale, scale, iw * 0.5, ih * 0.5)
    else
      -- Fallback circle
      love.graphics.setColor(0.8, 0.8, 0.8, finalAlpha)
      love.graphics.circle("fill", slotData.x, drawY, slotData.size)
    end
  end
  
  -- Reset color
  love.graphics.setColor(1, 1, 1, 1)
  
  -- Draw arrow below the active ball (center slot)
  if self.arrowImage then
    local r = config.shooter.radius
    
    -- Find center slot for arrow positioning
    local centerSlotIndex = math.floor(self.carousel.offset + 0.5)
    local centerSlot = self.slotRenderCache[centerSlotIndex]
    
    if centerSlot then
      local arrowY = drawY + centerSlot.size + r * 0.3 + 3
      
      -- Arrow position synced with shooter movement (relative offset)
      local arrowX = self.x + self.arrowOffsetX
      
      -- Scale arrow to match ball size
      local iw, ih = self.arrowImage:getWidth(), self.arrowImage:getHeight()
      local scale = (centerSlot.size * 1.5) / math.max(iw, ih) * 1.5
      love.graphics.draw(self.arrowImage, arrowX, arrowY, 0, scale, scale, iw * 0.5, ih * 0.5)
    end
  end
  
  love.graphics.setColor(1, 1, 1, 1)
end

return Shooter


