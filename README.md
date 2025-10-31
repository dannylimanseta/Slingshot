# Slingshot — Breakout x RPG (LÖVE)

A hybrid game combining Breakout-style physics gameplay with turn-based RPG combat. Your performance in the Breakout section determines damage dealt to enemies.

## Requirements
- LÖVE (Love2D) 11.x

## Run
```bash
# From the project directory
love .

# Or specify the full path
love "/path/to/Slingshot"
```

## Controls
- **Mouse**: Aim (dotted guide line shows trajectory with bounce prediction); Left-click to fire
- **A / D**: Move shooter left/right (hold to continue moving)

## Gameplay Overview
- The screen uses a virtual resolution (1280x720) that scales with letterboxing
- Center pane: Breakout gameplay with physics-based ball and blocks
- Background: RPG battle scene (Player vs Enemy) rendered behind the gameplay area
- **Turn Flow**:
  1. Aim and fire the ball
  2. Ball bounces off blocks and walls, accumulating score
  3. When ball reaches max bounces OR falls out the bottom, the turn ends
  4. Turn score and armor are applied to the enemy
  5. After a delay, enemy attacks the player
  6. Destroyed blocks respawn equal to the number destroyed last turn
  7. Next turn begins

## Scoring (Damage)
- **Base score on shot**: +3 points (configurable via `config.score.baseSeed`)
- **Per-hit reward**: +1 point for every block hit
- **Crit blocks**: Award x2 points (shows "x2" popup)
- Final turn score = base + all hit rewards (with crit multipliers)
- Enemy takes damage equal to final turn score (1:1 ratio)

## Block Types
Blocks spawn with 1 HP and are destroyed in one hit. There are three types:

1. **Damage Blocks** (Attack blocks)
   - Standard orange/red blocks
   - Award +1 point per hit

2. **Armor Blocks** (Defend blocks)
   - Blue blocks with shield icon
   - Grant temporary armor instead of score:
     - Blocks spawn at 1 HP → +3 ARM
     - Additional armor values: 2 HP → +2 ARM, 3 HP → +1 ARM (for future HP scaling)
   - Armor reduces incoming enemy damage for that turn only
   - Visual indicator appears next to player HP bar
   - Glowing border around HP bar when armor is active
   - Shatter effect when armor breaks

3. **Crit Blocks** (Critical blocks)
   - Rare spawns (8% chance)
   - Spawn in upper portion of playfield
   - Award x2 points per hit (shows "x2" popup)
   - Use crit sprite if available, otherwise fallback to attack sprite

## Ball Mechanics
- Ball speeds up slightly on each bounce (+1% per bounce)
- Starts at 40% speed, then eases to full speed over time
- Maximum 5 bounces before turn ends automatically
- Trail effect with gradient fade (head bright, tail dims)
- Glow effect with pulsing alpha
- When ball reaches max bounces or falls out the bottom, the turn ends and damage is applied to the enemy

## Right-Pane Battle
- **Visual Features**:
  - Player and Enemy sprites (with fallback circles if sprites missing)
  - HP bars with color coding (Player: pink, Enemy: green)
  - **Jackpot Damage Display**: Large accumulating damage number above enemy that updates in real-time as blocks are hit. Falls toward enemy when turn ends and shatters into fragments on impact. Crit hits cause the number to shake.
  - Armor indicator next to player HP bar (shows current armor value with icon)
  - Glowing border around player HP bar when armor is active
  - Border shatter fragments when armor breaks
  - Hit flashes with additive blending
  - Damage/armor popups with bounce animation
  - Lunge animations on attack
  - Knockback animations on hit
  - Screenshake on hits
  - Idle bob animation (vertical stretch)
  
- **Combat Flow**:
  - Player turn ends → player damage applied to enemy (with lunge animation)
  - Armor popup shows (if armor gained)
  - After delay, enemy attacks player
  - Damage mitigated by armor (armor popup shows reduction)
  - Armor resets to 0 after enemy turn
  - Win/lose states: enemy HP ≤ 0 (win), player HP ≤ 0 (lose)

## Block Respawn System
- After enemy turn ends, blocks respawn equal to the number destroyed in the last player turn
- New blocks spawn with animation (soft bounce-in from below)
- Uses spatial hash for efficient overlap checking
- Blocks maintain minimum gap spacing
- Crit blocks only spawn in upper portion of playfield

## Visual Effects
- **Ball**: Trail with shader-based soft edges, glow with pulse effect
- **Blocks**: Spawn animations, hit flashes, sprite support (attack/defend/crit)
- **Battle**: Lunge/knockback animations, screenshake, hit flashes, popups with icons, jackpot damage display with fall animation and shatter fragments
- **UI**: Dotted aim guide with bounce prediction, fade in/out based on canShoot state
- **Background**: Full-screen background image support

## Configuration (Single Source of Truth)
All tunables live in `src/config.lua`:

### Video
- `video.virtualWidth`, `video.virtualHeight`

### Playfield
- `playfield.margin`

### Ball
- `ball.radius`, `speed`, `maxBounces`, `spawnYFromBottom`
- `ball.easing.enabled`, `easing.startFactor`, `easing.easeK`
- `ball.bounceSpeedScale`
- `ball.trail.*` (enabled, width, maxPoints, sampleInterval, softness, color, colorStart, colorEnd, additive, overlap, taperPower, invert)
- `ball.glow.*` (enabled, radiusScale, color, pulse, pulseSpeed, pulseAmount, outerGlow.*)

