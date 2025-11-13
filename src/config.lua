local config = {}

-- Video: virtual resolution (for consistent scaling)
config.video = {
  virtualWidth = 1280,
  virtualHeight = 720,
  -- Supersampling for smooth scaling on larger monitors
  -- Renders at higher resolution internally, then downscales for crisp visuals
  supersampling = {
    enabled = true,
    factor = 2, -- 2x supersampling (renders at 2560x1440, displays at 1280x720)
    -- factor = 1 disables supersampling (renders at native resolution)
    -- factor = 2 gives 2x supersampling (recommended for most games)
    -- factor = 4 gives 4x supersampling (higher quality but more GPU intensive)
  },
}

-- Scene transition settings (used by SceneManager)
config.transition = {
  duration = 1.2, -- seconds for transition animation (faster, snappy transitions)
  gridWidth = 28, -- grid cells horizontally
  gridHeight = 15, -- grid cells vertically
  fadeType = 0, -- 0 = vertical (bottom-to-top), 1 = horizontal, 2 = center
}

-- Critical tunables (single source of truth)
config.playfield = {
  margin = 24, -- pixels from window edges for spawning blocks
  centerWidthFactor = 0.4, -- center playfield width as fraction of screen (reduced by 20% from 0.5)
  maxHeightFactor = 0.6, -- maximum playfield height as fraction of screen height (increased from 0.6 to reduce occlusion)
  horizontalSpacingFactor = 1.2, -- factor to scale horizontal spacing (~41/36 of previous; ~+5px between grid columns)
  topBarHeight = 60, -- height of top bar UI (pixels)
}

