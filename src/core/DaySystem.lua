local DaySystem = {}
DaySystem.__index = DaySystem

function DaySystem.new()
  return setmetatable({
    currentDay = 1,
    movesRemaining = 5, -- Will be set from config
    maxMovesPerDay = 5, -- Will be set from config
    totalDays = 30, -- Will be set from config
    _initialized = false,
  }, DaySystem)
end

function DaySystem:load(config)
  local newMax = (config and config.map and config.map.movesPerDay) or 5
  self.maxMovesPerDay = newMax
  -- On first load, initialize to full moves; afterwards, preserve remaining (clamped)
  if not self._initialized then
  self.movesRemaining = self.maxMovesPerDay
    self._initialized = true
  else
    local prevMoves = self.movesRemaining or self.maxMovesPerDay
    self.movesRemaining = math.max(0, math.min(prevMoves, self.maxMovesPerDay))
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
  return self.maxMovesPerDay
end

function DaySystem:advanceDay()
  self.currentDay = self.currentDay + 1
  self.movesRemaining = self.maxMovesPerDay
end

function DaySystem:getCurrentDay()
  return self.currentDay
end

function DaySystem:getTotalDays()
  return self.totalDays
end

function DaySystem:reset()
  self.currentDay = 1
  self.movesRemaining = self.maxMovesPerDay
end

return DaySystem

