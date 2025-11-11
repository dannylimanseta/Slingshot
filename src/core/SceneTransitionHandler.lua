-- Scene Transition Handler
-- Centralizes all scene transition logic to reduce duplication and improve maintainability

local MapScene = require("scenes.MapScene")
local SplitScene = require("scenes.SplitScene")
local FormationEditorScene = require("scenes.FormationEditorScene")
local RewardsScene = require("scenes.RewardsScene")
local OrbRewardScene = require("scenes.OrbRewardScene")
local EncounterSelectScene = require("scenes.EncounterSelectScene")
local EventScene = require("scenes.EventScene")

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
  
  -- Ensure map scene exists
  if not self.mapScene then
    self.mapScene = MapScene.new()
  end
  
  if victory then
    -- Mark victory on map for any follow-up logic
    self.mapScene._battleVictory = true
    -- Show rewards scene before returning to map
    local rewardsScene = RewardsScene.new({ goldReward = goldReward })
    self.sceneManager:set(rewardsScene)
    self.setCursorForScene(rewardsScene)
  else
    -- Defeat or returning from event: go straight back to map without transition
    -- Skip transition to avoid calling load() which would recalculate player position
    self.sceneManager:set(self.mapScene, true)
    self.setCursorForScene(self.mapScene)
    self.previousScene = nil
    if self.mapScene then
      self.mapScene._inputSuppressTimer = 0.2
    end
  end
end

-- Transition: Open orb reward scene
function SceneTransitionHandler:handleOpenOrbReward(data)
  data = data or {}
  
  -- If RewardsScene indicates pending actions remain, remember it to return after orb pick
  if data.returnToRewards then
    self.previousScene = self.sceneManager.currentScene
    if self.previousScene then
      self.previousScene._removeOrbButtonOnReturn = true
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
  local selectScene = EncounterSelectScene.new()
  selectScene:setPreviousScene(self.sceneManager.currentScene)
  self.previousScene = self.sceneManager.currentScene
  self.sceneManager:set(selectScene)
  self.setCursorForScene(selectScene)
end

-- Transition: Start battle
function SceneTransitionHandler:handleStartBattle()
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
  self.previousScene = self.mapScene
  local eventScene = EventScene.new(eventId)
  self.sceneManager:set(eventScene)
  self.setCursorForScene(eventScene)
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
    elseif transitionType == "start_battle" then
      self:handleStartBattle()
    elseif transitionType == "cancel" then
      self:handleCancel()
    elseif transitionType == "open_event" then
      self:handleOpenEvent(result)
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

