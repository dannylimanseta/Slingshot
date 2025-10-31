local SpriteAnimation = {}
SpriteAnimation.__index = SpriteAnimation

-- Create a sprite sheet animation
-- imagePath: path to sprite sheet image
-- frameW, frameH: size of each frame
-- cols, rows: how many columns/rows of frames
-- fps: playback frames per second
function SpriteAnimation.new(imagePath, frameW, frameH, cols, rows, fps)
  local self = setmetatable({
    image = nil,
    quads = {},
    frameW = frameW,
    frameH = frameH,
    cols = cols,
    rows = rows,
    fps = fps or 24,
    time = 0,
    index = 1,
    playing = false,
    loop = false,
    active = false,
  }, SpriteAnimation)

  if imagePath then
    local ok, img = pcall(love.graphics.newImage, imagePath)
    if ok and img then
      self.image = img
      local sheetW, sheetH = img:getWidth(), img:getHeight()
      for r = 0, rows - 1 do
        for c = 0, cols - 1 do
          local q = love.graphics.newQuad(c * frameW, r * frameH, frameW, frameH, sheetW, sheetH)
          table.insert(self.quads, q)
        end
      end
    end
  end

  return self
end

function SpriteAnimation:play(loop)
  if not self.image or #self.quads == 0 then return end
  self.loop = not not loop
  self.playing = true
  self.active = true
  self.time = 0
  self.index = 1
end

function SpriteAnimation:update(dt)
  if not self.playing or not self.image or #self.quads == 0 then return end
  self.time = self.time + dt
  local frameTime = 1 / math.max(1, self.fps or 24)
  while self.time >= frameTime do
    self.time = self.time - frameTime
    self.index = self.index + 1
    if self.index > #self.quads then
      if self.loop then
        self.index = 1
      else
        self.index = #self.quads
        self.playing = false
        self.active = false
        break
      end
    end
  end
end

function SpriteAnimation:draw(x, y, rot, sx, sy)
  if not self.image or #self.quads == 0 then return end
  local q = self.quads[math.max(1, math.min(#self.quads, self.index))]
  rot = rot or 0
  sx = sx or 1
  sy = sy or sx
  local ox = (self.frameW or 0) * 0.5
  local oy = (self.frameH or 0) * 0.5
  love.graphics.draw(self.image, q, x, y, rot, sx, sy, ox, oy)
end

return SpriteAnimation


