local SceneManager = {}
SceneManager.__index = SceneManager

function SceneManager.new()
  return setmetatable({ currentScene = nil }, SceneManager)
end

function SceneManager:set(scene)
  if self.currentScene and self.currentScene.unload then
    self.currentScene:unload()
  end
  self.currentScene = scene
  if self.currentScene and self.currentScene.load then
    self.currentScene:load()
  end
end

function SceneManager:update(deltaTime)
  if self.currentScene and self.currentScene.update then
    return self.currentScene:update(deltaTime)
  end
  return nil
end

function SceneManager:draw()
  if self.currentScene and self.currentScene.draw then
    self.currentScene:draw()
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


