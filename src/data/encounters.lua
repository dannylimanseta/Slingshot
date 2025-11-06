local enemies = require("data.enemies")
local formations = require("data.formations")

local M = {}

-- Declarative encounter definitions
-- Each encounter resolves to a battle profile via EncounterManager
local ENCOUNTERS = {
	{
		id = "ENCOUNTER_STARTER_1",
		label = "Patrol",
		difficulty = 1,
		tags = { "starter" },
		centerWidthFactor = 0.43,
		enemies = { "grunt", "pikeman", "rogue" },
		formationId = "starter_diamond",
	},
	{
		id = "ENCOUNTER_EASY_WALL",
		label = "Thin Wall",
		difficulty = 1,
		tags = { "easy" },
		centerWidthFactor = 0.43,
		enemies = {
			{ id = "grunt", maxHP = 70 },
			{ id = "pikeman", maxHP = 45 },
		},
		formationId = "thin_wall",
	},
	{
		id = "ENCOUNTER_RANDOM_SWARM",
		label = "Swarm",
		difficulty = 2,
		tags = { "random" },
		centerWidthFactor = 0.43,
		enemies = { "grunt", "grunt", "pikeman" },
		blockFormation = { type = "random", random = { count = 28, clustering = { enabled = true, clusterSizes = { 9, 12 } }, critSpawnRatio = 0.08, armorSpawnRatio = 0.12 } },
	},
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


