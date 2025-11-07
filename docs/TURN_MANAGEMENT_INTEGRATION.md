# Turn Management Integration Example

## Overview
This shows how to integrate the TurnManager with your existing game systems.

## Setup in SplitScene

```lua
-- In SplitScene:new()
local TurnManager = require("core.TurnManager")
local TurnActions = require("systems.TurnActions")

self.turnManager = TurnManager.new()
TurnActions.registerAll(self.turnManager)

-- Subscribe to turn events
self.turnManager:on("show_turn_indicator", function(data)
  if self.right and self.right.showTurnIndicator then
    self.right:showTurnIndicator(data.text, data.duration)
  end
end)

self.turnManager:on("apply_damage", function(data)
  if self.right and self.right.onPlayerTurnEnd then
    -- Apply damage through existing battle system
    local turnData = self.turnManager:getTurnData()
    self.right:onPlayerTurnEnd(turnData.score, turnData.armor)
  end
end)

self.turnManager:on("spawn_blocks", function(data)
  if self.left and self.left.respawnBlocks then
    self.left:respawnBlocks(data.count)
  end
end)

self.turnManager:on("state_enter", function(state)
  if state == TurnManager.States.PLAYER_TURN_ACTIVE then
    -- Enable player shooting
    if self.left then
      self.left.canShoot = true
    end
  end
end)
```

## Updating GameplayScene

```lua
-- In GameplayScene:update()
if self.turnManager then
  local state = self.turnManager:getState()
  
  if state == TurnManager.States.PLAYER_TURN_ACTIVE then
    -- Normal gameplay
    -- When turn ends (ball falls or max bounces):
    if self.turnEnded then
      self.turnManager:endPlayerTurn({
        score = self.score,
        armor = self.armorThisTurn,
        crits = self.critThisTurn,
        blocksDestroyed = self.destroyedThisTurn,
      })
      self.turnEnded = false
    end
  end
end
```

## Updating BattleScene

```lua
-- In BattleScene:update()
if self.turnManager then
  local state = self.turnManager:getState()
  
  if state == TurnManager.States.ENEMY_TURN_RESOLVING then
    -- Handle enemy attack timing through action queue
    -- Remove manual timer logic
  end
end

-- Subscribe to events
self.turnManager:on("enemy_attack", function(data)
  -- Perform enemy attack
  local dmg = love.math.random(data.min, data.max)
  -- ... attack logic
end)

self.turnManager:on("check_victory", function()
  if self.enemyHP <= 0 then
    self.turnManager:transitionTo(TurnManager.States.VICTORY)
  end
end)
```

## Benefits Achieved

1. **Centralized Logic**: All turn flow in one place
2. **Clear States**: Easy to see what phase we're in
3. **Action Sequencing**: Actions execute in order automatically
4. **Event-Driven**: Components react instead of polling
5. **Extensible**: Add new actions without touching core logic

## Adding New Features

### Example: Add a "Bonus Turn" feature

```lua
-- 1. Add new state (optional)
TurnManager.States.BONUS_TURN = "bonus_turn"

-- 2. Create new action
local BonusTurnAction = setmetatable({}, Action)
-- ... implement

-- 3. Register action
turnManager:registerAction("bonus_turn", BonusTurnAction)

-- 4. Use in turn flow
turnManager:queueAction("bonus_turn", { multiplier = 2 })
```

### Example: Add turn-based effects (poison, regen)

```lua
turnManager:on("state_enter", function(state)
  if state == TurnManager.States.PLAYER_TURN_START then
    -- Apply poison damage
    if player.poison > 0 then
      turnManager:queueAction("apply_damage", {
        target = "player",
        amount = player.poison,
      })
    end
    
    -- Apply regeneration
    if player.regen > 0 then
      turnManager:queueAction("heal", {
        target = "player",
        amount = player.regen,
      })
    end
  end
end)
```

## Migration Path

**Step 1**: Create TurnManager alongside existing system
**Step 2**: Migrate one phase at a time (start with player turn start)
**Step 3**: Replace manual timers with action queue
**Step 4**: Remove old callback-based system
**Step 5**: Add advanced features (undo, replay, analytics)

## Debugging

```lua
-- Enable debug logging
turnManager:on("state_enter", function(state, previous)
  print(string.format("[Turn %d] %s -> %s", 
    turnManager:getTurnNumber(), 
    previous, 
    state))
end)

-- View state history
for _, entry in ipairs(turnManager.stateHistory) do
  print(string.format("Turn %d: %s -> %s (t=%.2f)",
    entry.turn, entry.from, entry.to, entry.time))
end
```









