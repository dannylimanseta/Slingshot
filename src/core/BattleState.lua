-- BattleState.lua
-- Centralized battle state container with event-driven mutators.

local config = require("config")
local PlayerState = require("core.PlayerState")
local battle_profiles = require("data.battle_profiles")

local BattleState = {}
BattleState.__index = BattleState

-- Forward declaration for fallback event emitter
local function makeFallbackEmitter()
  local emitter = { listeners = {} }
  function emitter:on(name, fn)
    if not self.listeners[name] then self.listeners[name] = {} end
    table.insert(self.listeners[name], fn)
  end
  function emitter:off(name, fn)
    local list = self.listeners[name]
    if not list then return end
    for i = #list, 1, -1 do
      if list[i] == fn then table.remove(list, i) end
    end
  end
  function emitter:emit(name, ...)
    local list = self.listeners[name]
    if not list then return end
    for _, fn in ipairs(list) do
      fn(...)
    end
  end
  return emitter
end

local EventEmitter = nil
pcall(function() EventEmitter = require("core.EventEmitter") end)

---Singleton reference to current battle state
local _currentState = nil

---Creates (or replaces) the active battle state
---@param opts table? { profileId?, profile?, rngSeed?, battleId? }
---@return table state
function BattleState.new(opts)
  opts = opts or {}

  -- Resolve battle profile
  local profile = opts.profile
  if not profile then
    local profileId = opts.profileId or battle_profiles.Types.DEFAULT
    profile = battle_profiles.getProfile(profileId)
  end

  -- Player baseline
  local playerState = PlayerState.getInstance()
  local maxHP = playerState.getMaxHealth and playerState:getMaxHealth() or playerState.maxHealth or config.battle.playerMaxHP
  local currentHP = playerState.getHealth and playerState:getHealth() or playerState.health or maxHP
  local currentArmor = playerState.getArmor and playerState:getArmor() or playerState.armor or 0

  local state = {
    meta = {
      battleId = opts.battleId or tostring(os.time()) .. "-" .. tostring(love.math.random(1, 1e6)),
      seed = opts.rngSeed or love.math.random(1, 1e9),
      profileId = profile and profile.id or opts.profileId,
      startTime = love.timer and love.timer.getTime and love.timer.getTime() or os.time(),
    },

    turn = {
      number = 0,
      phase = "init",
      queue = {},
      currentAction = nil,
      timers = {
        action = 0,
        enemyAttackDelay = 0,
        playerAttackDelay = 0,
      },
    },

    player = {
      hp = currentHP,
      maxHP = maxHP,
      armor = currentArmor,
      combo = {
        count = 0,
        timeout = 0,
        lastHitAt = 0,
      },
      healingPending = 0,
      armorPending = 0,
      status = {
        stunned = false,
        buffs = {},
        debuffs = {},
      },
      resources = {
        energy = 0,
        mana = 0,
      },
    },

    enemies = {},

    blocks = {
      destroyedThisTurn = 0,
      respawnPending = 0,
      calcified = {},
    },

    projectiles = {
      balls = {},
      lightning = {},
      blackHoles = {},
    },

    effects = {
      screenshake = {
        magnitude = 0,
        duration = 0,
        remaining = 0,
      },
      popups = {},
      indicators = {},
    },

    rewards = {
      score = 0,
      armorThisTurn = 0,
      healThisTurn = 0,
      critCount = 0,
      multiplierCount = 0,
      aoeFlag = false,
      blockHitSequence = {},
      baseDamage = 0,
      projectileId = "strike",
    },

    flags = {
      canShoot = true,
      ballsInFlight = 0,
      pendingEnemyTurn = false,
      victory = false,
      defeat = false,
    },
  }

  -- Populate enemies from profile (high-level data only)
  if profile and profile.enemies then
    for index, enemyConfig in ipairs(profile.enemies) do
      table.insert(state.enemies, {
        id = enemyConfig.id or ("enemy_" .. index),
        index = index,
        name = enemyConfig.name or ("Enemy " .. tostring(index)),
        hp = enemyConfig.maxHP or 25,
        maxHP = enemyConfig.maxHP or 25,
        armor = enemyConfig.armor or 0,
        damageMin = enemyConfig.damageMin or 3,
        damageMax = enemyConfig.damageMax or 8,
        intent = nil,
        status = {
          disintegrating = false,
          pendingDisintegration = false,
          buffs = {},
          debuffs = {},
        },
        timers = {
          flash = 0,
          knockback = 0,
          lunge = 0,
          jump = 0,
        },
        visuals = {
          pulseTime = love.math.random() * math.pi * 2,
        },
      })
    end
  end

  -- Attach event emitter
  local emitter = (EventEmitter and EventEmitter.new and EventEmitter:new()) or makeFallbackEmitter()
  state._events = emitter

  _currentState = state
  return state
