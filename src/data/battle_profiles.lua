local battle_profiles = {}

-- Battle type definitions
battle_profiles.Types = {
  DEFAULT = "DEFAULT",
  -- Add more battle types here as needed
  -- DUEL = "DUEL",
  -- BOSS = "BOSS",
}

-- Battle profile data
-- Each profile contains layout configuration
battle_profiles.data = {
  [battle_profiles.Types.DEFAULT] = {
    centerWidthFactor = 0.45,
  },
  -- Example profiles (commented out until we decide on widths):
  -- [battle_profiles.Types.DUEL] = {
  --   centerWidthFactor = 0.35,
  -- },
  -- [battle_profiles.Types.BOSS] = {
  --   centerWidthFactor = 0.6,
  -- },
}

-- Get profile by type
function battle_profiles.getProfile(battleType)
  battleType = battleType or battle_profiles.Types.DEFAULT
  return battle_profiles.data[battleType] or battle_profiles.data[battle_profiles.Types.DEFAULT]
end

return battle_profiles

