local enemies = require("data.enemies")
local formations = require("data.formations")
local encounters = require("data.encounters")

local EncounterManager = {}
EncounterManager.__index = EncounterManager

local _currentEncounterId = nil
local _currentBattleProfile = nil

local function deepcopy(tbl)
	if type(tbl) ~= "table" then return tbl end
	local out = {}
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			out[k] = deepcopy(v)
		else
			out[k] = v
		end
	end
	return out
end

local function resolveEnemyRef(ref)
	-- ref can be string id or table { id=..., overrides... }
	if type(ref) == "string" then
		local base = enemies.get(ref)
		return base and deepcopy(base) or nil
	elseif type(ref) == "table" then
		local id = ref.id
		local base = id and enemies.get(id) or {}
		local cfg = deepcopy(base or {})
		for k, v in pairs(ref) do
			if k ~= "id" then cfg[k] = v end
		end
		return cfg
	end
	return nil
end

local function resolveFormation(enc)
	-- If formationId provided, use predefined formation
	if enc.formationId then
		local def = formations.get(enc.formationId)
		if def and def.type == "predefined" and type(def.predefined) == "table" then
			return { type = "predefined", predefined = def.predefined }
		end
	end
	-- If random formation provided directly
	if enc.blockFormation and enc.blockFormation.type == "random" then
		return deepcopy(enc.blockFormation)
	end
	-- Fallback to default random
	return { type = "random", random = { } }
end

local function buildBattleProfileFromEncounter(enc)
	if not enc then return nil end
	local profile = {
		centerWidthFactor = enc.centerWidthFactor or 0.43,
		enemySpacing = enc.enemySpacing or { [1] = 0, [2] = 40, [3] = -15 },
		enemies = {},
		blockFormation = resolveFormation(enc),
	}
	-- Resolve enemies
	if enc.enemies and type(enc.enemies) == "table" then
		for i = 1, #enc.enemies do
			local e = resolveEnemyRef(enc.enemies[i])
			if e then table.insert(profile.enemies, e) end
		end
	end
	-- Optional clamp on enemyCount (default to length of enemies list)
	profile.enemyCount = enc.enemyCount or (profile.enemies and #profile.enemies or 0)
	return profile
end

function EncounterManager.setEncounterById(id)
	_currentEncounterId = id
	_currentBattleProfile = nil
	local enc = encounters.get(id)
	if enc then
		_currentBattleProfile = buildBattleProfileFromEncounter(enc)
	end
end

function EncounterManager.clearEncounter()
	_currentEncounterId = nil
	_currentBattleProfile = nil
end

function EncounterManager.getCurrentEncounterId()
	return _currentEncounterId
end

function EncounterManager.getCurrentBattleProfile()
	return _currentBattleProfile
end

function EncounterManager.pickRandomEncounterId(filterFn)
	local list = encounters.list()
	local pool = {}
	for _, enc in ipairs(list) do
		if not filterFn or filterFn(enc) then
			table.insert(pool, enc.id)
		end
	end
	if #pool == 0 then return nil end
	local idx = love.math.random(1, #pool)
	return pool[idx]
end

return EncounterManager


