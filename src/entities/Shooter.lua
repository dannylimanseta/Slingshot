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
  
  -- Initial positions: ball1 on left (current, turn 1), ball2 on right
  local ball1InitialX = x - ballSpacing * 0.5 - ballSize + rightShift
  local ball2InitialX = x + ballSpacing * 0.5 + ballSize + rightShift
  
  local self = setmetatable({ 
    x = x, 
    y = y,
    projectileId = projectileId or "qi_orb", -- Default projectile
    projectileIcon = nil, -- Cached icon image
    turnManager = nil, -- Reference to TurnManager for turn-based display
    ball1Image = nil, -- Cached ball_1.png image
    ball2Image = nil, -- Cached ball_2.png image
    ballSlotsImage = nil, -- Cached ball_slots.png image
    arrowImage = nil, -- Cached arrow_1.png image
    -- Ball position tracking for tweening
    ball1X = ball1InitialX, -- Current position of ball 1
    ball2X = ball2InitialX, -- Current position of ball 2
    slotsX = x + rightShift, -- Current position of slots image (tweened)
    arrowX = ball1InitialX, -- Current position of arrow (tweened, follows active ball)
    ball1Size = currentBallSize, -- Current size of ball 1 (starts as current ball)
    ball2Size = ballSize, -- Current size of ball 2 (starts as other ball)
    lastTurnNumber = 1, -- Track turn number to detect changes
    tweenSpeed = 8, -- Speed of position tween
    sizeTweenSpeed = 12, -- Speed of size tween (faster for visual feedback)
  }, Shooter)
  
  -- Load projectile icon if available
  self:updateProjectileIcon()
  
  -- Load both ball images for side-by-side display
  self:loadBallImages()
  
  return self
end

-- Update the projectile icon based on current projectile ID
function Shooter:updateProjectileIcon()
  if not self.projectileId then
    self.projectileIcon = nil
    return
  end
  
  local projectile = ProjectileManager.getProjectile(self.projectileId)
  if projectile and projectile.icon then
    local ok, img = pcall(love.graphics.newImage, projectile.icon)
    if ok then
      self.projectileIcon = img
    else
      self.projectileIcon = nil
    end
  else
    self.projectileIcon = nil
  end
end

-- Set the projectile ID and update icon
function Shooter:setProjectile(projectileId)
  self.projectileId = projectileId or "qi_orb"
  self:updateProjectileIcon()
end

-- Set TurnManager reference
function Shooter:setTurnManager(turnManager)
  self.turnManager = turnManager
end

-- Load both ball images
function Shooter:loadBallImages()
  -- Load ball_1.png
  local ball1Path = (config.assets and config.assets.images and config.assets.images.ball) or "assets/images/ball_1.png"
  local ok1, img1 = pcall(love.graphics.newImage, ball1Path)
  if ok1 then self.ball1Image = img1 end
  
  -- Load ball_2.png
  local ball2Path = (config.assets and config.assets.images and config.assets.images.ball_2) or "assets/images/ball_2.png"
  local ok2, img2 = pcall(love.graphics.newImage, ball2Path)
  if ok2 then self.ball2Image = img2 end
  
  -- Load ball_slots.png
  local ballSlotsPath = "assets/images/ball_slots.png"
  local ok3, img3 = pcall(love.graphics.newImage, ballSlotsPath)
  if ok3 then self.ballSlotsImage = img3 end
  
  -- Load arrow_1.png
  local arrowPath = "assets/images/arrow_1.png"
  local ok4, img4 = pcall(love.graphics.newImage, arrowPath)
  if ok4 then self.arrowImage = img4 end
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
  
  -- Update ball positions based on turn number
  local turnNumber = 1
  if self.turnManager and self.turnManager.getTurnNumber then
    turnNumber = self.turnManager:getTurnNumber()
  end
  
  -- Detect turn change and update target positions
  if turnNumber ~= self.lastTurnNumber then
    self.lastTurnNumber = turnNumber
    -- Positions will be updated below based on the new turn
  end
  
  -- Calculate target positions based on current turn
  local r = config.shooter.radius
  local ballSpacing = r * 0.6
  local ballSize = r * 0.7
  local currentBallSize = ballSize * 1.2 -- Current ball is 20% larger
  local isSpreadTurn = (turnNumber % 2 == 0) -- Even turns = spread shot
  
  -- Shift balls to the right so the current ball (left ball) aligns with shooting guide
  -- The current ball is on the left: ball1 for regular turns, ball2 for spread turns
  local rightShift = currentBallSize * 0.5 -- Shift right by half the current ball's radius
  
  -- Target positions: if spread turn, ball2 is left (current), ball1 is right
  -- Positions are relative to shooter's x, shifted right for alignment
  local ball1Offset, ball2Offset
  local ball1TargetSize, ball2TargetSize
  if isSpreadTurn then
    -- Spread turn: ball2 on left (current), ball1 on right
    ball2Offset = -ballSpacing * 0.5 - ballSize + rightShift
    ball1Offset = ballSpacing * 0.5 + ballSize + rightShift
    ball2TargetSize = currentBallSize -- Current ball (left)
    ball1TargetSize = ballSize -- Other ball (right)
  else
    -- Regular turn: ball1 on left (current), ball2 on right
    ball1Offset = -ballSpacing * 0.5 - ballSize + rightShift
    ball2Offset = ballSpacing * 0.5 + ballSize + rightShift
    ball1TargetSize = currentBallSize -- Current ball (left)
    ball2TargetSize = ballSize -- Other ball (right)
  end
  
  -- Target positions relative to shooter center
  local ball1TargetX = self.x + ball1Offset
  local ball2TargetX = self.x + ball2Offset
  local slotsTargetX = self.x + rightShift
  
  -- Active ball is on the left: ball1 for regular turns, ball2 for spread turns
  local arrowTargetX = isSpreadTurn and ball2TargetX or ball1TargetX
  
  -- Tween ball positions toward targets (both for position swap and shooter movement)
  local k = math.min(1, self.tweenSpeed * dt)
  local ball1Delta = ball1TargetX - self.ball1X
  local ball2Delta = ball2TargetX - self.ball2X
  local slotsDelta = slotsTargetX - self.slotsX
  local arrowDelta = arrowTargetX - self.arrowX
  
  if math.abs(ball1Delta) > 0.01 then
    self.ball1X = self.ball1X + ball1Delta * k
  else
    self.ball1X = ball1TargetX
  end
  
  if math.abs(ball2Delta) > 0.01 then
    self.ball2X = self.ball2X + ball2Delta * k
  else
    self.ball2X = ball2TargetX
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
  
  -- Tween ball sizes toward targets
  local sizeK = math.min(1, self.sizeTweenSpeed * dt)
  local ball1SizeDelta = ball1TargetSize - self.ball1Size
  local ball2SizeDelta = ball2TargetSize - self.ball2Size
  
  if math.abs(ball1SizeDelta) > 0.01 then
    self.ball1Size = self.ball1Size + ball1SizeDelta * sizeK
  else
    self.ball1Size = ball1TargetSize
  end
  
  if math.abs(ball2SizeDelta) > 0.01 then
    self.ball2Size = self.ball2Size + ball2SizeDelta * sizeK
  else
    self.ball2Size = ball2TargetSize
  end
