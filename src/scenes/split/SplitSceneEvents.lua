-- SplitSceneEvents.lua
-- Handles TurnManager event subscriptions for SplitScene

local config = require("config")
local TurnManager = require("core.TurnManager")

local SplitSceneEvents = {}

--- Set up all TurnManager event handlers for SplitScene
---@param scene table The SplitScene instance
function SplitSceneEvents.setup(scene)
  if not scene.turnManager then return end
  
  SplitSceneEvents.setupTurnIndicatorEvents(scene)
  SplitSceneEvents.setupStateEvents(scene)
  SplitSceneEvents.setupDamageEvents(scene)
  SplitSceneEvents.setupVictoryDefeatEvents(scene)
  SplitSceneEvents.setupBlockEvents(scene)
  SplitSceneEvents.setupEnemySkillEvents(scene)
end

--- Show turn indicator event handler
function SplitSceneEvents.setupTurnIndicatorEvents(scene)
  scene.turnManager:on("show_turn_indicator", function(data)
    if scene.right and scene.right.showTurnIndicator then
      local text = data and data.text or "TURN"
      local duration = data and data.duration or 1.0
      scene.right:showTurnIndicator(text, duration)
    end
  end)
end

--- State transition event handlers
function SplitSceneEvents.setupStateEvents(scene)
  scene.turnManager:on("state_enter", function(newState, previousState)
    if newState == TurnManager.States.PLAYER_TURN_ACTIVE then
      if scene.left then
        scene.left.canShoot = true
      end
    elseif newState == TurnManager.States.PLAYER_TURN_START then
      -- Disable shooting at start of turn (will be enabled when active)
      if scene.left then
        scene.left.canShoot = false
      end
    elseif newState == TurnManager.States.ENEMY_TURN_START then
      -- Decrement calcify turns at the end of the player's turn
      if previousState == TurnManager.States.PLAYER_TURN_RESOLVING then
        if scene.left and scene.left.blocks and scene.left.blocks.blocks then
          for _, block in ipairs(scene.left.blocks.blocks) do
            if block and block.decrementCalcifyTurns then
              block:decrementCalcifyTurns()
            end
          end
        end
      end
    end
  end)
end