config.ball = {
  radius = 7, -- reduced for smaller visual/physics size
  speed = 700, -- pixels per second (reduced by 30% from 1000)
  maxBounces = 5,
  spawnYFromBottom = 40, -- launch position offset from bottom
  -- Spread shot projectile (alternates every turn)
  spreadShot = {
    enabled = true,
    count = 3, -- number of projectiles
    maxBounces = 3, -- each projectile bounces 3 times
    spreadAngle = 0.29, -- cone spread in radians (~16.6 degrees, increased by 8 degrees)
    radiusScale = 0.7, -- 30% smaller than regular projectile
    sprite = "assets/images/orb_multi_strike.png", -- sprite for spread projectiles
    trail = {
      enabled = true,
      width = 16.38, -- 30% smaller than regular trail (23.4 * 0.7)
      maxPoints = 32,
      sampleInterval = 0.016, -- seconds between samples (~60Hz)
      softness = 0.25, -- 0..0.5 edge softness across width
      color = { 1.0, 0.518, 0.0, 0.6 }, -- Hex #FF8400
      colorStart = { 1.0, 0.518, 0.0, 0.6 }, -- Hex #FF8400
      colorEnd = { 1.0, 0.518, 0.0, 0.6 }, -- Hex #FF8400
      additive = true,
      overlap = 5.46, -- 30% smaller than regular overlap (7.8 * 0.7)
      taperPower = 1.4, -- controls how quickly width tapers toward tail
      invert = true, -- invert along-length gradient (bright at head)
    },
  },
  -- Twin strike (orb_twin_strike) visual settings
  twinStrike = {
    trail = {
      enabled = true,
      width = 23.4, -- match base trail width
      maxPoints = 32,
      sampleInterval = 0.016,
      softness = 0.25,
      color = { 0.765, 0.298, 0.298, 0.6 }, -- Hex #C34C4C
      colorStart = { 0.765, 0.298, 0.298, 0.6 }, -- Hex #C34C4C
      colorEnd = { 0.765, 0.298, 0.298, 0.6 }, -- Hex #C34C4C
      additive = true,
      overlap = 7.8, -- match base overlap
      taperPower = 1.4,
      invert = true,
    },
  },
  -- Lightning orb visual settings
  lightning = {
    trail = {
      enabled = true,
      width = 23.4, -- match base trail width
      maxPoints = 32,
      sampleInterval = 0.016,
      softness = 0.25,
      color = { 0.3, 0.7, 1.0, 0.7 }, -- Bright cyan-blue
      colorStart = { 0.3, 0.7, 1.0, 0.7 }, -- Bright cyan-blue
      colorEnd = { 0.5, 0.9, 1.0, 0.5 }, -- Lighter cyan-blue
      additive = true,
      overlap = 7.8, -- match base overlap
      taperPower = 1.4,
      invert = true,
    },
    gridJumpDistance = 3, -- number of grid spaces to jump between blocks
    bounceDelay = 0.2, -- delay in seconds between each bounce/teleport
    -- Lightning streak visual settings
    streakLifetime = 0.8, -- How long streaks stay visible (seconds) - faster fade
    streakAnimDuration = 0.18, -- How long the streak takes to animate from start to end - slower glow
    streakOuterWidth = 12, -- Outer glow width (50% thicker)
    streakMainWidth = 6, -- Main streak width (50% thicker)
    streakCoreWidth = 3, -- Core streak width (50% thicker)
    streakOuterAlpha = 0.4, -- Outer glow alpha
    streakMainAlpha = 0.85, -- Main streak alpha
    streakCoreAlpha = 1.0, -- Core streak alpha
  },
  easing = {
    enabled = true,
    startFactor = 0.4, -- start at 40% of target speed
    easeK = 6, -- higher = faster approach to target
  },
  bounceSpeedScale = 1.01, -- +8% target speed per bounce
  trail = {
    enabled = true,
    width = 18, -- reduced thickness
    maxPoints = 32,
    sampleInterval = 0.016, -- seconds between samples (~60Hz)
    softness = 0.25, -- 0..0.5 edge softness across width
    color = { 1, 1, 1, 0.6 }, -- White
    colorStart = { 1, 1, 1, 0.6 }, -- White
    colorEnd = { 1, 1, 1, 0.6 }, -- White
    additive = true,
    overlap = 7.8, -- pixels to extend each segment at both ends to cover joins (increased by 30%, was 6)
    taperPower = 1.4, -- controls how quickly width tapers toward tail
    invert = true, -- invert along-length gradient (bright at head)
  },
  glow = {
    enabled = true,
    radiusScale = 4.5, -- multiple of ball radius (increased for stronger glow)
    color = { 1, 0.65, 0.2, 0.4 }, -- reduced alpha for softer glow (orange)
    pulse = true,
    pulseSpeed = 1.6,
    pulseAmount = 0.1, -- 0..1 additional alpha (reduced)
    outerGlow = {
      enabled = true,
      radiusScale = 7.0, -- outer glow layer for illumination
      color = { 1, 0.65, 0.2, 0.1 }, -- softer outer glow (orange, reduced)
    },
    burst = {
      enabled = true,
      duration = 0.2, -- seconds the burst effect lasts (increased for more visibility)
      intensityMultiplier = 9.5, -- how much brighter the glow gets (multiplies alpha) - increased from 2.5
      radiusMultiplier = 1.6, -- how much larger the glow gets during burst - increased from 1.3
    },
  },
}

