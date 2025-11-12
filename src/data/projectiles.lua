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
--   baseDamage = 3, -- fallback base damage
--   levels = { [1] = { baseDamage, maxBounces, count? }, ... },
--   description = "Optional flavor text" -- optional
-- }

projectiles.data = {
  {
    id = "strike",
    name = "Strike",
    rarity = projectiles.Rarity.COMMON,
    level = 1,
    baseDamage = 3,
    levels = {
      [1] = { baseDamage = 4, maxBounces = 5 },
      [2] = { baseDamage = 6, maxBounces = 6 },
      [3] = { baseDamage = 8, maxBounces = 7 },
      [4] = { baseDamage = 10, maxBounces = 8 },
      [5] = { baseDamage = 16, maxBounces = 10 },
    },
    icon = "assets/images/orb_strike.png", -- using existing ball sprite
    description = "A basic projectile that grows stronger with each block it hits."
  },
  {
    id = "multi_strike",
    name = "Multi Strike",
    rarity = projectiles.Rarity.UNCOMMON,
    level = 1,
    baseDamage = 2,
    levels = {
      [1] = { baseDamage = 2, count = 3, maxBounces = 3 },
      [2] = { baseDamage = 3, count = 3, maxBounces = 3 },
      [3] = { baseDamage = 4, count = 3, maxBounces = 4 },
      [4] = { baseDamage = 5, count = 4, maxBounces = 4 },
      [5] = { baseDamage = 6, count = 5, maxBounces = 4 },
    },
    icon = "assets/images/orb_multi_strike.png", -- spread shot sprite
    description = "Multiple projectiles fired in a spread pattern."
  },
  {
    id = "twin_strike",
    name = "Twin Strike",
    rarity = projectiles.Rarity.RARE,
    level = 1,
    baseDamage = 4,
    levels = {
      [1] = { baseDamage = 4, count = 2, maxBounces = 5 },
      [2] = { baseDamage = 6, count = 2, maxBounces = 6 },
      [3] = { baseDamage = 8, count = 2, maxBounces = 7 },
      [4] = { baseDamage = 10, count = 2, maxBounces = 8 },
      [5] = { baseDamage = 16, count = 2, maxBounces = 10 },
    },
    icon = "assets/images/orb_twin_strike.png",
    description = "Two projectiles that mirror each other's trajectory."
  },
  {
    id = "pierce",
    name = "Pierce",
    rarity = projectiles.Rarity.UNCOMMON,
    level = 1,
    baseDamage = 3,
    levels = {
      [1] = { baseDamage = 3, maxPierce = 4 },
      [2] = { baseDamage = 4, maxPierce = 5 },
      [3] = { baseDamage = 5, maxPierce = 6 },
      [4] = { baseDamage = 6, maxPierce = 7 },
      [5] = { baseDamage = 8, maxPierce = 8 },
    },
    icon = "assets/images/orb_pierce.png",
    description = "Doesn't bounce, pierces through up to 4 blocks."
  },
  {
    id = "black_hole",
    name = "Black Hole",
    rarity = projectiles.Rarity.RARE,
    level = 1,
    baseDamage = 2,
    levels = {
      [1] = { baseDamage = 2, maxBounces = 3 },
      [2] = { baseDamage = 3, maxBounces = 3 },
      [3] = { baseDamage = 4, maxBounces = 4 },
      [4] = { baseDamage = 5, maxBounces = 4 },
      [5] = { baseDamage = 6, maxBounces = 5 },
    },
    icon = "assets/images/orb_black_hole.png",
    description = "On first block hit, opens a black hole that pulls in nearby blocks."
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

return projectiles

