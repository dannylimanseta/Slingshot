local M = {}

-- Enemy archetypes (reusable across encounters)
-- sprite path is relative to assets/images/
local ENEMIES = {
	crawler = { id = "crawler", name = "Crawler", sprite = "enemy_1.png", maxHP = 80, damageMin = 6, damageMax = 8, spriteScale = 5, scaleMul = 1 },
	fungloom = { id = "fungloom", name = "Fungloom", sprite = "enemy_2.png", maxHP = 50, damageMin = 3, damageMax = 4, spriteScale = 3, scaleMul = 1 },
	fawn = { id = "fawn", name = "Fawn", sprite = "enemy_3.png", maxHP = 40, damageMin = 2, damageMax = 3, spriteScale = 4, scaleMul = 1 },
	stagmaw = { id = "stagmaw", name = "Stagmaw", sprite = "enemy_4.png", maxHP = 120, damageMin = 7, damageMax = 9, spriteScale = 6, scaleMul = 1 },
	deranged_boar = { id = "deranged_boar", name = "Deranged Boar", sprite = "enemy_boar.png", maxHP = 60, damageMin = 4, damageMax = 6, spriteScale = 4.5, scaleMul = 1 },
	bloodhound = { id = "bloodhound", name = "Bloodhound", sprite = "enemy_bloodhound.png", maxHP = 60, damageMin = 4, damageMax = 6, spriteScale = 4.5, scaleMul = 1 },
	mender = { id = "mender", name = "Mender", sprite = "enemy_monkey.png", maxHP = 55, damageMin = 2, damageMax = 4, spriteScale = 4, scaleMul = 1 },
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


