local M = {}

-- Named block formations usable by encounters
-- Coordinates use the same normalized format as battle_profiles predefined
local FORMATIONS = {
	-- A compact diamond-like formation (adapted from current default)
	starter_diamond = {
		id = "starter_diamond",
		type = "predefined",
		predefined = {
			{ x = 0.532, y = 0.048, kind = "damage", hp = 1 },
			{ x = 0.468, y = 0.048, kind = "damage", hp = 1 },
			{ x = 0.405, y = 0.048, kind = "damage", hp = 1 },
			{ x = 0.405, y = 0.119, kind = "damage", hp = 1 },
			{ x = 0.405, y = 0.191, kind = "damage", hp = 1 },
			{ x = 0.468, y = 0.262, kind = "damage", hp = 1 },
			{ x = 0.532, y = 0.262, kind = "damage", hp = 1 },
			{ x = 0.595, y = 0.191, kind = "damage", hp = 1 },
			{ x = 0.595, y = 0.119, kind = "damage", hp = 1 },
			{ x = 0.595, y = 0.048, kind = "damage", hp = 1 },
			{ x = 0.468, y = 0.119, kind = "crit", hp = 1 },
			{ x = 0.532, y = 0.191, kind = "crit", hp = 1 },
			{ x = 0.658, y = 0.048, kind = "aoe", hp = 1 },
			{ x = 0.342, y = 0.048, kind = "aoe", hp = 1 },
			{ x = 0.342, y = 0.191, kind = "aoe", hp = 1 },
			{ x = 0.658, y = 0.191, kind = "aoe", hp = 1 },
			{ x = 0.721, y = 0.119, kind = "armor", hp = 1 },
			{ x = 0.279, y = 0.119, kind = "armor", hp = 1 },
			{ x = 0.279, y = 0.262, kind = "armor", hp = 1 },
			{ x = 0.342, y = 0.334, kind = "armor", hp = 1 },
			{ x = 0.658, y = 0.334, kind = "armor", hp = 1 },
			{ x = 0.721, y = 0.262, kind = "armor", hp = 1 },
			{ x = 0.658, y = 0.119, kind = "potion", hp = 1 },
			{ x = 0.342, y = 0.119, kind = "potion", hp = 1 },
			{ x = 0.847, y = 0.048, kind = "damage", hp = 1 },
			{ x = 0.153, y = 0.048, kind = "damage", hp = 1 },
			{ x = 0.153, y = 0.191, kind = "damage", hp = 1 },
			{ x = 0.847, y = 0.191, kind = "damage", hp = 1 },
			{ x = 0.153, y = 0.334, kind = "damage", hp = 1 },
			{ x = 0.847, y = 0.334, kind = "damage", hp = 1 },
			{ x = 0.532, y = 0.406, kind = "aoe", hp = 1 },
			{ x = 0.784, y = 0.406, kind = "aoe", hp = 1 },
			{ x = 0.153, y = 0.406, kind = "aoe", hp = 1 },
			{ x = 0.468, y = 0.406, kind = "crit", hp = 1 },
			{ x = 0.721, y = 0.406, kind = "crit", hp = 1 },
		},
	},

	-- Thin wall formation (example)
	thin_wall = {
		id = "thin_wall",
		type = "predefined",
		predefined = {
			{ x = 0.5, y = 0.08, kind = "damage" },
			{ x = 0.45, y = 0.08, kind = "armor" },
			{ x = 0.55, y = 0.08, kind = "crit" },
			{ x = 0.4, y = 0.16, kind = "damage" },
			{ x = 0.6, y = 0.16, kind = "damage" },
			{ x = 0.35, y = 0.24, kind = "armor" },
			{ x = 0.65, y = 0.24, kind = "armor" },
			{ x = 0.5, y = 0.32, kind = "crit" },
		},
	},
}

function M.get(id)
	return FORMATIONS[id]
end

function M.list()
	local out = {}
	for _, v in pairs(FORMATIONS) do table.insert(out, v) end
	return out
end

return M


