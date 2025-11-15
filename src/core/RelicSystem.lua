local relicData = require("data.relics")
local PlayerState = require("core.PlayerState")

local RelicSystem = {}

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

function RelicSystem.debugEquip(id)
  local player = PlayerState.getInstance and PlayerState.getInstance()
  if player and player.addRelic then
    player:addRelic(id)
  end
end

return RelicSystem


