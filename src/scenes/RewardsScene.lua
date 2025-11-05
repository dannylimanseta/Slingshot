local config = require("config")
local theme = require("theme")
local RewardsBackdropShader = require("utils.RewardsBackdropShader")

local RewardsScene = {}
RewardsScene.__index = RewardsScene

function RewardsScene.new(opts)
  opts = opts or {}
  return setmetatable({
    time = 0,
    shader = RewardsBackdropShader.getShader(),
    victory = opts.victory and true or false,
    _mouseDown = false,
  }, RewardsScene)
end

function RewardsScene:load()
  -- No-op for now
end

function RewardsScene:update(dt)
  self.time = self.time + dt
  if self.shader then
    local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
    local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
    self.shader:send("u_time", self.time)
    self.shader:send("u_resolution", { vw, vh })
    -- Strong desaturation by default; adjust if needed
    self.shader:send("u_desaturate", 0.9)
    -- Subtle animated noise
    self.shader:send("u_noiseAmount", 0.1)   -- strength
    self.shader:send("u_noiseScale", 220.0)  -- frequency
    self.shader:send("u_noiseSpeed", 0.35)   -- animation speed
  end
  return nil
end

function RewardsScene:draw()
  local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
  local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()

  -- Shader backdrop
  if self.shader then
    love.graphics.push("all")
    love.graphics.setShader(self.shader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, vw, vh)
    love.graphics.setShader()
    love.graphics.pop()
  else
    love.graphics.clear(0.05, 0.06, 0.10, 1)
  end

  -- Title
  love.graphics.push()
  love.graphics.setFont(theme.fonts.jackpot or theme.fonts.large or love.graphics.getFont())
  love.graphics.setColor(1, 1, 1, 1)
  local title = self.victory and "REWARDS" or "RESULTS"
  local font = love.graphics.getFont()
  local textW = font:getWidth(title)
  love.graphics.print(title, (vw - textW) * 0.5, vh * 0.2)
  love.graphics.pop()

  -- Prompt
  love.graphics.push()
  love.graphics.setFont(theme.fonts.base or love.graphics.getFont())
  love.graphics.setColor(1, 1, 1, 0.8)
  local prompt = "Press SPACE or click to continue"
  local font2 = love.graphics.getFont()
  local promptW = font2:getWidth(prompt)
  love.graphics.print(prompt, (vw - promptW) * 0.5, vh * 0.8)
  love.graphics.pop()
end

function RewardsScene:keypressed(key)
  if key == "space" or key == "return" or key == "enter" then
    if self.victory then
      return { type = "return_to_map", victory = true }
    else
      return "return_to_map"
    end
  end
end

function RewardsScene:mousepressed(x, y, button)
  if button == 1 then
    self._mouseDown = true
  end
end

function RewardsScene:mousereleased(x, y, button)
  if button == 1 and self._mouseDown then
    self._mouseDown = false
    if self.victory then
      return { type = "return_to_map", victory = true }
    else
      return "return_to_map"
    end
  end
end

return RewardsScene


