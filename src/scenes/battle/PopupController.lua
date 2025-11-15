local config = require("config")

local PopupController = {}

function PopupController.buildDamageAnimationSequence(blockHitSequence, baseDamage, orbBaseDamage, critCount, multiplierCount, finalDamage)
  local sequence = {}

  local hasMultiplier = (critCount > 0) or (multiplierCount > 0)
  local finalText = tostring(finalDamage)
  if hasMultiplier then
    finalText = finalText .. "!"
  end

  table.insert(sequence, { text = finalText, duration = 0.3, isMultiplier = hasMultiplier })
  return sequence
end

local function calculateDamageSequenceDuration(sequence)
  local total = 0
  if not sequence then return total end
  for _, step in ipairs(sequence) do
    total = total + (step.duration or 0.1)
  end
  return total
end

local function resolvePopupLingerTime(sequence, options)
  options = options or {}
  local defaultLinger = options.default or 0.3
  local exclamationLinger = options.exclamation or defaultLinger

  local lastStep = sequence and sequence[#sequence]
  local hasExclamation = lastStep and lastStep.text and string.find(lastStep.text, "!", 1, true)

  if hasExclamation then
    return exclamationLinger, true
  end
  return defaultLinger, false
end

function PopupController.enemyHasActiveDamagePopup(scene, enemyIndex)
  if not enemyIndex then return false end
  for _, popup in ipairs(scene.popups or {}) do
    if popup.who == "enemy" and popup.enemyIndex == enemyIndex and popup.t and popup.t > 0 then
      if popup.kind == "animated_damage" and popup.sequence then
        local sequenceIndex = popup.sequenceIndex or 1
        local lastIndex = #popup.sequence
        if sequenceIndex < lastIndex then
          return true
        elseif sequenceIndex == lastIndex then
          local requiredTime = popup.finalStepDisplayTime
          if not requiredTime then
            local lastStep = popup.sequence[sequenceIndex]
            local lastDuration = (lastStep and lastStep.duration) or 0.15
            local linger = popup.lingerTime or 0
            requiredTime = lastDuration + linger
          end
          local sequenceTimer = popup.sequenceTimer or 0
          if sequenceTimer < requiredTime then
            return true
          end
        end
      else
        return true
      end
    end
  end
  return false
end

function PopupController.enqueueDamagePopup(scene, enemyIndex, damageSequence, behavior, impactIsCrit, opts)
  local enemy = scene.enemies and scene.enemies[enemyIndex]
  if not enemy or not damageSequence or #damageSequence == 0 then
    return
  end

  opts = opts or {}
  behavior = behavior or {}

  if not behavior.suppressInitialFlash then
    enemy.flash = config.battle.hitFlashDuration
  end

  if not behavior.suppressInitialKnockback then
    enemy.knockbackTime = 1e-6
  end

  local sequenceDuration = calculateDamageSequenceDuration(damageSequence)
  local lingerOptions = opts.linger or {}
  local lingerTime, hasExclamation = resolvePopupLingerTime(damageSequence, lingerOptions)

  local lastStep = damageSequence[#damageSequence]
  local lastStepDuration = (lastStep and lastStep.duration) or 0.15

  local disintegrationDisplayTime = opts.disintegrationDisplayTime or 0
  local safetyBuffer = opts.safetyBuffer or 0.5
  local disintegrationTime = opts.disintegrationTime
  if disintegrationTime == nil then
    local disintegrationCfg = config.battle.disintegration or {}
    disintegrationTime = disintegrationCfg.duration or 1.5
  end

  local finalStepDisplayTime
  if opts.finalStepDisplayTimeMultiplier then
    finalStepDisplayTime = lastStepDuration * opts.finalStepDisplayTimeMultiplier
  else
    local extra = opts.finalStepDisplayTimeExtra or 0
    finalStepDisplayTime = lastStepDuration + lingerTime + extra
  end

  local totalPopupLifetime = sequenceDuration + lingerTime + disintegrationDisplayTime + disintegrationTime + safetyBuffer
  local popupStartDelay = opts.popupStartDelay
  if popupStartDelay == nil then
    popupStartDelay = behavior.popupDelay or 0
  end

  table.insert(scene.popups, {
    x = 0,
    y = 0,
    kind = "animated_damage",
    sequence = damageSequence,
    sequenceIndex = 1,
    sequenceTimer = 0,
    bounceTimer = 0,
    t = totalPopupLifetime,
    originalLifetime = totalPopupLifetime,
    who = "enemy",
    enemyIndex = enemyIndex,
    startDelay = popupStartDelay,
    lingerTime = lingerTime,
    disintegrationDisplayTime = disintegrationDisplayTime,
    safetyBuffer = safetyBuffer,
    sequenceDuration = sequenceDuration,
    hasExclamation = hasExclamation,
    finalStepDisplayTime = finalStepDisplayTime,
  })

  if scene.particles and not behavior.suppressInitialParticles then
    local ex, ey = scene:getEnemyCenterPivot(enemyIndex, scene._lastBounds)
    if ex and ey then
      scene.particles:emitHitBurst(ex, ey, nil, impactIsCrit)
    end
  end
end

function PopupController.handleEnemyDefeatPostHit(scene, enemyIndex)
  local enemy = scene.enemies and scene.enemies[enemyIndex]
  if not enemy or enemy.hp > 0 then
    return
  end

  local disintegrationCfg = config.battle.disintegration or {}
  local duration = disintegrationCfg.duration or 1.5
  local hasCompleted = (enemy.disintegrationTime or 0) >= duration
  if hasCompleted then
    return
  end

  local impactsActive = (scene.impactInstances and #scene.impactInstances > 0) or (scene.blackHoleAttacks and #scene.blackHoleAttacks > 0)
  local damagePopupActive = PopupController.enemyHasActiveDamagePopup(scene, enemyIndex)

  if impactsActive or damagePopupActive then
    if not enemy.pendingDisintegration then
      enemy.pendingDisintegration = true
    end
    return
  end

  if not enemy.disintegrating then
    enemy.disintegrating = true
    enemy.disintegrationTime = 0
  end
end

function PopupController.startDisintegrationIfReady(scene)
  if scene.state == "win" then
    return
  end

  local disintegrationCfg = config.battle.disintegration or {}
  local duration = disintegrationCfg.duration or 1.5
  local impactsActive = (scene.impactInstances and #scene.impactInstances > 0) or (scene.blackHoleAttacks and #scene.blackHoleAttacks > 0)

  for index, enemy in ipairs(scene.enemies or {}) do
    if enemy.hp <= 0 and not enemy.disintegrating and not enemy.pendingDisintegration then
      local hasCompleted = (enemy.disintegrationTime or 0) >= duration
      if not hasCompleted then
        local damagePopupActive = PopupController.enemyHasActiveDamagePopup(scene, index)
        if impactsActive or damagePopupActive then
          enemy.pendingDisintegration = true
        else
          enemy.disintegrating = true
          enemy.disintegrationTime = 0
        end
      end
    end
  end
end

function PopupController.triggerPendingDisintegrations(scene)
  local impactsActive = (scene.impactInstances and #scene.impactInstances > 0) or (scene.blackHoleAttacks and #scene.blackHoleAttacks > 0)

  for index, enemy in ipairs(scene.enemies or {}) do
    if enemy.pendingDisintegration and enemy.hp <= 0 then
      local damagePopupActive = PopupController.enemyHasActiveDamagePopup(scene, index)
      if not impactsActive and not damagePopupActive then
        enemy.pendingDisintegration = false
        if not enemy.disintegrating then
          enemy.disintegrating = true
          enemy.disintegrationTime = 0
        end
      end
    end
  end
end

function PopupController.update(scene, dt)
  local alive = {}

  for _, p in ipairs(scene.popups or {}) do
    if p.startDelay and p.startDelay > 0 then
      p.startDelay = p.startDelay - dt
      if p.startDelay > 0 then
        table.insert(alive, p)
        goto continue
      else
        p.startDelay = nil
      end
    end

    local sequenceCompleted = false
    if p.kind == "animated_damage" and p.sequence and #p.sequence > 0 then
      if not p.sequenceIndex then
        p.sequenceIndex = 1
        p.sequenceTimer = 0
      end

      p.sequenceTimer = (p.sequenceTimer or 0) + dt
      local currentStep = p.sequence[p.sequenceIndex]

      if currentStep and p.sequenceTimer >= currentStep.duration then
        if p.sequenceIndex < #p.sequence then
          p.sequenceTimer = 0
          p.sequenceIndex = p.sequenceIndex + 1
          p.bounceTimer = 0
        end
      end

      if p.sequenceIndex == #p.sequence then
        local finalStep = p.sequence[p.sequenceIndex]
        if finalStep and p.sequenceTimer >= finalStep.duration then
          sequenceCompleted = true
          if not p.sequenceFinished then
            p.sequenceFinished = true

            if p.who == "enemy" and p.enemyIndex then
              local enemy = scene.enemies and scene.enemies[p.enemyIndex]
              if enemy and enemy.pendingDamage and enemy.pendingDamage > 0 then
                scene:_applyEnemyDamage(p.enemyIndex, enemy.pendingDamage)
                enemy.pendingDamage = 0
              end
            end

            local lastStep = p.sequence[#p.sequence]
            local hasExclamation = lastStep and lastStep.text and string.find(lastStep.text, "!") ~= nil
            local lingerTime = hasExclamation and 0.9 or 0.45
            local disintegrationDisplayTime = 0.25
            p.t = lingerTime + disintegrationDisplayTime
            p.originalLifetime = p.t
          end
        end
      else
        sequenceCompleted = false
      end

      if p.bounceTimer == nil then
        p.bounceTimer = 0
      end
      p.bounceTimer = p.bounceTimer + dt

      local currentStepInner = p.sequence[p.sequenceIndex]
      if currentStepInner and currentStepInner.isMultiplier then
        if not p.charBounceTimers then
          p.charBounceTimers = { 0, 0, 0 }
          p.multiplierTarget = nil
        end

        local charBounceDelay = 0.08
        if not p.multiplierStartTime then
          p.multiplierStartTime = p.sequenceTimer or 0
        end
        local multiplierElapsed = (p.sequenceTimer or 0) - p.multiplierStartTime

        for i = 1, #p.charBounceTimers do
          if multiplierElapsed >= (i - 1) * charBounceDelay then
            p.charBounceTimers[i] = (p.charBounceTimers[i] or 0) + dt
          end
        end
      end

      local isFinalStep = (p.sequenceIndex == #p.sequence)
      local finalStep = p.sequence[#p.sequence]
      local hasExclamation = finalStep and finalStep.text and string.find(finalStep.text, "!") ~= nil

      if isFinalStep and hasExclamation then
        if not p.shakeTime then
          local finalStepDuration = finalStep.duration or 0.1
          p.shakeTime = finalStepDuration * 2.5
          p.shakeRotation = 0
          p.shakeUpdateTimer = 0
        end

        if p.shakeTime > 0 then
          p.shakeTime = p.shakeTime - dt
          p.shakeUpdateTimer = (p.shakeUpdateTimer or 0) + dt

          local shakeDuration = (finalStep.duration or 0.1) * 2.5
          local progress = shakeDuration > 0 and (p.shakeTime / shakeDuration) or 0
          local shakeMagnitude = 4 * progress

          local shakeUpdateInterval = 0.05
          if p.shakeUpdateTimer >= shakeUpdateInterval then
            p.shakeUpdateTimer = 0
            p.shakeOffsetX = (love.math.random() * 2 - 1) * shakeMagnitude
            p.shakeOffsetY = (love.math.random() * 2 - 1) * shakeMagnitude
          end

          local rotationSpeed = 15
          local elapsedTime = shakeDuration - p.shakeTime
          p.shakeRotation = math.sin(elapsedTime * rotationSpeed * 2 * math.pi) * 0.15 * progress
        else
          p.shakeOffsetX = 0
          p.shakeOffsetY = 0
          p.shakeRotation = 0
          p.shakeUpdateTimer = nil
        end
      else
        p.shakeOffsetX = 0
        p.shakeOffsetY = 0
        p.shakeRotation = 0
        p.shakeTime = nil
      end
    end

    local isAnimatedDamage = (p.kind == "animated_damage" and p.sequence)
    if not isAnimatedDamage then
      p.t = (p.t or 0) - dt
    elseif sequenceCompleted or (p.sequenceFinished == true) then
      p.t = (p.t or 0) - dt
    end

    if p.t and p.t > 0 then
      table.insert(alive, p)
    end

    ::continue::
  end

  scene.popups = alive
end

return PopupController


