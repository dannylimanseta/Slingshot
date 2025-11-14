-- Difficulty 2: Deranged Boar + Double Fawn
-- Formation Shape: Left = Diamond (for boar), Right = Wave pattern (for fawns)
-- Center bridge connects formations for multi-target effectiveness
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
        -- Left side: Diamond formation (for deranged boar)
        -- Top point
        { hp = 1, kind = "crit", x = 0.279, y = 0.334 },
        -- Upper middle (wider)
        { hp = 1, kind = "damage", x = 0.216, y = 0.406 },
        { hp = 1, kind = "armor", x = 0.279, y = 0.406 },
        { hp = 1, kind = "damage", x = 0.342, y = 0.406 },
        -- Middle (widest part)
        { hp = 1, kind = "armor", x = 0.216, y = 0.477 },
        { hp = 1, kind = "damage", x = 0.279, y = 0.477 },
        { hp = 1, kind = "crit", x = 0.342, y = 0.477 },
        { hp = 1, kind = "damage", x = 0.405, y = 0.477 },
        -- Lower middle (narrower)
        { hp = 1, kind = "armor", x = 0.279, y = 0.549 },
        { hp = 1, kind = "multiplier", x = 0.342, y = 0.549 },
        { hp = 1, kind = "armor", x = 0.405, y = 0.549 },
        -- Bottom point
        { hp = 1, kind = "damage", x = 0.342, y = 0.621 },
        -- Side support
        { hp = 1, kind = "potion", x = 0.153, y = 0.477 },
        { hp = 1, kind = "crit", x = 0.153, y = 0.334 },
        
        -- Right side: Wave pattern (zigzag for fawns - creates flowing visual)
        -- Wave pattern (zigzag)
        { hp = 1, kind = "damage", x = 0.658, y = 0.477 },  -- Down
        { hp = 1, kind = "damage", x = 0.721, y = 0.406 },  -- Up
        { hp = 1, kind = "crit", x = 0.784, y = 0.477 },    -- Down
        { hp = 1, kind = "damage", x = 0.847, y = 0.406 },   -- Up
        -- Second wave row
        { hp = 1, kind = "armor", x = 0.595, y = 0.549 },   -- Down
        { hp = 1, kind = "damage", x = 0.658, y = 0.621 },   -- Down
        { hp = 1, kind = "armor", x = 0.721, y = 0.549 },    -- Down
        { hp = 1, kind = "damage", x = 0.784, y = 0.621 },   -- Down
        { hp = 1, kind = "armor", x = 0.847, y = 0.549 },    -- Down
        -- Upper wave
        { hp = 1, kind = "damage", x = 0.595, y = 0.334 },   -- Up
        { hp = 1, kind = "crit", x = 0.658, y = 0.262 },     -- Up
        { hp = 1, kind = "damage", x = 0.721, y = 0.334 },   -- Up
        { hp = 1, kind = "multiplier", x = 0.784, y = 0.262 }, -- Up
        { hp = 1, kind = "damage", x = 0.847, y = 0.334 },   -- Up
        -- Side support
        { hp = 1, kind = "potion", x = 0.595, y = 0.406 },
        { hp = 1, kind = "potion", x = 0.847, y = 0.191 },
        
        -- Center bridge - AOE blocks (effective against all enemies)
        { hp = 1, kind = "aoe", x = 0.405, y = 0.477 },
        { hp = 1, kind = "aoe", x = 0.468, y = 0.477 },
        { hp = 1, kind = "aoe", x = 0.532, y = 0.477 },
        { hp = 1, kind = "aoe", x = 0.595, y = 0.477 },
        -- Center top - high value targets
        { hp = 1, kind = "crit", x = 0.468, y = 0.406 },
        { hp = 1, kind = "multiplier", x = 0.532, y = 0.406 },
        { hp = 1, kind = "armor", x = 0.5, y = 0.334 },
        -- Center middle support
        { hp = 1, kind = "damage", x = 0.468, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.532, y = 0.549 }
      },
      type = "predefined"
    }
  }
}

