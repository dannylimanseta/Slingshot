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
    -- Ball position tracking for tweening
    ball1X = ball1InitialX, -- Current position of ball 1
    ball2X = ball2InitialX, -- Current position of ball 2
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
  
  -- Tween ball positions toward targets (both for position swap and shooter movement)
  local k = math.min(1, self.tweenSpeed * dt)
  local ball1Delta = ball1TargetX - self.ball1X
  local ball2Delta = ball2TargetX - self.ball2X
  
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
  return currentBallX, self.y - r * 0.5
end

function Shooter:draw()
  love.graphics.setColor(1, 1, 1, 1)
  
  -- Draw ball 1 at its current tweened position and size
  if self.ball1Image then
    local iw, ih = self.ball1Image:getWidth(), self.ball1Image:getHeight()
    local scale = (self.ball1Size * 2) / math.max(iw, ih)
    love.graphics.draw(self.ball1Image, self.ball1X, self.y, 0, scale, scale, iw * 0.5, ih * 0.5)
  else
    -- Fallback circle for ball 1
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    love.graphics.circle("fill", self.ball1X, self.y, self.ball1Size)
  end
  
  -- Draw ball 2 at its current tweened position and size
  if self.ball2Image then
    local iw, ih = self.ball2Image:getWidth(), self.ball2Image:getHeight()
    local scale = (self.ball2Size * 2) / math.max(iw, ih)
    love.graphics.draw(self.ball2Image, self.ball2X, self.y, 0, scale, scale, iw * 0.5, ih * 0.5)
  else
    -- Fallback circle for ball 2
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.circle("fill", self.ball2X, self.y, self.ball2Size)
  end
  
  love.graphics.setColor(1, 1, 1, 1)
end

return Shooter


