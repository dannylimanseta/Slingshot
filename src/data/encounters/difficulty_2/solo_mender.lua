-- Difficulty 2: Solo Mender
-- Formation Shape: Wave Pattern (flowing, support-themed shape)
-- Clean wave formation with proper spacing and clear visual flow
return {
  {
    id = "ENCOUNTER_SOLO_MENDER",
    difficulty = 2,
    centerWidthFactor = 0.43,
    enemies = {
      "mender"
    },
    blockFormation = {
      predefined = {
        -- Wave pattern - flowing, support-themed shape
        -- Top wave (peak)
        { hp = 1, kind = "crit", x = 0.5, y = 0.262 },
        { hp = 1, kind = "armor", x = 0.436, y = 0.262 },
        { hp = 1, kind = "armor", x = 0.564, y = 0.262 },
        
        -- Upper wave (trough)
        { hp = 1, kind = "damage", x = 0.405, y = 0.334 },
        { hp = 1, kind = "multiplier", x = 0.468, y = 0.334 },
        { hp = 1, kind = "damage", x = 0.532, y = 0.334 },
        { hp = 1, kind = "damage", x = 0.595, y = 0.334 },
        
        -- Middle wave (peak)
        { hp = 1, kind = "crit", x = 0.436, y = 0.406 },
        { hp = 1, kind = "crit", x = 0.5, y = 0.406 },
        { hp = 1, kind = "crit", x = 0.564, y = 0.406 },
        
        -- Lower wave (trough)
        { hp = 1, kind = "armor", x = 0.405, y = 0.477 },
        { hp = 1, kind = "damage", x = 0.468, y = 0.477 },
        { hp = 1, kind = "damage", x = 0.532, y = 0.477 },
        { hp = 1, kind = "armor", x = 0.595, y = 0.477 },
        
        -- Bottom wave (peak)
        { hp = 1, kind = "damage", x = 0.436, y = 0.549 },
        { hp = 1, kind = "armor", x = 0.5, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.564, y = 0.549 },
        
        -- Base foundation
        { hp = 1, kind = "damage", x = 0.468, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.532, y = 0.621 },
        
        -- Side wings for variety
        { hp = 1, kind = "potion", x = 0.342, y = 0.406 },
        { hp = 1, kind = "potion", x = 0.658, y = 0.406 },
        { hp = 1, kind = "potion", x = 0.342, y = 0.549 },
        { hp = 1, kind = "potion", x = 0.658, y = 0.549 }
      },
      type = "predefined"
    }
  }
}

