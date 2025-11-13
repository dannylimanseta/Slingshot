# BattleState Refactor Plan

Refactor goal: replace the fragmented battle data spread across `GameplayScene`, `BattleScene`, `TurnManager`, `PlayerState`, projectile/effect managers, and various UI consumers with a single authoritative module: `core/BattleState.lua`.

This document captures the design, schema, helper API, event flow, and migration steps for the staged rollout.

---

## 1. Objectives

- **Single source of truth** for all run-time battle data (player, enemies, blocks, projectiles, turn lifecycle, analytics).
- **Explicit mutators** that describe intent (e.g., `BattleState:applyPlayerDamage`) instead of ad-hoc field edits scattered across files.
- **Event-driven updates** so UI, FX, logs, and analytics subscribe to state changes rather than polling or relying on side effects.
- **Testability**: ability to take snapshots, replay turn flows, and create deterministic battle simulations.
- **Safety**: minimize the risk of stale or out-of-sync state (e.g., `GameplayScene.canShoot` vs `TurnManager` vs `SplitScene` proxies).

---

## 2. Current Data Sources

| Area | Current Owner(s) | Notes |
|------|------------------|-------|
| Player HP / Armor / Damage queue | `BattleScene`, `PlayerState`, `TurnManager` | Lives partly in PlayerState (persistent) and partly in BattleScene (displayHP). |
| Enemies (HP, intents, animations) | `BattleScene` | `enemies[]` table with per-enemy timers and effects. |
| Blocks (grid, calcified, combos) | `GameplayScene`, `BlockManager`, `ProjectileEffects` | GameplayScene fields track combo, blocks hit, etc. |
| Projectiles / Balls | `BallManager`, `GameplayScene`, `SplitScene` proxies | We recently added compatibility proxies. |
| Turn phase / action queue | `TurnManager` | Maintains state, actionQueue, currentState. |
| Damage / heal / armor tallies | `GameplayScene`, passed to `TurnManager:endPlayerTurn`. |
| Visual effects state | `VisualEffects`, partially driven off state booleans. |
| Combo tracking / analytics | `GameplayScene` locals. |
| Delay timers (enemy attack delay, player attack delay) | `BattleScene`, `TurnManager`. |
| Shared flags (e.g., `canShoot`, `hasAliveBall`) | `GameplayScene`, `SplitScene`, `BattleScene`. |

---

## 3. Proposed BattleState Schema

```lua
BattleState = {
  meta = {
    battleId = uuid,
    seed = number,
    startTime = os.time(),
  },

  turn = {
    number = 0,
    phase = "player_active", -- init | player_start | player_active | player_resolving | enemy_start | enemy_resolving | victory | defeat
    queue = {},              -- mirrors TurnManager.actionQueue (consider migrating to BattleState entirely)
    currentAction = nil,
    timers = {
      action = 0,
      enemyAttackDelay = 0,
      playerAttackDelay = 0,
    },
  },

  player = {
    hp = 0,
    maxHP = 0,
    armor = 0,
    combo = {
      count = 0,
      timeout = 0,
      lastHitAt = 0,
    },
    healingPending = 0,
    armorPending = 0,
    status = {
      stunned = false,
      buffs = {},
      debuffs = {},
    },
    resources = {
      energy = 0,      -- future proofing
      mana = 0,
    },
  },

  enemies = {
    -- array of enemy states, each:
    -- { id, name, hp, maxHP, armor, intent = {...}, timers = {...}, isDead, status = {...}, visuals = {...} }
  },

  blocks = {
    grid = {},            -- block definitions (delegate to BlockManager but store high-level info)
    destroyedThisTurn = 0,
    respawnPending = 0,
    calcified = {},       -- quick lookup for calcified block ids
  },

  projectiles = {
    balls = {},           -- array of active balls (ids, position, type, owner)
    lightning = {},       -- active lightning chains, streak paths
    blackHoles = {},      -- as currently tracked in ProjectileEffects
  },

  effects = {
    screenshake = {
      magnitude = 0,
      duration = 0,
      remaining = 0,
    },
    popups = {},          -- scoreboard popups to show
    indicators = {},      -- turn indicator, enemy warning banners, etc.
  },

  rewards = {
    score = 0,
    armorThisTurn = 0,
    healThisTurn = 0,
    critCount = 0,
    multiplierCount = 0,
    aoeFlag = false,
    blockHitSequence = {},
    baseDamage = 0,
  },

  flags = {
    canShoot = true,
    ballsInFlight = 0,
    pendingEnemyTurn = false,
    victory = false,
    defeat = false,
  },
}
```

> Implementation detail: `BlockManager` and `BallManager` will still maintain their own rich objects for physics/visuals, but they will synchronize the high-level state (counts, ids, statuses) with BattleState so other systems can reason about the game without needing internal pointers.

---

## 4. Mutator & Query API

Goals:
- Provide explicit intent (e.g., “apply damage to enemy”) instead of raw table edits.
- Emit events describing what changed.
- Avoid accidental partial updates.

### Proposed Helper Set