config.blocks = {
  count = 24,
  sizeMin = { w = 48, h = 20 },
  sizeMax = { w = 96, h = 28 },
  attemptsPerBlock = 24, -- attempts to place a non-overlapping block
  baseSize = 24, -- block side = baseSize (constant size)
  tweenK = 12, -- how quickly size eases to target per second
  flashDuration = 0.08, -- seconds of white flash on hit (if not destroyed)
  flashPasses = 2, -- additive white overlay passes for stronger flash
  flashAlphaScale = 1.0, -- multiply base flash alpha (0..1)
  armorSpawnRatio = 0.25, -- 25% of spawned blocks are armor blocks (rest are damage)
  spriteScale = 2, -- visual scale multiplier for block sprites
  -- Placement controls
  minGap = -11, -- minimum pixels of space between blocks (prevents touching)
  -- Grid snapping for formation editor
  gridSnap = {
    enabled = true,
    cellSize = 38, -- pixels per grid cell (reduced slightly for better spacing)
    showGrid = false, -- show grid visually (toggle with G key)
    padding = 30, -- padding around grid edges (pixels) to allow edge block placement
    sidePadding = 40, -- additional padding on left and right sides (pixels)
  },
  -- Spawn animation for newly added blocks
  spawnAnim = {
    duration = 0.35, -- seconds
    offset = 28, -- starting offset in pixels below final position
    staggerDelay = 0.015, -- faster stagger: halve delay between each block's animation start
  },
  -- Rare crit block spawn ratio (0..1)
  critSpawnRatio = 0.08,
  -- Crit blocks spawn in a higher band (fraction of playfield height)
  critMaxHeightFactor = 0.4,
  -- Clustering: blocks spawn in rectangular clusters
  clustering = {
    enabled = true,
    clusterSizes = {9, 12}, -- valid cluster sizes (9 = 3x3, 12 = 3x4 or 4x3)
    clusterAttempts = 12, -- attempts to place entire cluster before falling back to individual blocks
    minRemainingForCluster = 9, -- if fewer blocks remain, place individually
  },
  -- Pulse animation: subtle brightness pulsing
  pulse = {
    enabled = true,
    speed = 1.2, -- pulse speed (cycles per second)
    brightnessVariation = 0.08, -- +/- 10% brightness variation
  },
}

config.score = {
  baseSeed = 3,
  rewardByHp = { [5] = 1, [4] = 2, [3] = 3, [2] = 4, [1] = 5 },
  rewardPerHit = 1,
  tickerSpeed = 10, -- points per second smoothing toward current score (base speed)
  critMultiplier = 2,
  -- Apply once if a soul block was hit this turn
  powerCritMultiplier = 4,
  blockPopupLifetime = 0.8,
  blockPopupFadeMultiplier = 0.5, -- 50% faster fade within fade window (1.0 = baseline)
  blockPopupFadeStart = 0.7, -- start fading at 70% of lifetime (last 30%)
  blockPopupBounceHeight = 40, -- vertical distance for +X popup bounce
  -- Dynamic ticker: speeds up for large damage deltas
  dynamicTicker = {
    enabled = true,
    threshold = 20, -- damage delta threshold to start speeding up (points)
    speedMultiplier = 3, -- multiplier applied above threshold (3x faster at threshold)
    maxSpeed = 60, -- maximum ticker speed (points per second)
  },
}

config.armor = {
  rewardByHp = { [1] = 3, [2] = 2, [3] = 1 },
}

-- Healing config
config.heal = {
  potionHeal = 8, -- HP restored when hitting a potion block
}

config.shooter = {
  speed = 520, -- px/s
  radius = 12, -- half-width of diamond from center to a corner
  spawnYFromBottom = 36,
  aimGuide = {
    enabled = true,
    dotted = true,
    length = 600,
    dotSpacing = 16,
    dotRadius = 2,
    fade = true,
    alphaStart = 1.0,
    alphaEnd = 0.0,
    fadeSpeed = 6, -- how quickly guide fades in/out when canShoot toggles
  },
  -- Infinite carousel for projectile slots
  carousel = {
    enabled = true,
    scrollSpeed = 8, -- tween speed for smooth scrolling
    -- Dynamic fade distances (calculated per projectile count)
    fadeStartOffset = 0.3, -- distance beyond last slot where fade begins (tight, prevents duplicates)
    fadeEndOffset = 0.6, -- distance beyond last slot where fully transparent
    fadeInStartOffset = 0.5, -- distance before last slot where incoming ball starts fading in (tight to prevent +1)
    fadeInEndOffset = 0.2, -- distance before last slot where incoming ball becomes fully visible
    depthFade = 0.15, -- 0..1, how much to dim slots based on distance (Option B)
    ballSpacingMultiplier = 2, -- multiplier for spacing between balls (shooter.radius * this)
    -- maxVisibleSlots is now AUTO-CALCULATED from equippedProjectiles length
  },
}

-- Gameplay effects
config.gameplay = {
  -- Combo system for multi-block hits
  comboWindow = 0.5, -- seconds between hits to count as combo
  comboShake = {
    baseMagnitude = 2, -- base shake for 2-block combo (pixels)
    scalePerCombo = 0.5, -- additional shake per extra block in combo
    maxMagnitude = 8, -- maximum shake magnitude (pixels)
    duration = 0.15, -- shake duration (seconds)
  },
}

