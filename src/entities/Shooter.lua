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
  
  -- Initial positions: slot1 on left (current, turn 1), slot2 on right
  local slot1InitialX = x - ballSpacing * 0.5 - ballSize + rightShift
  local slot2InitialX = x + ballSpacing * 0.5 + ballSize + rightShift
  
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
    -- Slot position tracking for tweening (always 2 visible slots)
    slot1X = slot1InitialX, -- Current position of slot 1 (left, current)
    slot2X = slot2InitialX, -- Current position of slot 2 (right, next)
    slotsX = x + rightShift, -- Current position of slots image (tweened)
    arrowX = slot1InitialX, -- Current position of arrow (tweened, follows active ball)
    slot1Size = currentBallSize, -- Current size of slot 1 (starts as current ball)
    slot2Size = ballSize, -- Current size of slot 2 (starts as next ball)
    slot1Index = 0, -- Index of projectile in slot 1 (current)
    slot2Index = 1, -- Index of projectile in slot 2 (next)
    lastTurnNumber = 1, -- Track turn number to detect changes
    tweenSpeed = 8, -- Speed of position tween
    sizeTweenSpeed = 12, -- Speed of size tween (faster for visual feedback)
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
  
  -- Ensure we have at least 2 projectiles for rotation
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
  
  -- If only one projectile, duplicate it for display
  if self.numProjectiles == 1 then
    local duplicate = {
      id = self.projectileSlots[1].id,
      icon = self.projectileSlots[1].icon,
      image = self.projectileSlots[1].image,
    }
    table.insert(self.projectileSlots, duplicate)
    self.numProjectiles = 2
  end
  
  -- Initialize slot indices (turn 1: first projectile, turn 2: second projectile)
  self.slot1Index = 0
  self.slot2Index = 1
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

-- Get projectile image for a slot index (wraps around)
function Shooter:getProjectileImage(slotIndex)
  if self.numProjectiles == 0 then return nil end
  local index = ((slotIndex % self.numProjectiles) + self.numProjectiles) % self.numProjectiles + 1
  local slot = self.projectileSlots[index]
  return slot and slot.image or nil
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
  
  -- Update slot indices based on turn number (cycle through all projectiles)
  -- Turn 1: projectile 0 (index 0), Turn 2: projectile 1 (index 1), etc.
  local targetSlot1Index = (turnNumber - 1) % self.numProjectiles
  local targetSlot2Index = turnNumber % self.numProjectiles
  
  -- Detect turn change and update slot indices
  if turnNumber ~= self.lastTurnNumber then
    self.lastTurnNumber = turnNumber
    self.slot1Index = targetSlot1Index
    self.slot2Index = targetSlot2Index
  end
  
  -- Calculate target positions based on current turn
  local r = config.shooter.radius
  local ballSpacing = r * 0.6
  local ballSize = r * 0.7
  local currentBallSize = ballSize * 1.2 -- Current ball is 20% larger
  local rightShift = currentBallSize * 0.5 -- Shift right by half the current ball's radius
  
  -- Slot 1 (left, current) is always the active projectile for this turn
  -- Slot 2 (right, next) shows the next projectile
  local slot1Offset = -ballSpacing * 0.5 - ballSize + rightShift
  local slot2Offset = ballSpacing * 0.5 + ballSize + rightShift
  
  -- Target positions relative to shooter center
  local slot1TargetX = self.x + slot1Offset
  local slot2TargetX = self.x + slot2Offset
  local slotsTargetX = self.x + rightShift
  
  -- Active ball is always slot 1 (left)
  local arrowTargetX = slot1TargetX
  
  -- Tween slot positions toward targets (both for position swap and shooter movement)
  local k = math.min(1, self.tweenSpeed * dt)
  local slot1Delta = slot1TargetX - self.slot1X
  local slot2Delta = slot2TargetX - self.slot2X
  local slotsDelta = slotsTargetX - self.slotsX
  local arrowDelta = arrowTargetX - self.arrowX
  
  if math.abs(slot1Delta) > 0.01 then
    self.slot1X = self.slot1X + slot1Delta * k
  else
    self.slot1X = slot1TargetX
  end
  
  if math.abs(slot2Delta) > 0.01 then
    self.slot2X = self.slot2X + slot2Delta * k
  else
    self.slot2X = slot2TargetX
  end
  
  -- Tween slots position toward target (syncs with ball movement)
  if math.abs(slotsDelta) > 0.01 then
    self.slotsX = self.slotsX + slotsDelta * k
  else
    self.slotsX = slotsTargetX
  end
  
  -- Tween arrow position toward active ball (syncs with ball movement)
  if math.abs(arrowDelta) > 0.01 then
    self.arrowX = self.arrowX + arrowDelta * k
  else
    self.arrowX = arrowTargetX
  end
  
  -- Tween slot sizes toward targets
  local sizeK = math.min(1, self.sizeTweenSpeed * dt)
  local slot1TargetSize = currentBallSize -- Current ball (left)
  local slot2TargetSize = ballSize -- Next ball (right)
  local slot1SizeDelta = slot1TargetSize - self.slot1Size
  local slot2SizeDelta = slot2TargetSize - self.slot2Size
  
  if math.abs(slot1SizeDelta) > 0.01 then
    self.slot1Size = self.slot1Size + slot1SizeDelta * sizeK
  else
    self.slot1Size = slot1TargetSize
  end
  
  if math.abs(slot2SizeDelta) > 0.01 then
    self.slot2Size = self.slot2Size + slot2SizeDelta * sizeK
  else
    self.slot2Size = slot2TargetSize
  end
