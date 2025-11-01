local config = {}

-- Video: virtual resolution (for consistent scaling)
config.video = {
  virtualWidth = 1280,
  virtualHeight = 720,
}

-- Critical tunables (single source of truth)
config.playfield = {
  margin = 24, -- pixels from window edges for spawning blocks
  centerWidthFactor = 0.4, -- center playfield width as fraction of screen (reduced by 20% from 0.5)
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
    sprite = "assets/images/ball_2.png", -- sprite for spread projectiles
    trail = {
      enabled = true,
      width = 16.38, -- 30% smaller than regular trail (23.4 * 0.7)
      maxPoints = 32,
      sampleInterval = 0.016, -- seconds between samples (~60Hz)
      softness = 0.25, -- 0..0.5 edge softness across width
      color = { 0.5, 0.9, 0.6, 0.6 }, -- RGBA (fallback color - less saturated green)
      colorStart = { 0.5, 0.9, 0.6, 0.6 }, -- Color at head (soft green)
      colorEnd = { 0.4, 0.75, 0.5, 0.6 }, -- Color at tail (softer darker green)
      additive = true,
      overlap = 5.46, -- 30% smaller than regular overlap (7.8 * 0.7)
      taperPower = 1.4, -- controls how quickly width tapers toward tail
      invert = true, -- invert along-length gradient (bright at head)
    },
  },
  easing = {
    enabled = true,
    startFactor = 0.4, -- start at 40% of target speed
    easeK = 6, -- higher = faster approach to target
  },
  bounceSpeedScale = 1.01, -- +8% target speed per bounce
  trail = {
    enabled = true,
    width = 23.4, -- increased by 30% (was 18)
    maxPoints = 32,
    sampleInterval = 0.016, -- seconds between samples (~60Hz)
    softness = 0.25, -- 0..0.5 edge softness across width
    color = { 1, 0.65, 0.2, 0.6 }, -- RGBA (fallback color)
    colorStart = { 1, 0.65, 0.2, 0.6 }, -- Color at head (orange)
    colorEnd = { 1, 0.2, 0.1, 0.6 }, -- Color at tail (red)
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
    cellSize = 32, -- pixels per grid cell
    showGrid = false, -- show grid visually (toggle with G key)
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
  soulReward = 25, -- bonus damage when soul block is hit
  tickerSpeed = 10, -- points per second smoothing toward current score (base speed)
  critMultiplier = 2,
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
    fadeStart = 1, -- distance from center where fade begins (in slot units)
    fadeEnd = 1.5, -- distance from center where fully transparent (in slot units)
    depthFade = 0.2, -- 0..1, how much to dim slots based on distance (Option B)
    renderBuffer = 0.5, -- extra slots to render beyond visible range (for smooth fading)
    maxVisibleSlots = 3, -- maximum slots visible at once (shows only unique projectiles, no repetition)
    ballSpacingMultiplier = 2, -- multiplier for spacing between balls (shooter.radius * this)
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
  playerAttackDelay = 0.5,
  enemyAttackDelay = 1.0,
  enemyAttackPostArmorDelay = 0.3,
  hitFlashDuration = 0.5,
  hitFlashPasses = 3, -- draw additive flash this many times for stronger effect
  hitFlashAlphaScale = 0.4, -- multiply base flash alpha (clamped to 1) - reduced from 1.0 to tone down intensity
  popupLifetime = 0.8,
  popupBounceHeight = 60, -- vertical distance for damage popup bounce
  popupFadeStart = 0.7, -- start fading at 70% of lifetime (last 30%)
  popupFadeMultiplier = 0.5, -- 50% faster fade within fade window (1.0 = baseline)
  hpBarTweenSpeed = 8, -- HP bar tween speed (how quickly bar moves toward actual HP)
  spriteScale = 5, -- global fallback
  playerSpriteScale = 5,
  enemySpriteScale = 5,
  positionOffsetY = 50, -- Reduced by 100px to avoid tooltip occlusion
  lungeDistance = 80,
  lungeDuration = 0.12, -- 30% faster forward phase
  lungeReturnDuration = 0.13, -- slowed by 30%
  lungePauseDuration = 0.3, -- pause at peak before returning
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
    thickness = 4,
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

-- Asset paths (relative to project root)
config.assets = {
  images = {
    background = "assets/images/bg_1.png",
    player = "assets/images/player_char_1.png",
    enemy = "assets/images/enemy_1.png",
    ball = "assets/images/ball_1.png",
    ball_2 = "assets/images/ball_2.png", -- spread shot projectile sprite
    ball_3 = "assets/images/ball_3.png", -- twin strike projectile sprite
    block_attack = "assets/images/block_attack.png",
    block_defend = "assets/images/block_defend.png",
    block_crit = "assets/images/block_crit.png",
    block_soul = "assets/images/block_soul.png",
    icon_armor = "assets/images/icon_armor.png",
    icon_attack = "assets/images/icon_attack.png",
    impact = "assets/images/fx/impact_1.png",
  },
  fonts = {
    ui = "assets/fonts/BarlowCondensed-Bold.ttf",
  }
}

return config



