local projectiles = require("data.projectiles")

local ProjectileManager = {}
ProjectileManager.__index = ProjectileManager

-- Simple data access manager for projectiles
-- No discovery, upgrades, or persistence yet - just reading data

function ProjectileManager.new()
  return setmetatable({}, ProjectileManager)
end

-- Get a projectile by its ID
-- @param id string - The projectile ID (e.g., "strike")
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
-- (Removed) getStatsForDisplay: UI now builds dynamic stats from effective values

-- Compute effective stats for a projectile at its current level.
-- Accepts either a projectile table or an ID.
-- Returns a table with: baseDamage (number), maxBounces (number|nil), count (number|nil), maxPierce (number|nil)
function ProjectileManager.getEffective(projectileOrId)
  local p = projectileOrId
  if type(projectileOrId) == "string" then
    p = projectiles.getById(projectileOrId)
  end
  if not p then return { baseDamage = 0 } end
  local level = p.level or 1
  local levelData = (p.levels and p.levels[level]) or nil
  return {
    baseDamage = (levelData and levelData.baseDamage) or p.baseDamage or 0,
    maxBounces = levelData and levelData.maxBounces or nil,
    count = levelData and levelData.count or nil,
    maxPierce = levelData and levelData.maxPierce or nil,
  }
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

-- Upgrade a projectile's level by 1 (capped at 5)
function ProjectileManager.upgradeLevel(id)
  local p = projectiles.getById(id)
  if not p then return false end
  local lvl = (p.level or 1)
  if lvl >= 5 then return false end
  p.level = math.min(5, lvl + 1)
  return true
end

-- Add a projectile to the player's equipped list if not already present
-- Sets the projectile's level to 1 when adding as a new orb
function ProjectileManager.addToEquipped(id)
  local config = require("config")
  local eq = (config.player and config.player.equippedProjectiles)
  if not eq then
    config.player = config.player or {}
    config.player.equippedProjectiles = { id }
    -- Set level to 1 for new orb
    local p = projectiles.getById(id)
    if p then
      p.level = 1
    end
    return true
  end
  for _, x in ipairs(eq) do
    if x == id then return false end
  end
  table.insert(eq, id)
  -- Set level to 1 for new orb
  local p = projectiles.getById(id)
  if p then
    p.level = 1
  end
  return true
end

-- Remove a projectile from the player's equipped list
-- @param id string - The projectile ID to remove
-- @return boolean - True if removed, false if not found
function ProjectileManager.removeFromEquipped(id)
  local config = require("config")
  local eq = (config.player and config.player.equippedProjectiles)
  if not eq then return false end
  
  for i, x in ipairs(eq) do
    if x == id then
      table.remove(eq, i)
      return true
    end
  end
  return false
end

-- Transform a random equipped orb to a different random orb
-- @return string|nil - The ID of the new orb, or nil if transformation failed
function ProjectileManager.transformRandomOrb()
  local config = require("config")
  local eq = (config.player and config.player.equippedProjectiles)
  if not eq or #eq == 0 then return nil end
  
  -- Get all available projectile IDs
  local allProjectiles = projectiles.getAll()
  local allIds = {}
  for _, p in ipairs(allProjectiles) do
    table.insert(allIds, p.id)
  end
  
  if #allIds == 0 then return nil end
  
  -- Pick a random equipped orb to transform
  local randomIndex = love.math.random(#eq)
  local oldOrbId = eq[randomIndex]
  
  -- Get all IDs except the one being transformed (and any other equipped ones)
  local availableIds = {}
  for _, id in ipairs(allIds) do
    local isEquipped = false
    for _, equippedId in ipairs(eq) do
      if equippedId == id then
        isEquipped = true
        break
      end
    end
    if not isEquipped then
      table.insert(availableIds, id)
    end
  end
  
  -- If no available IDs (all orbs are equipped), allow transforming to any orb except the current one
  if #availableIds == 0 then
    for _, id in ipairs(allIds) do
      if id ~= oldOrbId then
        table.insert(availableIds, id)
      end
    end
  end
  
  if #availableIds == 0 then return nil end
  
  -- Pick a random new orb
  local newOrbId = availableIds[love.math.random(#availableIds)]
  
  -- Remove old orb and add new orb
  ProjectileManager.removeFromEquipped(oldOrbId)
  ProjectileManager.addToEquipped(newOrbId)
  
  return newOrbId
end

return ProjectileManager

