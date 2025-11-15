-- Scene Transition Handler
-- Centralizes all scene transition logic to reduce duplication and improve maintainability

local MapScene = require("scenes.MapScene")
local MapManager = require("managers.MapManager")
local SplitScene = require("scenes.SplitScene")
local FormationEditorScene = require("scenes.FormationEditorScene")
local RewardsScene = require("scenes.RewardsScene")
local OrbRewardScene = require("scenes.OrbRewardScene")
local EncounterSelectScene = require("scenes.EncounterSelectScene")
local RelicSelectScene = require("scenes.RelicSelectScene")
local EventSelectScene = require("scenes.EventSelectScene")
local InventoryScene = require("scenes.InventoryScene")
local EventScene = require("scenes.EventScene")
local RestSiteScene = require("scenes.RestSiteScene")
local EncounterManager = require("core.EncounterManager")

local SceneTransitionHandler = {}
SceneTransitionHandler.__index = SceneTransitionHandler

function SceneTransitionHandler.new(sceneManager, setCursorForScene)
  return setmetatable({
    sceneManager = sceneManager,
    setCursorForScene = setCursorForScene,
    previousScene = nil,
    mapScene = nil,
  }, SceneTransitionHandler)
end

-- Helper: Check if result matches a transition type (handles both string and table results)
local function matchesTransition(result, transitionType)
  if type(result) == "string" then
    return result == transitionType
  elseif type(result) == "table" then
    return result.type == transitionType
  end
  return false
end

-- Helper: Get transition data from result (handles both string and table results)
local function getTransitionData(result)
  if type(result) == "table" then
    return result
  else
    return { type = result }
  end
end

-- Transition: Enter battle from map
function SceneTransitionHandler:handleEnterBattle()
  -- Save current map world position to restore precisely after transitions
  if self.mapScene then
    self.mapScene._savedWorldX = self.mapScene.playerWorldX
    self.mapScene._savedWorldY = self.mapScene.playerWorldY
  end
  self.previousScene = self.mapScene
  local battleScene = SplitScene.new()
  self.sceneManager:set(battleScene)
  self.setCursorForScene(battleScene)
end

-- Transition: Return to map (with victory/defeat handling)
function SceneTransitionHandler:handleReturnToMap(data)
  data = data or {}
  local victory = data.victory or false
  local goldReward = data.goldReward or 0
  local skipTransition = data.skipTransition
  
  -- If there's a previousScene (e.g., EventSelectScene), return to it instead of map
  if self.previousScene then
    local prevScene = self.previousScene
    self.previousScene = nil
    self.sceneManager:set(prevScene)
    self.setCursorForScene(prevScene)
    return
  end
  
  -- Ensure map scene exists
  if not self.mapScene then
    self.mapScene = MapScene.new()
  end
  
  if victory then
    -- Apply end-of-battle relic effects (e.g., post-combat healing)
    do
      local RelicSystem = require("core.RelicSystem")
      if RelicSystem and RelicSystem.applyBattleEnd then
        RelicSystem.applyBattleEnd({ result = "victory" })
      end
    end
    -- Mark victory on map for any follow-up logic
    self.mapScene._battleVictory = true
    -- Ensure we use a transition when coming back from Rewards to the map
    self._pendingMapReturnWithTransition = true
    -- Show rewards scene before returning to map
    local encounter = EncounterManager.getCurrentEncounter()
    local relicRewardEligible = encounter and encounter.elite == true
    local rewardsScene = RewardsScene.new({
      goldReward = goldReward,
      relicRewardEligible = relicRewardEligible,
    })
    self.sceneManager:set(rewardsScene)
    self.setCursorForScene(rewardsScene)
  else
    -- If skipTransition is explicitly false, use transition; otherwise skip for events/defeat
    -- Rest sites set skipTransition = false to enable transitions
    -- If we previously set a pending flag (coming back from battle rewards), force transition
    if self._pendingMapReturnWithTransition then
      skipTransition = false
      self._pendingMapReturnWithTransition = nil
    end
    if skipTransition == false then
      -- Use transition (for rest sites)
      self.sceneManager:set(self.mapScene, false)
      self.setCursorForScene(self.mapScene)
      self.previousScene = nil
      if self.mapScene then
        -- Ensure stale movement/input state is cleared on resume
        if self.mapScene.resetMovementOnResume then
          self.mapScene:resetMovementOnResume()
        end
        self.mapScene._inputSuppressTimer = 0.2
      end
    else
      -- Skip transition (for events/defeat) to avoid calling load() which would recalculate player position
      self.sceneManager:set(self.mapScene, true)
      self.setCursorForScene(self.mapScene)
      self.previousScene = nil
      if self.mapScene then
        -- Ensure stale movement/input state is cleared on resume
        if self.mapScene.resetMovementOnResume then
          self.mapScene:resetMovementOnResume()
        end
        self.mapScene._inputSuppressTimer = 0.2
      end
    end
  end
