-- Difficulty 2: Mender + Deranged Boar
-- Formation Shape: Left = Circle (Mender), Right = Diamond (Boar)
-- Support + damage dealer combo
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
        -- Left side: Circle formation (for Mender)
        -- Center
        { hp = 1, kind = "crit", x = 0.279, y = 0.477 },
        -- Inner ring
        { hp = 1, kind = "armor", x = 0.216, y = 0.406 },
        { hp = 1, kind = "damage", x = 0.342, y = 0.406 },
        { hp = 1, kind = "armor", x = 0.216, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.342, y = 0.549 },
        -- Outer ring
        { hp = 1, kind = "damage", x = 0.153, y = 0.334 },
        { hp = 1, kind = "multiplier", x = 0.216, y = 0.334 },
        { hp = 1, kind = "crit", x = 0.279, y = 0.334 },
        { hp = 1, kind = "damage", x = 0.342, y = 0.334 },
        { hp = 1, kind = "damage", x = 0.153, y = 0.621 },
        { hp = 1, kind = "armor", x = 0.216, y = 0.621 },
        { hp = 1, kind = "armor", x = 0.342, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.342, y = 0.621 },
        
        -- Right side: Diamond formation (for Deranged Boar)
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
        
        -- Center bridge - AOE blocks (effective against both enemies)
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

