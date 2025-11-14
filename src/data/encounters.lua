local enemies = require("data.enemies")
local formations = require("data.formations")

local M = {}

-- Declarative encounter definitions
-- Each encounter resolves to a battle profile via EncounterManager
local ENCOUNTERS = {
  {
      id = "ENCOUNTER_SOLO_FAWN",
      difficulty = 1,
      centerWidthFactor = 0.43,
      enemies = {
            "fawn"
          },
      blockFormation = {
            predefined = {
                    -- Bottom row (foundation) - damage blocks
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.468,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.532,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.595,
                              y = 0.621
                            },
                    -- Second row - mix of damage and armor
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.405,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.468,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.532,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.595,
                              y = 0.549
                            },
                    -- Third row - center focus with crit
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.436,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.5,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.564,
                              y = 0.477
                            },
                    -- Fourth row - armor protection layer
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.468,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.532,
                              y = 0.406
                            },
                    -- Top section - strategic positioning
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.5,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.436,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.564,
                              y = 0.262
                            },
                    -- Side wings for variety
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.342,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.658,
                              y = 0.477
                            }
                  },
            type = "predefined"
          }
    },
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
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.342,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
                              y = 0.621
                            },
                    -- Left side second row
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.279,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.342,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.405,
                              y = 0.549
                            },
                    -- Left side third row
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.342,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.405,
                              y = 0.477
                            },
                    -- Left side top
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.342,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.216,
                              y = 0.477
                            },
                    -- Right side formation (for right enemy)
                    -- Bottom foundation
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.595,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.658,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.721,
                              y = 0.621
                            },
                    -- Right side second row
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.595,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.658,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.721,
                              y = 0.549
                            },
                    -- Right side third row
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.595,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.658,
                              y = 0.477
                            },
                    -- Right side top
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.658,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.784,
                              y = 0.477
                            },
                    -- Center bridge - AOE blocks (effective against both enemies)
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.468,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.532,
                              y = 0.477
                            },
                    -- Center top - high value target
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.5,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.468,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.532,
                              y = 0.406
                            }
                  },
            type = "predefined"
          }
    },
  {
      id = "ENCOUNTER_SOLO_FUNGLOOM",
      difficulty = 1,
      centerWidthFactor = 0.43,
      enemies = {
            "fungloom"
          },
      blockFormation = {
            predefined = {
                    -- Vertical tower formation - well-spaced to avoid occlusion
                    -- Bottom foundation (wide base, good spacing)
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.5,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.595,
                              y = 0.621
                            },
                    -- Second row - armor protection (staggered for better visibility)
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.436,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.5,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.564,
                              y = 0.549
                            },
                    -- Third row - crit focus (wider spacing to prevent occlusion)
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.5,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.595,
                              y = 0.477
                            },
                    -- Fourth row - multiplier introduction (protected, wider spacing)
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.436,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.5,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.564,
                              y = 0.406
                            },
                    -- Fifth row - high value targets (spread out)
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.405,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.5,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.595,
                              y = 0.334
                            },
                    -- Top section - potions and final crit (well spaced)
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.405,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.5,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.595,
                              y = 0.262
                            },
                    -- Side wings - additional damage blocks (no AOE for single enemy)
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.342,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.658,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.279,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.721,
                              y = 0.406
                            }
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
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.216,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.342,
                              y = 0.621
                            },
                    -- Left second row
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.216,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.342,
                              y = 0.549
                            },
                    -- Left third row
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.342,
                              y = 0.477
                            },
                    -- Left top
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.279,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.216,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.153,
                              y = 0.477
                            },
                    -- Right side formation (for right fungloom)
                    -- Bottom foundation
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.658,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.721,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.784,
                              y = 0.621
                            },
                    -- Right second row
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.658,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.721,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.784,
                              y = 0.549
                            },
                    -- Right third row
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.658,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.721,
                              y = 0.477
                            },
                    -- Right top
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.721,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.784,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.847,
                              y = 0.477
                            },
                    -- Center bridge - AOE blocks (effective against both enemies)
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.405,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.468,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.532,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.595,
                              y = 0.477
                            },
                    -- Center top - high value targets
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.468,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.532,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.5,
                              y = 0.334
                            },
                    -- Center bottom support
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.468,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.532,
                              y = 0.549
                            }
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
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.342,
                              y = 0.621
                            },
                    -- Left second row
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.279,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.342,
                              y = 0.549
                            },
                    -- Left third row
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.342,
                              y = 0.477
                            },
                    -- Left top
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.279,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.342,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.216,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.153,
                              y = 0.477
                            },
                    -- Right side (for fawn) - wider formation
                    -- Bottom foundation
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.658,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.721,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.784,
                              y = 0.621
                            },
                    -- Right second row
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.658,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.721,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.784,
                              y = 0.549
                            },
                    -- Right third row
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.658,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.721,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.784,
                              y = 0.477
                            },
                    -- Right top
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.658,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.721,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.784,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.658,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.784,
                              y = 0.334
                            },
                    -- Center bridge - AOE blocks (effective against both enemies)
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.468,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.532,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.5,
                              y = 0.549
                            },
                    -- Center top - high value targets
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.468,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.532,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.5,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.5,
                              y = 0.262
                            }
                  },
            type = "predefined"
          }
    },
  {
      id = "ENCOUNTER_CRAWLER_DERANGED_BOAR",
      difficulty = 1,
      centerWidthFactor = 0.43,
      enemies = {
            "crawler",
            "deranged_boar"
          },
      blockFormation = {
            predefined = {
                    -- Left side (for crawler) - shockwave-resistant spread formation
                    -- Top row
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.216,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.342,
                              y = 0.191
                            },
                    -- Left second row - armor protection
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.216,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.279,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.342,
                              y = 0.262
                            },
                    -- Left third row - strategic targets
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.216,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.342,
                              y = 0.334
                            },
                    -- Left fourth row
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.216,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.342,
                              y = 0.406
                            },
                    -- Left fifth row
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.216,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.279,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.342,
                              y = 0.477
                            },
                    -- Left bottom
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.279,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.342,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.342,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.153,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.153,
                              y = 0.334
                            },
                    -- Right side (for deranged boar) - compact tower formation
                    -- Top row
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.658,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.721,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.784,
                              y = 0.191
                            },
                    -- Right second row
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.658,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.721,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.784,
                              y = 0.262
                            },
                    -- Right third row
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.658,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.721,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.784,
                              y = 0.334
                            },
                    -- Right fourth row
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.658,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.721,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.784,
                              y = 0.406
                            },
                    -- Right fifth row
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.658,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.721,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.784,
                              y = 0.477
                            },
                    -- Right bottom
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.658,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.721,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.784,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.658,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.721,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.784,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.847,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.847,
                              y = 0.334
                            },
                    -- Center bridge - AOE blocks (effective against both enemies)
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.405,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.468,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.532,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.595,
                              y = 0.477
                            },
                    -- Center top - high value targets
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.468,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.532,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.5,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.468,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.532,
                              y = 0.549
                            },
                    -- Center middle - additional AOE support
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.5,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.595,
                              y = 0.334
                            }
                  },
            type = "predefined"
          },
      elite = true
    },
  {
      id = "ENCOUNTER_CRAWLER_DOUBLE_FAWN",
      difficulty = 1,
      centerWidthFactor = 0.43,
      enemies = {
            "crawler",
            "fawn",
            "fawn"
          },
      blockFormation = {
            predefined = {
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.468,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.532,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.595,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.721,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
                              y = 0.119
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.595,
                              y = 0.119
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.468,
                              y = 0.119
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.532,
                              y = 0.119
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.721,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.721,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.279,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.279,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.342,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.658,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.658,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.342,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.468,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.532,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.595,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.595,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.5,
                              y = 0.37
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.153,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.847,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.847,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.153,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.847,
                              y = 0.119
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.153,
                              y = 0.119
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.405,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.595,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.847,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.153,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.468,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.532,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.721,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.279,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.153,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.847,
                              y = 0.334
                            }
                  },
            type = "predefined"
          },
      elite = true
    },
  {
      id = "ENCOUNTER_STAGMAW_DOUBLE_FAWN",
      difficulty = 1,
      centerWidthFactor = 0.43,
      enemies = {
            "fawn",
            "stagmaw",
            "fawn"
          },
      blockFormation = {
            predefined = {
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.153,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.153,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.216,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.153,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.216,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.342,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.658,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.721,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.784,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.784,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.847,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.847,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.847,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.847,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.721,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.279,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.153,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.153,
                              y = 0.119
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.279,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.721,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.847,
                              y = 0.119
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.721,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.658,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.595,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.279,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.342,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.405,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.468,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.532,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.468,
                              y = 0.692
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.532,
                              y = 0.692
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.468,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.532,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.279,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.153,
                              y = 0.048
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.721,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.847,
                              y = 0.048
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.658,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.595,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.342,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.405,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.405,
                              y = 0.119
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.595,
                              y = 0.119
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.405,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.595,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.721,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.279,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.658,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.595,
                              y = 0.692
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.342,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.405,
                              y = 0.692
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.468,
                              y = 0.764
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.532,
                              y = 0.764
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.595,
                              y = 0.764
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.405,
                              y = 0.764
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.468,
                              y = 0.836
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.532,
                              y = 0.836
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.595,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.405,
                              y = 0.621
                            }
                  },
            type = "predefined"
          },
      elite = true
    },
  {
      id = "ENCOUNTER_SOLO_DERANGED_BOAR",
      difficulty = 2,
      centerWidthFactor = 0.43,
      enemies = {
            "deranged_boar"
          },
      blockFormation = {
            predefined = {
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.595,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.532,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.468,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.439,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.563,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.502,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.5,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.595,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.405,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.468,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.532,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.503,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.468,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.532,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.5,
                              y = 0.549
                            }
                  },
            type = "predefined"
          }
    },
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
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.405,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.342,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.342,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.342,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.216,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.153,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.468,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.309,
                              y = 0.3
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.658,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.721,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.658,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.721,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.658,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.721,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.595,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.532,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.784,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.847,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.693,
                              y = 0.3
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.309,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.693,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.279,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.342,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.658,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.721,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.405,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.595,
                              y = 0.262
                            }
                  },
            type = "predefined"
          }
    },
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
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.532,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.595,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.658,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.216,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.847,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.532,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.468,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.468,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.405,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.532,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.532,
                              y = 0.549
                            }
                  },
            type = "predefined"
          }
    }
}

-- Index by id for quick lookup
local INDEX = {}
for _, enc in ipairs(ENCOUNTERS) do
	INDEX[enc.id] = enc
end

function M.get(id)
	return INDEX[id]
end

function M.list()
	return ENCOUNTERS
end

return M