end

function Shooter:getMuzzle()
  -- Shoot from the current ball (left ball) position, slightly above
  -- Determine which ball is current based on turn
  local turnNumber = 1
  if self.turnManager and self.turnManager.getTurnNumber then
    turnNumber = self.turnManager:getTurnNumber()
  end
  local isSpreadTurn = (turnNumber % 2 == 0)
  
  -- Current ball is on the left: ball1 for regular turns, ball2 for spread turns
  local currentBallX = isSpreadTurn and self.ball2X or self.ball1X
  local r = config.shooter.radius
  -- Account for 20px upward shift in draw
  return currentBallX, (self.y - 20) - r * 0.5
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
  
  -- Draw ball 1 at its current tweened position and size
  if self.ball1Image then
    local iw, ih = self.ball1Image:getWidth(), self.ball1Image:getHeight()
    local scale = (self.ball1Size * 2) / math.max(iw, ih)
    love.graphics.draw(self.ball1Image, self.ball1X, drawY, 0, scale, scale, iw * 0.5, ih * 0.5)
  else
    -- Fallback circle for ball 1
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    love.graphics.circle("fill", self.ball1X, drawY, self.ball1Size)
  end
  
  -- Draw ball 2 at its current tweened position and size
  if self.ball2Image then
    local iw, ih = self.ball2Image:getWidth(), self.ball2Image:getHeight()
    local scale = (self.ball2Size * 2) / math.max(iw, ih)
    love.graphics.draw(self.ball2Image, self.ball2X, drawY, 0, scale, scale, iw * 0.5, ih * 0.5)
  else
    -- Fallback circle for ball 2
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.circle("fill", self.ball2X, drawY, self.ball2Size)
  end
  
  -- Draw arrow below the active ball
  if self.arrowImage then
    -- Determine which ball is active based on turn (for size reference)
    local turnNumber = 1
    if self.turnManager and self.turnManager.getTurnNumber then
      turnNumber = self.turnManager:getTurnNumber()
    end
    local isSpreadTurn = (turnNumber % 2 == 0)
    local activeBallSize = isSpreadTurn and self.ball2Size or self.ball1Size
    
    -- Position arrow below the active ball using tweened position
    local r = config.shooter.radius
    local arrowY = drawY + activeBallSize + r * 0.3 + 3
    
    -- Scale arrow to match ball size
    local iw, ih = self.arrowImage:getWidth(), self.arrowImage:getHeight()
    local scale = (activeBallSize * 1.5) / math.max(iw, ih) * 1.5
    love.graphics.draw(self.arrowImage, self.arrowX, arrowY, 0, scale, scale, iw * 0.5, ih * 0.5)
  end
  
  love.graphics.setColor(1, 1, 1, 1)
end

return Shooter


