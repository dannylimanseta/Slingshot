local battle_profiles = require("data.battle_profiles")

local LayoutManager = {}
LayoutManager.__index = LayoutManager

function LayoutManager.new()
  local defaultProfile = battle_profiles.getProfile(battle_profiles.Types.DEFAULT)
  return setmetatable({
    currentFactor = defaultProfile.centerWidthFactor,
    targetFactor = defaultProfile.centerWidthFactor,
    tweenT = 0,
    tweenDuration = 0.25, -- seconds for width transition
    currentBattleType = battle_profiles.Types.DEFAULT,
  }, LayoutManager)
end

-- Set battle type (triggers tween to new width)
function LayoutManager:setBattleType(battleType, duration)
  battleType = battleType or battle_profiles.Types.DEFAULT
  local profile = battle_profiles.getProfile(battleType)
  
  if profile.centerWidthFactor ~= self.targetFactor then
    self.targetFactor = profile.centerWidthFactor
    self.tweenT = 0
    self.tweenDuration = duration or 0.25
    self.currentBattleType = battleType
  end
end

-- Set target width factor directly (for testing/flexibility)
function LayoutManager:setTargetFactor(factor, duration)
  if type(factor) ~= "number" or factor < 0 or factor > 1 then
    return false
  end
  if factor ~= self.targetFactor then
    self.targetFactor = factor
    self.tweenT = 0
    self.tweenDuration = duration or 0.25
  end
  return true
end

-- Update tweening (call each frame)
function LayoutManager:update(dt)
  if self.tweenT < self.tweenDuration then
    self.tweenT = math.min(self.tweenDuration, self.tweenT + dt)
    local t = self.tweenT / math.max(0.0001, self.tweenDuration)
    -- Smooth ease-in-out
    local ease = t < 0.5 and (2 * t * t) or (1 - math.pow(-2 * t + 2, 2) / 2)
    self.currentFactor = self.currentFactor + (self.targetFactor - self.currentFactor) * ease
    -- Clamp to avoid floating point drift
    if math.abs(self.targetFactor - self.currentFactor) < 0.001 then
      self.currentFactor = self.targetFactor
      self.tweenT = self.tweenDuration
    end
  end
end

-- Get current center rectangle
-- Returns: { x, y, w, h, center = { x, w, h } }
function LayoutManager:getCenterRect(screenW, screenH)
  screenW = screenW or 1280
  screenH = screenH or 720
  local centerW = math.floor(screenW * self.currentFactor)
  local centerX = math.floor((screenW - centerW) * 0.5)
  return {
    x = centerX,
    y = 0,
    w = centerW,
    h = screenH,
    center = {
      x = centerX,
      w = centerW,
      h = screenH,
    }
  }
end

-- Get bounds image transform
-- Returns: { dx, dy, scale, alpha }
function LayoutManager:getBoundsImageTransform(screenW, boundsImageWidth)
  screenW = screenW or 1280
  boundsImageWidth = boundsImageWidth or 1
  local centerRect = self:getCenterRect(screenW)
  local scale = centerRect.w / math.max(1, boundsImageWidth)
  return {
    dx = centerRect.x,
    dy = -500, -- preserve existing vertical offset
    scale = scale,
    alpha = 0.3,
  }
end

-- Check if currently tweening
function LayoutManager:isTweening()
  return self.tweenT < self.tweenDuration
end

-- Get current battle type
function LayoutManager:getBattleType()
  return self.currentBattleType
end

return LayoutManager

