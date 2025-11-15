-- Turn Action Implementations
-- Each action is a self-contained unit of work

local TurnActions = {}

-- Base Action class
local Action = {}
Action.__index = Action

function Action.new(params)
  return setmetatable({
    duration = params.duration or 0,
    params = params,
  }, Action)
end

function Action:canExecute(turnManager)
  return true
end

function Action:execute(turnManager)
  -- Override in subclasses
end

-- Wait Action
local WaitAction = setmetatable({}, Action)
WaitAction.__index = WaitAction

function WaitAction.new(params)
  local self = Action.new(params)
  self.duration = params.duration or 0.5
  return setmetatable(self, WaitAction)
end

function WaitAction:execute(turnManager)
  -- Just wait, nothing to do
end

-- Show Turn Indicator Action
local ShowIndicatorAction = setmetatable({}, Action)
ShowIndicatorAction.__index = ShowIndicatorAction

function ShowIndicatorAction.new(params)
  local self = Action.new(params)
  -- Calculate actual indicator duration (slowed by 50%)
  local indicatorDuration = params.indicatorDuration or 1.0
  local slowedDuration = indicatorDuration * 1.5
  -- Set action duration to match indicator animation duration so turn waits for it to complete
  self.duration = slowedDuration
  return setmetatable(self, ShowIndicatorAction)
end

function ShowIndicatorAction:execute(turnManager)
  -- Extract text and duration from params (params contains the full actionDef)
  local text = self.params.text or "TURN"
  local duration = self.params.indicatorDuration or 1.0
  -- Slow down animation by 50% (multiply duration by 1.5)
  local slowedDuration = duration * 1.5
  turnManager:emit("show_turn_indicator", {
    text = text,
    duration = slowedDuration,
  })
end

-- Apply Damage Action
local ApplyDamageAction = setmetatable({}, Action)
ApplyDamageAction.__index = ApplyDamageAction

function ApplyDamageAction.new(params)
  local self = Action.new(params)
  self.duration = params.duration or 0.5
  return setmetatable(self, ApplyDamageAction)
end

function ApplyDamageAction:execute(turnManager)
  turnManager:emit("apply_damage", {
    target = self.params.target, -- "player" or "enemy"
    amount = self.params.amount or 0,
  })
end

-- Show Armor Popup Action
local ShowArmorPopupAction = setmetatable({}, Action)
ShowArmorPopupAction.__index = ShowArmorPopupAction

function ShowArmorPopupAction.new(params)
  local self = Action.new(params)
  self.duration = params.duration or 0.2
  return setmetatable(self, ShowArmorPopupAction)
end

function ShowArmorPopupAction:execute(turnManager)
  if (self.params.amount or 0) > 0 then
    turnManager:emit("show_armor_popup", {
      amount = self.params.amount,
    })
  end
end

-- Enemy Attack Action
local EnemyAttackAction = setmetatable({}, Action)
EnemyAttackAction.__index = EnemyAttackAction

function EnemyAttackAction.new(params)
  local self = Action.new(params)
  self.duration = params.duration or 0.8
  return setmetatable(self, EnemyAttackAction)
end

function EnemyAttackAction:execute(turnManager)
  turnManager:emit("enemy_attack", {
    min = self.params.min or 3,
    max = self.params.max or 8,
  })
end

-- Spawn Blocks Action
local SpawnBlocksAction = setmetatable({}, Action)
SpawnBlocksAction.__index = SpawnBlocksAction

function SpawnBlocksAction.new(params)
  local self = Action.new(params)
  self.duration = params.duration or 0.1
  return setmetatable(self, SpawnBlocksAction)
end

function SpawnBlocksAction:execute(turnManager)
  turnManager:emit("spawn_blocks", {
    count = self.params.count or 0,
  })
end

-- Check Victory Action
local CheckVictoryAction = setmetatable({}, Action)
CheckVictoryAction.__index = CheckVictoryAction

