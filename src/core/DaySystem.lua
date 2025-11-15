local DaySystem = {}
DaySystem.__index = DaySystem

function DaySystem.new()
  return setmetatable({
    currentDay = 1,
    movesRemaining = 5, -- Will be set from config
    maxMovesPerDay = 5, -- Base max moves (before relic bonuses)
    totalDays = 30, -- Will be set from config
    _initialized = false,
  }, DaySystem)
end

-- Get effective max moves including relic bonuses
function DaySystem:getEffectiveMaxMoves()
  local ok, RelicSystem = pcall(require, "core.RelicSystem")
  local bonus = 0
  if ok and RelicSystem and RelicSystem.getDailyStepsBonus then
    bonus = RelicSystem.getDailyStepsBonus() or 0
  end
  return self.maxMovesPerDay + bonus
end

function DaySystem:load(config)
  local newMax = (config and config.map and config.map.movesPerDay) or 5
  self.maxMovesPerDay = newMax
  local effectiveMax = self:getEffectiveMaxMoves()
  -- On first load, initialize to full moves; afterwards, preserve remaining (clamped)
  if not self._initialized then
    self.movesRemaining = effectiveMax
    self._initialized = true
  else
    local prevMoves = self.movesRemaining or effectiveMax
    self.movesRemaining = math.max(0, math.min(prevMoves, effectiveMax))
  end
  self.totalDays = (config and config.map and config.map.totalDays) or self.totalDays
end

function DaySystem:useMove()
  if self.movesRemaining > 0 then
    self.movesRemaining = self.movesRemaining - 1
    return true
  end
  return false
end

function DaySystem:canMove()
  return self.movesRemaining > 0
end

function DaySystem:getMovesRemaining()
  return self.movesRemaining
end

function DaySystem:getMaxMoves()
  return self:getEffectiveMaxMoves()
end

function DaySystem:setMaxMovesPerDay(newMax)
  if not newMax then
    return
  end
  local clamped = math.max(1, math.floor(newMax))
  self.maxMovesPerDay = clamped
  local effectiveMax = self:getEffectiveMaxMoves()
  self.movesRemaining = effectiveMax
end

function DaySystem:advanceDay()
  self.currentDay = self.currentDay + 1
  local effectiveMax = self:getEffectiveMaxMoves()
  self.movesRemaining = effectiveMax
end

function DaySystem:getCurrentDay()
  return self.currentDay
end

function DaySystem:getTotalDays()
  return self.totalDays
end

function DaySystem:reset()
  self.currentDay = 1
  local effectiveMax = self:getEffectiveMaxMoves()
  self.movesRemaining = effectiveMax
end

return DaySystem

