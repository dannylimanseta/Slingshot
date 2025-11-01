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
    id = "spread_shot",
    name = "Multi Strike",
    rarity = projectiles.Rarity.UNCOMMON,
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
  {
    id = "twin_strike",
    name = "Twin Strike",
    rarity = projectiles.Rarity.RARE,
    level = 1,
    baseDamage = 4,
    icon = "assets/images/ball_3.png",
    stats = {
      "Fires 2 mirrored projectiles",
      "Deals 4 damage",
      "Bounces 5 times"
    },
    description = "Two projectiles that mirror each other's trajectory."
  },
  {
    id = "power_shot",
    name = "Power Shot",
    rarity = projectiles.Rarity.EPIC,
    level = 1,
    baseDamage = 8,
    icon = "assets/images/ball_1.png", -- reusing sprite for demo
    stats = {
      "High damage projectile",
      "Deals 8 damage",
      "Bounces 3 times",
      "Slower fire rate"
    },
    description = "A powerful single shot that deals massive damage."
  },
  {
    id = "wide_spread",
    name = "Wide Spread",
    rarity = projectiles.Rarity.RARE,
    level = 1,
    baseDamage = 2,
    icon = "assets/images/ball_2.png", -- using spread shot sprite
    stats = {
      "Fires 5 projectiles",
      "Each bounces 3 times",
      "Wide cone spread",
      "Lower damage per hit"
    },
    description = "An improved spread shot that fires more projectiles."
  },
  {
    id = "triple_strike",
    name = "Triple Strike",
    rarity = projectiles.Rarity.EPIC,
    level = 1,
    baseDamage = 5,
    icon = "assets/images/ball_3.png", -- same sprite as Twin Strike
    stats = {
      "Fires 3 mirrored projectiles",
      "Deals 5 damage each",
      "Bounces 4 times",
      "Wider mirror spread"
    },
    description = "Three projectiles that mirror across the center axis."
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

