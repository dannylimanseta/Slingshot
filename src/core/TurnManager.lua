-- Scalable Turn Management System
-- Combines State Machine + Event System + Action Queue

local TurnManager = {}
TurnManager.__index = TurnManager

-- Turn state definitions
TurnManager.States = {
  INIT = "init",
  PLAYER_TURN_START = "player_start",
  PLAYER_TURN_ACTIVE = "player_active",
  PLAYER_TURN_RESOLVING = "player_resolving",
  ENEMY_TURN_START = "enemy_start",
  ENEMY_TURN_RESOLVING = "enemy_resolving",
  VICTORY = "victory",
  DEFEAT = "defeat",
}

function TurnManager.new()
  return setmetatable({
    currentState = TurnManager.States.INIT,
    previousState = nil,
    stateHistory = {}, -- For debugging
    actionQueue = {}, -- Queue of actions to execute
    currentAction = nil,
    actionTimer = 0,
    events = {}, -- Event listeners: { eventName = { listeners... } }
    actionTypes = {}, -- Registered action types
    turnNumber = 0,
    turnData = {}, -- Data for current turn (score, armor, etc.)
  }, TurnManager)
end

-- Event System
function TurnManager:on(eventName, callback)
  self.events[eventName] = self.events[eventName] or {}
  table.insert(self.events[eventName], callback)
end

function TurnManager:off(eventName, callback)
  if not self.events[eventName] then return end
  for i, cb in ipairs(self.events[eventName]) do
    if cb == callback then
      table.remove(self.events[eventName], i)
      return
    end
  end
end

function TurnManager:emit(eventName, ...)
  if not self.events[eventName] then return end
  for _, callback in ipairs(self.events[eventName]) do
    callback(...)
  end
end

-- Action System
function TurnManager:registerAction(actionName, actionClass)
  self.actionTypes[actionName] = actionClass
end

function TurnManager:queueAction(actionName, params)
  local actionClass = self.actionTypes[actionName]
  if not actionClass then
    error("Unknown action type: " .. tostring(actionName))
  end
  local action = actionClass.new(params)
  table.insert(self.actionQueue, action)
end

function TurnManager:queueActions(actions)
  if not actions then return end
  for _, actionDef in ipairs(actions) do
    self:queueAction(actionDef.type, actionDef)
  end
end

function TurnManager:processActionQueue(dt)
  -- If no current action, start next one
  if not self.currentAction and #self.actionQueue > 0 then
    self.currentAction = table.remove(self.actionQueue, 1)
    if self.currentAction:canExecute(self) then
      self.currentAction:execute(self)
      self.actionTimer = self.currentAction.duration or 0
    else
      -- Action can't execute yet, put it back at the front of the queue
      table.insert(self.actionQueue, 1, self.currentAction)
      self.currentAction = nil
      return -- Try again next frame
    end
  end
  
  -- Update current action timer
  if self.currentAction then
    self.actionTimer = self.actionTimer - dt
    if self.actionTimer <= 0 then
      self.currentAction = nil
    end
  end
end

-- State Management
function TurnManager:transitionTo(newState, options)
  options = options or {}
  
  -- Validate transition
  if not self:canTransition(self.currentState, newState) then
    return false
  end
  
  -- Save history
  table.insert(self.stateHistory, {
    from = self.currentState,
    to = newState,
    turn = self.turnNumber,
    time = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0,
  })
  
  -- Exit current state
  self:emit("state_exit", self.currentState, newState)
  
  -- Update state
  self.previousState = self.currentState
  self.currentState = newState
  
  -- Queue actions if provided
  if options.actions then
    self:queueActions(options.actions)
  end
  
  -- Enter new state
  self:emit("state_enter", newState, self.previousState)
  
  return true
end

function TurnManager:canTransition(from, to)
  -- Define valid transitions (can be overridden)
  local validTransitions = {
    [TurnManager.States.INIT] = { TurnManager.States.PLAYER_TURN_START },
    [TurnManager.States.PLAYER_TURN_START] = { TurnManager.States.PLAYER_TURN_ACTIVE },
    [TurnManager.States.PLAYER_TURN_ACTIVE] = { TurnManager.States.PLAYER_TURN_RESOLVING },
    [TurnManager.States.PLAYER_TURN_RESOLVING] = { TurnManager.States.ENEMY_TURN_START, TurnManager.States.VICTORY },
    [TurnManager.States.ENEMY_TURN_START] = { TurnManager.States.ENEMY_TURN_RESOLVING },
    [TurnManager.States.ENEMY_TURN_RESOLVING] = { TurnManager.States.PLAYER_TURN_START, TurnManager.States.DEFEAT },
  }
  
  local allowed = validTransitions[from]
  if not allowed then return false end
  
  for _, allowedState in ipairs(allowed) do
    if allowedState == to then return true end
  end
  
  return false