end

---Returns the active state reference
---@return table|nil
function BattleState.get()
  return _currentState
end

---Returns deep-ish snapshot for debugging/testing
---@return table|nil
function BattleState.snapshot()
  if not _currentState then return nil end
  return BattleState.Serializable.export(_currentState)
end

---Restores state from snapshot
---@param snap table
---@return table
function BattleState.restore(snap)
  local imported = BattleState.Serializable.import(snap)
  _currentState = imported
  return imported
end

function BattleState.on(eventName, callback)
  assert(_currentState and _currentState._events, "BattleState not initialized")
  _currentState._events:on(eventName, callback)
end

function BattleState.off(eventName, callback)
  assert(_currentState and _currentState._events, "BattleState not initialized")
  _currentState._events:off(eventName, callback)
end

function BattleState._emit(eventName, ...)
  if not _currentState or not _currentState._events then return end
  _currentState._events:emit(eventName, ...)
end

-- Mutators -----------------------------------------------------------

function BattleState.setCanShoot(value)
  local state = assert(_currentState, "BattleState not initialized")
  if state.flags.canShoot ~= value then
    state.flags.canShoot = value and true or false
    BattleState._emit("can_shoot_changed", state.flags.canShoot)
  end
end

function BattleState.setBallsInFlight(count)
  local state = assert(_currentState, "BattleState not initialized")
  local newCount = math.max(0, count or 0)
  if state.flags.ballsInFlight ~= newCount then
    state.flags.ballsInFlight = newCount
    BattleState._emit("balls_in_flight_changed", newCount)
  end
end

function BattleState.registerBall(ball)
  local state = assert(_currentState, "BattleState not initialized")
  state.projectiles.balls = state.projectiles.balls or {}
  table.insert(state.projectiles.balls, ball)
  state.flags.ballsInFlight = #state.projectiles.balls
  BattleState._emit("ball_registered", ball)
  BattleState._emit("balls_in_flight_changed", state.flags.ballsInFlight)
end

function BattleState.removeBall(predicate)
  local state = assert(_currentState, "BattleState not initialized")
  local balls = state.projectiles.balls or {}
  local removed = nil
  for i = #balls, 1, -1 do
    local ball = balls[i]
    local shouldRemove = false
    if type(predicate) == "function" then
      shouldRemove = predicate(ball)
    elseif predicate == ball.id then
      shouldRemove = true
    end
    if shouldRemove then
      removed = ball
      table.remove(balls, i)
    end
  end
  state.flags.ballsInFlight = #balls
  if removed then
    BattleState._emit("ball_removed", removed)
    BattleState._emit("balls_in_flight_changed", state.flags.ballsInFlight)
  end
end

function BattleState.setBlackHoles(list)
  local state = assert(_currentState, "BattleState not initialized")
  state.projectiles.blackHoles = list or {}
  BattleState._emit("black_holes_changed", state.projectiles.blackHoles)
end

function BattleState.setLightningSequences(list)
  local state = assert(_currentState, "BattleState not initialized")
  state.projectiles.lightning = list or {}
  BattleState._emit("lightning_sequences_changed", state.projectiles.lightning)
end

function BattleState.setTurnPhase(phase, opts)
  local state = assert(_currentState, "BattleState not initialized")
  if state.turn.phase ~= phase then
    local prev = state.turn.phase
    state.turn.phase = phase
    if opts and opts.turnNumber then
      state.turn.number = opts.turnNumber
    end
    BattleState._emit("turn_phase_changed", phase, prev)
  end