end

-- Transition: Open orb reward scene
function SceneTransitionHandler:handleOpenOrbReward(data)
  data = data or {}
  -- Save current map world position before switching scenes
  if self.mapScene then
    self.mapScene._savedWorldX = self.mapScene.playerWorldX
    self.mapScene._savedWorldY = self.mapScene.playerWorldY
  end
  
  -- If RewardsScene indicates pending actions remain, remember it to return after orb pick
  if data.returnToRewards then
    self.previousScene = self.sceneManager.currentScene
    if self.previousScene then
      self.previousScene._removeOrbButtonOnReturn = true
      if self.previousScene._relicButtonClaimed then
        self.previousScene._removeRelicButtonOnReturn = true
      end
    end
  end
  
  local orbScene = OrbRewardScene.new({
    returnToPreviousOnExit = data.returnToRewards,
    shaderTime = data.shaderTime
  })
  self.sceneManager:set(orbScene, true)
  self.setCursorForScene(orbScene)
end

-- Transition: Return to previous scene
function SceneTransitionHandler:handleReturnToPrevious()
  if self.previousScene then
    self.sceneManager:set(self.previousScene)
    self.setCursorForScene(self.previousScene)
    self.previousScene = nil
  end
end

-- Transition: Open formation editor
function SceneTransitionHandler:handleOpenFormationEditor()
  self.previousScene = self.sceneManager.currentScene
  local editorScene = FormationEditorScene.new()
  editorScene:setPreviousScene(self.previousScene)
  self.sceneManager:set(editorScene)
  self.setCursorForScene(editorScene)
end

-- Transition: Restart (return to previous or start new map)
function SceneTransitionHandler:handleRestart()
  if self.previousScene then
    -- Check if returning to map scene or battle scene
    if self.previousScene == self.mapScene then
      -- Returning to map from battle
      self.sceneManager:set(self.previousScene)
      self.setCursorForScene(self.previousScene)
      self.previousScene = nil
    else
      -- Returning to battle scene (from formation editor)
      if self.previousScene.reloadBlocks then
        self.previousScene:reloadBlocks()
      end
      self.sceneManager:set(self.previousScene)
      self.setCursorForScene(self.previousScene)
      self.previousScene = nil
    end
  else
    -- No previous scene, restart with map
    self.mapScene = MapScene.new()
    self.sceneManager:set(self.mapScene)
    self.setCursorForScene(self.mapScene)
  end
end

