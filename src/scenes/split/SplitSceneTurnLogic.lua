-- SplitSceneTurnLogic.lua
-- Handles turn end detection, victory/defeat logic, and damage calculation

local config = require("config")
local TurnManager = require("core.TurnManager")
local BattleState = require("core.BattleState")

local SplitSceneTurnLogic = {}

--- Calculate turn score from BattleState rewards
---@param scene table SplitScene instance
---@return table turnData Data for ending the turn
function SplitSceneTurnLogic.calculateTurnData(scene)
  local battleState = BattleState.get()
  local rewards = battleState and battleState.rewards or {}
  
  -- Collect turn data - BattleState is now the single source of truth
  local blockHitSequence = rewards.blockHitSequence or {}
  local orbBaseDamage = rewards.baseDamage or 0
  
  -- Calculate base damage by summing only non-crit, non-multiplier blocks
  local baseDamage = orbBaseDamage
  for _, hit in ipairs(blockHitSequence) do
    local kind = (type(hit) == "table" and hit.kind) or "damage"
    local amount = (type(hit) == "table" and (hit.damage or hit.amount)) or 0
    if kind ~= "crit" and kind ~= "multiplier" and kind ~= "armor" and kind ~= "heal" and kind ~= "potion" then
      baseDamage = baseDamage + amount
    end
  end
  
  local mult = (config.score and config.score.critMultiplier) or 2
  local critCount = rewards.critCount or 0
  local multiplierCount = rewards.multiplierCount or 0
  
  -- Apply crit multiplier
  local turnScore = baseDamage
  if critCount > 0 then
    turnScore = turnScore * (mult ^ critCount)
  end
  
  -- Apply simple damage multiplier
  if multiplierCount > 0 then
    local dmgMult = (config.score and config.score.powerCritMultiplier) or 4
    turnScore = turnScore * dmgMult
  end
  
  local armor = rewards.armorThisTurn or 0
  local heal = rewards.healThisTurn or 0
  local blocksDestroyed = (battleState and battleState.blocks and battleState.blocks.destroyedThisTurn) or 0
  local isAOE = rewards.aoeFlag or false
  local projectileId = rewards.projectileId or "strike"
  
  return {
    score = turnScore,
    armor = armor,
    heal = heal,
    crits = critCount,
    blocksDestroyed = blocksDestroyed,
    isAOE = isAOE,
    projectileId = projectileId,
    blockHitSequence = blockHitSequence,
    baseDamage = baseDamage,
    orbBaseDamage = orbBaseDamage,
    critCount = critCount,
    multiplierCount = multiplierCount,
  }
end

--- End player turn using TurnManager
---@param scene table SplitScene instance
---@return boolean success Whether the turn was ended
function SplitSceneTurnLogic.endPlayerTurn(scene)
  local state = scene.turnManager:getState()
  if state ~= TurnManager.States.PLAYER_TURN_ACTIVE then return false end
  
  local turnData = SplitSceneTurnLogic.calculateTurnData(scene)
  scene.turnManager:endPlayerTurn(turnData)
  
  return true
end

--- Check if there are active black holes delaying turn end
---@param scene table SplitScene instance
---@return boolean hasActive
function SplitSceneTurnLogic.hasActiveBlackHoles(scene)
  if not scene.left or not scene.left.blackHoles or #scene.left.blackHoles == 0 then
    return false
  end
  
  local cfg = (config.gameplay and config.gameplay.blackHole) or {}
  local duration = cfg.duration or 1.8
  for _, hole in ipairs(scene.left.blackHoles) do
    if (hole.t or 0) < duration then
      return true
    end
  end
  return false
end

--- Check if there are pending lightning hits delaying turn end
---@param scene table SplitScene instance
---@return boolean hasPending
function SplitSceneTurnLogic.hasPendingLightningHits(scene)
  if not scene.left or not scene.left.blocks or not scene.left.blocks.blocks then
    return false
  end
  
  for _, b in ipairs(scene.left.blocks.blocks) do
    if b and b.alive and b._lightningHitPending then
      return true
    end
  end
  return false
end

