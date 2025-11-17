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
    icon = "assets/images/orb_strike.png",
    description = "A basic projectile that grows stronger with each block it hits."
  },
  {
    id = "lightning",
    name = "Lightning Orb",
    rarity = projectiles.Rarity.RARE,
    level = 1,
    baseDamage = 5,
    levels = {
      [1] = { baseDamage = 5, maxBounces = 3 },
      [2] = { baseDamage = 6, maxBounces = 4 },
      [3] = { baseDamage = 7, maxBounces = 5 },
      [4] = { baseDamage = 8, maxBounces = 6 },
      [5] = { baseDamage = 10, maxBounces = 7 },
    },
    icon = "assets/images/orb_lightning.png",
    description = "Shoots a lightning orb that bounces between blocks."
  },
  {
    id = "multi_strike",
    name = "Multi Strike",
    rarity = projectiles.Rarity.UNCOMMON,
    level = 1,
    baseDamage = 3,
    levels = {
      [1] = { baseDamage = 3, maxBounces = 3, count = 3 },
      [2] = { baseDamage = 4, maxBounces = 3, count = 3 },
      [3] = { baseDamage = 5, maxBounces = 4, count = 3 },
      [4] = { baseDamage = 6, maxBounces = 4, count = 4 },
      [5] = { baseDamage = 8, maxBounces = 5, count = 4 },
    },
    icon = "assets/images/orb_multi_strike.png",
    description = "Fires multiple projectiles in a spread pattern."
  },
  {
    id = "twin_strike",
    name = "Twin Strike",
    rarity = projectiles.Rarity.UNCOMMON,
    level = 1,
    baseDamage = 4,
    levels = {
      [1] = { baseDamage = 4, maxBounces = 5, count = 2 },
      [2] = { baseDamage = 5, maxBounces = 6, count = 2 },
      [3] = { baseDamage = 7, maxBounces = 7, count = 2 },
      [4] = { baseDamage = 9, maxBounces = 8, count = 2 },
      [5] = { baseDamage = 12, maxBounces = 9, count = 2 },
    },
    icon = "assets/images/orb_twin_strike.png",
    description = "Fires two mirrored projectiles simultaneously."
  },
  {
    id = "pierce",
    name = "Pierce Orb",
    rarity = projectiles.Rarity.RARE,
    level = 1,
    baseDamage = 4,
    levels = {
      [1] = { baseDamage = 4, maxPierce = 4 },
      [2] = { baseDamage = 5, maxPierce = 5 },
      [3] = { baseDamage = 6, maxPierce = 6 },
      [4] = { baseDamage = 8, maxPierce = 7 },
      [5] = { baseDamage = 10, maxPierce = 8 },
    },
    icon = "assets/images/orb_pierce.png",
    description = "Pierces through multiple blocks in a straight line."
  },
  {
    id = "black_hole",
    name = "Black Hole",
    rarity = projectiles.Rarity.EPIC,
    level = 1,
    baseDamage = 6,
    levels = {
      [1] = { baseDamage = 6, maxBounces = 3 },
      [2] = { baseDamage = 7, maxBounces = 4 },
      [3] = { baseDamage = 9, maxBounces = 5 },
      [4] = { baseDamage = 11, maxBounces = 6 },
      [5] = { baseDamage = 14, maxBounces = 7 },
    },
    icon = "assets/images/orb_black_hole.png",
    description = "Creates a black hole that pulls in and destroys nearby blocks."
  },
  {
    id = "flurry_strikes",
    name = "Flurry Strikes",
    rarity = projectiles.Rarity.UNCOMMON,
    level = 1,
    baseDamage = 2,
    levels = {
      [1] = { baseDamage = 2, maxBounces = 3, count = 3 },
      [2] = { baseDamage = 3, maxBounces = 4, count = 3 },
      [3] = { baseDamage = 4, maxBounces = 5, count = 4 },
      [4] = { baseDamage = 5, maxBounces = 6, count = 4 },
      [5] = { baseDamage = 7, maxBounces = 7, count = 5 },
    },
    icon = "assets/images/orb_flurry.png",
    description = "Fires multiple projectiles in quick succession."
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

