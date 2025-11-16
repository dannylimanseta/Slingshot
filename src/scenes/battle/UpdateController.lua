local config = require("config")
local Visuals = require("scenes.battle.Visuals")
local EnemySkills = require("scenes.battle.EnemySkills")
local ImpactSystem = require("scenes.battle.ImpactSystem")
local PlayerState = require("core.PlayerState")
local RelicSystem = require("core.RelicSystem")
local BattleState = require("core.BattleState")
local TurnManager = require("core.TurnManager")
local EnemyController = require("scenes.battle.EnemyController")
local PopupController = require("scenes.battle.PopupController")

local UpdateController = {}

local function pushLog(scene, line)
  if scene and scene.pushLog then
    scene:pushLog(line)
  end
end

function UpdateController.update(scene, dt)
  scene:_syncStateFromBridge()

  UpdateController.updateEnemyFlashTimers(scene, dt)
  UpdateController.updatePlayerHitEffects(scene, dt)
  UpdateController.tweenHealthBars(scene, dt)

  PopupController.startDisintegrationIfReady(scene)

  UpdateController.updateIntentFadeAnimations(scene, dt)
  UpdateController.updateEnrageFx(scene, dt)
  UpdateController.advanceDisintegrationAnimations(scene, dt)

  UpdateController.updateVictoryState(scene)
  UpdateController.updateTurnIndicator(scene, dt)

  PopupController.update(scene, dt)
  PopupController.triggerPendingDisintegrations(scene)

  UpdateController.updateArmorEffects(scene, dt)
  UpdateController.updateEnemyTurnDelay(scene, dt)

  EnemySkills.update(scene, dt)

  UpdateController.updateHealGlowTimers(scene, dt)
  UpdateController.processChargedAttackDamage(scene, dt)

  UpdateController.updateMultiHitAttacks(scene, dt)
  UpdateController.updateEnemyDarkness(scene, dt)
  UpdateController.updateEnemyAttackDelays(scene, dt)

  UpdateController.updatePlayerAttackDelay(scene, dt)

  Visuals.update(scene, dt)
end

function UpdateController.updateEnemyFlashTimers(scene, dt)
  for _, enemy in ipairs(scene.enemies or {}) do
    if enemy.flash and enemy.flash > 0 then
      enemy.flash = math.max(0, enemy.flash - dt * 0.85)
    end
  end
end

function UpdateController.updatePlayerHitEffects(scene, dt)
  if scene.prevPlayerFlash == 0 and scene.playerFlash > 0 then
    ImpactSystem.createPlayerSplatter(scene, scene._lastBounds)
  end
  scene.prevPlayerFlash = scene.playerFlash

  if scene.playerFlash and scene.playerFlash > 0 then
    scene.playerFlash = math.max(0, scene.playerFlash - dt)
  end

  ImpactSystem.update(scene, dt)

  if scene.particles then
    scene.particles:update(dt)
  end

  local playerState = PlayerState.getInstance()
  playerState:setHealth(scene.playerHP)
end

function UpdateController.tweenHealthBars(scene, dt)
  local hpTweenSpeed = (config.battle and config.battle.hpBarTweenSpeed) or 8

  local playerDelta = scene.playerHP - (scene.displayPlayerHP or scene.playerHP)
  if math.abs(playerDelta) > 0.01 then
    local k = math.min(1, hpTweenSpeed * dt)
    scene.displayPlayerHP = (scene.displayPlayerHP or scene.playerHP) + playerDelta * k
  else
    scene.displayPlayerHP = scene.playerHP
  end

  for _, enemy in ipairs(scene.enemies or {}) do
    local enemyDelta = enemy.hp - (enemy.displayHP or enemy.hp)
    if math.abs(enemyDelta) > 0.01 then
      local k = math.min(1, hpTweenSpeed * dt)
      enemy.displayHP = (enemy.displayHP or enemy.hp) + enemyDelta * k
    else
      enemy.displayHP = enemy.hp
    end
  end
end

