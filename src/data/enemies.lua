local M = {}

-- Enemy archetypes (reusable across encounters)
-- sprite path is relative to assets/images/
local ENEMIES = {
	grunt = { id = "grunt", sprite = "enemy_1.png", maxHP = 80, damageMin = 3, damageMax = 8, spriteScale = 5.2, scaleMul = 1 },
	pikeman = { id = "pikeman", sprite = "enemy_2.png", maxHP = 50, damageMin = 3, damageMax = 5, spriteScale = 3, scaleMul = 1 },
	rogue = { id = "rogue", sprite = "enemy_3.png", maxHP = 40, damageMin = 4, damageMax = 7, spriteScale = 4, scaleMul = 1 },
}

function M.get(id)
	return ENEMIES[id]
end

function M.list()
	local out = {}
	for _, v in pairs(ENEMIES) do table.insert(out, v) end
	return out
end

return M