### Blocks
- `blocks.count`, `sizeMin`, `sizeMax`, `baseSize`, `tweenK`, `flashDuration`, `flashPasses`, `flashAlphaScale`
- `blocks.armorSpawnRatio`, `critSpawnRatio`, `critMaxHeightFactor`
- `blocks.spriteScale`, `minGap`, `attemptsPerBlock`
- `blocks.spawnAnim.duration`, `spawnAnim.offset`, `spawnAnim.staggerDelay`
- `blocks.clustering.*` (enabled, clusterSizes, clusterAttempts, minRemainingForCluster)

### Score
- `score.baseSeed`, `rewardPerHit`, `tickerSpeed`, `critMultiplier`
- `score.rewardByHp` (maps block HP to score reward - currently unused, reserved for future HP scaling)
- `score.blockPopupLifetime`, `blockPopupFadeStart`, `blockPopupFadeMultiplier`, `blockPopupBounceHeight`

### Armor
- `armor.rewardByHp` (maps HP to armor reward)

### Battle
- `battle.playerMaxHP`, `enemyMaxHP`
- `battle.enemyDamageMin`, `enemyDamageMax`
- `battle.playerAttackDelay`, `enemyAttackDelay`, `enemyAttackPostArmorDelay`
- `battle.hitFlashDuration`, `hitFlashPasses`, `hitFlashAlphaScale`
- `battle.popupLifetime`, `popupBounceHeight`
- `battle.spriteScale`, `playerSpriteScale`, `enemySpriteScale`
- `battle.positionOffsetY`
- `battle.lungeDistance`, `lungeDuration`, `lungeReturnDuration`
- `battle.knockbackDistance`, `knockbackDuration`, `knockbackReturnDuration`
- `battle.shakeMagnitude`, `shakeDuration`
- `battle.idleBobScaleY`, `idleBobSpeed`
- `battle.jackpot.*` (offsetY, fallDelay, fallDuration, fallDistanceFactor, shatterFragments, fragmentLifetime, fragmentSpeed, critScale, shakeAmplitude, shakeSpeed, bobAmplitude, bobDuration)

### Shooter
- `shooter.speed`, `radius`, `spawnYFromBottom`
- `shooter.aimGuide.*` (enabled, length, dotSpacing, dotRadius, fade, alphaStart, alphaEnd, fadeSpeed)

### Assets
- `assets.images.*` (background, player, enemy, block_attack, block_defend, block_crit, icon_armor, icon_attack)
- `assets.fonts.*` (ui)

## Project Structure
```
conf.lua                  # LÖVE config
main.lua                  # Entry point, virtual resolution setup
README.md
src/
  config.lua              # All tunables (single source of truth)
  theme.lua               # Colors & fonts
  core/
    SceneManager.lua       # Scene management
    TurnManager.lua        # Turn state machine & event system
  scenes/
    SplitScene.lua         # Left/Right panes container
    GameplayScene.lua     # Breakout gameplay (center pane)
    BattleScene.lua       # RPG battle (background)
    EmptyScene.lua
  entities/
    Ball.lua              # Physics ball with trail/glow
    Block.lua             # Damage/Armor/Crit blocks (1 HP, sprite support)
    Shooter.lua           # Player-controlled shooter
  managers/
    BlockManager.lua      # Spawning, respawning, spatial hash
    ParticleManager.lua   # Particle effects
  systems/
    TurnActions.lua       # Turn action implementations (command pattern)
  utils/
    math2d.lua            # 2D math utilities
    collision.lua         # Collision helpers
    trail.lua             # Ball trail rendering
  ui/
    Bar.lua               # HP bar component
docs/
  TURN_MANAGEMENT_DESIGN.md      # Turn system architecture documentation
  TURN_MANAGEMENT_INTEGRATION.md # Integration guide
assets/
  fonts/                  # TTF fonts
  images/                  # Sprites (background, characters, blocks, icons)
```

## Turn Management System
The game uses a centralized turn management system that orchestrates the flow between player and enemy turns:

- **TurnManager** (`src/core/TurnManager.lua`): State machine with explicit turn states (INIT, PLAYER_TURN_START, PLAYER_TURN_ACTIVE, PLAYER_TURN_RESOLVING, ENEMY_TURN_START, ENEMY_TURN_RESOLVING, VICTORY, DEFEAT)
- **TurnActions** (`src/systems/TurnActions.lua`): Command pattern for sequential actions (wait, show indicators, apply damage, enemy attacks, spawn blocks, etc.)
- **Event System**: Components subscribe to turn events rather than polling state
- **Action Queue**: Sequential actions execute in order with timing control

The system provides clear separation between turn logic and game logic, making it easy to add new turn phases or modify the flow. See `docs/TURN_MANAGEMENT_DESIGN.md` for detailed architecture documentation.

## Technical Notes
- **Physics**: Uses `love.physics` (Box2D). Walls, bottom sensor, dynamic ball, static blocks
- **Performance**: Spatial hash for block overlap checking, particle counts tuned for performance
- **Visuals**: Sprite support with fallback shapes. Shader-based trail effects. Virtual resolution with letterboxing for consistent scaling
- **Architecture**: Single source of truth configuration, modular scene system, event-driven turn flow with centralized turn management

## License
Personal project; adapt as you wish.
