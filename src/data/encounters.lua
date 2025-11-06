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
                              x = 0.595,
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
                              x = 0.532,
                              y = 0.477
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.468,
                              y = 0.262
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.468,
                              y = 0.334
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.532,
                              y = 0.406
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
                              x = 0.468,
                              y = 0.406
                            },
                    {
                              hp = 1,
                              kind = "armor",
                              x = 0.532,
                              y = 0.262
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
                              x = 0.468,
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
                              kind = "damage",
                              x = 0.405,
                              y = 0.048
                            },
                    {
                              hp = 1,
                              kind = "damage",
                              x = 0.595,
                              y = 0.048
                            },
                    {
                              hp = 1,
                              kind = "potion",
                              x = 0.468,
                              y = 0.048
                            },
                    {
                              hp = 1,
                              kind = "crit",
                              x = 0.532,
                              y = 0.048
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
