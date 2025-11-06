local projectiles = {}

-- Projectile rarity constants
projectiles.Rarity = {
  COMMON = "COMMON",
  UNCOMMON = "UNCOMMON",
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
    id = "strike",
    name = "Strike",
    rarity = projectiles.Rarity.COMMON,
    level = 1,
    baseDamage = 3,
    icon = "assets/images/ball_1.png", -- using existing ball sprite
    stats = {
      "Fires 1 projectile",
      "Lasts 5 bounces"
    },
    description = "A basic projectile that grows stronger with each block it hits."
  },
  {
    id = "multi_strike",
    name = "Multi Strike",
    rarity = projectiles.Rarity.UNCOMMON,
    level = 1,
    baseDamage = 2,
    icon = "assets/images/ball_2.png", -- spread shot sprite
    stats = {
      "Fires 3 projectiles in a spread pattern",
      "Each bounces 3 times",
    },
    description = "Multiple projectiles fired in a spread pattern."
  },
  {
    id = "twin_strike",
    name = "Twin Strike",
    rarity = projectiles.Rarity.RARE,
    level = 1,
    baseDamage = 4,
    icon = "assets/images/ball_3.png",
    stats = {
      "Fires 2 mirrored projectiles",
      "Bounces 5 times"
    },
    description = "Two projectiles that mirror each other's trajectory."
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