end

function BattleState.incrementTurnNumber()
  local state = assert(_currentState, "BattleState not initialized")
  state.turn.number = state.turn.number + 1
  BattleState._emit("turn_number_changed", state.turn.number)
end

function BattleState.applyPlayerDamage(amount)
  local state = assert(_currentState, "BattleState not initialized")
  local dmg = math.max(0, amount or 0)
  if state.player.armor > 0 then
    local absorbed = math.min(state.player.armor, dmg)
    state.player.armor = state.player.armor - absorbed
    dmg = dmg - absorbed
  end
  if dmg > 0 then
    state.player.hp = math.max(0, state.player.hp - dmg)
    if state.player.hp == 0 then
      state.flags.defeat = true
    end
  end
  BattleState._emit("player_hp_changed", state.player.hp)
  BattleState._emit("player_armor_changed", state.player.armor)
end

function BattleState.applyPlayerHeal(amount)
  local state = assert(_currentState, "BattleState not initialized")
  local heal = math.max(0, amount or 0)
  if heal > 0 then
    state.player.hp = math.min(state.player.maxHP, state.player.hp + heal)
    BattleState._emit("player_hp_changed", state.player.hp)
  end
end

function BattleState.setPlayerArmor(value)
  local state = assert(_currentState, "BattleState not initialized")
  local armor = math.max(0, value or 0)
  if state.player.armor ~= armor then
    state.player.armor = armor
    BattleState._emit("player_armor_changed", armor)
  end
end

function BattleState.addPlayerArmor(amount)
  local state = assert(_currentState, "BattleState not initialized")
  local armor = math.max(0, (state.player.armor or 0) + (amount or 0))
  state.player.armor = armor
  BattleState._emit("player_armor_changed", armor)
end

function BattleState.resetTurnRewards()
  local state = assert(_currentState, "BattleState not initialized")
  state.rewards.score = 0
  state.rewards.armorThisTurn = 0
  state.rewards.healThisTurn = 0
  state.rewards.critCount = 0
  state.rewards.multiplierCount = 0
  state.rewards.aoeFlag = false
  state.rewards.blockHitSequence = {}
  state.rewards.baseDamage = 0
  state.rewards.projectileId = "strike"
  BattleState._emit("turn_rewards_reset", state.rewards)
end

function BattleState.setBaseDamage(amount)
  local state = assert(_currentState, "BattleState not initialized")
  local value = amount or 0
  if state.rewards.baseDamage ~= value then
    state.rewards.baseDamage = value
    BattleState._emit("base_damage_changed", value)
  end
end

function BattleState.setLastProjectile(projectileId)
  local state = assert(_currentState, "BattleState not initialized")
  local id = projectileId or "strike"
  if state.rewards.projectileId ~= id then
    state.rewards.projectileId = id
    BattleState._emit("projectile_changed", id)
  end
end

function BattleState.trackDamage(kind, amount)
  local state = assert(_currentState, "BattleState not initialized")
  local hit = amount or 0
  state.rewards.score = state.rewards.score + hit
  if kind == "crit" then
    state.rewards.critCount = state.rewards.critCount + 1
  elseif kind == "multiplier" then
    state.rewards.multiplierCount = state.rewards.multiplierCount + 1
  elseif kind == "aoe" then
    state.rewards.aoeFlag = true
  elseif kind == "armor" then
    state.rewards.armorThisTurn = state.rewards.armorThisTurn + hit
  elseif kind == "heal" then
    state.rewards.healThisTurn = state.rewards.healThisTurn + hit
  end
  table.insert(state.rewards.blockHitSequence, { kind = kind, amount = hit })
  BattleState._emit("rewards_updated", state.rewards)
end

function BattleState.registerEnemyIntent(enemyId, intent)
  local state = assert(_currentState, "BattleState not initialized")
  for _, enemy in ipairs(state.enemies) do
    if enemy.id == enemyId or enemy.index == enemyId then
      enemy.intent = intent
      BattleState._emit("enemy_intent_changed", enemy, intent)
      break
    end
  end
