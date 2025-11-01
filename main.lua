-- Expand Lua's package path to include `src/` for modules
package.path = package.path .. ";src/?.lua;src/?/init.lua;src/?/?.lua"

local config = require("config")
local SceneManager = require("core.SceneManager")
local SplitScene = require("scenes.SplitScene")
local FormationEditorScene = require("scenes.FormationEditorScene")

local sceneManager
local screenCanvas
local virtualW, virtualH
local scaleFactor = 1
local offsetX, offsetY = 0, 0
local previousScene = nil -- Store previous scene when switching to formation editor

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
  updateScreenScale()

  sceneManager = SceneManager.new()
  sceneManager:set(SplitScene.new())
end

function love.update(deltaTime)
  if sceneManager then sceneManager:update(deltaTime) end
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
      -- Return to previous scene (SplitScene) or restart game
      if previousScene then
        -- Reload blocks with saved formation before switching back
        if previousScene.reloadBlocks then
          previousScene:reloadBlocks()
        end
        sceneManager:set(previousScene)
        previousScene = nil
      else
        -- No previous scene, restart with new SplitScene
        sceneManager:set(SplitScene.new())
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


