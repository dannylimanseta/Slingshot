local theme = require("theme")
local config = require("config")

-- Shared sprites for blocks (loaded once)
local SPRITES = { attack = nil, armor = nil, crit = nil, soul = nil, aoe = nil }
do
  local imgs = (config.assets and config.assets.images) or {}
  if imgs.block_attack then
    local ok, img = pcall(love.graphics.newImage, imgs.block_attack)
    if ok then SPRITES.attack = img end
  end
  if imgs.block_defend then
    local ok, img = pcall(love.graphics.newImage, imgs.block_defend)
    if ok then SPRITES.armor = img end
  end
  if imgs.block_crit then
    local ok, img = pcall(love.graphics.newImage, imgs.block_crit)
    if ok then SPRITES.crit = img end
  end
  if imgs.block_crit_2 then
    local ok, img = pcall(love.graphics.newImage, imgs.block_crit_2)
    if ok then SPRITES.soul = img end
  end
  if imgs.block_aoe then
    local ok, img = pcall(love.graphics.newImage, imgs.block_aoe)
    if ok then SPRITES.aoe = img end
  end
end

local Block = {}
Block.__index = Block

function Block.new(world, cx, cy, hp, kind, opts)
  local base = config.blocks.baseSize
  local h = math.max(1, hp or 1)
  local targetSize = base
  local self = setmetatable({
    cx = cx,
    cy = cy,
    hp = h,
    kind = kind or "damage", -- "damage" or "armor"
    size = targetSize,
    targetSize = targetSize,
    alive = true,
    body = nil,
    shape = nil,
    fixture = nil,
    pendingDestroy = false,
    pendingResize = false,
    flashTime = 0,
    hitThisFrame = false, -- Flag to prevent multiple hits from multiple balls
    -- spawn animation
    spawnAnimating = opts and opts.animateSpawn == true or false,
    spawnAnimT = 0,
    spawnAnimDelay = (opts and opts.spawnDelay) or 0, -- delay before animation starts (for staggering)
    spawnAnimDuration = (config.blocks and config.blocks.spawnAnim and config.blocks.spawnAnim.duration) or 0.35,
    spawnAnimOffset = (config.blocks and config.blocks.spawnAnim and config.blocks.spawnAnim.offset) or 28,
    -- pulse animation
    pulseTime = love.math.random() * (2 * math.pi), -- random phase offset for different timings
  }, Block)

  -- Static body at origin; use shape offsets for placement
  self.body = love.physics.newBody(world, 0, 0, "static")
  self:rebuildFixture()
  if self.spawnAnimating and self.fixture then
    self.fixture:setSensor(true)
  end
  return self
end

function Block:getAABB()
  -- Physics AABB should match visual sprite size (scaled)
  local mul = (config.blocks and config.blocks.spriteScale) or 1
  local physSize = self.size * math.max(1, mul)
  local half = physSize * 0.5
  return self.cx - half, self.cy - half, physSize, physSize
end

-- Visual/placement AABB accounts for sprite scaling so blocks don't visually overlap
function Block:getPlacementAABB()
  local mul = (config.blocks and config.blocks.spriteScale) or 1
  local visSize = self.size * math.max(1, mul)
  local half = visSize * 0.5
  return self.cx - half, self.cy - half, visSize, visSize
end

function Block:hit()
  if not self.alive or self.hitThisFrame then return end
  self.hitThisFrame = true -- Mark as hit to prevent duplicate processing
  self.hp = 0
  self.flashTime = config.blocks.flashDuration
  -- Delay destruction until after flash is visible
  self.pendingDestroyDelay = config.blocks.flashDuration
end

function Block:update(dt)
  if not self.alive then return end
  -- spawn animation advance
  if self.spawnAnimating then
    -- Handle delay before animation starts
    if self.spawnAnimDelay > 0 then
      self.spawnAnimDelay = math.max(0, self.spawnAnimDelay - dt)
    else
      -- Animation is active, advance timer
      self.spawnAnimT = math.min(self.spawnAnimDuration, (self.spawnAnimT or 0) + dt)
      if self.spawnAnimT >= self.spawnAnimDuration then
        self.spawnAnimating = false
        if self.fixture then self.fixture:setSensor(false) end
      end
    end
  end
  if self.pendingDestroyDelay then
    self.pendingDestroyDelay = self.pendingDestroyDelay - dt
    if self.pendingDestroyDelay <= 0 then
      self:destroy()
      return
    end
  end
  if self.pendingResize then
    self:rebuildFixture()
    self.pendingResize = false
  end
  local k = config.blocks.tweenK
  local ds = (self.targetSize - self.size) * math.min(1, k * dt)
  self.size = self.size + ds
  if self.flashTime > 0 then
    self.flashTime = math.max(0, self.flashTime - dt)
  end
  -- Update pulse animation
  local pulseConfig = config.blocks.pulse
  if pulseConfig and (pulseConfig.enabled ~= false) then
    local speed = pulseConfig.speed or 1.2
    self.pulseTime = (self.pulseTime or 0) + dt * speed * 2 * math.pi
  end
end