```lua
-- Player
BattleState:setPlayerHP(amount)
BattleState:applyPlayerDamage(amount, source?)
BattleState:applyPlayerArmor(amount)
BattleState:setCanShoot(bool)

-- Enemies
BattleState:getEnemy(enemyId)
BattleState:setEnemyIntent(enemyId, intentTable)
BattleState:applyEnemyDamage(enemyId, amount, opts)
BattleState:setEnemyStatus(enemyId, statusKey, value)

-- Blocks
BattleState:registerBlockHit(blockId, data)
BattleState:setBlocksInFlight(count)

-- Projectiles
BattleState:registerBall(ball)
BattleState:removeBall(ballId)
BattleState:setLightningSequence(ballId, sequenceData)
BattleState:setBlackHoles(list)

-- Turn lifecycle
BattleState:setTurnPhase(phase, opts)
BattleState:enqueueAction(action)
BattleState:dequeueAction()

-- Rewards / scoring
BattleState:trackDamage(kind, amount)
BattleState:resetTurnRewards()

-- Utility
BattleState:snapshot()     -- deep copy for debugging/testing
BattleState:restore(data)  -- restore snapshot (for tests)
```

### Event Emitter

Reuse or wrap the existing event system (similar to `TurnManager:on/emit`):

```lua
BattleState:on("player_hp_changed", listener)
BattleState:on("enemy_intent_changed", listener)
BattleState:on("ball_registered", listener)
BattleState:emit("turn_phase_changed", newPhase, oldPhase)
```

Events should fire once per mutator call, with coalescing where sensible (e.g., block hits may batch).

---

## 5. Integration & Migration Plan

### Stage 1 — **Design (current stage)**
- ✅ Document schema (this file).
- ✅ List mutators and events.
- ✅ Map staged migration tasks.

### Stage 2 — **BattleState Core Module**
- Create `src/core/BattleState.lua`.
- Implement schema initialization from `PlayerState`, battle profile, and RNG seed.
- Provide mutators, event bus, snapshot utilities.
- Add unit tests for initialization and core mutators (Busted/Lust).

### Stage 3 — **GameplayScene Integration**
- Instantiate `BattleState` when gameplay starts.
- Update `GameplayScene` to push ball/block/combo changes via BattleState mutators (instead of local fields).
- Remove now-redundant fields (`score`, `armorThisTurn`, `blackHoles`, proxies).
- Ensure `BallManager` / `ProjectileEffects` call BattleState to register/deregister projectiles and effects.
- Migrate `GameplayScene` read paths to pull from BattleState (e.g., `canShoot`, combo counts).
- Emit events to `BattleScene`/`SplitScene` instead of direct `self.ball` queries.

### Stage 4 — **BattleScene & TurnManager**
- `BattleScene:new()` populates UI from `BattleState.player`, `BattleState.enemies`.
- Move enemy intent storage into BattleState (`BattleState:setEnemyIntent()`).
- TurnManager reads/writes `BattleState.turn.phase`, `BattleState.turn.queue` instead of local fields.
- Replace `TurnManager.turnData` merges with writing results into `BattleState.rewards`.
- Ensure start/end turn transitions drive BattleState and rely on events.

### Stage 5 — **Consumers (UI, FX, SplitScene)**
- Replace direct field reads with subscriptions or queries:
  - TopBar listens to `player_hp_changed`.
  - ImpactSystem reads `BattleState.rewards`.
  - SplitScene checks `BattleState.flags.canShoot`, `BattleState.projectiles.balls`.
  - Visual effects respond to events like `screenshake_triggered`.
- Remove now-unused proxies/resync logic (e.g., `GameplayScene.ball`, `blackHoles`).

### Stage 6 — **Testing & Diagnostics**
- Add integration tests covering:
  - Player turn shot → damage resolution → enemy turn start.
  - Lightning chain.
  - Black hole effect removing blocks.
  - Enemy intent cycle.
- Implement dev command to dump current BattleState (for debugging/test harness).
- Update docs (`docs/BATTLE_STATE_PLAN.md`, `docs/TURN_MANAGEMENT_DESIGN.md`).

---

## 6. Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Partial migration leading to duplicate state | Stage the rollout carefully; feature flags or bridging layer while porting each system. |
| Performance overhead from deep copies or events | Keep mutators in-place but disciplined; avoid excessive allocations in real-time loops. |
| Manager interplay (BlockManager/BallManager) still needs internal precision | Keep managers authoritative for physics, but expose simplified view via BattleState. |
| UI flicker due to event order changes | Provide deterministic event order (e.g., state update first, then emit). Build unit tests for UI data. |
| Regression in turn timing | Add tests mirroring `SplitScene` logic before removing old proxies. |

---

## 7. Deliverables Per Stage

| Stage | Deliverable |
|-------|-------------|
| 1 | ✅ This design document |
| 2 | `core/BattleState.lua`, unit tests, initialization from profile |
| 3 | `GameplayScene` refactored to use BattleState; removal of local state duplicates |
| 4 | `BattleScene`, `TurnManager`, `SplitScene` consuming BattleState directly |
| 5 | UI/FX subscribers (`TopBar`, `VisualEffects`, `ImpactSystem`, logs) wired to events |
| 6 | Integration tests, debug utilities, documentation updates |

---

## 8. Next Actions

1. Build `core/BattleState.lua` skeleton with schema + events.
2. Write tests verifying initialization and key mutators (`setCanShoot`, `applyPlayerDamage`, `registerBall`).
3. Draft migration PR for `GameplayScene` to adopt BattleState while keeping compatibility proxies temporarily (feature flag).
4. Coordinate with TurnManager migration once GameplayScene is stable.

---

*Refactor approved by: TBD*  
*Last updated: 2025-11-13*


