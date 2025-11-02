local config = require("config")
local TransitionShader = require("utils.TransitionShader")

local SceneManager = {}
SceneManager.__index = SceneManager

function SceneManager.new()
  return setmetatable({
    currentScene = nil,
    previousScene = nil,
    previousSceneCanvas = nil,
    currentSceneCanvas = nil, -- Reusable canvas for current scene during transition
    transitionTimer = 0,
    transitionDuration = 0,
    isTransitioning = false,
    transitionShader = TransitionShader.getShader(),
  }, SceneManager)
end

function SceneManager:set(scene, skipTransition)
  -- If skipTransition is true, switch immediately without transition
  if skipTransition then
    if self.currentScene and self.currentScene.unload then
      self.currentScene:unload()
    end
    self.currentScene = scene
    if self.currentScene and self.currentScene.load then
      self.currentScene:load()
    end
    self.isTransitioning = false
    self.previousSceneCanvas = nil
    return
  end
  
  -- Start transition
  if self.currentScene then
    -- Capture current scene to canvas before switching
    local virtualW = (config.video and config.video.virtualWidth) or 1280
    local virtualH = (config.video and config.video.virtualHeight) or 720
    local canvas = love.graphics.newCanvas(virtualW, virtualH)
    love.graphics.push('all')
    love.graphics.setCanvas(canvas)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    if self.currentScene.draw then
      self.currentScene:draw()
    end
    love.graphics.setCanvas()
    love.graphics.pop()
    
    self.previousScene = self.currentScene
    self.previousSceneCanvas = canvas
    
    -- Unload previous scene
    if self.currentScene.unload then
      self.currentScene:unload()
    end
  end
  
  -- Set new scene
  self.currentScene = scene
  if self.currentScene and self.currentScene.load then
    self.currentScene:load()
  end
  
  -- Start transition animation
  self.isTransitioning = true
  self.transitionTimer = 0
  self.transitionDuration = (config.transition and config.transition.duration) or 0.6
  
  -- Create reusable canvas for current scene
  local virtualW = (config.video and config.video.virtualWidth) or 1280
  local virtualH = (config.video and config.video.virtualHeight) or 720
  if not self.currentSceneCanvas then
    self.currentSceneCanvas = love.graphics.newCanvas(virtualW, virtualH)
  end
end

function SceneManager:update(deltaTime)
  -- Update transition timer
  if self.isTransitioning then
    self.transitionTimer = self.transitionTimer + deltaTime
    if self.transitionTimer >= self.transitionDuration then
      self.isTransitioning = false
      self.previousSceneCanvas = nil
      self.previousScene = nil
      -- Keep currentSceneCanvas for reuse in next transition
    end
  end
  
  -- Update current scene
  if self.currentScene and self.currentScene.update then
    return self.currentScene:update(deltaTime)
  end
  return nil
end

function SceneManager:draw()
  -- If transitioning, render with transition shader
  if self.isTransitioning and self.previousSceneCanvas and self.currentSceneCanvas then
    -- Get virtual resolution (canvas size)
    local virtualW = (config.video and config.video.virtualWidth) or 1280
    local virtualH = (config.video and config.video.virtualHeight) or 720
    
    -- Render current scene to reusable canvas (reuse instead of creating new one each frame)
    love.graphics.push('all')
    love.graphics.setCanvas(self.currentSceneCanvas)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    if self.currentScene and self.currentScene.draw then
      self.currentScene:draw()
    end
    love.graphics.setCanvas()
    love.graphics.pop()
    
    -- Calculate fade timer
    -- Progress goes from 0 (start) to 1 (end)
    -- fadeTimer should go from very negative (all previous scene) to very positive (all current scene)
    -- For horizontal fade: wider range makes transition slower and more visible
    -- Using -2.0 to 2.0 range (total 4.0) instead of -1.5 to 1.5 (total 3.0) for slower transition
    local progress = self.transitionTimer / self.transitionDuration
    local fadeTimer = progress * 4.0 - 2.0
    
    -- Set shader uniforms
    self.transitionShader:send("u_fadeTimer", fadeTimer)
    self.transitionShader:send("u_fadeType", (config.transition and config.transition.fadeType) or 1)
    self.transitionShader:send("u_gridWidth", (config.transition and config.transition.gridWidth) or 28)
    self.transitionShader:send("u_gridHeight", (config.transition and config.transition.gridHeight) or 15)
    self.transitionShader:send("u_previousScene", self.previousSceneCanvas)
    
    -- Draw current scene canvas with transition shader
    love.graphics.push('all')
    love.graphics.origin()
    love.graphics.setShader(self.transitionShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.currentSceneCanvas, 0, 0)
    love.graphics.setShader()
    love.graphics.pop()
  else
    -- Normal rendering without transition
    if self.currentScene and self.currentScene.draw then
      self.currentScene:draw()
    end
  end
end

-- Forward common Love2D callbacks to the active scene if implemented
function SceneManager:resize(width, height)
  if self.currentScene and self.currentScene.resize then
    self.currentScene:resize(width, height)
  end
end

function SceneManager:keypressed(key, scancode, isRepeat)
  if self.currentScene and self.currentScene.keypressed then
    return self.currentScene:keypressed(key, scancode, isRepeat)
  end
end

function SceneManager:keyreleased(key, scancode)
  if self.currentScene and self.currentScene.keyreleased then
    self.currentScene:keyreleased(key, scancode)
  end
end

function SceneManager:mousepressed(x, y, button, isTouch, presses)
  if self.currentScene and self.currentScene.mousepressed then
    self.currentScene:mousepressed(x, y, button, isTouch, presses)
  end
end

function SceneManager:mousereleased(x, y, button, isTouch, presses)
  if self.currentScene and self.currentScene.mousereleased then
    self.currentScene:mousereleased(x, y, button, isTouch, presses)
  end
end

function SceneManager:mousemoved(x, y, dx, dy, isTouch)
  if self.currentScene and self.currentScene.mousemoved then
    self.currentScene:mousemoved(x, y, dx, dy, isTouch)
  end
end

function SceneManager:wheelmoved(dx, dy)
  if self.currentScene and self.currentScene.wheelmoved then
    self.currentScene:wheelmoved(dx, dy)
  end
end

return SceneManager


