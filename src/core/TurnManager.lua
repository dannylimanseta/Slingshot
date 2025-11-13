-- Scalable Turn Management System
-- Combines State Machine + Event System + Action Queue

local BattleState = require("core.BattleState")

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
  
  -- Sync BattleState turn phase
  if BattleState.get() then
    BattleState.setTurnPhase(newState, { turnNumber = self.turnNumber })
    if newState == TurnManager.States.PLAYER_TURN_ACTIVE then
      BattleState.setCanShoot(true)
    elseif newState ~= TurnManager.States.PLAYER_TURN_ACTIVE then
      BattleState.setCanShoot(false)
    end
  end
  
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
  local state = BattleState.get()
  if state then
    BattleState.incrementTurnNumber()
    state = BattleState.get()
    self.turnNumber = state.turn.number
    self.turnData = {}
    BattleState.resetTurnRewards()
    BattleState.resetBlocksDestroyedThisTurn()
    BattleState.setCanShoot(false)
  else
    self.turnNumber = self.turnNumber + 1
    self.turnData = {}
  end
  
  -- If already in PLAYER_TURN_START, just queue the actions without transitioning
  if self.currentState == TurnManager.States.PLAYER_TURN_START then
    self:queueActions({
      { type = "wait", duration = 0.3 },
      { type = "show_indicator", text = "YOUR TURN" },
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
      { type = "show_indicator", text = "YOUR TURN" },
      -- Ensure indicator has appeared on-screen before enabling shooter
      { type = "wait", duration = 0.5 },
      { type = "transition", state = TurnManager.States.PLAYER_TURN_ACTIVE },
    }
  })
end

function TurnManager:endPlayerTurn(turnData)
  local state = BattleState.get()
  local rewards = state and state.rewards or {}
  local blocksDestroyed = (state and state.blocks and state.blocks.destroyedThisTurn) or 0
  self.turnData = {
    score = rewards.score or (turnData and turnData.score) or 0,
    armor = rewards.armorThisTurn or (turnData and turnData.armor) or 0,
    crits = rewards.critCount or (turnData and turnData.crits) or 0,
    blocksDestroyed = blocksDestroyed or (turnData and turnData.blocksDestroyed) or 0,
    isAOE = rewards.aoeFlag or (turnData and turnData.isAOE) or false,
    blockHitSequence = rewards.blockHitSequence or (turnData and turnData.blockHitSequence) or {},
    baseDamage = rewards.baseDamage or (turnData and turnData.baseDamage) or rewards.score or 0,
    heal = rewards.healThisTurn or (turnData and turnData.heal) or 0,
    projectileId = rewards.projectileId or (turnData and turnData.projectileId) or "strike",
  }
  
  self:transitionTo(TurnManager.States.PLAYER_TURN_RESOLVING, {
    actions = {
      { type = "apply_damage", target = "enemy", amount = self.turnData.score },
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
  local config = require("config")
  local enemyAttackDelay = (config.battle and config.battle.enemyAttackDelay) or 1.0
  local success = self:transitionTo(TurnManager.States.ENEMY_TURN_START, {
    actions = {
      { type = "show_indicator", text = "ENEMY'S TURN", indicatorDuration = 1.0 },
      { type = "wait", duration = enemyAttackDelay },
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
  
  if success and BattleState.get() then
    BattleState.resetBlocksDestroyedThisTurn()
  end
  
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

