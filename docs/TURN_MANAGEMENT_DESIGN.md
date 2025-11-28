# Scalable Turn Management System Design

## Current Issues
- Turn logic scattered across `SplitScene`, `BattleScene`, and `GameplayScene`
- Multiple timers and flags (`_leftTurnForwarded`, `_leftForwardTimer`, `enemyAttackTimer`)
- Implicit state transitions (checking flags, timers, callbacks)
- Hard to add new turn phases or modify flow
- Difficult to debug timing issues

## Proposed Architecture

### 1. Centralized Turn Manager (State Machine + Event System)

**Core Principles:**
- **Single Source of Truth**: One manager owns turn state
- **Explicit States**: Clear, well-defined turn phases
- **Event-Driven**: Components react to turn events, not poll state
- **Action Queue**: Sequential actions execute in order
- **Extensible**: Easy to add new phases/actions

### 2. Turn States

```lua
TurnStates = {
  INIT = "init",                    -- Game initialization
  PLAYER_TURN_START = "player_start", -- Player can act
  PLAYER_TURN_ACTIVE = "player_active", -- Player is acting (shooting)
  PLAYER_TURN_RESOLVING = "player_resolving", -- Calculating results
  ENEMY_TURN_START = "enemy_start", -- Enemy turn begins
  ENEMY_TURN_RESOLVING = "enemy_resolving", -- Enemy actions executing
  VICTORY = "victory",
  DEFEAT = "defeat",
}
```

### 3. Turn Actions (Command Pattern)

Actions are units of work that execute sequentially:

```lua
-- Base Action
Action = {
  execute = function(self, turnManager) end,
  canExecute = function(self) return true end,
  duration = 0, -- Time to wait after execution
}

-- Example Actions:
- ShowTurnIndicatorAction({ text = "PLAYER'S TURN", delay = 0.3 })
- ApplyDamageAction({ target = "enemy", amount = 10 })
- ShowArmorPopupAction({ amount = 3 })
- EnemyAttackAction({ min = 3, max = 8 })
- WaitAction({ duration = 0.5 })
- SpawnBlocksAction({ count = 5 })
```

### 4. Event System

Components subscribe to turn events:

```lua
turnManager:on("player_turn_start", function()
  -- Reset gameplay state
  -- Enable shooting
end)

turnManager:on("armor_gained", function(amount)
  -- Show armor UI
  -- Play sound
end)

turnManager:on("turn_end", function(turnData)
  -- Log turn summary
  -- Analytics
end)
```

## Implementation Structure

```
src/
  core/
    TurnManager.lua      -- Central turn state machine
    ActionQueue.lua      -- Sequential action execution
    EventEmitter.lua      -- Event subscription/pubsub
  systems/
    TurnActions.lua      -- All turn action implementations
    TurnEffects.lua      -- Side effects (UI, audio, etc.)
```

## Benefits

1. **Separation of Concerns**: Turn logic separate from game logic
2. **Testability**: Easy to test states and transitions
3. **Debuggability**: Clear state history and action logs
4. **Extensibility**: Add new actions/phases without touching existing code
5. **Reusability**: Actions can be composed into complex sequences
6. **Timing Control**: Centralized delay/async handling

## Migration Strategy

1. **Phase 1**: Create TurnManager alongside existing system
2. **Phase 2**: Migrate one turn phase at a time
3. **Phase 3**: Replace old system once all phases migrated
4. **Phase 4**: Add advanced features (undo, replay, analytics)

## Example Usage

```lua
-- Initialize
local turnManager = TurnManager.new()
turnManager:registerAction("show_indicator", ShowTurnIndicatorAction)
turnManager:registerAction("apply_damage", ApplyDamageAction)
turnManager:registerAction("wait", WaitAction)

-- Transition to player turn
turnManager:transitionTo("PLAYER_TURN_START", {
  actions = {
    { type = "wait", duration = 0.3 },
    { type = "show_indicator", text = "PLAYER'S TURN" },
  }
})

-- Player acts, then end turn
turnManager:endPlayerTurn({
  score = 15,
  armor = 3,
  actions = {
    { type = "apply_damage", target = "enemy", amount = 15 },
    { type = "show_armor_popup", amount = 3 },
    { type = "wait", duration = 0.5 },
    { type = "transition", state = "ENEMY_TURN_START" },
  }
})
```















