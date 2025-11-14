-- Difficulty 2: Deranged Boar + Double Fawn
-- Formation Shape: Left = Pyramid (for boar), Right = Dual Towers (for two fawns)
-- Clean, organized formations with proper spacing and clear center bridge
return {
  {
    id = "ENCOUNTER_DERANGED_BOAR_DOUBLE_FAWN",
    difficulty = 2,
    centerWidthFactor = 0.43,
    enemies = {
      "deranged_boar",
      "fawn",
      "fawn"
    },
    blockFormation = {
      predefined = {
        -- Left side: Pyramid formation (for deranged boar)
        -- Bottom row (wide base)
        { hp = 1, kind = "damage", x = 0.216, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.279, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.342, y = 0.621 },
        -- Second row
        { hp = 1, kind = "armor", x = 0.279, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.342, y = 0.549 },
        -- Third row
        { hp = 1, kind = "damage", x = 0.279, y = 0.477 },
        { hp = 1, kind = "crit", x = 0.342, y = 0.477 },
        -- Fourth row
        { hp = 1, kind = "armor", x = 0.279, y = 0.406 },
        { hp = 1, kind = "multiplier", x = 0.342, y = 0.406 },
        -- Top
        { hp = 1, kind = "crit", x = 0.309, y = 0.334 },
        -- Side support
        { hp = 1, kind = "potion", x = 0.153, y = 0.477 },
        { hp = 1, kind = "potion", x = 0.153, y = 0.334 },
        
        -- Right side: Dual Towers (for two fawns - side by side)
        -- Left tower (for first fawn)
        -- Bottom
        { hp = 1, kind = "damage", x = 0.658, y = 0.621 },
        -- Second row
        { hp = 1, kind = "armor", x = 0.658, y = 0.549 },
        -- Third row
        { hp = 1, kind = "damage", x = 0.658, y = 0.477 },
        -- Fourth row
        { hp = 1, kind = "crit", x = 0.658, y = 0.406 },
        -- Top
        { hp = 1, kind = "crit", x = 0.658, y = 0.334 },
        
        -- Right tower (for second fawn)
        -- Bottom
        { hp = 1, kind = "damage", x = 0.784, y = 0.621 },
        -- Second row
        { hp = 1, kind = "armor", x = 0.784, y = 0.549 },
        -- Third row
        { hp = 1, kind = "damage", x = 0.784, y = 0.477 },
        -- Fourth row
        { hp = 1, kind = "multiplier", x = 0.784, y = 0.406 },
        -- Top
        { hp = 1, kind = "crit", x = 0.784, y = 0.334 },
        
        -- Bridge between towers
        { hp = 1, kind = "damage", x = 0.721, y = 0.477 },
        { hp = 1, kind = "armor", x = 0.721, y = 0.406 },
        
        -- Side support
        { hp = 1, kind = "potion", x = 0.847, y = 0.477 },
        { hp = 1, kind = "potion", x = 0.847, y = 0.334 },
        
        -- Center bridge - AOE blocks (effective against all enemies)
        -- Well-separated from left (ends at x=0.342) and right (starts at x=0.658)
        { hp = 1, kind = "aoe", x = 0.43, y = 0.477 },
        { hp = 1, kind = "aoe", x = 0.5, y = 0.477 },
        { hp = 1, kind = "aoe", x = 0.57, y = 0.477 },
        -- Center top - high value targets
        { hp = 1, kind = "crit", x = 0.5, y = 0.334 },
        { hp = 1, kind = "armor", x = 0.43, y = 0.262 },
        { hp = 1, kind = "armor", x = 0.57, y = 0.262 }
      },
      type = "predefined"
    }
  }
}