-- Battle config
config.battle = {
  playerMaxHP = 60,
  enemyMaxHP = 80,
  enemyDamageMin = 3,
  enemyDamageMax = 8,
  enemy2MaxHP = 50,
  enemy2DamageMin = 3,
  enemy2DamageMax = 5,
  enemy2SpriteScale = 1.6, -- visual scale multiplier for enemy2
  playerAttackDelay = 1.0,
  enemyAttackDelay = 1.5,
  enemyAttackPostArmorDelay = 0.3,
  hitFlashDuration = 0.5,
  hitFlashPasses = 3, -- draw additive flash this many times for stronger effect
  hitFlashAlphaScale = 0.4, -- multiply base flash alpha (clamped to 1) - reduced from 1.0 to tone down intensity
  popupLifetime = 0.8,
  popupBounceHeight = 42, -- vertical distance for damage popup bounce (reduced by 30% to avoid topbar)
  popupFadeStart = 0.7, -- start fading at 70% of lifetime (last 30%)
  popupFadeMultiplier = 0.5, -- 50% faster fade within fade window (1.0 = baseline)
  hpBarTweenSpeed = 8, -- HP bar tween speed (how quickly bar moves toward actual HP)
  spriteScale = 4, -- global fallback (reduced by 20%)
  playerSpriteScale = 3.84, -- increased by 20% from 3.2
  enemySpriteScale = 4, -- reduced by 20%
  positionOffsetY = 50, -- Reduced by 100px to avoid tooltip occlusion
  lungeDistance = 80,
  lungeDuration = 0.168, -- 40% slower than original 0.12
  lungeReturnDuration = 0.182, -- 40% slower than original 0.13
  lungePauseDuration = 0.42, -- 40% slower than original 0.3
  shakeMagnitude = 10,
  shakeDuration = 0.25,
  -- Knockback on hit
  knockbackDistance = 18, -- 50% more knockback distance (was 12)
  knockbackDuration = 0.08,
  knockbackReturnDuration = 0.12,
  -- Player lunge speed streaks
  speedStreaks = {
    enabled = true,
    emitRate = 90, -- streaks per second during forward phase
    lifetimeMin = 0.12,
    lifetimeMax = 0.22,
    speedMin = -900, -- px/s (leftward)
    speedMax = -600,
    lengthMin = 24,
    lengthMax = 60,
    thickness = 6, -- increased thickness for more visible streaks
    alpha = 0.45,
    jitterY = 18, -- vertical jitter around mid-height
  },
  -- Idle bob (vertical-only stretch)
  idleBobScaleY = 0.03, -- +3% max additional height
  idleBobSpeed = 1.2,   -- cycles per second
  -- Pulse animation: subtle brightness pulsing for characters
  pulse = {
    enabled = true,
    speed = 1.2, -- pulse speed (cycles per second)
    brightnessVariation = 0.08, -- +/- 8% brightness variation
  },
  -- Impact animation
  impactFps = 70, -- frames per second for impact sprite animation
  impactScale = 1.3, -- scale multiplier for impact sprite (reduced by 40% from 1.6)
  impactStaggerDelay = 0.15, -- delay between each impact sprite for staggered slashes (seconds)
  -- Jackpot damage number display (above enemy)
  jackpot = {
    offsetY = 220,           -- distance above enemy head where number hovers
    fallDelay = 0.0,         -- start immediately (reduced by 0.2s)
    fallDuration = 0.25,     -- duration of crash animation
    fallDistanceFactor = 0.5, -- 1 = to enemy top, 0.5 = halfway
    shatterFragments = 18,   -- how many shards spawn on impact
    fragmentLifetime = 0.5,  -- lifetime of each shard
    fragmentSpeed = 320,     -- base speed of shards
    -- Crit visual treatment
    critScale = 1.5,         -- kept for fallback; jackpot uses larger font for crispness
    shakeAmplitude = 3,      -- px jitter radius for crit shaking (reduced)
    shakeSpeed = 42,         -- shake oscillation speed (50% faster)
    -- Bob when jackpot increments
    bobAmplitude = 8,        -- px upward bob peak
    bobDuration = 0.18,      -- seconds for one bob cycle
  },
  -- Enemy death disintegration effect
  disintegration = {
    duration = 1.5,          -- seconds for full disintegration
    noiseScale = 20,         -- noise scale for disintegration pattern
    thickness = 0.25,        -- thickness of disintegration edge
    lineColor = {1.0, 0.3, 0.1, 1.0}, -- RGBA color of disintegration lines (orange)
    colorIntensity = 2.0,    -- intensity multiplier for line color
  },
  -- Foreground fog effect
  fog = {
    enabled = true,          -- enable/disable fog effect
    cloudDensity = 0.8,     -- overall density [0, 1] (reduced from 1.0 to prevent white screen)
    noisiness = 0.5,        -- overall strength of the noise effect [0, 1]
    speed = 0.13,             -- controls the animation speed [0, 0.1 ish)
    cloudHeight = 20.0,       -- (inverse) height of the input gradient [0, ...)
    startY = 0.0,           -- normalized Y (0=top, 1=bottom) where fog starts
  },
}

