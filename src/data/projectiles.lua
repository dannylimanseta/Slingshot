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