function Block:draw()
  if not self.alive then return end
  local x, y, w, h = self:getAABB()
  local yOffset = 0
  local alpha = 1
  if self.spawnAnimating and self.spawnAnimDuration > 0 and self.spawnAnimDelay <= 0 then
    local t = math.min(1, (self.spawnAnimT or 0) / self.spawnAnimDuration)
    -- soft bounce (easeOutBack-ish) similar to popups
    local c1, c3 = 1.70158, 2.70158
    local u = (t - 1)
    local bounce = 1 + c3 * (u * u * u) + c1 * (u * u)
    yOffset = (1 - bounce) * self.spawnAnimOffset
    -- Fade in from 0 alpha (ease in)
    alpha = t * t -- ease in quadratic for smooth fade
  elseif self.spawnAnimating and self.spawnAnimDelay > 0 then
    -- Still waiting for delay, fully transparent
    alpha = 0
  end

  -- Calculate pulse brightness multiplier
  local brightnessMultiplier = 1
  local pulseConfig = config.blocks.pulse
  if pulseConfig and (pulseConfig.enabled ~= false) then
    local variation = pulseConfig.brightnessVariation or 0.05
    brightnessMultiplier = 1 + math.sin(self.pulseTime or 0) * variation
  end

  -- Draw sprite if available, else fallback to colored rectangle
  local sprite
  if self.kind == "armor" then
    sprite = SPRITES.armor
  elseif self.kind == "crit" then
    sprite = SPRITES.crit or SPRITES.attack
  elseif self.kind == "soul" then
    sprite = SPRITES.soul or SPRITES.attack
  elseif self.kind == "aoe" then
    sprite = SPRITES.aoe or SPRITES.attack
  else
    sprite = SPRITES.attack
  end
  if sprite then
    local iw, ih = sprite:getWidth(), sprite:getHeight()
    local s = self.size / math.max(1, math.max(iw, ih))
    local mul = (config.blocks and config.blocks.spriteScale) or 1
    s = s * mul
    local dx = self.cx - iw * s * 0.5
    local dy = (self.cy + yOffset) - ih * s * 0.5
    love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, alpha)
    love.graphics.draw(sprite, dx, dy, 0, s, s)
    -- Hit flash: additive white overlay passes similar to battle sprites
    if self.flashTime > 0 then
      local base = self.flashTime / math.max(0.0001, (config.blocks and config.blocks.flashDuration) or 0.08)
      local a = math.min(1, base * ((config.blocks and config.blocks.flashAlphaScale) or 1))
      local passes = math.max(1, (config.blocks and config.blocks.flashPasses) or 1)
      love.graphics.setBlendMode("add")
      love.graphics.setColor(1, 1, 1, a * alpha) -- Flash remains white for proper visual feedback
      for i = 1, passes do
        love.graphics.draw(sprite, dx, dy, 0, s, s)
      end
      love.graphics.setBlendMode("alpha")
      love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, alpha)
    end
  else
    if self.kind == "armor" then
      love.graphics.setColor(
        (theme.colors.blockArmor[1] or 1) * brightnessMultiplier,
        (theme.colors.blockArmor[2] or 1) * brightnessMultiplier,
        (theme.colors.blockArmor[3] or 1) * brightnessMultiplier,
        (theme.colors.blockArmor[4] or 1) * alpha
      )
    else
      love.graphics.setColor(
        (theme.colors.block[1] or 1) * brightnessMultiplier,
        (theme.colors.block[2] or 1) * brightnessMultiplier,
        (theme.colors.block[3] or 1) * brightnessMultiplier,
        (theme.colors.block[4] or 1) * alpha
      )
    end
    love.graphics.rectangle("fill", x, y + yOffset, w, h, 4, 4)
    love.graphics.setColor(
      (theme.colors.blockOutline[1] or 1) * brightnessMultiplier,
      (theme.colors.blockOutline[2] or 1) * brightnessMultiplier,
      (theme.colors.blockOutline[3] or 1) * brightnessMultiplier,
      (theme.colors.blockOutline[4] or 1) * alpha
    )
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y + yOffset, w, h, 4, 4)
    love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, alpha)
    if self.flashTime > 0 then
      local base = self.flashTime / math.max(0.0001, (config.blocks and config.blocks.flashDuration) or 0.08)
      local a = math.min(1, base * ((config.blocks and config.blocks.flashAlphaScale) or 1))
      local passes = math.max(1, (config.blocks and config.blocks.flashPasses) or 1)
      love.graphics.setBlendMode("add")
      love.graphics.setColor(1, 1, 1, a * alpha) -- Flash remains white for proper visual feedback
      for i = 1, passes do
        love.graphics.rectangle("fill", x, y + yOffset, w, h, 4, 4)
      end
      love.graphics.setBlendMode("alpha")
      love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, alpha)
    end
  end
  -- Reset color for other draw calls
  love.graphics.setColor(1, 1, 1, 1)
end

function Block:rebuildFixture()
  if self.fixture then pcall(function() self.fixture:destroy() end) end
  local mul = (config.blocks and config.blocks.spriteScale) or 1
  local w = self.targetSize * math.max(1, mul)
  local h = self.targetSize * math.max(1, mul)
  self.shape = love.physics.newRectangleShape(self.cx, self.cy, w, h)
  self.fixture = love.physics.newFixture(self.body, self.shape, 0)
  self.fixture:setFriction(0)
  self.fixture:setRestitution(1)
  self.fixture:setUserData({ type = "block", ref = self })
end

function Block:destroy()
  if not self.alive then return end
  self.alive = false
  if self.fixture then pcall(function() self.fixture:destroy() end) end
  if self.body then pcall(function() self.body:destroy() end) end
  if self.onDestroyed then self.onDestroyed(self) end
end

return Block


