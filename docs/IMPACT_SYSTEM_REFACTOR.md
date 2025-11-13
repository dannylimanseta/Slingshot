# Impact System Refactoring Summary

## Overview
Refactored the impact/attack visual system from boolean-flag-driven to data-driven configuration for improved scalability and maintainability.

## What Changed

### Before (Boolean Hell)
```lua
-- Function with 11 parameters
function onPlayerTurnEnd(turnScore, armor, isAOE, blockHitSequence, baseDamage, 
                         orbBaseDamage, critCount, multiplierCount, 
                         isPierce, isBlackHole, isLightning)
  
-- Scattered conditionals everywhere
if isBlackHole then
  -- special behavior
end
if isLightning then  
  -- different special behavior
end

-- Tracking variables in GameplayScene
pierceThisTurn = false
blackHoleThisTurn = false
lightningThisTurn = false
```

### After (Data-Driven)
```lua
-- Single consolidated parameter
function onPlayerTurnEnd(turnData)
  -- turnData = { damage, armor, projectileId, isAOE, ... }
  
-- Centralized configuration
local behavior = impactConfigs.getBehavior(projectileId)
if not behavior.suppressInitialFlash then
  enemy.flash = ...
end
```

## Key Improvements

### 1. **Centralized Configuration** (`src/data/impact_configs.lua`)
All projectile-specific impact behaviors in one place:
- Attack delays
- Visual effect suppression flags
- Popup timing
- Impact animation types

### 2. **Reduced Parameter Count**
- `ImpactSystem.create`: **7 params → 1 object**
- `BattleScene:onPlayerTurnEnd`: **11 params → 1 object**
- `_createImpactInstances`: **7 params → 1 object**

### 3. **Removed Boolean Tracking**
Eliminated these from GameplayScene:
- ❌ `pierceThisTurn`
- ❌ `blackHoleThisTurn`
- ❌ `lightningThisTurn`

Uses `projectileId` directly instead.

### 4. **Backward Compatibility**
All functions support both old and new calling styles:
```lua
-- Old style still works (for any legacy code)
onPlayerTurnEnd(100, 5, false, {}, 100, 5, 0, 0, false, false, false)

-- New style (preferred)
onPlayerTurnEnd({ damage = 100, armor = 5, projectileId = "lightning", ... })
```

## Adding New Projectile Types

### Old System (Touched 8+ files)
1. Add boolean to GameplayScene (`newOrbThisTurn`)
2. Add boolean to SplitScene parameter passing
3. Add boolean to TurnManager turnData
4. Add boolean to BattleScene:onPlayerTurnEnd signature
5. Add boolean to _createImpactInstances signature
6. Add boolean to ImpactSystem.create signature
7. Add conditional logic in 6+ places
8. Add reset logic
9. Add tracking logic

### New System (Touch 2 files)
1. **Add config** in `impact_configs.lua`:
```lua
new_orb = {
  impactType = "custom_animation", -- or "standard"
  attackDelay = 0.3,
  suppressInitialFlash = false,
  suppressInitialKnockback = false,
  suppressInitialSplatter = false,
  suppressInitialParticles = false,
  popupDelay = 0,
}
```

2. **Add custom animation** (only if needed) in `ImpactSystem.lua`:
```lua
if impactType == "custom_animation" then
  return ImpactSystem.createCustomAnimation(scene, blockCount, isAOE)
end
```

## Files Modified
- ✅ `src/data/impact_configs.lua` (NEW - centralized config)
- ✅ `src/scenes/SplitScene.lua` (passes projectileId)
- ✅ `src/scenes/BattleScene.lua` (uses turnData object)
- ✅ `src/scenes/battle/ImpactSystem.lua` (data-driven dispatch)
- ✅ `src/scenes/GameplayScene.lua` (removed boolean tracking)

## Scalability Improvement
- **Before**: Adding 5 more projectiles = **40+ code changes** across 8 files
- **After**: Adding 5 more projectiles = **5-10 code changes** in 1-2 files

## Testing Checklist
- [x] Lightning Orb: Streaks in gameplay, lightning strikes in battle
- [x] Black Hole: Gameplay effect, shatter animation in battle  
- [x] Pierce: Works normally
- [x] Twin Strike: Works normally
- [x] Standard projectiles: Work normally
- [x] AOE behavior: Still functions correctly
- [x] Backward compatibility: Old calling style still works

## Future-Proofing
The system now scales linearly instead of exponentially:
- **Easy to add**: New projectile types
- **Easy to modify**: Behavior tweaks in one place
- **Easy to test**: Isolated configurations
- **Easy to maintain**: Clear separation of concerns

## Design Pattern
**Strategy Pattern + Registry**
- Impact configs act as strategy definitions
- ImpactSystem dispatches based on strategy type
- Behavior variations configured declaratively

