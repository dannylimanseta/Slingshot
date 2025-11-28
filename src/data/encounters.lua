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
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.595,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.595,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.595,
                              y = 0.401
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
                              x = 0.405,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.595,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.468,
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
                              kind = "armor",
                              x = 0.5,
                              y = 0.543
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
                              x = 0.468,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.532,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.5,
                              y = 0.298
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.5,
                              y = 0.362
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.5,
                              y = 0.051
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
                              kind = "armor",
                              x = 0.564,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.5,
                              y = 0.334
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
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.5,
                              y = 0.405
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.342,
                              y = 0.336
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
                              x = 0.437,
                              y = 0.617
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.502,
                              y = 0.617
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.565,
                              y = 0.615
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.595,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.468,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.532,
                              y = 0.191
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
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.342,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.342,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.216,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
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
                              x = 0.216,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.405,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.216,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.595,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.784,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.595,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.595,
                              y = 0.262
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
                              x = 0.721,
                              y = 0.191
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
                              x = 0.784,
                              y = 0.334
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
                              x = 0.405,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.216,
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
                              x = 0.721,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.689,
                              y = 0.617
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
                              x = 0.311,
                              y = 0.617
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.691,
                              y = 0.123
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.314,
                              y = 0.124
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.309,
                              y = 0.37
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.689,
                              y = 0.368
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.691,
                              y = 0.436
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.309,
                              y = 0.436
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
                              kind = "potion",
                              x = 0.405,
                              y = 0.439
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.593,
                              y = 0.436
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.502,
                              y = 0.503
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.437,
                              y = 0.567
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.566,
                              y = 0.567
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.249,
                              y = 0.511
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.754,
                              y = 0.511
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.437,
                              y = 0.633
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.566,
                              y = 0.633
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.502,
                              y = 0.633
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.503,
                              y = 0.566
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.629,
                              y = 0.566
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.374,
                              y = 0.567
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.439,
                              y = 0.699
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.502,
                              y = 0.699
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.566,
                              y = 0.698
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.249,
                              y = 0.444
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.753,
                              y = 0.444
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.694,
                              y = 0.566
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.306,
                              y = 0.566
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.691,
                              y = 0.377
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.311,
                              y = 0.376
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.438,
                              y = 0.258
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.566,
                              y = 0.258
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.503,
                              y = 0.231
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.374,
                              y = 0.316
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.627,
                              y = 0.317
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.468,
                              y = 0.387
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.531,
                              y = 0.385
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.437,
                              y = 0.501
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.567,
                              y = 0.499
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
                              x = 0.468,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.532,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.342,
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
                              kind = "damage",
                              x = 0.279,
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
                              kind = "damage",
                              x = 0.721,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.595,
                              y = 0.692
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.532,
                              y = 0.764
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.468,
                              y = 0.764
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
                              y = 0.692
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.784,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.216,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.502,
                              y = 0.127
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.595,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.405,
                              y = 0.262
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
                              x = 0.658,
                              y = 0.621
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
                              kind = "armor",
                              x = 0.405,
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
                              kind = "potion",
                              x = 0.468,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.532,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.503,
                              y = 0.337
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.502,
                              y = 0.609
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
                              x = 0.405,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
                              y = 0.262
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
                              x = 0.595,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.595,
                              y = 0.334
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
                              x = 0.405,
                              y = 0.406
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
                              kind = "crit",
                              x = 0.5,
                              y = 0.368
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
                              x = 0.342,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.658,
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
                              x = 0.721,
                              y = 0.119
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.279,
                              y = 0.119
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.279,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.279,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "aoe",
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
                              kind = "damage",
                              x = 0.216,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.342,
                              y = 0.334
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
                              x = 0.502,
                              y = 0.184
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.503,
                              y = 0.046
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.502,
                              y = 0.112
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.847,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.153,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.501,
                              y = 0.543
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.501,
                              y = 0.613
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.501,
                              y = 0.682
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
                              y = 0.406
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
                              x = 0.405,
                              y = 0.477
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
                              x = 0.468,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.501,
                              y = 0.444
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
                              x = 0.405,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.595,
                              y = 0.334
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
                              x = 0.405,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "armor",
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
                              kind = "crit",
                              x = 0.658,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.721,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.721,
                              y = 0.692
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.279,
                              y = 0.692
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.279,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.721,
                              y = 0.621
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
                              x = 0.658,
                              y = 0.692
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
                              x = 0.279,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
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
                              kind = "damage",
                              x = 0.279,
                              y = 0.477
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
                              x = 0.405,
                              y = 0.692
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.468,
                              y = 0.692
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.532,
                              y = 0.692
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.595,
                              y = 0.692
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
                              x = 0.721,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.721,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.721,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.595,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.532,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.468,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
                              y = 0.191
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
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.153,
                              y = 0.119
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.262
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
                              x = 0.847,
                              y = 0.119
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
                              x = 0.595,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.342,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
                              y = 0.262
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
                            },
                    {
                              hp = 1,
                              kind = "damage",
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
                              x = 0.371,
                              y = 0.476
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.628,
                              y = 0.475
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.403,
                              y = 0.546
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.599,
                              y = 0.546
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.635,
                              y = 0.609
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.371,
                              y = 0.611
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.307,
                              y = 0.649
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.245,
                              y = 0.613
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.699,
                              y = 0.643
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.762,
                              y = 0.607
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.436,
                              y = 0.656
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.567,
                              y = 0.652
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.502,
                              y = 0.691
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.333
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.721,
                              y = 0.334
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
                              x = 0.213,
                              y = 0.548
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.793,
                              y = 0.541
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
                              kind = "damage",
                              x = 0.153,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.186,
                              y = 0.617
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.248,
                              y = 0.617
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.28,
                              y = 0.552
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.313,
                              y = 0.482
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.694,
                              y = 0.483
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.721,
                              y = 0.556
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.753,
                              y = 0.62
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.816,
                              y = 0.62
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.847,
                              y = 0.549
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.405,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.595,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.342,
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
                              kind = "multiplier",
                              x = 0.279,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.721,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.342,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.342,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.658,
                              y = 0.262
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
                              x = 0.342,
                              y = 0.406
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
                              kind = "damage",
                              x = 0.784,
                              y = 0.334
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
                              x = 0.279,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.216,
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
                              kind = "damage",
                              x = 0.405,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.405,
                              y = 0.262
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
                              y = 0.262
                            },
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
                              x = 0.595,
                              y = 0.549
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
                              x = 0.279,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.721,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.784,
                              y = 0.119
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.216,
                              y = 0.119
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
                              x = 0.595,
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
                              x = 0.405,
                              y = 0.692
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
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.721,
                              y = 0.262
                            }
                  },
            type = "predefined"
          },
      elite = true
    },
  {
      id = "ENCOUNTER_SPORE_CALLER_BLOODHOUND",
      difficulty = 2,
      centerWidthFactor = 0.43,
      enemies = {
            "spore_caller",
            "bloodhound"
          },
      blockFormation = {
            predefined = {
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.153,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.153,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.216,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.342,
                              y = 0.692
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.468,
                              y = 0.621
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
                              x = 0.342,
                              y = 0.262
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
                              x = 0.405,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.342,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.721,
                              y = 0.191
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.847,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.847,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.784,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.658,
                              y = 0.692
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.532,
                              y = 0.621
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.595,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.658,
                              y = 0.262
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
                              x = 0.721,
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
                              kind = "damage",
                              x = 0.595,
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
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "multiplier",
                              x = 0.5,
                              y = 0.334
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
                              x = 0.279,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.721,
                              y = 0.262
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
                              x = 0.784,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.279,
                              y = 0.692
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.721,
                              y = 0.692
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
