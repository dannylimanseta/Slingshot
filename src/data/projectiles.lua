local projectiles = {}

-- Projectile rarity constants
projectiles.Rarity = {
  COMMON = "COMMON",
  RARE = "RARE",
  EPIC = "EPIC",
  LEGENDARY = "LEGENDARY",
}

-- Projectile definitions
-- Each projectile follows this schema:
-- {
--   id = "unique_id",
--   name = "Display Name",
--   rarity = projectiles.Rarity.COMMON | RARE | EPIC | LEGENDARY,
--   level = 1, -- default level
--   icon = "path/to/icon.png", -- or nil if using default ball sprite
--   stats = { "+1 damage per block", "Lasts 5 bounces" }, -- array of display strings
--   description = "Optional flavor text" -- optional
-- }

projectiles.data = {
  {
    id = "qi_orb",
    name = "Strike",
    rarity = projectiles.Rarity.COMMON,
    level = 1,
    baseDamage = 3,
    icon = "assets/images/ball_1.png", -- using existing ball sprite
    stats = {
      "+1 damage per block",
      "Lasts 5 bounces"
    },
    description = "A basic projectile that grows stronger with each block it hits."
  },
  {
    id = "fire_ball",
    name = "Fire Ball",
    rarity = projectiles.Rarity.RARE,
    level = 1,
    baseDamage = 4,
    icon = "assets/images/ball_1.png", -- placeholder
    stats = {
      "+2 damage per block",
      "Lasts 6 bounces",
      "10% chance to crit"
    },
    description = "A blazing projectile that burns through blocks."
  },
  {
    id = "ice_spike",
    name = "Ice Spike",
    rarity = projectiles.Rarity.RARE,
    level = 1,
    baseDamage = 3,
    icon = "assets/images/ball_1.png", -- placeholder
    stats = {
      "+1 damage per block",
      "Lasts 7 bounces",
      "Slows enemy attacks"
    },
    description = "A frosty projectile that freezes enemies in their tracks."
  },
  {
    id = "lightning_bolt",
    name = "Lightning Bolt",
    rarity = projectiles.Rarity.EPIC,
    level = 1,
    baseDamage = 5,
    icon = "assets/images/ball_1.png", -- placeholder
    stats = {
      "+3 damage per block",
      "Lasts 4 bounces",
      "Chain damage to nearby blocks"
    },
    description = "Electric energy that arcs between targets."
  },
  {
    id = "void_orb",
    name = "Void Orb",
    rarity = projectiles.Rarity.LEGENDARY,
    level = 1,
    baseDamage = 6,
    icon = "assets/images/ball_1.png", -- placeholder
    stats = {
      "+5 damage per block",
      "Lasts 8 bounces",
      "Absorbs block HP as damage",
      "Pierces through blocks"
    },
    description = "A dark void that consumes everything in its path."
  },
  {
    id = "spread_shot",
    name = "Multi Strike",
    rarity = projectiles.Rarity.COMMON,
    level = 1,
    baseDamage = 2,
    icon = "assets/images/ball_2.png", -- spread shot sprite
    stats = {
      "Fires 3 projectiles",
      "Each bounces 3 times",
      "Narrow cone spread"
    },
    description = "Multiple projectiles fired in a spread pattern."
  },
}

-- Helper function to get projectile by ID
function projectiles.getById(id)
  for _, projectile in ipairs(projectiles.data) do
    if projectile.id == id then
      return projectile
    end
  end
  return nil
end

-- Helper function to get all projectiles
function projectiles.getAll()
  return projectiles.data
end

-- Helper function to get stats for display (returns the stats array as-is)
function projectiles.getStatsForDisplay(projectileData)
  if not projectileData or not projectileData.stats then
    return {}
  end
  return projectileData.stats
end

return projectiles

