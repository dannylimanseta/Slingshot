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
      type = "random", -- "random" or "predefined"
      -- Random formation parameters (used when type = "random")
      random = {
        count = nil, -- nil = use config.blocks.count, otherwise override
        clustering = {
          enabled = nil, -- nil = use config.blocks.clustering.enabled
          clusterSizes = nil, -- nil = use config.blocks.clustering.clusterSizes
          clusterAttempts = nil, -- nil = use config.blocks.clustering.clusterAttempts
          minRemainingForCluster = nil, -- nil = use config.blocks.clustering.minRemainingForCluster
        },
        -- Block type ratios (nil = use config defaults)
        critSpawnRatio = nil,
        armorSpawnRatio = nil,
      },
      -- Predefined formation (used when type = "predefined")
      -- Format: array of {x, y, kind, hp} where x,y are normalized (0-1) coordinates relative to playfield
      -- kind: "damage", "armor", "crit", or "soul" (soul blocks should be rare, typically 0-1 per formation)
      -- hp: starting HP (defaults to 1 if not specified)
      predefined = nil, -- Example: {{x = 0.5, y = 0.3, kind = "damage"}, {x = 0.4, y = 0.3, kind = "armor"}, ...}
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

