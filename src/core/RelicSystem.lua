local relicData = require("data.relics")
local PlayerState = require("core.PlayerState")

local RelicSystem = {}

-- Iterate over equipped relic effects matching a trigger
local function getEquippedRelics()
  local player = PlayerState.getInstance and PlayerState.getInstance()
  if not player or not player.getEquippedRelics then
    return {}
  end
  local equipped = player:getEquippedRelics()
  return equipped or {}
end

local function forEachEffect(trigger, callback, context)
  local equipped = getEquippedRelics()
  for relicId, isActive in pairs(equipped) do
    if isActive then
      local def = relicData.get(relicId)
      if def and def.effects then
        for _, effect in ipairs(def.effects) do
          if effect.trigger == trigger then
            callback(effect, def, context)
          end
        end
      end
    end
  end
end

function RelicSystem.get(id)
  return relicData.get(id)
end

function RelicSystem.list()
  return relicData.list()
end

function RelicSystem.has(id)
  local equipped = getEquippedRelics()
  return equipped[id] == true
end

function RelicSystem.applyArmorReward(baseValue, context)
  local value = baseValue or 0
  forEachEffect("armor_block_reward", function(effect)
    local mode = effect.mode or "add"
    if mode == "override" then
      if effect.value ~= nil then
        value = math.max(value, effect.value)
      end
    elseif mode == "add" then
      value = value + (effect.value or 0)
    elseif mode == "multiply" then
      value = value * (effect.value or 1)
    end
    if effect.min then
      value = math.max(value, effect.min)
    end
    if effect.max then
      value = math.min(value, effect.max)
    end
  end, context)
  return value
end

-- Apply start-of-battle effects (e.g., grant starting armor)
function RelicSystem.applyBattleStart()
  -- Lazy-require to avoid any potential circular requires
  local BattleState = require("core.BattleState")
  forEachEffect("battle_start", function(effect)
    local action = effect.action or "add_player_armor"
    if action == "add_player_armor" then
      local value = tonumber(effect.value) or 0
      if value > 0 then
        BattleState.addPlayerArmor(value)
      end
    end
  end)
end

-- Apply end-of-battle effects (e.g., heal on victory)
-- @param context table | nil  e.g., { result = "victory" | "defeat" }
function RelicSystem.applyBattleEnd(context)
  local PlayerState = require("core.PlayerState")
  local player = PlayerState.getInstance and PlayerState.getInstance()
  forEachEffect("battle_end", function(effect)
    local action = effect.action or "heal_player"
    if action == "heal_player" and player then
      local value = tonumber(effect.value) or 0
      if value > 0 then
        local newHP = math.min(player:getMaxHealth(), player:getHealth() + value)
        player:setHealth(newHP)
      end
    end
  end, context)
end

function RelicSystem.debugEquip(id)
  local player = PlayerState.getInstance and PlayerState.getInstance()
  if player and player.addRelic then
    player:addRelic(id)
  end
end

return RelicSystem