--- Damage application event handlers
function SplitSceneEvents.setupDamageEvents(scene)
  -- Apply damage event (when player turn ends)
  scene.turnManager:on("apply_damage", function(data)
    if data.target == "enemy" and scene.right and scene.right.onPlayerTurnEnd then
      local turnData = scene.turnManager:getTurnData()
      -- Pass consolidated turn data object
      scene.right:onPlayerTurnEnd({
        damage = data.amount,
        armor = turnData.armor or 0,
        isAOE = turnData.isAOE or false,
        projectileId = turnData.projectileId or "strike",
        blockHitSequence = turnData.blockHitSequence or {},
        baseDamage = turnData.baseDamage or data.amount,
        orbBaseDamage = turnData.orbBaseDamage or 0,
        critCount = turnData.critCount or 0,
        multiplierCount = turnData.multiplierCount or 0,
        impactBlockCount = (scene._pendingImpactParams and scene._pendingImpactParams.blockCount) or 1,
        impactIsCrit = (scene._pendingImpactParams and scene._pendingImpactParams.isCrit) or false,
      })
      -- Apply healing if any
      if turnData.heal and turnData.heal > 0 and scene.right and scene.right.applyHealing then
        scene.right:applyHealing(turnData.heal)
      end
      -- Trigger screenshake for player attack
      scene:triggerShake((config.battle and config.battle.shakeMagnitude) or 10, (config.battle and config.battle.shakeDuration) or 0.25)
    end
  end)
  
  -- Show armor popup event (handled by BattleScene's onPlayerTurnEnd via pendingArmor)
  scene.turnManager:on("show_armor_popup", function(data)
    -- No additional action needed here
  end)
end

--- Victory and defeat check event handlers
function SplitSceneEvents.setupVictoryDefeatEvents(scene)
  -- Check victory event
  scene.turnManager:on("check_victory", function()
    if scene.right and scene.right.enemies then
      local allDefeated = true
      for _, enemy in ipairs(scene.right.enemies) do
        if enemy.hp > 0 and not enemy.disintegrating then
          allDefeated = false
          break
        end
      end
      if allDefeated then
        scene.turnManager:transitionTo(TurnManager.States.VICTORY)
      end
    end
  end)
  
  -- Check defeat event
  scene.turnManager:on("check_defeat", function()
    if scene.right and scene.right.playerHP and scene.right.playerHP <= 0 then
      scene.turnManager:transitionTo(TurnManager.States.DEFEAT)
    end
  end)
end

--- Block spawn/manipulation event handlers
function SplitSceneEvents.setupBlockEvents(scene)
  -- Spawn blocks event
  scene.turnManager:on("spawn_blocks", function(data)
    if scene.left and scene.left.respawnDestroyedBlocks then
      local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
      local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
      local centerRect = scene.layoutManager:getCenterRect(vw, vh)
      scene.left:respawnDestroyedBlocks({ x = 0, y = 0, w = centerRect.w, h = vh }, (data and data.count) or 0)
    end
  end)
  
  -- Enemy shockwave blocks event
  scene.turnManager:on("enemy_shockwave_blocks", function()
    if scene.left and scene.left.triggerBlockShakeAndDrop then
      scene.left:triggerBlockShakeAndDrop()
    end
  end)
  
  -- Enemy calcify blocks event (immediate calcify, no animation)
  scene.turnManager:on("enemy_calcify_blocks", function(data)
    if scene.left and scene.left.calcifyBlocks then
      scene.left:calcifyBlocks(data.count or 3)
    end
  end)
  
  -- Enemy calcify request blocks event (for particle animation)
  scene.turnManager:on("enemy_calcify_request_blocks", function(data)
    if scene.left and scene.left.getCalcifyBlockPositions then
      local blockPositions = scene.left:getCalcifyBlockPositions(data.count or 3)
      if blockPositions and #blockPositions > 0 then
        -- Convert block positions from GameplayScene local coordinates to screen coordinates
        local w = (config.video and config.video.virtualWidth) or 1280
        local h = (config.video and config.video.virtualHeight) or 720
        local centerRect = scene.layoutManager:getCenterRect(w, h)
        local centerX = centerRect.x - 100 -- Shift breakout canvas 100px to the left (matching draw)
        
        -- Convert each block position to screen coordinates
        for _, blockPos in ipairs(blockPositions) do
          blockPos.x = blockPos.x + centerX -- Convert from local to screen X
        end
        
        -- Send block positions back to BattleScene
        if scene.right and scene.right.startCalcifyAnimation then
          scene.right:startCalcifyAnimation(data.enemyX, data.enemyY, blockPositions)
        end
      end
    end
  end)
end

--- Enemy skill event handlers (charge, spore, etc.)
function SplitSceneEvents.setupEnemySkillEvents(scene)
  -- Enemy charge skill: spawn armor blocks on the board
  scene.turnManager:on("enemy_charge_spawn_armor_blocks", function(data)
    if scene.left and scene.left.spawnArmorBlocks then
      local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
      local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
      local centerRect = scene.layoutManager:getCenterRect(vw, vh)
      scene.left:spawnArmorBlocks({ x = 0, y = 0, w = centerRect.w, h = vh }, (data and data.count) or 3)
    end
  end)

  -- Enemy spore skill: spawn spore blocks on the board
  scene.turnManager:on("enemy_spore_spawn_blocks", function(data)
    if scene.left and scene.left.spawnSporeBlocks then
      local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
      local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
      local centerRect = scene.layoutManager:getCenterRect(vw, vh)
      scene.left:spawnSporeBlocks({ x = 0, y = 0, w = centerRect.w, h = vh }, (data and data.count) or 2)
    end
  end)

  -- Enemy spore request positions (for particle animation)
  scene.turnManager:on("enemy_spore_request_positions", function(data)
    if scene.left and scene.left.getSporeSpawnPositions and scene.right and scene.right.startSporeAnimation then
      local positions = scene.left:getSporeSpawnPositions((data and data.count) or 2)
      if positions and #positions > 0 then
        -- Convert block positions from GameplayScene local coordinates to screen coordinates
        local w = (config.video and config.video.virtualWidth) or 1280
        local h = (config.video and config.video.virtualHeight) or 720
        local centerRect = scene.layoutManager:getCenterRect(w, h)
        local centerX = centerRect.x - 100 -- Shift breakout canvas 100px to the left (matching draw)
        
        -- Convert each block position to screen coordinates
        for _, blockPos in ipairs(positions) do
          blockPos.x = blockPos.x + centerX -- Convert from local to screen X
        end
        
        -- Send block positions back to BattleScene
        scene.right:startSporeAnimation((data and data.enemyX) or 0, (data and data.enemyY) or 0, positions)
      end
    end
  end)

  -- Enemy spore: spawn a single block at provided coordinates
  scene.turnManager:on("enemy_spore_spawn_block_at", function(data)
    if scene.left and scene.left.spawnSporeBlockAt and data and data.x and data.y then
      -- Convert from screen coordinates back to GameplayScene local coordinates
      local w = (config.video and config.video.virtualWidth) or 1280
      local h = (config.video and config.video.virtualHeight) or 720
      local centerRect = scene.layoutManager:getCenterRect(w, h)
      local centerX = centerRect.x - 100 -- Same offset as used in conversion
      local localX = data.x - centerX -- Convert back to local coordinates
      scene.left:spawnSporeBlockAt(localX, data.y) -- Y doesn't need conversion
    end
  end)
end

return SplitSceneEvents