-- Player loadout: which projectiles are equipped (in rotation order)
config.player = {
  -- Array of projectile IDs that appear in the shooter carousel
  -- Order matters: this is the sequence they rotate through
  equippedProjectiles = {
    "lightning",     -- Lightning Orb (Level 1) - 1st slot
    "strike",        -- Strike (Level 1)
  },
}

-- Map exploration meta game config
config.map = {
  gridSize = 64, -- pixels per grid cell
  movesPerDay = 10, -- tighter daily budget to encourage steady forward progress
  totalDays = 30, -- campaign length in days
  playerMoveSpeed = 200, -- pixels per second for movement animation
  -- Visual settings
  nodeRadius = 20, -- visual radius of nodes (legacy, may be removed)
  nodeSpacing = 80, -- minimum spacing between nodes (legacy, may be removed)
  -- Camera/viewport settings
  cameraFollowSpeed = 8, -- tween speed for camera following player
  viewportPadding = 100, -- padding around viewport edges
  -- Player glow visual
  playerGlow = {
    tileScale = 16.8, -- size in tiles (previous 11.2 * 1.5)
  },
  -- Distance fog/fading effect
  distanceFog = {
    enabled = true, -- enable distance-based fading
    fadeStartRadius = 300, -- radius in pixels where fading begins (fully visible inside)
    fadeEndRadius = 500, -- radius in pixels where fading ends (minimum alpha reached)
    minAlpha = 0.03, -- minimum alpha value for objects at max distance (0% = fully transparent)
  },
  -- Rest site lighting effect
  restLighting = {
    enabled = true, -- enable rest site lighting
    glowRadius = 150, -- radius in pixels where objects are lit up
    lightIntensity = 0.5, -- additional alpha boost for objects near rest sites (0.0 to 1.0)
    pulsateSpeed = 1.0, -- pulsation speed (oscillations per second) - reduced for slower campfire effect
    pulsateSizeVariation = 0.15, -- size variation (15% larger/smaller)
    pulsateAlphaVariation = 0.2, -- alpha variation (20% brighter/dimmer)
  },
  -- Tree sway animation
  treeSway = {
    speed = 0.5, -- sway speed (oscillations per second)
    maxAngle = 0.03, -- maximum rotation angle in radians (about 1.7 degrees) - reduced intensity
    maxShear = 0.05, -- maximum horizontal shear for skewing effect
    phaseVariation = 2.0, -- variation in phase offset between trees
  },
  -- Enemy bobbing animation
  enemyBob = {
    speed = 1.2, -- bobbing speed (oscillations per second)
    heightVariation = 0.03, -- vertical scale variation as fraction (3%)
    phaseVariation = 1.5, -- variation in phase offset between enemies
  },
  -- Rest node bobbing and skewing animation
  restBob = {
    speed = 1.0, -- bobbing speed (oscillations per second)
    heightVariation = 0.03, -- vertical scale variation as fraction (3%)
    maxShear = 0.04, -- maximum horizontal shear for skewing effect (reduced intensity)
    phaseVariation = 1.5, -- variation in phase offset between rest nodes
  },
  -- Player bobbing animation during movement
  playerBob = {
    speed = 3.0, -- bobbing speed (oscillations per second) - faster for movement
    amplitude = 2, -- vertical offset in pixels (how much player bobs up/down)
  },
  -- Player vertical positioning offset
  playerVerticalOffset = 35, -- pixels to offset player downward from tile center
  -- Hold-to-move repeat behavior for WASD keys
  movementRepeat = {
    initialDelay = 0.35, -- seconds to wait before first auto-repeat
    interval = 0.12, -- seconds between subsequent auto-moves while holding
  },
  -- Darkening effect when player runs out of turns
  noTurnsDarkening = {
    enabled = true, -- enable darkening when out of turns
    alpha = 0.6, -- darkness overlay alpha (0.0 = no darkening, 1.0 = fully black)
    color = {0, 0, 0}, -- RGB color for the darkening overlay (black)
    tweenSpeed = 4, -- speed of the darkening transition (higher = faster)
  },
  -- Map generation parameters
  generation = {
    width = 90, -- expanded grid width for longer routes
    height = 68, -- expanded grid height for more exploration space
    corridor = {
      edgeMargin = 4, -- keep the primary spine comfortably away from map borders
      mainSegmentCount = 12, -- additional directional pushes to stretch the main corridor
      jitterChance = 0.18, -- minimal drift keeps corridors needle-thin
      maxStraightLength = 5, -- maximum consecutive moves in same direction before forcing a turn
      branchCount = 18, -- additional optional branches off the spine
      branchLengthMin = 13, -- minimum length of a branch (tiles)
      branchLengthMax = 31, -- maximum length of a branch (tiles)
      branchTurnChance = 0.22, -- very few turns keep branches straight
      widenChance = 0.01, -- almost never widen corridors
    },
    treasure = {
      count = 5, -- maximum number of treasures to place
      minSpacing = 12, -- enforce spacing between treasures to spread them around
    },
    groundSpriteChance = 0.06, -- chance per ground tile to receive a decorative sprite
    enemy = {
      min = 14,
      max = 16,
      minSpacing = 6,
      minDistanceFromStart = 9,
    },
    event = {
      min = 5,
      max = 6,
      minSpacing = 6,
      minDistanceFromStart = 7,
    },
    rest = {
      min = 5,
      max = 6,
      minSpacing = 7,
      minDistanceFromStart = 6,
    },
    merchant = {
      min = 4,
      max = 5,
      minSpacing = 6,
      minDistanceFromStart = 9,
    },
  },
}

