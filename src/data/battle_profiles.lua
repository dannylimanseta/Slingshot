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
    centerWidthFactor = 0.45,
    -- Block formation configuration
    -- Type: "random" (uses clustering/random placement) or "predefined" (uses exact positions)
    blockFormation = {
      type = "predefined", -- "random" or "predefined"






      -- Predefined formation (used when type = "predefined")
      -- Format: array of {x, y, kind, hp} where x,y are normalized (0-1) coordinates relative to playfield
      -- kind: "damage", "armor", "crit", or "soul" (soul blocks should be rare, typically 0-1 per formation)
      -- hp: starting HP (defaults to 1 if not specified)
      predefined = {
      {x = 0.414, y = 0.392, kind = "damage", hp = 1},
      {x = 0.552, y = 0.392, kind = "damage", hp = 1},
      {x = 0.552, y = 0.314, kind = "armor", hp = 1},
      {x = 0.414, y = 0.314, kind = "armor", hp = 1},
      {x = 0.483, y = 0.235, kind = "armor", hp = 1},
      {x = 0.483, y = 0.314, kind = "soul", hp = 1},
      {x = 0.483, y = 0.392, kind = "armor", hp = 1},
      {x = 0.621, y = 0.314, kind = "damage", hp = 1},
      {x = 0.345, y = 0.314, kind = "damage", hp = 1},
      {x = 0.345, y = 0.235, kind = "armor", hp = 1},
      {x = 0.621, y = 0.235, kind = "armor", hp = 1},
      {x = 0.621, y = 0.392, kind = "armor", hp = 1},
      {x = 0.345, y = 0.392, kind = "armor", hp = 1},
      {x = 0.759, y = 0.314, kind = "damage", hp = 1},
      {x = 0.207, y = 0.314, kind = "damage", hp = 1},
      {x = 0.138, y = 0.392, kind = "damage", hp = 1},
      {x = 0.828, y = 0.235, kind = "damage", hp = 1},
      {x = 0.897, y = 0.314, kind = "damage", hp = 1},
      {x = 0.828, y = 0.392, kind = "armor", hp = 1},
      {x = 0.069, y = 0.314, kind = "armor", hp = 1},
      {x = 0.138, y = 0.314, kind = "crit", hp = 1},
      {x = 0.828, y = 0.314, kind = "crit", hp = 1},
      {x = 0.138, y = 0.235, kind = "damage", hp = 1},
      {x = 0.414, y = 0.235, kind = "crit", hp = 1},
      {x = 0.552, y = 0.235, kind = "crit", hp = 1},
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

