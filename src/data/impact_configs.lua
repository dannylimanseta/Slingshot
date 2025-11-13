-- Impact behavior configuration for different projectile types
-- This centralizes all projectile-specific visual effect behaviors

local impactConfigs = {}

-- Impact type registry
-- Each projectile can specify how it behaves in battle
impactConfigs.behaviors = {
  -- Default behavior (used for most projectiles)
  default = {
    impactType = "standard", -- Uses standard slash animations
    attackDelay = 0.5, -- Delay before attack animation starts
    suppressInitialFlash = false, -- Show enemy flash on damage application
    suppressInitialKnockback = false, -- Show enemy knockback
    suppressInitialSplatter = false, -- Show splatter effect
    suppressInitialParticles = false, -- Show particle burst
    popupDelay = 0, -- Delay before damage numbers appear
  },
  
  -- Strike projectile (standard behavior)
  strike = {
    impactType = "standard",
    attackDelay = 0.5,
    suppressInitialFlash = false,
    suppressInitialKnockback = false,
    suppressInitialSplatter = false,
    suppressInitialParticles = false,
    popupDelay = 0,
  },
  
  -- Multi-strike projectile (standard behavior)
  multi_strike = {
    impactType = "standard",
    attackDelay = 0.5,
    suppressInitialFlash = false,
    suppressInitialKnockback = false,
    suppressInitialSplatter = false,
    suppressInitialParticles = false,
    popupDelay = 0,
  },
  
  -- Twin Strike projectile (standard behavior)
  twin_strike = {
    impactType = "standard",
    attackDelay = 0.5,
    suppressInitialFlash = false,
    suppressInitialKnockback = false,
    suppressInitialSplatter = false,
    suppressInitialParticles = false,
    popupDelay = 0,
  },
  
  -- Pierce projectile (standard behavior)
  pierce = {
    impactType = "standard",
    attackDelay = 0.5,
    suppressInitialFlash = false,
    suppressInitialKnockback = false,
    suppressInitialSplatter = false,
    suppressInitialParticles = false,
    popupDelay = 0,
  },
  
  -- Black Hole projectile (custom animation, delayed effects)
  black_hole = {
    impactType = "black_hole", -- Uses black hole shatter animation
    attackDelay = 0.05, -- Start almost immediately
    suppressInitialFlash = true, -- No flash until shards hit
    suppressInitialKnockback = true, -- No knockback at all (shards pull)
    suppressInitialSplatter = true, -- No splatter until shards hit
    suppressInitialParticles = true, -- No particles until shards hit
    popupDelay = 1.04, -- Delay until shards appear (0.65 * 1.6s)
  },
  
  -- Lightning projectile (custom animation, fast)
  lightning = {
    impactType = "lightning_strike", -- Uses lightning strike animation
    attackDelay = 0.05, -- Start almost immediately
    suppressInitialFlash = false, -- Show flash on damage
    suppressInitialKnockback = false, -- Show knockback
    suppressInitialSplatter = false, -- Show splatter
    suppressInitialParticles = false, -- Show particles
    popupDelay = 0, -- Show numbers immediately
  },
}

-- Get behavior config for a projectile ID
-- Returns default behavior if projectile not found
function impactConfigs.getBehavior(projectileId)
  return impactConfigs.behaviors[projectileId] or impactConfigs.behaviors.default
end

-- Check if a projectile uses custom impact animation
function impactConfigs.usesCustomImpact(projectileId)
  local behavior = impactConfigs.getBehavior(projectileId)
  return behavior.impactType ~= "standard"
end

-- Get impact type for a projectile
function impactConfigs.getImpactType(projectileId)
  local behavior = impactConfigs.getBehavior(projectileId)
  return behavior.impactType
end

return impactConfigs