--- Check if current projectile is lightning
---@param scene table SplitScene instance
---@return boolean isLightning
function SplitSceneTurnLogic.isLightningAttack(scene)
  local projectileId = "strike"
  if scene.left and scene.left.shooter and scene.left.shooter.getCurrentProjectileId then
    projectileId = scene.left.shooter:getCurrentProjectileId()
  elseif scene.currentProjectileId then
    projectileId = scene.currentProjectileId
  end
  return projectileId == "lightning"
end

--- Check if balls are still in flight
---@param scene table SplitScene instance
---@return boolean hasBall
function SplitSceneTurnLogic.hasBallInFlight(scene)
  local hasSingleBall = (scene.left and scene.left.ball and scene.left.ball.alive) and true or false
  local hasMultipleBalls = false
  if scene.left and scene.left.balls then
    for _, ball in ipairs(scene.left.balls) do
      if ball and ball.alive then
        hasMultipleBalls = true
        break
      end
    end
  end
  return hasSingleBall or hasMultipleBalls
end

--- Check if all actions are complete for victory transition
---@param scene table SplitScene instance
---@return boolean allComplete
function SplitSceneTurnLogic.areAllActionsComplete(scene)
  if not scene.right then return false end
  
  -- Check if any enemies are still disintegrating
  if scene.right.enemies then
    local cfg = config.battle and config.battle.disintegration or {}
    local duration = cfg.duration or 0.8
    
    for _, enemy in ipairs(scene.right.enemies) do
      -- Check if disintegrating and not yet complete
      if enemy.disintegrating then
        local disintegrationTime = enemy.disintegrationTime or 0
        if disintegrationTime < duration then
          return false -- Still disintegrating
        end
      end
      -- Check if pending disintegration
      if enemy.pendingDisintegration then
        return false
      end
    end
  end
  
  -- Check if impact animations are still active
  if scene.right.impactInstances and #scene.right.impactInstances > 0 then
    return false
  end
  if scene.right.blackHoleAttacks and #scene.right.blackHoleAttacks > 0 then
    return false
  end
  
  -- Check if any popups are still active
  if scene.right.popups and #scene.right.popups > 0 then
    for _, popup in ipairs(scene.right.popups) do
      if popup.t and popup.t > 0 then
        -- Check animated damage popups
        if popup.kind == "animated_damage" and popup.sequence then
          local sequenceIndex = popup.sequenceIndex or 1
          if sequenceIndex < #popup.sequence then
            return false
          end
          if popup.sequenceTimer and popup.sequenceTimer > 0 then
            local lastStep = popup.sequence[#popup.sequence]
            if lastStep then
              local hasExclamation = lastStep.text and string.find(lastStep.text, "!") ~= nil
              local lingerTime = hasExclamation and 0.2 or 0.05
              local totalDisplayTime = (lastStep.duration or 0.15) + lingerTime
              if popup.sequenceTimer < totalDisplayTime then
                return false
              end
            end
          end
        elseif popup.t > 0 then
          return false
        end
      end
    end
  end
  
  return true
end

--- Check victory condition
---@param scene table SplitScene instance
---@return boolean isVictory
function SplitSceneTurnLogic.checkVictory(scene)
  if not scene.right then return false end
  
  if scene.right.state == "win" then
    return true
  end
  
  if scene.right.enemies then
    local allDefeated = true
    for _, enemy in ipairs(scene.right.enemies) do
      if enemy.hp > 0 and not enemy.disintegrating then
        allDefeated = false
        break
      end
    end
    if allDefeated then
      return true
    end
  end
  
  return false
end

--- Check defeat condition
---@param scene table SplitScene instance
---@return boolean isDefeat
function SplitSceneTurnLogic.checkDefeat(scene)
  if not scene.right then return false end
  
  if (scene.right.playerHP and scene.right.playerHP <= 0) or (scene.right.state == "lose") then
    return true
  end
  
  return false
end

--- Calculate gold reward based on encounter type
---@param encounter table Encounter data
---@return number goldReward
function SplitSceneTurnLogic.calculateGoldReward(encounter)
  if not encounter then
    return love.math.random(16, 25)
  end
  
  if encounter.elite == true then
    return love.math.random(24, 36)
  else
    return love.math.random(16, 25)
  end
end

--- Detect turn end and trigger impact VFX
--- Returns true if turn should end this frame
---@param scene table SplitScene instance
---@param dt number Delta time
---@return boolean shouldEndTurn
function SplitSceneTurnLogic.detectTurnEnd(scene, dt)
  local turnState = scene.turnManager:getState()
  if turnState ~= TurnManager.States.PLAYER_TURN_ACTIVE then
    return false
  end
  
  local canShoot = scene.left and scene.left.canShoot
  local shotWasFired = (canShoot == false)
  local hasBall = SplitSceneTurnLogic.hasBallInFlight(scene)
  local hasActiveBlackHoles = SplitSceneTurnLogic.hasActiveBlackHoles(scene)
  local hasPendingLightningHits = SplitSceneTurnLogic.hasPendingLightningHits(scene)
  local isLightning = SplitSceneTurnLogic.isLightningAttack(scene)
  
  -- Start lightning impact delay timer when last lightning hit completes
  if isLightning and not hasPendingLightningHits and scene._lightningImpactDelayTimer == 0 
     and shotWasFired and not hasBall and not hasActiveBlackHoles then
    scene._lightningImpactDelayTimer = scene._lightningImpactDelayDuration
  end
  
  -- Update lightning impact delay timer
  if scene._lightningImpactDelayTimer > 0 then
    scene._lightningImpactDelayTimer = scene._lightningImpactDelayTimer - dt
    if scene._lightningImpactDelayTimer < 0 then
      scene._lightningImpactDelayTimer = 0
    end
  end
  
  -- Determine if we should trigger impact and end turn
  if shotWasFired and not hasBall and not hasActiveBlackHoles and not hasPendingLightningHits then
    if isLightning then
      -- For lightning, wait for delay timer to expire
      if scene._lightningImpactDelayTimer <= 0 then
        return true
      end
    else
      -- For non-lightning, trigger immediately
      return true
    end
  end
  
  return false
end

--- Handle victory/defeat detection and map return timer
---@param scene table SplitScene instance
---@param dt number Delta time
---@return table|nil result Return signal if timer expires
function SplitSceneTurnLogic.updateVictoryDefeat(scene, dt)
  local isVictory = SplitSceneTurnLogic.checkVictory(scene)
  local isDefeat = SplitSceneTurnLogic.checkDefeat(scene)
  
  if isVictory then
    if not scene._victoryDetected then
      scene._victoryDetected = true
      -- Ensure TurnManager is in VICTORY state
      if scene.turnManager then
        local state = scene.turnManager:getState()
        if state ~= TurnManager.States.VICTORY then
          scene.turnManager:transitionTo(TurnManager.States.VICTORY)
        end
      end
      
      -- Award gold based on encounter type
      local EncounterManager = require("core.EncounterManager")
      local encounter = EncounterManager.getCurrentEncounter()
      if encounter then
        local goldReward = SplitSceneTurnLogic.calculateGoldReward(encounter)
        if goldReward > 0 then
          scene._battleGoldReward = goldReward
        end
      end
    end
    
    -- Only start timer after all actions complete
    if scene._victoryDetected and (not scene._returnToMapTimer or scene._returnToMapTimer == 0) then
      if SplitSceneTurnLogic.areAllActionsComplete(scene) then
        scene._returnToMapTimer = 0.05
      end
    end
  end
  
  if isDefeat then
    if not scene._defeatDetected then
      scene._defeatDetected = true
      scene._returnToMapTimer = 2.0
      -- Ensure TurnManager is in DEFEAT state
      if scene.turnManager then
        local state = scene.turnManager:getState()
        if state ~= TurnManager.States.DEFEAT then
          scene.turnManager:transitionTo(TurnManager.States.DEFEAT)
        end
      end
    end
  end
  
  -- Return to map when timer expires
  if scene._returnToMapTimer and scene._returnToMapTimer > 0 then
    scene._returnToMapTimer = scene._returnToMapTimer - dt
    if scene._returnToMapTimer <= 0 then
      local wasVictory = scene._victoryDetected
      local goldReward = scene._battleGoldReward or 0
      -- Reset flags
      scene._victoryDetected = false
      scene._defeatDetected = false
      scene._returnToMapTimer = 0
      scene._battleGoldReward = nil
      -- Return victory status and gold reward
      return { type = "return_to_map", victory = wasVictory, goldReward = goldReward }
    end
  end
  
  return nil
end

return SplitSceneTurnLogic

