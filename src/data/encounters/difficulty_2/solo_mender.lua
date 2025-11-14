-- Difficulty 2: Solo Mender
-- Formation Shape: Circle (support-focused, balanced shape)
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
        -- Circle formation - balanced, interesting shape for support enemy
        -- Center
        { hp = 1, kind = "crit", x = 0.5, y = 0.477 },
        -- Inner ring
        { hp = 1, kind = "armor", x = 0.436, y = 0.406 },
        { hp = 1, kind = "damage", x = 0.564, y = 0.406 },
        { hp = 1, kind = "armor", x = 0.436, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.564, y = 0.549 },
        -- Outer ring
        { hp = 1, kind = "damage", x = 0.405, y = 0.334 },
        { hp = 1, kind = "multiplier", x = 0.468, y = 0.334 },
        { hp = 1, kind = "crit", x = 0.532, y = 0.334 },
        { hp = 1, kind = "damage", x = 0.595, y = 0.334 },
        { hp = 1, kind = "damage", x = 0.405, y = 0.621 },
        { hp = 1, kind = "armor", x = 0.468, y = 0.621 },
        { hp = 1, kind = "armor", x = 0.532, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.595, y = 0.621 },
        -- Side support
        { hp = 1, kind = "potion", x = 0.342, y = 0.477 },
        { hp = 1, kind = "potion", x = 0.658, y = 0.477 },
        { hp = 1, kind = "crit", x = 0.342, y = 0.334 },
        { hp = 1, kind = "crit", x = 0.658, y = 0.334 }
      },
      type = "predefined"
    }
  }
}

