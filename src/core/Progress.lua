local config = require("config")

local Progress = {}
Progress.__index = Progress

-- In-memory run progress (reset on app restart unless you persist snapshot)
local state = {
  enemiesEncountered = 0, -- total individual enemies faced this run
}

local function enemiesPerStep()
  local cfg = (config.battle and config.battle.difficulty) or {}
  return cfg.enemiesPerStep or 5
end

---Returns current total enemies encountered so far in the run.
function Progress.getEnemiesEncountered()
  return state.enemiesEncountered or 0
end

---Returns difficulty level based on current enemiesEncountered (1-based).
function Progress.peekDifficultyLevel()
  local per = enemiesPerStep()
  local count = Progress.getEnemiesEncountered()
  return math.floor(count / math.max(1, per)) + 1
end

---Assigns a difficulty for the next enemy and increments the encountered counter by 1.
function Progress.assignDifficultyForNextEnemy()
  local diff = Progress.peekDifficultyLevel()
  state.enemiesEncountered = (state.enemiesEncountered or 0) + 1
  return diff
end

return Progress