function UpdateController.updateIntentFadeAnimations(scene, dt)
  local turnManager = scene.turnManager
  local isPlayerTurn = turnManager and (
    turnManager:getState() == TurnManager.States.PLAYER_TURN_START or
    turnManager:getState() == TurnManager.States.PLAYER_TURN_ACTIVE
  )

  local fadeInDuration = 0.3
  local fadeOutDuration = 0.2
  local fadeOutRate = fadeOutDuration > 0 and (fadeInDuration / fadeOutDuration) or 0

  for _, enemy in ipairs(scene.enemies or {}) do
    if enemy.intentFadeTime ~= nil then
      if isPlayerTurn then
        if enemy.intentFadeTime < fadeInDuration then
          enemy.intentFadeTime = math.min(fadeInDuration, enemy.intentFadeTime + dt)
        else
          enemy.intentFadeTime = fadeInDuration
        end
      else
        if fadeOutRate > 0 then
          enemy.intentFadeTime = math.max(0, enemy.intentFadeTime - dt * fadeOutRate)
        else
          enemy.intentFadeTime = 0
        end
        if enemy.intentFadeTime <= 0 then
          enemy.intentFadeTime = nil
        end
      end
    end
  end
end

function UpdateController.updateEnrageFx(scene, dt)
  local fxDuration = 0.8
  for _, enemy in ipairs(scene.enemies or {}) do
    if enemy.enrageFxActive and enemy.enrageFxTime ~= nil then
      enemy.enrageFxTime = enemy.enrageFxTime + dt
      if enemy.enrageFxTime >= fxDuration or enemy.hp <= 0 then
        enemy.enrageFxActive = false
      end
    end
  end
end

function UpdateController.advanceDisintegrationAnimations(scene, dt)
  local cfg = config.battle.disintegration or {}
  local duration = cfg.duration or 1.5

  for index, enemy in ipairs(scene.enemies or {}) do
    if enemy.disintegrating then
      enemy.disintegrationTime = (enemy.disintegrationTime or 0) + dt * 0.5
      if enemy.disintegrationTime >= duration then
        enemy.disintegrating = false
        if scene.selectedEnemyIndex == index then
          EnemyController.selectNextEnemy(scene)
        end
      end
    end
  end
end

function UpdateController.updateVictoryState(scene)
  if scene.state == "win" then
    return
  end

  local allEnemiesDefeated = true
  local anyDisintegrating = false
  local anyPending = false

  for _, enemy in ipairs(scene.enemies or {}) do
    if enemy.hp > 0 and not enemy.disintegrating then
      allEnemiesDefeated = false
    end
    if enemy.disintegrating then
      anyDisintegrating = true
    end
    if enemy.pendingDisintegration then
      anyPending = true
    end
  end

  if allEnemiesDefeated and not anyDisintegrating and not anyPending then
    scene.state = "win"
  end
end

function UpdateController.updateTurnIndicator(scene, dt)
  if scene.turnIndicatorDelay and scene.turnIndicatorDelay > 0 then
    scene.turnIndicatorDelay = scene.turnIndicatorDelay - dt
    if scene.turnIndicatorDelay <= 0 then
      if scene._pendingTurnIndicator then
        scene.turnIndicator = scene._pendingTurnIndicator
        scene._pendingTurnIndicator = nil
        if scene.turnManager and scene.turnManager.emit then
          scene.turnManager:emit("turn_indicator_shown", { text = scene.turnIndicator.text })
        end
      end
      scene.turnIndicatorDelay = 0
    end
  end

  if scene.turnIndicator then
    scene.turnIndicator.t = scene.turnIndicator.t - dt
    if scene.turnIndicator.t <= 0 then
      scene.turnIndicator = nil
    end
  end
end

