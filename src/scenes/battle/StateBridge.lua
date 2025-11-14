local BattleState = require("core.BattleState")

local StateBridge = {}

function StateBridge.ensure(scene, battleProfile)
  if not scene.battleState then
    scene.battleState = BattleState.get()
  end
  if not scene.battleState then
    scene.battleState = BattleState.new({ profile = battleProfile })
  end
  return scene.battleState
end

function StateBridge.get(scene)
  scene.battleState = scene.battleState or BattleState.get()
  return scene.battleState
end

function StateBridge.syncPlayer(scene)
  local state = scene.battleState or BattleState.get()
  if not state or not state.player then return end
  scene.playerHP = state.player.hp or scene.playerHP
  scene.displayPlayerHP = scene.displayPlayerHP or scene.playerHP
  scene.playerArmor = state.player.armor or scene.playerArmor or 0
  scene.battleState = state
end

function StateBridge.syncEnemies(scene)
  local state = scene.battleState or BattleState.get()
  if not state or not state.enemies then return end
  for i, enemy in ipairs(scene.enemies or {}) do
    local stateEnemy = state.enemies[i]
    if not stateEnemy then
      stateEnemy = {
        id = enemy.id or ("enemy_" .. i),
        index = i,
        name = enemy.name,
        hp = enemy.hp,
        maxHP = enemy.maxHP,
        armor = enemy.armor or 0,
        damageMin = enemy.damageMin,
        damageMax = enemy.damageMax,
        intent = enemy.intent,
        status = {
          disintegrating = enemy.disintegrating,
          pendingDisintegration = enemy.pendingDisintegration,
          buffs = {},
          debuffs = {},
        },
        timers = {
          flash = enemy.flash,
          knockback = enemy.knockbackTime,
          lunge = enemy.lungeTime,
          jump = enemy.jumpTime,
        },
        visuals = {
          pulseTime = enemy.pulseTime,
        },
      }
      state.enemies[i] = stateEnemy
    else
      enemy.hp = stateEnemy.hp or enemy.hp
      enemy.maxHP = stateEnemy.maxHP or enemy.maxHP
      enemy.armor = stateEnemy.armor or enemy.armor
      enemy.intent = stateEnemy.intent or enemy.intent
      stateEnemy.damageMin = stateEnemy.damageMin or enemy.damageMin
      stateEnemy.damageMax = stateEnemy.damageMax or enemy.damageMax
    end
    enemy.stateRef = stateEnemy
  end
  scene.battleState = state
end

function StateBridge.applyPlayerDamage(scene, amount)
  if not amount or amount <= 0 then return 0, 0 end
  local state = scene.battleState or BattleState.get()
  if not state then return 0, 0 end
  local armorBefore = state.player.armor or 0
  local hpBefore = state.player.hp or 0
  BattleState.applyPlayerDamage(amount)
  StateBridge.syncPlayer(scene)
  scene.prevPlayerArmor = scene.playerArmor or 0
  local armorAfter = state.player.armor or 0
  local hpAfter = state.player.hp or 0
  return armorBefore - armorAfter, hpBefore - hpAfter
end

function StateBridge.applyPlayerHeal(scene, amount)
  if not amount or amount <= 0 then return end
  BattleState.applyPlayerHeal(amount)
  StateBridge.syncPlayer(scene)
  scene.playerHealGlowTimer = 1.0
end

function StateBridge.setPlayerArmor(scene, value)
  BattleState.setPlayerArmor(value)
  StateBridge.syncPlayer(scene)
  scene.prevPlayerArmor = scene.playerArmor or 0
end

function StateBridge.addPlayerArmor(scene, amount)
  if not amount or amount == 0 then return end
  BattleState.addPlayerArmor(amount)
  StateBridge.syncPlayer(scene)
  scene.prevPlayerArmor = scene.playerArmor or 0
end

function StateBridge.applyEnemyDamage(scene, index, amount)
  if not amount or amount <= 0 then return end
  BattleState.applyEnemyDamage(index, amount)
  local state = scene.battleState or BattleState.get()
  if not state or not state.enemies then return end
  local stateEnemy = state.enemies[index]
  local enemy = scene.enemies and scene.enemies[index]
  if enemy and stateEnemy then
    enemy.hp = stateEnemy.hp or enemy.hp
    local prevArmor = enemy.armor or 0
    enemy.armor = stateEnemy.armor or enemy.armor
    if not scene.prevEnemyArmor[index] then
      scene.prevEnemyArmor[index] = prevArmor
    end
    enemy.intent = stateEnemy.intent or enemy.intent
  end
end

function StateBridge.registerEnemyIntent(scene, index, intent)
  BattleState.registerEnemyIntent(index, intent)
  local state = scene.battleState or BattleState.get()
  if state and state.enemies and state.enemies[index] then
    state.enemies[index].intent = intent
  end
  local enemy = scene.enemies and scene.enemies[index]
  if enemy then enemy.intent = intent end
end

return StateBridge

