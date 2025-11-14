local config = require("config")

local EnemyIntents = {}

local function getHitCount(enemy, intent)
  if enemy.id == "bloodhound" or enemy.name == "Bloodhound" then
    local hpPercent = enemy.maxHP and enemy.maxHP > 0 and (enemy.hp / enemy.maxHP) or 1
    if hpPercent < 0.25 then
      return 3
    elseif hpPercent < 0.5 then
      return 2
    else
      return 1
    end
  end
  return (intent and intent.hits) or 1
end

local function evaluateIntent(scene, enemy, index)
  if enemy.hp <= 0 or enemy.disintegrating then
    return nil
  end

  local intent = nil
  local isEnemy1 = enemy.spritePath == "enemy_1.png"
  local isEnemy2 = enemy.spritePath == "enemy_2.png" or
                   enemy.name == "Fungloom" or
                   (enemy.spritePath and enemy.spritePath:find("enemy_2"))
  local isBoar = enemy.spritePath == "enemy_boar.png"
    or enemy.name == "Deranged Boar"
    or (enemy.spritePath and enemy.spritePath:find("enemy_boar"))
  local isStagmaw = enemy.spritePath == "enemy_4.png" or
                    enemy.name == "Stagmaw" or
                    (enemy.spritePath and enemy.spritePath:find("enemy_4"))
  local isMender = enemy.name == "Mender" or enemy.id == "mender"
  local isBloodhound = enemy.name == "Bloodhound" or enemy.id == "bloodhound"
  local isSporeCaller = enemy.name == "Spore Caller" or enemy.id == "spore_caller"

  local shouldCalcify = isStagmaw and (love.math.random() < 0.3)
  local shouldShockwave = isEnemy1 and (love.math.random() < 0.3)
  local shouldCharge = isBoar and not enemy.chargeReady and (love.math.random() < 0.3)

  if isEnemy2 and not enemy.armorTurnCounter then
    enemy.armorTurnCounter = 0
  end
  local shouldGainArmor = isEnemy2 and (enemy.armorTurnCounter or 0) >= 2

  if isSporeCaller and not enemy.sporeTurnCounter then
    enemy.sporeTurnCounter = 0
  end
  local shouldSpawnSpores = isSporeCaller and (enemy.sporeTurnCounter or 0) >= 1

  local shouldHeal = false
  local healTargetIndex = nil

  if isMender then
    if not enemy.healTurnCounter then
      enemy.healTurnCounter = 0
    end

    local mostDamagedAlly = nil
    local mostDamagedAllyIndex = nil
    local lowestAllyHpPercent = 1.0

    local selfHpPercent = enemy.hp / (enemy.maxHP or 1)
    local selfNeedsHealing = selfHpPercent < 0.5

    for j, otherEnemy in ipairs(scene.enemies or {}) do
      if j ~= index and otherEnemy.hp > 0 and not otherEnemy.disintegrating then
        local hpPercent = otherEnemy.hp / (otherEnemy.maxHP or 1)
        if hpPercent < lowestAllyHpPercent then
          lowestAllyHpPercent = hpPercent
          mostDamagedAlly = otherEnemy
          mostDamagedAllyIndex = j
        end
      end
    end

    if mostDamagedAlly and lowestAllyHpPercent < 0.5 then
      shouldHeal = true
      healTargetIndex = mostDamagedAllyIndex
    elseif selfNeedsHealing then
      shouldHeal = true
      healTargetIndex = index
    elseif (enemy.healTurnCounter or 0) >= 3 then
      shouldHeal = true
      if mostDamagedAlly then
        healTargetIndex = mostDamagedAllyIndex
      else
        healTargetIndex = index
      end
    end
  end

  if isBoar and enemy.chargeReady then
    intent = {
      type = "attack",
      attackType = "charged",
      damageMin = 12,
      damageMax = 16,
    }
    enemy.chargeReady = false
  elseif shouldHeal then
    intent = {
      type = "skill",
      skillType = "heal",
      targetIndex = healTargetIndex,
      amount = 18,
    }
    if isMender then
      enemy.healTurnCounter = 0
    end
  elseif shouldSpawnSpores then
    intent = {
      type = "skill",
      skillType = "spore",
      sporeCount = love.math.random(2, 3),
    }
    enemy.sporeTurnCounter = 0
  elseif shouldGainArmor then
    intent = {
      type = "armor",
      amount = 5,
    }
    enemy.armorTurnCounter = 0
  elseif shouldCalcify then
    intent = {
      type = "skill",
      skillType = "calcify",
      blockCount = 3,
    }
  elseif shouldCharge then
    intent = {
      type = "skill",
      skillType = "charge",
      armorBlockCount = 3,
    }
  elseif shouldShockwave then
    intent = {
      type = "skill",
      skillType = "shockwave",
      damage = 6,
    }
  elseif isBloodhound then
    local hpPercent = enemy.maxHP and enemy.maxHP > 0 and (enemy.hp / enemy.maxHP) or 1
    local hits = 1
    if hpPercent < 0.25 then
      hits = 3
    elseif hpPercent < 0.5 then
      hits = 2
    end
    local prevLevel = enemy.enrageLevel or 0
    local newLevel = 0
    if hits == 2 then
      newLevel = 1
    elseif hits == 3 then
      newLevel = 2
    end
    if newLevel > prevLevel then
      enemy.enrageLevel = newLevel
      enemy.enrageFxTime = 0
      enemy.enrageFxActive = true
    else
      enemy.enrageLevel = newLevel
    end
    intent = {
      type = "attack",
      attackType = "normal",
      damageMin = enemy.damageMin,
      damageMax = enemy.damageMax,
      hits = hits,
    }
  else
    intent = {
      type = "attack",
      attackType = "normal",
      damageMin = enemy.damageMin,
      damageMax = enemy.damageMax,
    }
  end

  if isEnemy2 and not shouldGainArmor then
    enemy.armorTurnCounter = (enemy.armorTurnCounter or 0) + 1
  end

  if isMender and not shouldHeal then
    enemy.healTurnCounter = (enemy.healTurnCounter or 0) + 1
  end

  if isSporeCaller and not shouldSpawnSpores then
    enemy.sporeTurnCounter = (enemy.sporeTurnCounter or 0) + 1
  end

  if intent then
    intent._hitCount = getHitCount(enemy, intent)
  end

  return intent
end

function EnemyIntents.calculate(scene)
  local intents = {}
  for i, enemy in ipairs(scene.enemies or {}) do
    intents[i] = evaluateIntent(scene, enemy, i)
  end
  return intents
end

function EnemyIntents.apply(scene, intents)
  local enemyCount = scene.enemies and #scene.enemies or 0
  for i = 1, enemyCount do
    local enemy = scene.enemies[i]
    local intent = intents and intents[i] or nil
    if enemy then
      if intent then
        enemy.intent = intent
        intent._hitCount = getHitCount(enemy, intent)
        enemy.intentFadeTime = 0
        scene:_registerEnemyIntent(i, intent)
      else
        enemy.intent = nil
        enemy.intentFadeTime = nil
        scene:_registerEnemyIntent(i, nil)
      end
    end
  end
end

return EnemyIntents

