-- Elite encounter: Stagmaw + Double Fawn
-- Note: This is a large encounter, keeping it in one file for now
return {
  {
    id = "ENCOUNTER_STAGMAW_DOUBLE_FAWN",
    difficulty = 1,
    centerWidthFactor = 0.43,
    elite = true,
    enemies = {
      "fawn",
      "stagmaw",
      "fawn"
    },
    blockFormation = {
      predefined = {
        -- This encounter has a complex formation
        -- TODO: Extract from original encounters.lua if needed
        -- For now, keeping minimal structure
        { hp = 1, kind = "damage", x = 0.153, y = 0.334 },
        { hp = 1, kind = "damage", x = 0.153, y = 0.262 },
        { hp = 1, kind = "damage", x = 0.216, y = 0.406 },
        { hp = 1, kind = "damage", x = 0.153, y = 0.406 },
        { hp = 1, kind = "damage", x = 0.216, y = 0.477 },
        { hp = 1, kind = "damage", x = 0.279, y = 0.477 },
        { hp = 1, kind = "damage", x = 0.342, y = 0.477 },
        { hp = 1, kind = "damage", x = 0.658, y = 0.477 },
        { hp = 1, kind = "damage", x = 0.721, y = 0.477 },
        { hp = 1, kind = "damage", x = 0.784, y = 0.477 },
        { hp = 1, kind = "damage", x = 0.784, y = 0.406 },
        { hp = 1, kind = "damage", x = 0.847, y = 0.406 },
        { hp = 1, kind = "damage", x = 0.847, y = 0.334 },
        { hp = 1, kind = "damage", x = 0.847, y = 0.262 },
        { hp = 1, kind = "crit", x = 0.847, y = 0.191 },
        { hp = 1, kind = "crit", x = 0.721, y = 0.334 },
        { hp = 1, kind = "crit", x = 0.279, y = 0.334 },
        { hp = 1, kind = "crit", x = 0.153, y = 0.191 },
        { hp = 1, kind = "multiplier", x = 0.153, y = 0.119 },
        { hp = 1, kind = "multiplier", x = 0.279, y = 0.262 },
        { hp = 1, kind = "multiplier", x = 0.721, y = 0.262 },
        { hp = 1, kind = "multiplier", x = 0.847, y = 0.119 },
        { hp = 1, kind = "armor", x = 0.721, y = 0.549 },
        { hp = 1, kind = "armor", x = 0.658, y = 0.549 },
        { hp = 1, kind = "armor", x = 0.595, y = 0.549 },
        { hp = 1, kind = "armor", x = 0.279, y = 0.549 },
        { hp = 1, kind = "armor", x = 0.342, y = 0.549 },
        { hp = 1, kind = "armor", x = 0.405, y = 0.549 },
        { hp = 1, kind = "armor", x = 0.468, y = 0.621 },
        { hp = 1, kind = "armor", x = 0.532, y = 0.621 },
        { hp = 1, kind = "armor", x = 0.468, y = 0.692 },
        { hp = 1, kind = "armor", x = 0.532, y = 0.692 },
        { hp = 1, kind = "potion", x = 0.468, y = 0.549 },
        { hp = 1, kind = "potion", x = 0.532, y = 0.549 },
        { hp = 1, kind = "potion", x = 0.279, y = 0.191 },
        { hp = 1, kind = "potion", x = 0.153, y = 0.048 },
        { hp = 1, kind = "potion", x = 0.721, y = 0.191 },
        { hp = 1, kind = "potion", x = 0.847, y = 0.048 },
        { hp = 1, kind = "crit", x = 0.658, y = 0.262 },
        { hp = 1, kind = "crit", x = 0.595, y = 0.191 },
        { hp = 1, kind = "crit", x = 0.342, y = 0.262 },
        { hp = 1, kind = "crit", x = 0.405, y = 0.191 },
        { hp = 1, kind = "multiplier", x = 0.405, y = 0.119 },
        { hp = 1, kind = "multiplier", x = 0.595, y = 0.119 },
        { hp = 1, kind = "aoe", x = 0.405, y = 0.477 },
        { hp = 1, kind = "aoe", x = 0.595, y = 0.477 },
        { hp = 1, kind = "aoe", x = 0.721, y = 0.406 },
        { hp = 1, kind = "aoe", x = 0.279, y = 0.406 },
        { hp = 1, kind = "armor", x = 0.658, y = 0.621 },
        { hp = 1, kind = "armor", x = 0.595, y = 0.692 },
        { hp = 1, kind = "armor", x = 0.342, y = 0.621 },
        { hp = 1, kind = "armor", x = 0.405, y = 0.692 },
        { hp = 1, kind = "armor", x = 0.468, y = 0.764 },
        { hp = 1, kind = "armor", x = 0.532, y = 0.764 },
        { hp = 1, kind = "armor", x = 0.595, y = 0.764 },
        { hp = 1, kind = "armor", x = 0.405, y = 0.764 },
        { hp = 1, kind = "armor", x = 0.468, y = 0.836 },
        { hp = 1, kind = "armor", x = 0.532, y = 0.836 },
        { hp = 1, kind = "crit", x = 0.595, y = 0.621 },
        { hp = 1, kind = "crit", x = 0.405, y = 0.621 }
      },
      type = "predefined"
    }
  }
}

