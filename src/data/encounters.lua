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
                              y = 0.155
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.563,
                              y = 0.153
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.502,
                              y = 0.079
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.5,
                              y = 0.436
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
                              kind = "armor",
                              x = 0.503,
                              y = 0.266
                            }
                  },
            type = "predefined"
          }
    },
  {
      id = "ENCOUNTER_DOUBLE_FAWN",
      difficulty = 2,
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
                              kind = "crit",
                              x = 0.502,
                              y = 0.079
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.5,
                              y = 0.436
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.817,
                              y = 0.077
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.186,
                              y = 0.083
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
                              kind = "armor",
                              x = 0.503,
                              y = 0.266
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
                              x = 0.847,
                              y = 0.549
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
                              x = 0.153,
                              y = 0.549
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
                              kind = "aoe",
                              x = 0.44,
                              y = 0.147
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.565,
                              y = 0.143
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
                              x = 0.658,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.342,
                              y = 0.334
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
                              x = 0.595,
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
                              kind = "soul",
                              x = 0.498,
                              y = 0.3
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
                            }
                  },
            random = {
                    clustering = {
                              clusterSizes = {
                                          9,
                                          12
                                        },
                              enabled = true
                            },
                    count = 24
                  },
            type = "predefined"
          }
    },
  {
      id = "ENCOUNTER_DOUBLE_FUNGLOOM",
      difficulty = 2,
      centerWidthFactor = 0.43,
      enemies = {
            "fungloom",
            "fungloom"
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
                              kind = "soul",
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
                              kind = "soul",
                              x = 0.693,
                              y = 0.3
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
                              x = 0.784,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.595,
                              y = 0.262
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
                              x = 0.216,
                              y = 0.262
                            }
                  },
            type = "predefined"
          }
    },
  {
      id = "ENCOUNTER_FUNGLOOM_FAWN",
      difficulty = 2,
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
                              x = 0.216,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.406,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.343,
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
                              x = 0.313,
                              y = 0.079
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.311,
                              y = 0.436
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.406,
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
                              x = 0.279,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.343,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.314,
                              y = 0.266
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
                              x = 0.721,
                              y = 0.477
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
                              kind = "damage",
                              x = 0.784,
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
                              kind = "soul",
                              x = 0.691,
                              y = 0.3
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.252,
                              y = 0.142
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.371,
                              y = 0.141
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.66,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "aoe",
                              x = 0.723,
                              y = 0.406
                            }
                  },
            type = "predefined"
          }
    },
  {
      id = "ENCOUNTER_SOLO_CRAWLER",
      difficulty = 2,
      centerWidthFactor = 0.43,
      enemies = {
            "crawler"
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
                              x = 0.279,
                              y = 0.477
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
                              y = 0.477
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
                              kind = "soul",
                              x = 0.5,
                              y = 0.37
                            }
                  },
            type = "predefined"
          }
    },
  {
      id = "ENCOUNTER_CRAWLER_DOUBLE_FAWN",
      difficulty = 2,
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
                              kind = "soul",
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
