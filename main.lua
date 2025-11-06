-- Expand Lua's package path to include `src/` for modules
package.path = package.path .. ";src/?.lua;src/?/init.lua;src/?/?.lua"

local config = require("config")
local SceneManager = require("core.SceneManager")
local MapScene = require("scenes.MapScene")
local SplitScene = require("scenes.SplitScene")
local FormationEditorScene = require("scenes.FormationEditorScene")
local RewardsScene = require("scenes.RewardsScene")
local OrbRewardScene = require("scenes.OrbRewardScene")

local sceneManager
local screenCanvas
local virtualW, virtualH
local scaleFactor = 1
local offsetX, offsetY = 0, 0
local previousScene = nil -- Store previous scene when switching to formation editor
local mapScene = nil -- Store map scene to return to after battle

local function updateScreenScale()
  local winW, winH = love.graphics.getDimensions()
  local sx = winW / virtualW
  local sy = winH / virtualH
  scaleFactor = math.min(sx, sy)
  offsetX = math.floor((winW - virtualW * scaleFactor) * 0.5)
  offsetY = math.floor((winH - virtualH * scaleFactor) * 0.5)
end

function love.load()
  math.randomseed(os.time())

  virtualW = (config.video and config.video.virtualWidth) or 1280
  virtualH = (config.video and config.video.virtualHeight) or 720
  screenCanvas = love.graphics.newCanvas(virtualW, virtualH)
  -- Use linear filtering so upscaled text looks smooth in fullscreen
  screenCanvas:setFilter('linear', 'linear')
  love.graphics.setDefaultFilter('linear', 'linear', 1)
  updateScreenScale()

  sceneManager = SceneManager.new()
  -- Start with map exploration scene
  mapScene = MapScene.new()
  sceneManager:set(mapScene)
end

function love.update(deltaTime)
  if sceneManager then 
    local result = sceneManager:update(deltaTime)
    
    -- Handle battle transition signal from MapScene
    if result == "enter_battle" then
      -- Store map scene as previous scene
      previousScene = mapScene
      -- Switch to battle (SplitScene)
      sceneManager:set(SplitScene.new())
    elseif type(result) == "table" and result.type == "return_to_map" then
      -- Post-battle flow
      if result.victory then
        -- Mark victory on map for any follow-up logic
        if not mapScene then
          mapScene = MapScene.new()
        end
        mapScene._battleVictory = true
        -- Show rewards scene before returning to map
        sceneManager:set(RewardsScene.new())
      else
        -- Defeat: go straight back to map
        if mapScene then
          sceneManager:set(mapScene)
          previousScene = nil
        else
          mapScene = MapScene.new()
          sceneManager:set(mapScene)
        end
      end
    elseif result == "return_to_map" then
      -- Backward compatibility: handle string return
      if mapScene then
        sceneManager:set(mapScene)
        previousScene = nil
      else
        mapScene = MapScene.new()
        sceneManager:set(mapScene)
      end
    elseif result == "open_orb_reward" then
      sceneManager:set(OrbRewardScene.new())
    end
  end
end

function love.draw()
  -- Draw everything to virtual canvas
  love.graphics.setCanvas(screenCanvas)
  love.graphics.clear(0, 0, 0, 0)
  if sceneManager then sceneManager:draw() end
  love.graphics.setCanvas()

  -- Present canvas scaled with letterboxing
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(screenCanvas, offsetX, offsetY, 0, scaleFactor, scaleFactor)
  love.graphics.setColor(1, 1, 1, 1)
end

function love.resize(width, height)
  updateScreenScale()
  if sceneManager then sceneManager:resize(width, height) end
end

function love.keypressed(key, scancode, isRepeat)
  if sceneManager then 
    local result = sceneManager:keypressed(key, scancode, isRepeat)
    
    -- Handle scene switching signals
    if result == "open_formation_editor" then
      -- Store current scene as previous scene
      previousScene = sceneManager.currentScene
      -- Create and switch to formation editor
      local editorScene = FormationEditorScene.new()
      editorScene:setPreviousScene(previousScene)
      sceneManager:set(editorScene)
    elseif result == "restart" then
      -- Return to previous scene (could be MapScene or SplitScene) or restart game
      if previousScene then
        -- Check if returning to map scene or battle scene
        if previousScene == mapScene then
          -- Returning to map from battle
          sceneManager:set(previousScene)
          previousScene = nil
        else
          -- Returning to battle scene (from formation editor)
          if previousScene.reloadBlocks then
            previousScene:reloadBlocks()
          end
          sceneManager:set(previousScene)
          previousScene = nil
        end
      else
        -- No previous scene, restart with map
        mapScene = MapScene.new()
        sceneManager:set(mapScene)
      end
    elseif result == "return_to_map" then
      -- Return to map scene from battle
      if mapScene then
        sceneManager:set(mapScene)
        previousScene = nil
      else
        -- Create new map scene if none exists
        mapScene = MapScene.new()
        sceneManager:set(mapScene)
      end
    end
  end
end

function love.keyreleased(key, scancode)
  if sceneManager then sceneManager:keyreleased(key, scancode) end
end

function love.mousepressed(x, y, button, isTouch, presses)
  local vx = (x - offsetX) / scaleFactor
  local vy = (y - offsetY) / scaleFactor
  if sceneManager then sceneManager:mousepressed(vx, vy, button, isTouch, presses) end
end

function love.mousereleased(x, y, button, isTouch, presses)
  local vx = (x - offsetX) / scaleFactor
  local vy = (y - offsetY) / scaleFactor
  if sceneManager then sceneManager:mousereleased(vx, vy, button, isTouch, presses) end
end

function love.mousemoved(x, y, dx, dy, isTouch)
  local vx = (x - offsetX) / scaleFactor
  local vy = (y - offsetY) / scaleFactor
  local vdx = dx / scaleFactor
  local vdy = dy / scaleFactor
  if sceneManager then sceneManager:mousemoved(vx, vy, vdx, vdy, isTouch) end
end

function love.wheelmoved(dx, dy)
  if sceneManager then sceneManager:wheelmoved(dx, dy) end
end


