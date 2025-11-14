local config = require("config")

local Progress = {}
Progress.__index = Progress

-- In-memory run progress (reset on app restart unless you persist snapshot)
local state = {
  encountersStarted = 0, -- total encounters (battles) started this run
}

local function enemiesPerStep()
  local cfg = (config.battle and config.battle.difficulty) or {}
  return cfg.enemiesPerStep or 5
end

---Returns total encounters (battles) started in the run.
function Progress.getEncountersStarted()
  return state.encountersStarted or 0
end

---Returns difficulty level based on current enemiesEncountered (1-based).
function Progress.peekDifficultyLevel()
  local per = enemiesPerStep()
  local count = Progress.getEncountersStarted()
  return math.floor(count / math.max(1, per)) + 1
end

---Call when a new encounter (battle) starts; increments and returns difficulty for this encounter.
function Progress.startNextEncounter()
  local diff = Progress.peekDifficultyLevel()
  state.encountersStarted = (state.encountersStarted or 0) + 1
  return diff
end

---Returns the current difficulty level (for the encounter that was just started).
---This should be called after startNextEncounter() to get the difficulty for the current battle.
function Progress.getCurrentDifficultyLevel()
  -- Since startNextEncounter increments after calculating, we need to peek at the current level
  -- which represents the difficulty for the encounter that was just started
  local per = enemiesPerStep()
  local count = Progress.getEncountersStarted()
  -- The difficulty for the current encounter is based on the count BEFORE it was incremented
  -- So we subtract 1 to get the count that was used to calculate this encounter's difficulty
  local countForThisEncounter = math.max(0, count - 1)
  return math.floor(countForThisEncounter / math.max(1, per)) + 1
end

return Progress