function UpdateController.updateArmorEffects(scene, dt)
  if scene.armorIconFlashTimer and scene.armorIconFlashTimer > 0 then
    scene.armorIconFlashTimer = math.max(0, scene.armorIconFlashTimer - dt)
  end

  local prevPlayerArmor = scene.prevPlayerArmor or 0
  local playerArmor = scene.playerArmor or 0
  local armorBroken = prevPlayerArmor > 0 and playerArmor == 0
  local armorGained = prevPlayerArmor == 0 and playerArmor > 0

  if armorBroken and scene.playerBarX and scene.playerBarY and scene.playerBarW and scene.playerBarH then
    local gap = 3
    scene.borderFragments = EnemySkills.createBorderFragments(scene.playerBarX, scene.playerBarY, scene.playerBarW, scene.playerBarH, gap, 6)
  end

  if armorGained then
    scene.borderFadeInTime = scene.borderFadeInDuration
  end

  if scene.borderFadeInTime and scene.borderFadeInTime > 0 then
    scene.borderFadeInTime = math.max(0, scene.borderFadeInTime - dt)
  end

  scene.prevPlayerArmor = playerArmor

  local aliveFragments = {}
  for _, frag in ipairs(scene.borderFragments or {}) do
    frag.lifetime = (frag.lifetime or 0) - dt
    if frag.lifetime > 0 then
      local progress = frag.maxLifetime and (frag.lifetime / frag.maxLifetime) or 0
      local easeOut = progress * progress
      local velScale = 0.3 + easeOut * 0.7
      frag.x = frag.x + frag.vx * dt * velScale
      frag.y = frag.y + frag.vy * dt * velScale
      frag.rotation = frag.rotation + frag.rotationSpeed * dt * (0.5 + progress * 0.5)
      frag.progress = progress
      table.insert(aliveFragments, frag)
    end
  end
  scene.borderFragments = aliveFragments

  for i, enemy in ipairs(scene.enemies or {}) do
    local prevArmor = scene.prevEnemyArmor[i] or 0
    local currentArmor = enemy.armor or 0
    local enemyArmorBroken = prevArmor > 0 and currentArmor == 0
    local enemyArmorGained = prevArmor == 0 and currentArmor > 0

    if enemyArmorBroken and scene.enemyBarX[i] and scene.enemyBarY[i] and scene.enemyBarW[i] and scene.enemyBarH[i] then
      local gap = 3
      scene.enemyBorderFragments[i] = EnemySkills.createBorderFragments(scene.enemyBarX[i], scene.enemyBarY[i], scene.enemyBarW[i], scene.enemyBarH[i], gap, 6)
    end

    if enemyArmorGained then
      scene.enemyBorderFadeInTime[i] = scene.borderFadeInDuration
    end

    if scene.enemyBorderFadeInTime[i] and scene.enemyBorderFadeInTime[i] > 0 then
      scene.enemyBorderFadeInTime[i] = math.max(0, scene.enemyBorderFadeInTime[i] - dt)
    end

    scene.prevEnemyArmor[i] = currentArmor

    if scene.enemyBorderFragments[i] then
      local aliveEnemyFragments = {}
      for _, frag in ipairs(scene.enemyBorderFragments[i]) do
        frag.lifetime = (frag.lifetime or 0) - dt
        if frag.lifetime > 0 then
          local progress = frag.maxLifetime and (frag.lifetime / frag.maxLifetime) or 0
          local easeOut = progress * progress
          local velScale = 0.3 + easeOut * 0.7
          frag.x = frag.x + frag.vx * dt * velScale
          frag.y = frag.y + frag.vy * dt * velScale
          frag.rotation = frag.rotation + frag.rotationSpeed * dt * (0.5 + progress * 0.5)
          frag.progress = progress
          table.insert(aliveEnemyFragments, frag)
        end
      end
      scene.enemyBorderFragments[i] = aliveEnemyFragments
    end
  end
end