end

function BattleState.applyEnemyDamage(enemyId, amount)
  local state = assert(_currentState, "BattleState not initialized")
  for _, enemy in ipairs(state.enemies) do
    if enemy.id == enemyId or enemy.index == enemyId then
      local dmg = math.max(0, amount or 0)
      if enemy.armor and enemy.armor > 0 then
        local absorbed = math.min(enemy.armor, dmg)
        enemy.armor = enemy.armor - absorbed
        dmg = dmg - absorbed
      end
      if dmg > 0 then
        enemy.hp = math.max(0, (enemy.hp or enemy.maxHP or 0) - dmg)
        if enemy.hp == 0 then
          enemy.status.disintegrating = true
        end
      end
      BattleState._emit("enemy_hp_changed", enemy)
      break
    end
  end
end

function BattleState.addEnemyArmor(enemyId, amount)
  local state = assert(_currentState, "BattleState not initialized")
  for _, enemy in ipairs(state.enemies) do
    if enemy.id == enemyId or enemy.index == enemyId then
      local armor = math.max(0, amount or 0)
      enemy.armor = (enemy.armor or 0) + armor
      BattleState._emit("enemy_armor_changed", enemy)
      break
    end
  end
end

function BattleState.updateCombo(count, timeout, timestamp)
  local state = assert(_currentState, "BattleState not initialized")
  state.player.combo.count = count or state.player.combo.count
  state.player.combo.timeout = timeout or state.player.combo.timeout
  state.player.combo.lastHitAt = timestamp or state.player.combo.lastHitAt
  BattleState._emit("combo_updated", state.player.combo)
end

function BattleState.registerBlockHit(blockId, data)
  local state = assert(_currentState, "BattleState not initialized")
  if data and data.destroyed then
    state.blocks.destroyedThisTurn = (state.blocks.destroyedThisTurn or 0) + 1
  end
  BattleState._emit("block_hit_registered", blockId, data)
end

function BattleState.resetBlocksDestroyedThisTurn()
  local state = assert(_currentState, "BattleState not initialized")
  if state.blocks.destroyedThisTurn ~= 0 then
    state.blocks.destroyedThisTurn = 0
    BattleState._emit("blocks_destroyed_reset")
  end
end

function BattleState.setVictory()
  local state = assert(_currentState, "BattleState not initialized")
  if not state.flags.victory then
    state.flags.victory = true
    BattleState._emit("battle_victory")
  end
end

function BattleState.setDefeat()
  local state = assert(_currentState, "BattleState not initialized")
  if not state.flags.defeat then
    state.flags.defeat = true
    BattleState._emit("battle_defeat")
  end
end

-- Serialization ------------------------------------------------------

BattleState.Serializable = BattleState.Serializable or {}

function BattleState.Serializable.export(state)
  if not state then return nil end
  return {
    meta = table.deepcopy(state.meta),
    turn = table.deepcopy(state.turn),
    player = table.deepcopy(state.player),
    enemies = table.deepcopy(state.enemies),
    blocks = table.deepcopy(state.blocks),
    projectiles = table.deepcopy(state.projectiles),
    effects = table.deepcopy(state.effects),
    rewards = table.deepcopy(state.rewards),
    flags = table.deepcopy(state.flags),
  }
end

function BattleState.Serializable.import(data)
  assert(data, "BattleState.Serializable.import requires data")
  local state = {
    meta = table.deepcopy(data.meta),
    turn = table.deepcopy(data.turn),
    player = table.deepcopy(data.player),
    enemies = table.deepcopy(data.enemies),
    blocks = table.deepcopy(data.blocks),
    projectiles = table.deepcopy(data.projectiles),
    effects = table.deepcopy(data.effects),
    rewards = table.deepcopy(data.rewards),
    flags = table.deepcopy(data.flags),
  }
  state._events = (EventEmitter and EventEmitter.new and EventEmitter:new()) or makeFallbackEmitter()
  return state
end

return BattleState

