local theme = require("theme")

local EmptyScene = {}
EmptyScene.__index = EmptyScene

function EmptyScene.new()
  return setmetatable({ message = "" }, EmptyScene)
end

function EmptyScene:load()
  self.message = "Empty Scene"
end

function EmptyScene:update(deltaTime)
  -- Intentionally empty for scaffold
end

function EmptyScene:draw(bounds)
  local width = bounds and bounds.w or love.graphics.getWidth()
  local height = bounds and bounds.h or love.graphics.getHeight()
  theme.printfWithOutline(self.message, 0, height * 0.5 - 10, width, "center", 1, 1, 1, 0.7, 2)
  love.graphics.setColor(1, 1, 1, 1)
end

function EmptyScene:resize(width, height)
  -- No-op for now
end

return EmptyScene


