-- Elite encounter: Crawler + Double Fawn
return {
  {
    id = "ENCOUNTER_CRAWLER_DOUBLE_FAWN",
    difficulty = 1,
    centerWidthFactor = 0.43,
    elite = true,
    enemies = {
      "crawler",
      "fawn",
      "fawn"
    },
    blockFormation = {
      predefined = {
        -- Left side (for crawler) - shockwave-resistant spread formation
        -- Top row
        { hp = 1, kind = "damage", x = 0.216, y = 0.191 },
        { hp = 1, kind = "damage", x = 0.279, y = 0.191 },
        { hp = 1, kind = "crit", x = 0.342, y = 0.191 },
        -- Left second row - armor protection
        { hp = 1, kind = "armor", x = 0.216, y = 0.262 },
        { hp = 1, kind = "armor", x = 0.279, y = 0.262 },
        { hp = 1, kind = "armor", x = 0.342, y = 0.262 },
        -- Left third row - strategic targets
        { hp = 1, kind = "multiplier", x = 0.216, y = 0.334 },
        { hp = 1, kind = "damage", x = 0.279, y = 0.334 },
        { hp = 1, kind = "crit", x = 0.342, y = 0.334 },
        -- Left fourth row
        { hp = 1, kind = "armor", x = 0.216, y = 0.406 },
        { hp = 1, kind = "damage", x = 0.279, y = 0.406 },
        { hp = 1, kind = "damage", x = 0.342, y = 0.406 },
        -- Left fifth row
        { hp = 1, kind = "damage", x = 0.216, y = 0.477 },
        { hp = 1, kind = "multiplier", x = 0.279, y = 0.477 },
        { hp = 1, kind = "crit", x = 0.342, y = 0.477 },
        -- Left bottom
        { hp = 1, kind = "armor", x = 0.279, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.342, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.279, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.342, y = 0.621 },
        { hp = 1, kind = "multiplier", x = 0.153, y = 0.406 },
        { hp = 1, kind = "potion", x = 0.153, y = 0.334 },
        -- Right side (for fawns) - compact tower formation
        -- Top row
        { hp = 1, kind = "damage", x = 0.658, y = 0.191 },
        { hp = 1, kind = "crit", x = 0.721, y = 0.191 },
        { hp = 1, kind = "damage", x = 0.784, y = 0.191 },
        { hp = 1, kind = "crit", x = 0.847, y = 0.191 },
        -- Right second row
        { hp = 1, kind = "armor", x = 0.658, y = 0.262 },
        { hp = 1, kind = "armor", x = 0.721, y = 0.262 },
        { hp = 1, kind = "armor", x = 0.784, y = 0.262 },
        { hp = 1, kind = "armor", x = 0.847, y = 0.262 },
        -- Right third row
        { hp = 1, kind = "multiplier", x = 0.658, y = 0.334 },
        { hp = 1, kind = "crit", x = 0.721, y = 0.334 },
        { hp = 1, kind = "damage", x = 0.784, y = 0.334 },
        { hp = 1, kind = "crit", x = 0.847, y = 0.334 },
        -- Right fourth row
        { hp = 1, kind = "armor", x = 0.658, y = 0.406 },
        { hp = 1, kind = "damage", x = 0.721, y = 0.406 },
        { hp = 1, kind = "armor", x = 0.784, y = 0.406 },
        -- Right fifth row
        { hp = 1, kind = "damage", x = 0.658, y = 0.477 },
        { hp = 1, kind = "crit", x = 0.721, y = 0.477 },
        { hp = 1, kind = "multiplier", x = 0.784, y = 0.477 },
        { hp = 1, kind = "crit", x = 0.847, y = 0.477 },
        -- Right bottom
        { hp = 1, kind = "armor", x = 0.658, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.721, y = 0.549 },
        { hp = 1, kind = "armor", x = 0.784, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.847, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.658, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.721, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.784, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.847, y = 0.621 },
        { hp = 1, kind = "multiplier", x = 0.847, y = 0.406 },
        { hp = 1, kind = "potion", x = 0.847, y = 0.334 },
        -- Center bridge - AOE blocks (effective against all enemies)
        { hp = 1, kind = "aoe", x = 0.405, y = 0.477 },
        { hp = 1, kind = "aoe", x = 0.468, y = 0.477 },
        { hp = 1, kind = "aoe", x = 0.532, y = 0.477 },
        { hp = 1, kind = "aoe", x = 0.595, y = 0.477 },
        -- Center top - high value targets
        { hp = 1, kind = "crit", x = 0.468, y = 0.406 },
        { hp = 1, kind = "multiplier", x = 0.532, y = 0.406 },
        { hp = 1, kind = "armor", x = 0.5, y = 0.334 },
        { hp = 1, kind = "damage", x = 0.468, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.532, y = 0.549 },
        -- Center middle - additional AOE support
        { hp = 1, kind = "aoe", x = 0.5, y = 0.262 }
      },
      type = "predefined"
    }
  }
}