-- Asset paths (relative to project root)
config.assets = {
  images = {
    background = "assets/images/bg_1.png",
    player = "assets/images/player_char_1.png",
    enemy = "assets/images/enemy_1.png",
    enemy2 = "assets/images/enemy_2.png",
    ball = "assets/images/orb_strike.png",
    ball_2 = "assets/images/orb_multi_strike.png", -- spread shot projectile sprite
    ball_3 = "assets/images/orb_twin_strike.png", -- twin strike projectile sprite
    block_attack = "assets/images/block_attack.png",
    block_defend = "assets/images/block_defend.png",
    block_crit = "assets/images/block_crit.png",
    block_crit_2 = "assets/images/block_crit_2.png",
    block_aoe = "assets/images/block_aoe.png",
    block_heal = "assets/images/block_heal.png",
    icon_armor = "assets/images/icon_armor.png",
    icon_attack = "assets/images/icon_attack.png",
    icon_heal = "assets/images/icon_heal.png",
    icon_health = "assets/images/icon_health.png",
    icon_gold = "assets/images/icon_gold.png",
    impact = "assets/images/fx/impact_1.png",
    end_turn = "assets/images/icon_end_turn.png",
    key_space = "assets/images/key_space.png",
  },
  fonts = {
    ui = "assets/fonts/BarlowCondensed-Bold.ttf",
  },
}

return config



