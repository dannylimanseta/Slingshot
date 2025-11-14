-- Difficulty 2: Solo Deranged Boar
-- Formation Shape: Hexagon (balanced, interesting shape for difficulty 2)
return {
  {
    id = "ENCOUNTER_SOLO_DERANGED_BOAR",
    difficulty = 2,
    centerWidthFactor = 0.43,
    enemies = {
      "deranged_boar"
    },
    blockFormation = {
      predefined = {
        -- Hexagon formation - creates balanced, interesting targeting
        -- Top point
        { hp = 1, kind = "crit", x = 0.5, y = 0.262 },
        -- Upper sides
        { hp = 1, kind = "armor", x = 0.436, y = 0.334 },
        { hp = 1, kind = "multiplier", x = 0.5, y = 0.334 },
        { hp = 1, kind = "armor", x = 0.564, y = 0.334 },
        -- Middle sides (widest part)
        { hp = 1, kind = "damage", x = 0.405, y = 0.406 },
        { hp = 1, kind = "crit", x = 0.468, y = 0.406 },
        { hp = 1, kind = "damage", x = 0.532, y = 0.406 },
        { hp = 1, kind = "damage", x = 0.595, y = 0.406 },
        -- Lower middle
        { hp = 1, kind = "armor", x = 0.436, y = 0.477 },
        { hp = 1, kind = "damage", x = 0.5, y = 0.477 },
        { hp = 1, kind = "armor", x = 0.564, y = 0.477 },
        -- Lower sides
        { hp = 1, kind = "damage", x = 0.468, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.532, y = 0.549 },
        -- Bottom point
        { hp = 1, kind = "damage", x = 0.5, y = 0.621 },
        -- Side wings for variety
        { hp = 1, kind = "potion", x = 0.342, y = 0.406 },
        { hp = 1, kind = "potion", x = 0.658, y = 0.406 },
        { hp = 1, kind = "crit", x = 0.342, y = 0.334 },
        { hp = 1, kind = "crit", x = 0.658, y = 0.334 }
      },
      type = "predefined"
    }
  }
}

