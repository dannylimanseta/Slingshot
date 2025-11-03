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
    -- enemySpacing: spacing between enemies in pixels (default: 40)
    enemySpacing = -10, -- Gap between enemies in pixels
    -- enemies: array of enemy configs, each with:
    --   sprite: path to sprite image (relative to assets/images/)
    --   maxHP: maximum HP for this enemy
    --   damageMin: minimum damage this enemy deals
    --   damageMax: maximum damage this enemy deals
    --   spriteScale: visual scale multiplier (optional, defaults to config.battle.enemySpriteScale)
    --   scaleMul: additional scale multiplier (optional, defaults to 1)
    enemies = {
      {
        sprite = "enemy_1.png",
        maxHP = 80,
        damageMin = 3,
        damageMax = 8,
        spriteScale = 3,
        scaleMul = 1,
      },
      {
        sprite = "enemy_2.png",
        maxHP = 50,
        damageMin = 3,
        damageMax = 5,
        spriteScale = 3,
        scaleMul = 1,
      },
      {
        sprite = "enemy_2.png",
        maxHP = 50,
        damageMin = 3,
        damageMax = 5,
        spriteScale = 3,
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
      -- kind: "damage", "armor", "crit", or "soul" (soul blocks should be rare, typically 0-1 per formation)
      -- hp: starting HP (defaults to 1 if not specified)
      predefined = {
      {x = 0.847, y = 0.406, kind = "damage", hp = 1},
      {x = 0.153, y = 0.406, kind = "damage", hp = 1},
      {x = 0.468, y = 0.048, kind = "damage", hp = 1},
      {x = 0.532, y = 0.048, kind = "damage", hp = 1},
      {x = 0.468, y = 0.836, kind = "damage", hp = 1},
      {x = 0.532, y = 0.836, kind = "damage", hp = 1},
      {x = 0.595, y = 0.048, kind = "damage", hp = 1},
      {x = 0.405, y = 0.048, kind = "damage", hp = 1},
      {x = 0.405, y = 0.836, kind = "damage", hp = 1},
      {x = 0.595, y = 0.836, kind = "damage", hp = 1},
      {x = 0.658, y = 0.836, kind = "damage", hp = 1},
      {x = 0.721, y = 0.836, kind = "damage", hp = 1},
      {x = 0.784, y = 0.836, kind = "damage", hp = 1},
      {x = 0.847, y = 0.836, kind = "damage", hp = 1},
      {x = 0.342, y = 0.836, kind = "damage", hp = 1},
      {x = 0.279, y = 0.836, kind = "damage", hp = 1},
      {x = 0.216, y = 0.836, kind = "damage", hp = 1},
      {x = 0.153, y = 0.836, kind = "damage", hp = 1},
      {x = 0.153, y = 0.048, kind = "damage", hp = 1},
      {x = 0.216, y = 0.048, kind = "damage", hp = 1},
      {x = 0.279, y = 0.048, kind = "damage", hp = 1},
      {x = 0.342, y = 0.048, kind = "damage", hp = 1},
      {x = 0.658, y = 0.048, kind = "damage", hp = 1},
      {x = 0.721, y = 0.048, kind = "damage", hp = 1},
      {x = 0.847, y = 0.048, kind = "damage", hp = 1},
      {x = 0.784, y = 0.048, kind = "damage", hp = 1},
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