-- Transition: Open encounter select
function SceneTransitionHandler:handleOpenEncounterSelect()
  -- Save current map world position before switching scenes
  if self.mapScene then
    self.mapScene._savedWorldX = self.mapScene.playerWorldX
    self.mapScene._savedWorldY = self.mapScene.playerWorldY
  end
  
  -- Check if current tile is elite
  local isEliteTile = false
  if self.mapScene and self.mapScene.mapManager then
    local gridX = self.mapScene.mapManager.playerGridX
    local gridY = self.mapScene.mapManager.playerGridY
    if gridX > 0 and gridY > 0 then
      local tile = self.mapScene.mapManager:getTile(gridX, gridY)
      if tile and tile.type == MapManager.TileType.ENEMY then
        isEliteTile = (tile.spriteVariant == 2)
      end
    end
  end
  
  local selectScene = EncounterSelectScene.new()
  selectScene:setPreviousScene(self.sceneManager.currentScene)
  selectScene:setEliteFilter(isEliteTile)
  self.previousScene = self.sceneManager.currentScene
  self.sceneManager:set(selectScene)
  self.setCursorForScene(selectScene)
end

-- Transition: Open relic select
function SceneTransitionHandler:handleOpenRelicSelect()
  if self.mapScene then
    self.mapScene._savedWorldX = self.mapScene.playerWorldX
    self.mapScene._savedWorldY = self.mapScene.playerWorldY
  end

  local selectScene = RelicSelectScene.new()
  selectScene:setPreviousScene(self.sceneManager.currentScene)
  self.previousScene = self.sceneManager.currentScene
  self.sceneManager:set(selectScene)
  self.setCursorForScene(selectScene)
end

-- Transition: Open event select
function SceneTransitionHandler:handleOpenEventSelect()
  if self.mapScene then
    self.mapScene._savedWorldX = self.mapScene.playerWorldX
    self.mapScene._savedWorldY = self.mapScene.playerWorldY
  end

  local selectScene = EventSelectScene.new()
  selectScene:setPreviousScene(self.sceneManager.currentScene)
  self.previousScene = self.sceneManager.currentScene
  self.sceneManager:set(selectScene)
  self.setCursorForScene(selectScene)
end

-- Transition: Open inventory scene
function SceneTransitionHandler:handleOpenInventory()
  if self.mapScene then
    self.mapScene._savedWorldX = self.mapScene.playerWorldX
    self.mapScene._savedWorldY = self.mapScene.playerWorldY
  end

  local inventoryScene = InventoryScene.new()
  inventoryScene:setPreviousScene(self.sceneManager.currentScene)
  self.previousScene = self.sceneManager.currentScene
  self.sceneManager:set(inventoryScene)
  self.setCursorForScene(inventoryScene)
end

-- Transition: Start battle
function SceneTransitionHandler:handleStartBattle()
  -- Save current map world position to restore precisely after transitions
  if self.mapScene then
    self.mapScene._savedWorldX = self.mapScene.playerWorldX
    self.mapScene._savedWorldY = self.mapScene.playerWorldY
  end
  self.previousScene = self.mapScene
  local battleScene = SplitScene.new()
  self.sceneManager:set(battleScene)
  self.setCursorForScene(battleScene)
end

-- Transition: Cancel (return to previous or map)
function SceneTransitionHandler:handleCancel()
  if self.previousScene then
    self.sceneManager:set(self.previousScene)
    self.setCursorForScene(self.previousScene)
    self.previousScene = nil
  elseif self.mapScene then
    self.sceneManager:set(self.mapScene)
    self.setCursorForScene(self.mapScene)
  end
end

-- Transition: Open event scene
function SceneTransitionHandler:handleOpenEvent(data)
  data = data or {}
  local eventId = data.eventId or "whispering_idol"  -- Default fallback
  -- Save current map world position before switching scenes
  if self.mapScene then
    self.mapScene._savedWorldX = self.mapScene.playerWorldX
    self.mapScene._savedWorldY = self.mapScene.playerWorldY
  end
  -- Set previousScene to current scene (e.g., EventSelectScene) if it exists,
  -- otherwise default to mapScene
  local currentScene = self.sceneManager.currentScene
  if currentScene then
    self.previousScene = currentScene
  elseif not self.previousScene then
    self.previousScene = self.mapScene
  end
  local eventScene = EventScene.new(eventId)
  self.sceneManager:set(eventScene)
  self.setCursorForScene(eventScene)
end