function UpdateController.updateEnemyTurnDelay(scene, dt)
  if not (scene._enemyTurnDelay and scene._enemyTurnDelay > 0) then
    return
  end

  scene._enemyTurnDelay = scene._enemyTurnDelay - dt

  local playerAttackActive = (scene.playerLungeTime and scene.playerLungeTime > 0) or false
  local blackHoleActive = (scene.blackHoleAttacks and #scene.blackHoleAttacks > 0) or false

  if (playerAttackActive or blackHoleActive) and scene._pendingEnemyTurnStart then
    local remainingTime = 0

    if playerAttackActive then
      local lungeD = (config.battle and config.battle.lungeDuration) or 0
      local lungeRD = (config.battle and config.battle.lungeReturnDuration) or 0
      local lungePause = (config.battle and config.battle.lungePauseDuration) or 0
      local totalLungeDuration = lungeD + lungePause + lungeRD
      remainingTime = math.max(remainingTime, totalLungeDuration - (scene.playerLungeTime or 0))
    end

    if blackHoleActive then
      for _, attack in ipairs(scene.blackHoleAttacks or {}) do
        local attackRemaining = (attack.duration or 0) - (attack.t or 0)
        remainingTime = math.max(remainingTime, attackRemaining)
      end
    end

    if remainingTime > 0 then
      scene._enemyTurnDelay = remainingTime + 0.1
    end
  end

  if scene._enemyTurnDelay <= 0 then
    scene._enemyTurnDelay = nil
    scene._pendingEnemyTurnStart = false
    if scene.turnManager then
      scene.turnManager:startEnemyTurn()
    end
  end
end

function UpdateController.updateHealGlowTimers(scene, dt)
  if scene.playerHealGlowTimer and scene.playerHealGlowTimer > 0 then
    scene.playerHealGlowTimer = math.max(0, scene.playerHealGlowTimer - dt)
  end

  for i in ipairs(scene.enemies or {}) do
    if scene.enemyHealGlowTimer[i] and scene.enemyHealGlowTimer[i] > 0 then
      scene.enemyHealGlowTimer[i] = math.max(0, scene.enemyHealGlowTimer[i] - dt)
    end
  end
end

function UpdateController.processChargedAttackDamage(scene, dt)
  for _, enemy in ipairs(scene.enemies or {}) do
    if enemy.pendingChargedDamage and enemy.chargeLungeTime and enemy.chargeLungeTime > 0 and enemy.chargeLunge then
      local t = enemy.chargeLungeTime
      local windup = enemy.chargeLunge.windupDuration or 0.55
      local forward = enemy.chargeLunge.forwardDuration or 0.2
      local returnDuration = enemy.chargeLunge.returnDuration or 0.2

      if t >= windup and not enemy.chargedDamageApplied then
        enemy.chargedDamageApplied = true

        local dmg = enemy.pendingChargedDamage
        local blocked, net = scene:_applyPlayerDamage(dmg)

        if net <= 0 then
          scene.armorIconFlashTimer = 0.5
          table.insert(scene.popups, { x = 0, y = 0, kind = "armor_blocked", t = config.battle.popupLifetime, who = "player" })
        else
          scene.playerFlash = config.battle.hitFlashDuration
          scene.playerKnockbackTime = 1e-6
          table.insert(scene.popups, { x = 0, y = 0, text = tostring(net), t = config.battle.popupLifetime, who = "player" })
          if scene.particles then
            local px, py = scene:getPlayerCenterPivot(scene._lastBounds)
            if px and py then
              scene.particles:emitHitBurst(px, py)
            end
          end
          pushLog(scene, (enemy.name or "Enemy") .. " dealt " .. net)
          if scene.onPlayerDamage then
            scene.onPlayerDamage()
          end
        end

        scene:triggerShake((config.battle and config.battle.shakeMagnitude) or 10, (config.battle and config.battle.shakeDuration) or 0.25)
        enemy.pendingChargedDamage = nil
      end

      if t >= windup + forward + returnDuration then
        enemy.chargedDamageApplied = nil
      end
    end
  end
end

function UpdateController.updateMultiHitAttacks(scene, dt)
  for _, enemy in ipairs(scene.enemies or {}) do
    local state = enemy.multiHitState
    if state then
      state.timer = state.timer + dt

      if state.timer >= state.delay then
        state.timer = 0
        state.currentHit = state.currentHit + 1

        if state.currentHit <= state.remainingHits then
          local blocked, net = scene:_applyPlayerDamage(state.damage)

          if net <= 0 then
            scene.armorIconFlashTimer = 0.5
            table.insert(scene.popups, { x = 0, y = 0, kind = "armor_blocked", t = config.battle.popupLifetime, who = "player" })
          else
            scene.playerFlash = config.battle.hitFlashDuration
            scene.playerKnockbackTime = 1e-6
            table.insert(scene.popups, { x = 0, y = 0, text = tostring(net), t = config.battle.popupLifetime, who = "player" })
            if scene.particles then
              local px, py = scene:getPlayerCenterPivot(scene._lastBounds)
              if px and py then
                scene.particles:emitHitBurst(px, py)
              end
            end
            if scene.onPlayerDamage then
              scene.onPlayerDamage()
            end
          end

          enemy.lungeTime = 1e-6
          scene:triggerShake((config.battle and config.battle.shakeMagnitude) or 8, (config.battle and config.battle.shakeDuration) or 0.2)

          if state.currentHit >= state.remainingHits then
            enemy.multiHitState = nil
            if scene.playerHP <= 0 then
              scene.state = "lose"
              if scene.turnManager then
                scene.turnManager:transitionTo(TurnManager.States.DEFEAT)
              end
            end
          end
        end
      end
    end
  end
end

function UpdateController.updateEnemyDarkness(scene, dt)
  local targetDarkness = (scene._attackingEnemyIndex ~= nil) and 1.0 or 0.0
  local darknessSpeed = 4.0
  local darknessDelta = targetDarkness - (scene._nonAttackingEnemyDarkness or 0)
  scene._nonAttackingEnemyDarkness = (scene._nonAttackingEnemyDarkness or 0) + darknessDelta * math.min(1, darknessSpeed * dt)
end

function UpdateController.updateEnemyAttackDelays(scene, dt)
  local shockwaveActive = scene._shockwaveSequence ~= nil
  local calcifyActive = scene._calcifySequence ~= nil
  local chargedAttackActive = false

  for _, enemy in ipairs(scene.enemies or {}) do
    if enemy.chargeLungeTime and enemy.chargeLungeTime > 0 then
      chargedAttackActive = true
      break
    end
  end

  local aliveAttackDelays = {}
  for _, delayData in ipairs(scene._enemyAttackDelays or {}) do
    if shockwaveActive or calcifyActive or chargedAttackActive then
      table.insert(aliveAttackDelays, delayData)
    else
      delayData.delay = delayData.delay - dt
      if delayData.delay <= 0 then
        scene._attackingEnemyIndex = delayData.index

        local enemy = scene.enemies[delayData.index]
        if enemy and enemy.hp > 0 then
          local intent = enemy.intent
          if intent and intent.type == "armor" then
            EnemySkills.performArmorGain(scene, enemy, delayData.index, intent.amount or 5)
          elseif intent and intent.type == "skill" and intent.skillType == "heal" then
            EnemySkills.performHeal(scene, enemy, intent.targetIndex, intent.amount or 18)
          elseif intent and intent.type == "skill" and intent.skillType == "calcify" then
            EnemySkills.performCalcify(scene, enemy, intent.blockCount or 3)
          elseif intent and intent.type == "skill" and intent.skillType == "charge" then
            EnemySkills.performCharge(scene, enemy, (intent and intent.armorBlockCount) or 3)
          elseif intent and intent.type == "skill" and intent.skillType == "spore" then
            EnemySkills.performSpore(scene, enemy, (intent and intent.sporeCount) or 2)
          elseif (intent and intent.type == "skill" and intent.skillType == "shockwave") or
                 (intent and intent.type == "attack" and intent.attackType == "shockwave") then
            EnemySkills.performShockwave(scene, enemy)
          else
            local isChargedAttack = intent and intent.type == "attack" and intent.attackType == "charged"
            local hitCount = scene:_getEnemyHitCount(enemy, intent)

            local dmg
            if intent and intent.type == "attack" and intent.damageMin and intent.damageMax then
              dmg = love.math.random(intent.damageMin, intent.damageMax)
            else
              dmg = love.math.random(enemy.damageMin, enemy.damageMax)
            end

            if isChargedAttack then
              enemy.pendingChargedDamage = dmg * hitCount
              enemy.chargedDamageApplied = nil
              enemy.chargeLungeTime = 1e-6
              enemy.chargeLunge = {
                windupDuration = 0.55,
                forwardDuration = 0.22,
                returnDuration = 0.24,
                backDistance = ((config.battle and config.battle.lungeDistance) or 80) * 0.6,
                forwardDistance = ((config.battle and config.battle.lungeDistance) or 80) * 2.8,
              }
            else
              scene:_applyMultiHitDamage(enemy, dmg, hitCount, delayData.index)
            end

            if scene.playerHP <= 0 then
              scene.state = "lose"
              pushLog(scene, "You were defeated!")
              if scene.turnManager then
                scene.turnManager:transitionTo(TurnManager.States.DEFEAT)
              end
            end
          end
        end
      else
        table.insert(aliveAttackDelays, delayData)
      end
    end
  end
  scene._enemyAttackDelays = aliveAttackDelays

  if (#scene._enemyAttackDelays == 0) and not shockwaveActive and not calcifyActive then
    if not scene._attackingEnemyClearDelay then
      scene._attackingEnemyClearDelay = 0.3
    else
      scene._attackingEnemyClearDelay = scene._attackingEnemyClearDelay - dt
      if scene._attackingEnemyClearDelay <= 0 then
        scene._attackingEnemyIndex = nil
        scene._attackingEnemyClearDelay = nil
      end
    end
  else
    scene._attackingEnemyClearDelay = nil
  end
end

function UpdateController.updatePlayerAttackDelay(scene, dt)
  if not (scene._playerAttackDelayTimer and scene._playerAttackDelayTimer > 0) then
    return
  end

  scene._playerAttackDelayTimer = scene._playerAttackDelayTimer - dt
  if scene._playerAttackDelayTimer > 0 then
    return
  end

  scene._playerAttackDelayTimer = nil

  if scene._pendingPlayerAttackDamage then
    local pending = scene._pendingPlayerAttackDamage
    local dmg = pending.damage
    local isAOE = pending.isAOE or false
    local projectileId = pending.projectileId or "strike"
    local behavior = pending.behavior
    local impactBlockCount = pending.impactBlockCount or 1
    local impactIsCrit = pending.impactIsCrit or false

    if impactBlockCount and impactBlockCount > 0 then
      scene:_createImpactInstances({
        blockCount = impactBlockCount,
        isCrit = impactIsCrit,
        isAOE = isAOE,
        projectileId = projectileId,
        behavior = behavior,
      })
    end

    local blockHitSequence = pending.blockHitSequence or {}
    local orbBaseDamage = pending.orbBaseDamage or 0
    local baseDamage = pending.baseDamage

    if not baseDamage or baseDamage == 0 then
      baseDamage = orbBaseDamage
      for _, hit in ipairs(blockHitSequence) do
        local kind = (type(hit) == "table" and hit.kind) or "damage"
        local amount = (type(hit) == "table" and (hit.damage or hit.amount)) or 0
        if kind ~= "crit" and kind ~= "multiplier" and kind ~= "armor" and kind ~= "heal" and kind ~= "potion" then
          baseDamage = baseDamage + amount
        end
      end
    end

    local damageSequence = PopupController.buildDamageAnimationSequence(
      blockHitSequence,
      baseDamage,
      orbBaseDamage,
      pending.critCount or 0,
      pending.multiplierCount or 0,
      dmg
    )

    if isAOE then
      for i, enemy in ipairs(scene.enemies or {}) do
        if enemy and enemy.hp > 0 then
          if behavior.delayHPReduction then
            enemy.pendingDamage = (enemy.pendingDamage or 0) + dmg
          else
            scene:_applyEnemyDamage(i, dmg)
          end

          PopupController.enqueueDamagePopup(scene, i, damageSequence, behavior, impactIsCrit, {
            linger = { default = 0.05, exclamation = 0.2 },
            disintegrationTime = 0,
            disintegrationDisplayTime = 0.2,
          })
          PopupController.handleEnemyDefeatPostHit(scene, i)
        end
      end
      pushLog(scene, "You dealt " .. dmg .. " to all enemies!")
    else
      local selectedEnemy = scene:getSelectedEnemy()
      if selectedEnemy then
        local index = scene.selectedEnemyIndex
        if selectedEnemy.hp > 0 then
          if behavior.delayHPReduction then
            selectedEnemy.pendingDamage = (selectedEnemy.pendingDamage or 0) + dmg
          else
            scene:_applyEnemyDamage(index, dmg)
          end

          PopupController.enqueueDamagePopup(scene, index, damageSequence, behavior, impactIsCrit, {
            linger = { default = 0.3 },
            finalStepDisplayTimeMultiplier = 0.5,
          })
          PopupController.handleEnemyDefeatPostHit(scene, index)

          if selectedEnemy.hp <= 0 then
            EnemyController.selectNextEnemy(scene)
          end
        end
      end
      pushLog(scene, "You dealt " .. dmg)
    end

    local healAmount = RelicSystem.getPlayerAttackHeal({
      damage = dmg,
      isAOE = isAOE,
      projectileId = projectileId,
      blockHitSequence = blockHitSequence,
      critCount = pending.critCount or 0,
      multiplierCount = pending.multiplierCount or 0,
      source = "player_attack_resolved",
    })
    if healAmount and healAmount > 0 then
      BattleState.trackDamage("heal", healAmount)
      if scene.applyHealing then
        scene:applyHealing(healAmount)
      end
    end

    scene._pendingPlayerAttackDamage = nil
  end

  if scene._pendingImpactParams then
    scene:_createImpactInstances(scene._pendingImpactParams.blockCount, scene._pendingImpactParams.isCrit)
    scene._pendingImpactParams = nil
  end

  scene.playerLungeTime = 1e-6
  scene:triggerShake((config.battle and config.battle.shakeMagnitude) or 10, (config.battle and config.battle.shakeDuration) or 0.25)
end

return UpdateController