end

-- Turn lifecycle
function TurnManager:startPlayerTurn()
  -- Increment turn number and reset turn data
  self.turnNumber = self.turnNumber + 1
  self.turnData = {
    score = 0,
    armor = 0,
    crits = 0,
    blocksDestroyed = 0,
  }
  
  -- If already in PLAYER_TURN_START, just queue the actions without transitioning
  if self.currentState == TurnManager.States.PLAYER_TURN_START then
    self:queueActions({
      { type = "wait", duration = 0.3 },
      { type = "show_indicator", text = "PLAYER'S TURN" },
      -- Ensure indicator has appeared on-screen before enabling shooter
      { type = "wait", duration = 0.5 },
      { type = "transition", state = TurnManager.States.PLAYER_TURN_ACTIVE },
    })
    return true
  end
  
  -- Otherwise, transition to PLAYER_TURN_START and queue actions
  return self:transitionTo(TurnManager.States.PLAYER_TURN_START, {
    actions = {
      { type = "wait", duration = 0.3 },
      { type = "show_indicator", text = "PLAYER'S TURN" },
      -- Ensure indicator has appeared on-screen before enabling shooter
      { type = "wait", duration = 0.5 },
      { type = "transition", state = TurnManager.States.PLAYER_TURN_ACTIVE },
    }
  })
end

function TurnManager:endPlayerTurn(turnData)
  -- Merge turn data
  for k, v in pairs(turnData or {}) do
    self.turnData[k] = v
  end
  
  self:transitionTo(TurnManager.States.PLAYER_TURN_RESOLVING, {
    actions = {
      { type = "apply_damage", target = "enemy", amount = turnData.score },
      { type = "check_victory" },
      -- Transition to enemy turn will be triggered after armor popup (if any) or immediately
      { type = "transition_to_enemy_turn" },
    }
  })
end

-- Start enemy turn sequence (called after player turn resolving completes)
-- Note: armor popup is already shown by BattleScene, so we just sequence the rest
function TurnManager:startEnemyTurn()
  -- Ensure we're in the correct state to start enemy turn
  -- Only allow transition from PLAYER_TURN_RESOLVING, or if already in ENEMY_TURN_START (no-op)
  if self.currentState == TurnManager.States.ENEMY_TURN_START or 
     self.currentState == TurnManager.States.ENEMY_TURN_RESOLVING then
    -- Already in enemy turn - check if actions are queued/processing
    -- If actions are being processed, don't restart
    if #self.actionQueue > 0 or self.currentAction then
      -- Already processing enemy turn, don't restart
      return true
    end
    -- If we're in ENEMY_TURN_START/RESOLVING but no actions, something went wrong
    -- But don't restart - return false to prevent loops
    return false
  end
  
  -- Must be in PLAYER_TURN_RESOLVING to transition to enemy turn
  if self.currentState ~= TurnManager.States.PLAYER_TURN_RESOLVING then
    -- Invalid state transition - log error or handle gracefully
    return false
  end
  
  -- Transition to enemy turn and queue actions
  -- Armor popup was already handled by BattleScene's timing logic
  local success = self:transitionTo(TurnManager.States.ENEMY_TURN_START, {
    actions = {
      { type = "show_indicator", text = "ENEMY'S TURN", indicatorDuration = 1.0 },
      { type = "wait", duration = 0.8 },
      { type = "enemy_attack" },
      { type = "check_defeat" },
      { type = "spawn_blocks", count = self.turnData.blocksDestroyed or 0 },
      { type = "wait", duration = 0.3 },
      -- End enemy turn phase then move to player turn start per valid transitions
      { type = "transition", state = TurnManager.States.ENEMY_TURN_RESOLVING },
      -- Call startPlayerTurn to increment turn number and setup next player turn
      { type = "start_player_turn" },
    }
  })
  
  return success
end

function TurnManager:endEnemyTurn()
  self:transitionTo(TurnManager.States.ENEMY_TURN_RESOLVING, {
    actions = {
      { type = "enemy_attack" },
      { type = "check_defeat" },
      { type = "spawn_blocks", count = self.turnData.blocksDestroyed },
      { type = "wait", duration = 0.3 },
      { type = "transition", state = TurnManager.States.PLAYER_TURN_START },
    }
  })
end

-- Update loop
function TurnManager:update(dt)
  self:processActionQueue(dt)
  self:emit("update", dt)
end

-- Getters
function TurnManager:getState()
  return self.currentState
end

function TurnManager:getTurnNumber()
  return self.turnNumber
end

function TurnManager:getTurnData()
  return self.turnData
end

return TurnManager

