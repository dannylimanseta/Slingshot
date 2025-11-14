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
      id = "ENCOUNTER_SOLO_FUNGLOOM",
      difficulty = 1,
      centerWidthFactor = 0.43,
      enemies = {
            "fungloom"
          },
      blockFormation = {
            predefined = {
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
      id = "ENCOUNTER_DOUBLE_FAWN",
      difficulty = 1,
      centerWidthFactor = 0.43,
      enemies = {
            "fawn",
            "fawn"
          },
      blockFormation = {
            predefined = {
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
      id = "ENCOUNTER_DOUBLE_FUNGLOOM",
      difficulty = 1,
      centerWidthFactor = 0.43,
      enemies = {
            "fungloom",
            "fungloom"
          },
      blockFormation = {
            predefined = {
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
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.342,
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
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.847,
                              y = 0.191
                            },
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
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.847,
                              y = 0.262
                            },
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
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.847,
                              y = 0.334
                            },
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
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.847,
                              y = 0.477
                            },
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
                              x = 0.847,
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
                              kind = "damage",
                              x = 0.847,
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
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.5,
                              y = 0.262
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
                              kind = "crit",
                              x = 0.5,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.436,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.5,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.564,
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
                              kind = "crit",
                              x = 0.468,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.532,
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
                              kind = "armor",
                              x = 0.436,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.5,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.564,
                              y = 0.477
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
                              kind = "damage",
                              x = 0.5,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.342,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.658,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.342,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.658,
                              y = 0.334
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
                              kind = "crit",
                              x = 0.279,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.216,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
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
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.279,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.342,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.216,
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
                              kind = "potion",
                              x = 0.153,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.153,
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
                              x = 0.658,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
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
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.658,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.784,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.721,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.847,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.847,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.43,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.5,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.57,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.5,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.43,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.57,
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
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.342,
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
                              kind = "multiplier",
                              x = 0.342,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.309,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.153,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.153,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.658,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.658,
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
                              kind = "crit",
                              x = 0.658,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.658,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.784,
                              y = 0.621
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
                              x = 0.784,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.784,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.784,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.721,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.721,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.847,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.847,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.43,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.5,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.57,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.5,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.43,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.57,
                              y = 0.262
                            }
                  },
            type = "predefined"
          }
    },
  {
      id = "ENCOUNTER_SOLO_MENDER",
      difficulty = 2,
      centerWidthFactor = 0.43,
      enemies = {
            "mender"
          },
      blockFormation = {
            predefined = {
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.5,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.436,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.564,
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
                              kind = "multiplier",
                              x = 0.468,
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
                              kind = "damage",
                              x = 0.595,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.436,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.5,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.564,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.405,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.468,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.532,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.595,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.436,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.5,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.564,
                              y = 0.549
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
                              kind = "potion",
                              x = 0.342,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.658,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.342,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.658,
                              y = 0.549
                            }
                  },
            type = "predefined"
          }
    },
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
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.216,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.342,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.468,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.595,
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
                              kind = "crit",
                              x = 0.847,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.153,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.279,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.532,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.658,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.784,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.153,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.279,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.405,
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
                              kind = "aoe",
                              x = 0.658,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.784,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.847,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.153,
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
                              kind = "crit",
                              x = 0.405,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.532,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.658,
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
                              x = 0.216,
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
                              kind = "damage",
                              x = 0.721,
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
                              x = 0.405,
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
                              x = 0.658,
                              y = 0.621
                            }
                  },
            type = "predefined"
          }
    },
  {
      id = "ENCOUNTER_SOLO_BLOODHOUND",
      difficulty = 2,
      centerWidthFactor = 0.43,
      enemies = {
            "bloodhound"
          },
      blockFormation = {
            predefined = {
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.31,
                              y = 0.19
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.69,
                              y = 0.19
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.374,
                              y = 0.262
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
                              x = 0.5,
                              y = 0.24
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.564,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.626,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.374,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.626,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.5,
                              y = 0.406
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
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
                              y = 0.592
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.468,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.532,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.595,
                              y = 0.592
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
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.405,
                              y = 0.524
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.593,
                              y = 0.524
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.659,
                              y = 0.617
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.341,
                              y = 0.617
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.341,
                              y = 0.681
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.659,
                              y = 0.683
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.468,
                              y = 0.688
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.533,
                              y = 0.688
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.503,
                              y = 0.752
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.276,
                              y = 0.124
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.726,
                              y = 0.123
                            }
                  },
            type = "predefined"
          }
    },
  {
      id = "ENCOUNTER_ELITE_BLOODHOUND_MENDERS",
      difficulty = 2,
      centerWidthFactor = 0.43,
      enemies = {
            "bloodhound",
            "mender",
            "mender"
          },
      blockFormation = {
            predefined = {
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.153,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.216,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.153,
                              y = 0.334
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
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.279,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.279,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.342,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.468,
                              y = 0.119
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.532,
                              y = 0.119
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.595,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.658,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.405,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.595,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.721,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.721,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.721,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.784,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.847,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.784,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.847,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.784,
                              y = 0.477
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
                              x = 0.342,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.468,
                              y = 0.643
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.532,
                              y = 0.643
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.659,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.659,
                              y = 0.62
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.502,
                              y = 0.709
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.44,
                              y = 0.366
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.561,
                              y = 0.364
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.658,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.342,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.342,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.658,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.5,
                              y = 0.428
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.721,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.279,
                              y = 0.477
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
                              x = 0.595,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.405,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.658,
                              y = 0.692
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.502,
                              y = 0.775
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.342,
                              y = 0.692
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
                              x = 0.502,
                              y = 0.224
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.468,
                              y = 0.579
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.533,
                              y = 0.579
                            }
                  },
            type = "predefined"
          },
      elite = true
    }
}

-- Load additional encounters from modular files (if present)
local ok_spore, extra_spore = pcall(require, "data.encounters.difficulty_2.spore_caller_boar")
if ok_spore and type(extra_spore) == "table" then
	for _, enc in ipairs(extra_spore) do
		table.insert(ENCOUNTERS, enc)
	end
end

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
