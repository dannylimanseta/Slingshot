-- Base double enemy encounters
return {
  {
    id = "ENCOUNTER_DOUBLE_FAWN",
    difficulty = 1,
    centerWidthFactor = 0.43,
    enemies = {
      "fawn",
      "fawn"
    },
    blockFormation = {
      predefined = {
        -- Left side formation (for left enemy)
        -- Bottom foundation
        { hp = 1, kind = "damage", x = 0.279, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.342, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.405, y = 0.621 },
        -- Left side second row
        { hp = 1, kind = "armor", x = 0.279, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.342, y = 0.549 },
        { hp = 1, kind = "crit", x = 0.405, y = 0.549 },
        -- Left side third row
        { hp = 1, kind = "damage", x = 0.342, y = 0.477 },
        { hp = 1, kind = "armor", x = 0.405, y = 0.477 },
        -- Left side top
        { hp = 1, kind = "crit", x = 0.342, y = 0.406 },
        { hp = 1, kind = "potion", x = 0.216, y = 0.477 },
        -- Right side formation (for right enemy)
        -- Bottom foundation
        { hp = 1, kind = "damage", x = 0.595, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.658, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.721, y = 0.621 },
        -- Right side second row
        { hp = 1, kind = "crit", x = 0.595, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.658, y = 0.549 },
        { hp = 1, kind = "armor", x = 0.721, y = 0.549 },
        -- Right side third row
        { hp = 1, kind = "armor", x = 0.595, y = 0.477 },
        { hp = 1, kind = "damage", x = 0.658, y = 0.477 },
        -- Right side top
        { hp = 1, kind = "crit", x = 0.658, y = 0.406 },
        { hp = 1, kind = "potion", x = 0.784, y = 0.477 },
        -- Center bridge - AOE blocks (effective against both enemies)
        { hp = 1, kind = "aoe", x = 0.468, y = 0.477 },
        { hp = 1, kind = "aoe", x = 0.532, y = 0.477 },
        -- Center top - high value target
        { hp = 1, kind = "crit", x = 0.5, y = 0.334 },
        { hp = 1, kind = "armor", x = 0.468, y = 0.406 },
        { hp = 1, kind = "armor", x = 0.532, y = 0.406 }
      },
      type = "predefined"
    }
  },
  {
    id = "ENCOUNTER_DOUBLE_FUNGLOOM",
    difficulty = 1,
    centerWidthFactor = 0.43,
    enemies = {
      "fungloom",
      "fungloom"
    },
    blockFormation = {
      predefined = {
        -- Left side formation (for left fungloom)
        -- Bottom foundation
        { hp = 1, kind = "damage", x = 0.216, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.279, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.342, y = 0.621 },
        -- Left second row
        { hp = 1, kind = "armor", x = 0.216, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.279, y = 0.549 },
        { hp = 1, kind = "crit", x = 0.342, y = 0.549 },
        -- Left third row
        { hp = 1, kind = "damage", x = 0.279, y = 0.477 },
        { hp = 1, kind = "armor", x = 0.342, y = 0.477 },
        -- Left top
        { hp = 1, kind = "crit", x = 0.279, y = 0.406 },
        { hp = 1, kind = "multiplier", x = 0.216, y = 0.334 },
        { hp = 1, kind = "potion", x = 0.153, y = 0.477 },
        -- Right side formation (for right fungloom)
        -- Bottom foundation
        { hp = 1, kind = "damage", x = 0.658, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.721, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.784, y = 0.621 },
        -- Right second row
        { hp = 1, kind = "crit", x = 0.658, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.721, y = 0.549 },
        { hp = 1, kind = "armor", x = 0.784, y = 0.549 },
        -- Right third row
        { hp = 1, kind = "armor", x = 0.658, y = 0.477 },
        { hp = 1, kind = "damage", x = 0.721, y = 0.477 },
        -- Right top
        { hp = 1, kind = "crit", x = 0.721, y = 0.406 },
        { hp = 1, kind = "multiplier", x = 0.784, y = 0.334 },
        { hp = 1, kind = "potion", x = 0.847, y = 0.477 },
        -- Center bridge - AOE blocks (effective against both enemies)
        { hp = 1, kind = "aoe", x = 0.405, y = 0.477 },
        { hp = 1, kind = "aoe", x = 0.468, y = 0.477 },
        { hp = 1, kind = "aoe", x = 0.532, y = 0.477 },
        { hp = 1, kind = "aoe", x = 0.595, y = 0.477 },
        -- Center top - high value targets
        { hp = 1, kind = "crit", x = 0.468, y = 0.406 },
        { hp = 1, kind = "crit", x = 0.532, y = 0.406 },
        { hp = 1, kind = "armor", x = 0.5, y = 0.334 },
        -- Center bottom support
        { hp = 1, kind = "damage", x = 0.468, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.532, y = 0.549 }
      },
      type = "predefined"
    }
  },
  {
    id = "ENCOUNTER_FUNGLOOM_FAWN",
    difficulty = 1,
    centerWidthFactor = 0.43,
    enemies = {
      "fungloom",
      "fawn"
    },
    blockFormation = {
      predefined = {
        -- Left side (for fungloom) - vertical tower
        -- Bottom foundation
        { hp = 1, kind = "damage", x = 0.279, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.342, y = 0.621 },
        -- Left second row
        { hp = 1, kind = "armor", x = 0.279, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.342, y = 0.549 },
        -- Left third row
        { hp = 1, kind = "damage", x = 0.279, y = 0.477 },
        { hp = 1, kind = "crit", x = 0.342, y = 0.477 },
        -- Left top
        { hp = 1, kind = "armor", x = 0.279, y = 0.406 },
        { hp = 1, kind = "crit", x = 0.342, y = 0.406 },
        { hp = 1, kind = "multiplier", x = 0.216, y = 0.334 },
        { hp = 1, kind = "potion", x = 0.153, y = 0.477 },
        -- Right side (for fawn) - wider formation
        -- Bottom foundation
        { hp = 1, kind = "damage", x = 0.658, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.721, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.784, y = 0.621 },
        -- Right second row
        { hp = 1, kind = "damage", x = 0.658, y = 0.549 },
        { hp = 1, kind = "armor", x = 0.721, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.784, y = 0.549 },
        -- Right third row
        { hp = 1, kind = "armor", x = 0.658, y = 0.477 },
        { hp = 1, kind = "crit", x = 0.721, y = 0.477 },
        { hp = 1, kind = "armor", x = 0.784, y = 0.477 },
        -- Right top
        { hp = 1, kind = "damage", x = 0.658, y = 0.406 },
        { hp = 1, kind = "crit", x = 0.721, y = 0.406 },
        { hp = 1, kind = "damage", x = 0.784, y = 0.406 },
        { hp = 1, kind = "potion", x = 0.658, y = 0.334 },
        { hp = 1, kind = "potion", x = 0.784, y = 0.334 },
        -- Center bridge - AOE blocks (effective against both enemies)
        { hp = 1, kind = "aoe", x = 0.468, y = 0.477 },
        { hp = 1, kind = "aoe", x = 0.532, y = 0.477 },
        { hp = 1, kind = "aoe", x = 0.5, y = 0.549 },
        -- Center top - high value targets
        { hp = 1, kind = "crit", x = 0.468, y = 0.406 },
        { hp = 1, kind = "crit", x = 0.532, y = 0.406 },
        { hp = 1, kind = "armor", x = 0.5, y = 0.334 },
        { hp = 1, kind = "damage", x = 0.5, y = 0.262 }
      },
      type = "predefined"
    }
  }
}

