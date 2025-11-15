local config = require("config")

local PlayerState = {}
PlayerState.__index = PlayerState

local function ensureRelicState(self)
  if not self.relics then
    self.relics = {
      owned = {},
      equipped = {},
      order = {},
    }
  end
end

function PlayerState.new()
  return setmetatable({
    health = config.battle.playerMaxHP,
    maxHealth = config.battle.playerMaxHP,
    gold = 0,
    relics = {
      owned = {},
      equipped = {},
      order = {},
    },
    seenEvents = {}, -- Track which events have been shown
  }, PlayerState)
end

-- Get singleton instance
local instance = nil
function PlayerState.getInstance()
  if not instance then
    instance = PlayerState.new()
  end
  return instance
end

function PlayerState:setHealth(value)
  self.health = math.max(0, math.min(value, self.maxHealth))
end

function PlayerState:setMaxHealth(value)
  self.maxHealth = math.max(1, value)
  self.health = math.min(self.health, self.maxHealth)
end

function PlayerState:setGold(value)
  self.gold = math.max(0, value)
end

function PlayerState:addGold(amount)
  self.gold = math.max(0, self.gold + amount)
end

function PlayerState:addRelic(id, opts)
  if not id then return end
  ensureRelicState(self)
  self.relics.owned[id] = true
  local shouldEquip = true
  if opts and opts.autoEquip == false then
    shouldEquip = false
  elseif opts and opts.equip ~= nil then
    shouldEquip = opts.equip and true or false
  end
  if shouldEquip then
    if not self.relics.equipped[id] then
      self.relics.equipped[id] = true
      table.insert(self.relics.order, id)
    end
  end
end

function PlayerState:removeRelic(id)
  if not id then return end
  ensureRelicState(self)
  if self.relics.equipped[id] then
    self.relics.equipped[id] = nil
    local order = self.relics.order
    for i = #order, 1, -1 do
      if order[i] == id then
        table.remove(order, i)
      end
    end
  end
end

function PlayerState:getHealth()
  return self.health
end

function PlayerState:getMaxHealth()
  return self.maxHealth
end

function PlayerState:getGold()
  return self.gold
end

function PlayerState:getRelicState()
  ensureRelicState(self)
  return self.relics
end

function PlayerState:getEquippedRelics()
  ensureRelicState(self)
  return self.relics.equipped
end

function PlayerState:hasRelic(id)
  ensureRelicState(self)
  return self.relics.equipped[id] == true
end

function PlayerState:markEventSeen(eventId)
  if not eventId then return end
  if not self.seenEvents then
    self.seenEvents = {}
  end
  self.seenEvents[eventId] = true
end

function PlayerState:hasSeenEvent(eventId)
  if not self.seenEvents then
    self.seenEvents = {}
  end
  return self.seenEvents[eventId] == true
end

function PlayerState:resetSeenEvents()
  self.seenEvents = {}
end

return PlayerState

