local config = require("config")

local PlayerState = {}
PlayerState.__index = PlayerState

function PlayerState.new()
  return setmetatable({
    health = config.battle.playerMaxHP,
    maxHealth = config.battle.playerMaxHP,
    gold = 0,
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

function PlayerState:getHealth()
  return self.health
end

function PlayerState:getMaxHealth()
  return self.maxHealth
end

function PlayerState:getGold()
  return self.gold
end

return PlayerState

