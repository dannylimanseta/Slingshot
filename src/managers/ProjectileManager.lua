local projectiles = require("data.projectiles")

local ProjectileManager = {}
ProjectileManager.__index = ProjectileManager

-- Simple data access manager for projectiles
-- No discovery, upgrades, or persistence yet - just reading data

function ProjectileManager.new()
  return setmetatable({}, ProjectileManager)
end

-- Get a projectile by its ID
-- @param id string - The projectile ID (e.g., "qi_orb")
-- @return table|nil - The projectile data table or nil if not found
function ProjectileManager:getProjectile(id)
  return projectiles.getById(id)
end

-- Get all projectile definitions
-- @return table - Array of all projectile data tables
function ProjectileManager:getAllProjectiles()
  return projectiles.getAll()
end

-- Get formatted stats array for display
-- @param projectileData table - The projectile data table
-- @return table - Array of stat display strings
function ProjectileManager:getStatsForDisplay(projectileData)
  if not projectileData then
    return {}
  end
  return projectiles.getStatsForDisplay(projectileData)
end

-- Get projectile by ID (static function wrapper)
-- @param id string - The projectile ID
-- @return table|nil - The projectile data table or nil if not found
function ProjectileManager.getProjectile(id)
  return projectiles.getById(id)
end

-- Get all projectiles (static function wrapper)
-- @return table - Array of all projectile data tables
function ProjectileManager.getAllProjectiles()
  return projectiles.getAll()
end

return ProjectileManager

