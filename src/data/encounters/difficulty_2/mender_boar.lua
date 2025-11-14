-- Difficulty 2: Mender + Deranged Boar
-- Formation Shape: Horizontal Spread - blocks spread across entire width
-- No left/right separation, integrated formation across the board
return {
  {
    id = "ENCOUNTER_MENDER_DERANGED_BOAR",
    difficulty = 2,
    centerWidthFactor = 0.43,
    enemies = {
      "mender",
      "deranged_boar"
    },
    blockFormation = {
      predefined = {
        -- Horizontal spread formation - blocks distributed across entire width
        -- Top row (spread across)
        { hp = 1, kind = "crit", x = 0.216, y = 0.262 },
        { hp = 1, kind = "armor", x = 0.342, y = 0.262 },
        { hp = 1, kind = "multiplier", x = 0.468, y = 0.262 },
        { hp = 1, kind = "crit", x = 0.595, y = 0.262 },
        { hp = 1, kind = "armor", x = 0.721, y = 0.262 },
        { hp = 1, kind = "crit", x = 0.847, y = 0.262 },
        
        -- Upper middle row
        { hp = 1, kind = "damage", x = 0.153, y = 0.334 },
        { hp = 1, kind = "armor", x = 0.279, y = 0.334 },
        { hp = 1, kind = "damage", x = 0.405, y = 0.334 },
        { hp = 1, kind = "aoe", x = 0.532, y = 0.334 },
        { hp = 1, kind = "damage", x = 0.658, y = 0.334 },
        { hp = 1, kind = "armor", x = 0.784, y = 0.334 },
        
        -- Middle row (main horizontal line)
        { hp = 1, kind = "potion", x = 0.153, y = 0.406 },
        { hp = 1, kind = "crit", x = 0.279, y = 0.406 },
        { hp = 1, kind = "aoe", x = 0.405, y = 0.406 },
        { hp = 1, kind = "multiplier", x = 0.532, y = 0.406 },
        { hp = 1, kind = "aoe", x = 0.658, y = 0.406 },
        { hp = 1, kind = "crit", x = 0.784, y = 0.406 },
        { hp = 1, kind = "potion", x = 0.847, y = 0.406 },
        
        -- Lower middle row
        { hp = 1, kind = "armor", x = 0.153, y = 0.477 },
        { hp = 1, kind = "damage", x = 0.279, y = 0.477 },
        { hp = 1, kind = "crit", x = 0.405, y = 0.477 },
        { hp = 1, kind = "armor", x = 0.532, y = 0.477 },
        { hp = 1, kind = "crit", x = 0.658, y = 0.477 },
        { hp = 1, kind = "damage", x = 0.784, y = 0.477 },
        
        -- Bottom row (spread across)
        { hp = 1, kind = "damage", x = 0.216, y = 0.549 },
        { hp = 1, kind = "armor", x = 0.342, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.468, y = 0.549 },
        { hp = 1, kind = "armor", x = 0.595, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.721, y = 0.549 },
        
        -- Foundation row
        { hp = 1, kind = "damage", x = 0.279, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.405, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.532, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.658, y = 0.621 }
      },
      type = "predefined"
    }
  }
}

