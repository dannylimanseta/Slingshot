-- Difficulty 2: Double Deranged Boar
-- Formation Shape: Symmetrical Diamond formations (mirrored left and right)
-- Clear separation between formations with center bridge
-- Proper spacing: 0.05-0.07 horizontal, 0.07-0.09 vertical
return {
  {
    id = "ENCOUNTER_DOUBLE_DERANGED_BOAR",
    difficulty = 2,
    centerWidthFactor = 0.43,
    enemies = {
      "deranged_boar",
      "deranged_boar"
    },
    blockFormation = {
      predefined = {
        -- Left side: Diamond formation (mirrored)
        -- Top point
        { hp = 1, kind = "crit", x = 0.279, y = 0.334 },
        -- Upper middle (wider)
        { hp = 1, kind = "damage", x = 0.216, y = 0.406 },
        { hp = 1, kind = "multiplier", x = 0.279, y = 0.406 },
        { hp = 1, kind = "damage", x = 0.342, y = 0.406 },
        -- Middle (widest part)
        { hp = 1, kind = "armor", x = 0.216, y = 0.477 },
        { hp = 1, kind = "crit", x = 0.279, y = 0.477 },
        { hp = 1, kind = "armor", x = 0.342, y = 0.477 },
        -- Lower middle (narrower)
        { hp = 1, kind = "damage", x = 0.216, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.342, y = 0.549 },
        -- Bottom point
        { hp = 1, kind = "damage", x = 0.279, y = 0.621 },
        -- Side support
        { hp = 1, kind = "potion", x = 0.153, y = 0.477 },
        { hp = 1, kind = "potion", x = 0.153, y = 0.334 },
        
        -- Right side: Diamond formation (mirrored from left)
        -- Top point
        { hp = 1, kind = "crit", x = 0.721, y = 0.334 },
        -- Upper middle (wider)
        { hp = 1, kind = "damage", x = 0.658, y = 0.406 },
        { hp = 1, kind = "multiplier", x = 0.721, y = 0.406 },
        { hp = 1, kind = "damage", x = 0.784, y = 0.406 },
        -- Middle (widest part)
        { hp = 1, kind = "armor", x = 0.658, y = 0.477 },
        { hp = 1, kind = "crit", x = 0.721, y = 0.477 },
        { hp = 1, kind = "armor", x = 0.784, y = 0.477 },
        -- Lower middle (narrower)
        { hp = 1, kind = "damage", x = 0.658, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.784, y = 0.549 },
        -- Bottom point
        { hp = 1, kind = "damage", x = 0.721, y = 0.621 },
        -- Side support
        { hp = 1, kind = "potion", x = 0.847, y = 0.477 },
        { hp = 1, kind = "potion", x = 0.847, y = 0.334 },
        
        -- Center bridge - AOE blocks (symmetrical, well-separated from sides)
        -- Increased spacing to 0.07 to prevent occlusion
        -- Left side ends at x=0.342, center starts at x=0.43 (0.088 gap - safe)
        -- Right side starts at x=0.658, center ends at x=0.57 (0.088 gap - safe)
        { hp = 1, kind = "aoe", x = 0.43, y = 0.477 },
        { hp = 1, kind = "aoe", x = 0.5, y = 0.477 },
        { hp = 1, kind = "aoe", x = 0.57, y = 0.477 },
        -- Center top - high value targets (symmetrical vertical stack above bridge)
        { hp = 1, kind = "crit", x = 0.5, y = 0.334 },
        { hp = 1, kind = "armor", x = 0.43, y = 0.262 },
        { hp = 1, kind = "armor", x = 0.57, y = 0.262 }
      },
      type = "predefined"
    }
  }
}