function CheckVictoryAction.new(params)
  local self = Action.new(params)
  self.duration = 0
  return setmetatable(self, CheckVictoryAction)
end

function CheckVictoryAction:execute(turnManager)
  turnManager:emit("check_victory")
end

-- Check Defeat Action
local CheckDefeatAction = setmetatable({}, Action)
CheckDefeatAction.__index = CheckDefeatAction

function CheckDefeatAction.new(params)
  local self = Action.new(params)
  self.duration = 0
  return setmetatable(self, CheckDefeatAction)
end

function CheckDefeatAction:execute(turnManager)
  turnManager:emit("check_defeat")
end

-- Transition Action (special - changes state)
local TransitionAction = setmetatable({}, Action)
TransitionAction.__index = TransitionAction

function TransitionAction.new(params)
  local self = Action.new(params)
  self.duration = 0
  return setmetatable(self, TransitionAction)
end

function TransitionAction:execute(turnManager)
  turnManager:transitionTo(self.params.state)
end

-- Transition to Enemy Turn Action (waits for BattleScene to be ready)
local TransitionToEnemyTurnAction = setmetatable({}, Action)
TransitionToEnemyTurnAction.__index = TransitionToEnemyTurnAction

function TransitionToEnemyTurnAction.new(params)
  local self = Action.new(params)
  self.duration = 0
  return setmetatable(self, TransitionToEnemyTurnAction)
end

function TransitionToEnemyTurnAction:execute(turnManager)
  -- Emit event to trigger enemy turn start
  -- BattleScene will handle the timing (armor popup, etc.) and then call startEnemyTurn
  turnManager:emit("start_enemy_turn")
end

-- Start Player Turn Action (increments turn number and sets up player turn)
local StartPlayerTurnAction = setmetatable({}, Action)
StartPlayerTurnAction.__index = StartPlayerTurnAction

function StartPlayerTurnAction.new(params)
  local self = Action.new(params)
  self.duration = 0
  return setmetatable(self, StartPlayerTurnAction)
end

function StartPlayerTurnAction:execute(turnManager)
  -- Call startPlayerTurn to increment turn number and setup player turn
  turnManager:startPlayerTurn()
end

-- Export action registry
TurnActions.registerAll = function(turnManager)
  turnManager:registerAction("wait", WaitAction)
  turnManager:registerAction("show_indicator", ShowIndicatorAction)
  turnManager:registerAction("apply_damage", ApplyDamageAction)
  turnManager:registerAction("show_armor_popup", ShowArmorPopupAction)
  turnManager:registerAction("enemy_attack", EnemyAttackAction)
  -- Wait until BattleScene reports enemy attacks complete
  do
    local WaitEnemyAttacksAction = setmetatable({}, Action)
    WaitEnemyAttacksAction.__index = WaitEnemyAttacksAction
    function WaitEnemyAttacksAction.new(params)
      local self = Action.new(params)
      self.duration = 0
      return setmetatable(self, WaitEnemyAttacksAction)
    end
    function WaitEnemyAttacksAction:canExecute(turnManager)
      -- Execute (advance) only when enemy attacks are NOT busy
      local busy = (turnManager.isEnemyTurnBusy and turnManager:isEnemyTurnBusy()) or false
      return not busy
    end
    function WaitEnemyAttacksAction:execute(turnManager)
      -- no-op; advancing the queue means enemies are done
    end
    turnManager:registerAction("wait_for_enemy_attacks", WaitEnemyAttacksAction)
  end
  turnManager:registerAction("spawn_blocks", SpawnBlocksAction)
  turnManager:registerAction("check_victory", CheckVictoryAction)
  turnManager:registerAction("check_defeat", CheckDefeatAction)
  turnManager:registerAction("transition", TransitionAction)
  turnManager:registerAction("transition_to_enemy_turn", TransitionToEnemyTurnAction)
  turnManager:registerAction("start_player_turn", StartPlayerTurnAction)
end

return TurnActions