-- Transition: Open rest site scene
function SceneTransitionHandler:handleOpenRestSite()
  -- Save current map world position before switching scenes
  if self.mapScene then
    self.mapScene._savedWorldX = self.mapScene.playerWorldX
    self.mapScene._savedWorldY = self.mapScene.playerWorldY
  end
  self.previousScene = self.mapScene
  local restSiteScene = RestSiteScene.new()
  self.sceneManager:set(restSiteScene)
  self.setCursorForScene(restSiteScene)
end

-- Transition: Open treasure reward scene
function SceneTransitionHandler:handleOpenTreasureReward()
  -- Save current map world position before switching scenes
  if self.mapScene then
    self.mapScene._savedWorldX = self.mapScene.playerWorldX
    self.mapScene._savedWorldY = self.mapScene.playerWorldY
  end
  self.previousScene = self.mapScene
  -- Treasure chests always give a relic reward (no orb or gold)
  local rewardsScene = RewardsScene.new({
    goldReward = 0,
    relicRewardEligible = true,
    showOrbReward = false, -- Treasure chests don't offer orb rewards
  })
  self.sceneManager:set(rewardsScene)
  self.setCursorForScene(rewardsScene)
end

-- Main handler: processes transition results from scene updates/events
function SceneTransitionHandler:handleTransition(result)
  if not result then return end
  
  -- Handle string results (backward compatibility)
  if type(result) == "string" then
    if result == "enter_battle" then
      self:handleEnterBattle()
    elseif result == "return_to_map" then
      self:handleReturnToMap()
    elseif result == "open_orb_reward" then
      self:handleOpenOrbReward()
    elseif result == "return_to_previous" then
      self:handleReturnToPrevious()
    elseif result == "open_formation_editor" then
      self:handleOpenFormationEditor()
    elseif result == "restart" then
      self:handleRestart()
    elseif result == "open_encounter_select" then
      self:handleOpenEncounterSelect()
    elseif result == "open_relic_select" then
      self:handleOpenRelicSelect()
    elseif result == "open_event_select" then
      self:handleOpenEventSelect()
    elseif result == "open_inventory" then
      self:handleOpenInventory()
    elseif result == "start_battle" then
      self:handleStartBattle()
    elseif result == "cancel" then
      self:handleCancel()
    end
    return
  end
  
  -- Handle table results
  if type(result) == "table" then
    local transitionType = result.type
    if transitionType == "enter_battle" then
      self:handleEnterBattle()
    elseif transitionType == "return_to_map" then
      self:handleReturnToMap(result)
    elseif transitionType == "open_orb_reward" then
      self:handleOpenOrbReward(result)
    elseif transitionType == "return_to_previous" then
      self:handleReturnToPrevious()
    elseif transitionType == "open_formation_editor" then
      self:handleOpenFormationEditor()
    elseif transitionType == "restart" then
      self:handleRestart()
    elseif transitionType == "open_encounter_select" then
      self:handleOpenEncounterSelect()
    elseif transitionType == "open_relic_select" then
      self:handleOpenRelicSelect()
    elseif transitionType == "open_event_select" then
      self:handleOpenEventSelect()
    elseif transitionType == "open_inventory" then
      self:handleOpenInventory()
    elseif transitionType == "start_battle" then
      self:handleStartBattle()
    elseif transitionType == "cancel" then
      self:handleCancel()
    elseif transitionType == "open_event" then
      self:handleOpenEvent(result)
    elseif transitionType == "open_rest_site" then
      self:handleOpenRestSite()
    elseif transitionType == "open_treasure_reward" then
      self:handleOpenTreasureReward()
    end
  end
end

-- Initialize map scene (called from love.load)
function SceneTransitionHandler:initializeMapScene()
  self.mapScene = MapScene.new()
  self.sceneManager:set(self.mapScene)
  self.setCursorForScene(self.mapScene)
end

-- Getter for map scene (for external access if needed)
function SceneTransitionHandler:getMapScene()
  return self.mapScene
end

return SceneTransitionHandler

