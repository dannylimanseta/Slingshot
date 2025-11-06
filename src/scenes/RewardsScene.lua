local config = require("config")
local theme = require("theme")
local RewardsBackdropShader = require("utils.RewardsBackdropShader")

local RewardsScene = {}
RewardsScene.__index = RewardsScene

function RewardsScene.new(params)
  return setmetatable({
    time = 0,
    shader = RewardsBackdropShader.getShader(),
    params = params or {},
  }, RewardsScene)
end

function RewardsScene:load()
  self.time = 0
end

function RewardsScene:update(dt)
  self.time = self.time + dt
  if self.shader then
    local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
    local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
    self.shader:send("u_time", self.time)
    self.shader:send("u_resolution", { vw, vh })
  end
end

function RewardsScene:draw()
  local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
  local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()

  -- Backdrop shader
  if self.shader then
    love.graphics.push('all')
    love.graphics.setShader(self.shader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle('fill', 0, 0, vw, vh)
    love.graphics.setShader()
    love.graphics.pop()
  end

  -- Title
  theme.printfWithOutline("REWARDS", 0, vh * 0.2, vw, "center", 1, 1, 1, 0.85, 3)

  -- Continue hint
  theme.printfWithOutline("Press SPACE or click to continue", 0, vh * 0.8, vw, "center", 1, 1, 1, 0.8, 2)
end

function RewardsScene:keypressed(key, scancode, isRepeat)
  if key == "space" or key == "return" or key == "escape" then
    return "return_to_map"
  end
end

function RewardsScene:mousepressed(x, y, button)
  if button == 1 then
    return "return_to_map"
  end
end

return RewardsScene



