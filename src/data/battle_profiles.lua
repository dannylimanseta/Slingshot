local battle_profiles = {}

-- Battle type definitions
battle_profiles.Types = {
  DEFAULT = "DEFAULT",
  -- Add more battle types here as needed
  -- DUEL = "DUEL",
  -- BOSS = "BOSS",
}

-- Battle profile data
-- Each profile contains layout configuration and block formation settings
battle_profiles.data = {
  [battle_profiles.Types.DEFAULT] = {
    centerWidthFactor = 0.43,
    -- Enemy configuration
    -- enemyCount: number of enemies (1-3)
    -- enemySpacing: spacing between enemies in pixels.
    -- Can be a number (uniform) or a table keyed by enemy count.
    -- Example here: tighter spacing for 3, wider for 2.
    enemySpacing = { [1] = 0, [2] = 40, [3] = -15 },
    -- enemies: array of enemy configs, each with:
    --   sprite: path to sprite image (relative to assets/images/)
    --   maxHP: maximum HP for this enemy
    --   damageMin: minimum damage this enemy deals
    --   damageMax: maximum damage this enemy deals
    --   spriteScale: visual scale multiplier (optional, defaults to config.battle.enemySpriteScale)
    --   scaleMul: additional scale multiplier (optional, defaults to 1)
    enemies = {
      {
        id = "crawler",
        name = "Crawler",
        sprite = "enemy_1.png",
        maxHP = 80,
        damageMin = 3,
        damageMax = 8,
        spriteScale = 5.2,
        scaleMul = 1,
      },
      {
        id = "fungloom",
        name = "Fungloom",
        sprite = "enemy_2.png",
        maxHP = 50,
        damageMin = 3,
        damageMax = 5,
        spriteScale = 3,
        scaleMul = 1,
      },
      {
        id = "fawn",
        name = "Fawn",
        sprite = "enemy_3.png",
        maxHP = 40,
        damageMin = 4,
        damageMax = 7,
        spriteScale = 4,
        scaleMul = 1,
      },
    },
    enemyCount = 3, -- Number of enemies (will use first N entries from enemies array)
    -- Block formation configuration
    -- Type: "random" (uses clustering/random placement) or "predefined" (uses exact positions)
    blockFormation = {
      type = "predefined", -- "random" or "predefined"
























































































      -- Predefined formation (used when type = "predefined")
      -- Format: array of {x, y, kind, hp} where x,y are normalized (0-1) coordinates relative to playfield
      -- kind: "damage", "armor", "crit", or "multiplier" (multiplier blocks should be rare, typically 0-1 per formation)
      -- hp: starting HP (defaults to 1 if not specified)
      predefined = {
      {x = 0.216, y = 0.477, kind = "damage", hp = 1},
      {x = 0.342, y = 0.549, kind = "damage", hp = 1},
      {x = 0.468, y = 0.621, kind = "damage", hp = 1},
      {x = 0.532, y = 0.621, kind = "damage", hp = 1},
      {x = 0.658, y = 0.549, kind = "damage", hp = 1},
      {x = 0.784, y = 0.477, kind = "damage", hp = 1},
      {x = 0.595, y = 0.582, kind = "damage", hp = 1},
      {x = 0.405, y = 0.581, kind = "damage", hp = 1},
      {x = 0.280, y = 0.510, kind = "damage", hp = 1},
      {x = 0.154, y = 0.440, kind = "damage", hp = 1},
      {x = 0.721, y = 0.511, kind = "damage", hp = 1},
      {x = 0.847, y = 0.436, kind = "damage", hp = 1},
      {x = 0.216, y = 0.406, kind = "armor", hp = 1},
      {x = 0.342, y = 0.477, kind = "armor", hp = 1},
      {x = 0.468, y = 0.549, kind = "armor", hp = 1},
      {x = 0.532, y = 0.549, kind = "armor", hp = 1},
      {x = 0.658, y = 0.477, kind = "armor", hp = 1},
      {x = 0.784, y = 0.406, kind = "armor", hp = 1},
      {x = 0.594, y = 0.518, kind = "aoe", hp = 1},
      {x = 0.405, y = 0.513, kind = "aoe", hp = 1},
      {x = 0.154, y = 0.368, kind = "aoe", hp = 1},
      {x = 0.848, y = 0.364, kind = "aoe", hp = 1},
      {x = 0.721, y = 0.439, kind = "armor", hp = 1},
      {x = 0.278, y = 0.440, kind = "armor", hp = 1},
      {x = 0.468, y = 0.262, kind = "damage", hp = 1},
      {x = 0.532, y = 0.262, kind = "damage", hp = 1},
    },
    },
  },
  -- Example profiles (commented out until we decide on formations):
  -- [battle_profiles.Types.DUEL] = {
  --   centerWidthFactor = 0.35,
  --   blockFormation = {
  --     type = "random",
  --     random = {
  --       count = 18, -- Fewer blocks for duel
  --       clustering = { enabled = true },
  --     },
  --   },
  -- },
  -- [battle_profiles.Types.BOSS] = {
  --   centerWidthFactor = 0.6,
  --   blockFormation = {
  --     type = "predefined",
  --     predefined = {
  --       -- Wall formation
  --       {x = 0.5, y = 0.2, kind = "damage"},
  --       {x = 0.4, y = 0.2, kind = "damage"},
  --       {x = 0.6, y = 0.2, kind = "damage"},
  --       {x = 0.5, y = 0.3, kind = "armor"},
  --       {x = 0.4, y = 0.3, kind = "armor"},
  --       {x = 0.6, y = 0.3, kind = "armor"},
  --       {x = 0.5, y = 0.4, kind = "crit"},
  --     },
  --   },
  -- },
}

-- Get profile by type
function battle_profiles.getProfile(battleType)
  battleType = battleType or battle_profiles.Types.DEFAULT
  return battle_profiles.data[battleType] or battle_profiles.data[battle_profiles.Types.DEFAULT]
end

return battle_profiles