end

function Shooter:getMuzzle()
  -- Shoot from the current ball (slot 1, left) position, slightly above
  local r = config.shooter.radius
  -- Account for 20px upward shift in draw
  return self.slot1X, (self.y - 20) - r * 0.5
end

-- Get the current projectile ID based on turn number
function Shooter:getCurrentProjectileId()
  local turnNumber = 1
  if self.turnManager and self.turnManager.getTurnNumber then
    turnNumber = self.turnManager:getTurnNumber()
  end
  local index = ((turnNumber - 1) % self.numProjectiles) + 1
  local slot = self.projectileSlots[index]
  return slot and slot.id or "qi_orb"
end

function Shooter:draw()
  love.graphics.setColor(1, 1, 1, 1)
  
  -- Shift entire shooter up by 20px
  local drawY = self.y - 20
  
  -- Draw ball slots image beneath the balls (lower z-order)
  if self.ballSlotsImage then
    local r = config.shooter.radius
    local ballSpacing = r * 0.6
    local ballSize = r * 0.7
    local currentBallSize = ballSize * 1.2
    local rightShift = currentBallSize * 0.5
    
    -- Calculate the width needed to cover both ball positions
    local slotsWidth = ballSpacing + ballSize * 2 + currentBallSize
    local iw, ih = self.ballSlotsImage:getWidth(), self.ballSlotsImage:getHeight()
    local scale = (slotsWidth / math.max(iw, ih)) * 6
    
    -- Use tweened slots position (synced with ball movement)
    love.graphics.draw(self.ballSlotsImage, self.slotsX, drawY, 0, scale, scale, iw * 0.5, ih * 0.5)
  end
  
  -- Get current turn number to determine which projectiles to show
  local turnNumber = 1
  if self.turnManager and self.turnManager.getTurnNumber then
    turnNumber = self.turnManager:getTurnNumber()
  end
  
  -- Calculate which projectiles are in each slot
  local slot1ProjectileIndex = ((turnNumber - 1) % self.numProjectiles) + 1
  local slot2ProjectileIndex = (turnNumber % self.numProjectiles) + 1
  
  -- Get projectile images for current slots
  local slot1Image = self.projectileSlots[slot1ProjectileIndex] and self.projectileSlots[slot1ProjectileIndex].image or nil
  local slot2Image = self.projectileSlots[slot2ProjectileIndex] and self.projectileSlots[slot2ProjectileIndex].image or nil
  
  -- Draw slot 1 (left, current) at its current tweened position and size
  if slot1Image then
    local iw, ih = slot1Image:getWidth(), slot1Image:getHeight()
    local scale = (self.slot1Size * 2) / math.max(iw, ih)
    love.graphics.draw(slot1Image, self.slot1X, drawY, 0, scale, scale, iw * 0.5, ih * 0.5)
  else
    -- Fallback circle for slot 1
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    love.graphics.circle("fill", self.slot1X, drawY, self.slot1Size)
  end
  
  -- Draw slot 2 (right, next) at its current tweened position and size
  if slot2Image then
    local iw, ih = slot2Image:getWidth(), slot2Image:getHeight()
    local scale = (self.slot2Size * 2) / math.max(iw, ih)
    love.graphics.draw(slot2Image, self.slot2X, drawY, 0, scale, scale, iw * 0.5, ih * 0.5)
  else
    -- Fallback circle for slot 2
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.circle("fill", self.slot2X, drawY, self.slot2Size)
  end
  
  -- Draw arrow below the active ball (slot 1)
  if self.arrowImage then
    -- Position arrow below the active ball using tweened position
    local r = config.shooter.radius
    local arrowY = drawY + self.slot1Size + r * 0.3 + 3
    
    -- Scale arrow to match ball size
    local iw, ih = self.arrowImage:getWidth(), self.arrowImage:getHeight()
    local scale = (self.slot1Size * 1.5) / math.max(iw, ih) * 1.5
    love.graphics.draw(self.arrowImage, self.arrowX, arrowY, 0, scale, scale, iw * 0.5, ih * 0.5)
  end
  
  love.graphics.setColor(1, 1, 1, 1)
end

return Shooter


