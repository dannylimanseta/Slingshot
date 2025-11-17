local theme = require("theme")
local config = require("config")
local ShaderCache = require("utils.ShaderCache")
local IridescentShader = require("utils.IridescentShader")
local MultiplierFlameShader = require("utils.MultiplierFlameShader")
local SheenShader = require("utils.SheenShader")
local RelicSystem = require("core.RelicSystem")

-- Shared sprites for blocks (loaded once)
local SPRITES = { attack = nil, armor = nil, crit = nil, multiplier = nil, aoe = nil, potion = nil, spore = nil }
local ICON_ATTACK = nil
local ICON_ARMOR = nil
local ICON_HEAL = nil
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
    if ok then SPRITES.multiplier = img end
  end
  if imgs.block_aoe then
    local ok, img = pcall(love.graphics.newImage, imgs.block_aoe)
    if ok then SPRITES.aoe = img end
  end
  if imgs.block_heal then
    local ok, img = pcall(love.graphics.newImage, imgs.block_heal)
    if ok then SPRITES.potion = img end
  end
  if imgs.block_spore then
    local ok, img = pcall(love.graphics.newImage, imgs.block_spore)
    if ok then SPRITES.spore = img end
  end
  -- Load attack icon
  if imgs.icon_attack then
    local ok, img = pcall(love.graphics.newImage, imgs.icon_attack)
    if ok then
      -- Ensure anti-aliased sampling when scaling
      pcall(function() img:setFilter('linear', 'linear') end)
      ICON_ATTACK = img
    end
  end
  -- Load armor icon
  if imgs.icon_armor then
    local ok, img = pcall(love.graphics.newImage, imgs.icon_armor)
    if ok then
      -- Ensure anti-aliased sampling when scaling
      pcall(function() img:setFilter('linear', 'linear') end)
      ICON_ARMOR = img
    end
  end
  -- Load heal icon
  if imgs.icon_heal then
    local ok, img = pcall(love.graphics.newImage, imgs.icon_heal)
    if ok then
      -- Ensure anti-aliased sampling when scaling
      pcall(function() img:setFilter('linear', 'linear') end)
      ICON_HEAL = img
    end
  end
end

local SHADOW_REMOVAL_SOURCE = [[
  vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 texcolor = Texel(texture, texture_coords);
    float gray = dot(texcolor.rgb, vec3(0.299, 0.587, 0.114));
    float threshold = 0.3;
    float width = 0.15;
    float mask = smoothstep(threshold - width, threshold + width, gray);
    return vec4(0.0, 0.0, 0.0, mask * texcolor.a * color.a);
  }
]]

local DESATURATE_SOURCE = [[
  vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 texcolor = Texel(texture, texture_coords) * color;
    float gray = dot(texcolor.rgb, vec3(0.299, 0.587, 0.114));
    return vec4(gray, gray, gray, texcolor.a);
  }
]]

local shadowRemovalWarningPrinted = false
local desaturateWarningPrinted = false

local function getShadowRemovalShader()
  local shader, err = ShaderCache.get("block_shadow_removal", SHADOW_REMOVAL_SOURCE)
  if not shader and err and not shadowRemovalWarningPrinted then
    print("[Block] Failed to compile shadow removal shader:", err)
    shadowRemovalWarningPrinted = true
  end
  return shader
end

local function getDesaturateShader()
  local shader, err = ShaderCache.get("block_desaturate", DESATURATE_SOURCE)
  if not shader and err and not desaturateWarningPrinted then
    print("[Block] Failed to compile desaturate shader:", err)
    desaturateWarningPrinted = true
  end
  return shader
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
    -- bobbing animation (for spore blocks)
    bobTime = love.math.random() * (2 * math.pi), -- random phase offset for different timings
    bobScale = 1.0, -- size multiplier for bobbing (1.0 +/- 0.05)
    -- shader timing offsets so effects aren't synchronized across blocks
    shaderTimeOffset = love.math.random() * 10.0,
    flameTimeOffset = love.math.random() * 10.0,
    -- calcify state (indestructible for 1 turn)
    calcified = false,
    calcifiedTurnsRemaining = 0,
    -- bounce animation (for particle hit effect)
    bounceTime = 0,
    bounceDuration = 0.3,
    bounceScale = 1.0,
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
  -- Calcified blocks cannot be destroyed
  if self.calcified then return end
  self.hitThisFrame = true -- Mark as hit to prevent duplicate processing
  self.hp = 0
  self.flashTime = config.blocks.flashDuration
  -- Delay destruction until after flash is visible
  self.pendingDestroyDelay = config.blocks.flashDuration
end

-- Trigger bounce animation (for particle hit effect)
function Block:triggerBounce()
  if not self.alive then return end
  self.bounceTime = self.bounceDuration
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
  
  -- Update shake and drop animation (for shockwave effect)
  if self.shakeTime and self.shakeTime > 0 then
    self.shakeTime = math.max(0, self.shakeTime - dt)
    -- Shake offset: random jitter that decreases over time
    local shakeDuration = 0.6 -- Longer duration for visible shake and drop
    local progress = self.shakeTime / shakeDuration
    local shakeMagnitude = 6 * progress -- Stronger shake that decreases over time
    self.shakeOffsetX = (love.math.random() * 2 - 1) * shakeMagnitude
    self.shakeOffsetY = (love.math.random() * 2 - 1) * shakeMagnitude * 0.5 -- Less vertical shake, more horizontal
    
    -- Update rotation (blocks rotate as they drop)
    if self.dropRotationSpeed then
      self.dropRotation = (self.dropRotation or 0) + self.dropRotationSpeed * dt
    end
    
    -- Update drop velocity (blocks fall down)
    if self.dropVelocity ~= nil then
      -- Gravity acceleration - blocks fall downwards
      self.dropVelocity = (self.dropVelocity or 0) + 800 * dt -- Stronger gravity
      self.dropOffsetY = (self.dropOffsetY or 0) + self.dropVelocity * dt
    end
    
    -- Update fade alpha (fade out over time as blocks drop)
    if self.fadeAlpha then
      -- Fade out more gradually, starting after initial shake
      local fadeStart = 0.3 -- Start fading after 30% of duration
      if progress < fadeStart then
        self.fadeAlpha = 1 -- Fully visible during initial shake
      else
        -- Fade from 1 to 0 over remaining time
        local fadeProgress = (progress - fadeStart) / (1 - fadeStart)
        self.fadeAlpha = math.max(0, 1 - fadeProgress)
      end
    end
    
    -- Destroy block when it's fully faded or dropped off screen
    if self.shakeTime <= 0 or (self.fadeAlpha and self.fadeAlpha <= 0) then
      self:destroy()
      return
    end
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
  
  -- Update bobbing animation for spore blocks
  if self.kind == "spore" then
    local bobSpeed = 1.5 -- Oscillations per second
    self.bobTime = (self.bobTime or 0) + dt * bobSpeed * 2 * math.pi
    -- Bob scale: oscillate between 0.95 and 1.05 (5% variation)
    self.bobScale = 1.0 + math.sin(self.bobTime) * 0.05
  else
    self.bobScale = 1.0
  end
  
  -- Update bounce animation
  if self.bounceTime > 0 then
    self.bounceTime = math.max(0, self.bounceTime - dt)
    local t = 1 - (self.bounceTime / self.bounceDuration)
    -- Ease out bounce effect (scale up then back down)
    local bounceScale = 1.0
    if t < 0.5 then
      -- Scale up in first half
      local t2 = t * 2
      bounceScale = 1.0 + (0.15 * (1 - t2 * t2)) -- Scale up to 1.15, then ease out
    else
      -- Scale back down in second half
      local t2 = (t - 0.5) * 2
      bounceScale = 1.15 - (0.15 * t2 * t2) -- Scale down from 1.15 to 1.0
    end
    self.bounceScale = bounceScale
  else
    self.bounceScale = 1.0
  end
end

function Block:draw()
  if not self.alive then return end
  local x, y, w, h = self:getAABB()
  local yOffset = 0
  local xOffset = 0
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
  
  -- Apply shake and drop offsets (for shockwave effect)
  if self.shakeOffsetX then
    xOffset = self.shakeOffsetX
  end
  if self.dropOffsetY then
    yOffset = yOffset + self.dropOffsetY
  end
  if self.shakeOffsetY then
    yOffset = yOffset + self.shakeOffsetY
  end
  
  -- Apply fade alpha (for shockwave effect)
  if self.fadeAlpha then
    alpha = alpha * self.fadeAlpha
  end

  -- Calculate pulse brightness multiplier
  local brightnessMultiplier = 1
  local pulseConfig = config.blocks.pulse
  if pulseConfig and (pulseConfig.enabled ~= false) then
    local variation = pulseConfig.brightnessVariation or 0.05
    brightnessMultiplier = 1 + math.sin(self.pulseTime or 0) * variation
  end

  local spriteDrawWidth, spriteDrawHeight = nil, nil
  -- Draw sprite if available, else fallback to colored rectangle
  local sprite
  if self.kind == "armor" then
    sprite = SPRITES.armor
  elseif self.kind == "crit" then
    sprite = SPRITES.crit or SPRITES.attack
  elseif self.kind == "multiplier" then
    sprite = SPRITES.multiplier or SPRITES.attack
  elseif self.kind == "aoe" then
    sprite = SPRITES.aoe or SPRITES.attack
  elseif self.kind == "potion" then
    sprite = SPRITES.potion or SPRITES.attack
  elseif self.kind == "spore" then
    sprite = SPRITES.spore or SPRITES.attack
  else
    sprite = SPRITES.attack
  end
  if sprite then
    local iw, ih = sprite:getWidth(), sprite:getHeight()
    local s = self.size / math.max(1, math.max(iw, ih))
    local mul = (config.blocks and config.blocks.spriteScale) or 1
    s = s * mul * (self.bounceScale or 1.0) * (self.bobScale or 1.0) -- Apply bounce scale and bob scale
    local rotation = self.dropRotation or self._bhTwistAngle or 0
    local centerX = self.cx + xOffset
    local centerY = self.cy + yOffset
    local drawWidth = iw * s
    local drawHeight = ih * s
    spriteDrawWidth = drawWidth
    spriteDrawHeight = drawHeight
    local dx = centerX - drawWidth * 0.5
    local dy = centerY - drawHeight * 0.5
    
    -- Calcify visual effect: desaturated white tint with blend mode
    local prevBlendMode = love.graphics.getBlendMode()
    
    if self.calcified then
      local desaturateShader = getDesaturateShader()
      -- For calcified blocks: draw full grayscale desaturation, then white tint
      -- Skip normal colored draw - go straight to desaturated version
      local prevCalcifyShader = love.graphics.getShader()
      if desaturateShader then
        love.graphics.setShader(desaturateShader)
      end
      love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, alpha)
      if rotation ~= 0 then
        love.graphics.push()
        love.graphics.translate(centerX, centerY)
        love.graphics.rotate(rotation)
        love.graphics.translate(-centerX, -centerY)
        love.graphics.draw(sprite, dx, dy, 0, s, s)
        love.graphics.pop()
      else
        love.graphics.draw(sprite, dx, dy, 0, s, s)
      end
      -- Keep shader active for white tint overlay to ensure it's also grayscale
      -- Then: add white tint overlay (still using desaturate shader to prevent color bleed)
      love.graphics.setBlendMode("add")
      love.graphics.setColor(0.8, 0.8, 0.8, alpha * 1.0) -- Strong white tint overlay
      if rotation ~= 0 then
        love.graphics.push()
        love.graphics.translate(centerX, centerY)
        love.graphics.rotate(rotation)
        love.graphics.translate(-centerX, -centerY)
        love.graphics.draw(sprite, dx, dy, 0, s, s)
        love.graphics.pop()
      else
        love.graphics.draw(sprite, dx, dy, 0, s, s)
      end
      -- Second white tint pass for even more whiteness
      love.graphics.setColor(0.6, 0.6, 0.6, alpha * 0.7) -- Additional white tint overlay
      if rotation ~= 0 then
        love.graphics.push()
        love.graphics.translate(centerX, centerY)
        love.graphics.rotate(rotation)
        love.graphics.translate(-centerX, -centerY)
        love.graphics.draw(sprite, dx, dy, 0, s, s)
        love.graphics.pop()
      else
        love.graphics.draw(sprite, dx, dy, 0, s, s)
      end
      love.graphics.setShader(prevCalcifyShader)
      love.graphics.setBlendMode(prevBlendMode)
    else
      -- Normal blocks: draw with color and optional shaders
    love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, alpha)
    -- Apply iridescent shader for 2x (crit) and 4x (multiplier) blocks
    local isIridescent = (self.kind == "crit" or self.kind == "multiplier")
    -- Apply sheen shader for AOE/cleave blocks
    local isAOE = (self.kind == "aoe")
    local prevShader = nil
    if isIridescent then
      local S = IridescentShader and IridescentShader.getShader and IridescentShader.getShader()
      if S then
        prevShader = love.graphics.getShader()
        S:send("u_time", love.timer.getTime())
        S:send("u_timeOffset", self.shaderTimeOffset or 0.0)
        -- Even fainter mix so base color shows more
        local intensity = (self.kind == "multiplier") and 0.50 or 0.42
        S:send("u_intensity", intensity)
        -- Much fewer, softer bands
        S:send("u_scale", 2.0)
        S:send("u_angle", 0.6)
        -- Increase perpendicular wobble substantially
        local variation = (self.kind == "multiplier") and 0.85 or 0.7
        S:send("u_variation", variation)
        -- Organic warping noise and shininess
        -- Stronger, higher-frequency organic noise
        S:send("u_noiseScale", 5.5)
        S:send("u_noiseAmp", 1.2)
        -- Reduce shine further
        local shine = (self.kind == "multiplier") and 0.22 or 0.14
        S:send("u_shineStrength", shine)
        -- Favor patchy look over stripes
        local patchiness = (self.kind == "multiplier") and 0.8 or 0.75
        S:send("u_patchiness", patchiness)
        love.graphics.setShader(S)
      end
    elseif isAOE then
      -- Apply sheen shader for AOE blocks
      local S = SheenShader and SheenShader.getShader and SheenShader.getShader()
      if S then
        prevShader = love.graphics.getShader()
        S:send("u_time", love.timer.getTime())
        S:send("u_timeOffset", self.shaderTimeOffset or 0.0)
        S:send("u_speed", 0.1) -- Sweep speed (reduced from 0.8 for slower frequency)
        S:send("u_width", 0.6) -- Width of sheen highlight (increased by 60% from 0.25 to 0.4)
        S:send("u_intensity", 0.2) -- Brightness of sheen (reduced from 0.5 for lower opacity)
        S:send("u_angle", 0.785) -- ~45 degree angle for diagonal sweep
        love.graphics.setShader(S)
      end
    end
    if rotation ~= 0 then
      love.graphics.push()
      love.graphics.translate(centerX, centerY)
      love.graphics.rotate(rotation)
      love.graphics.translate(-centerX, -centerY)
      love.graphics.draw(sprite, dx, dy, 0, s, s)
      love.graphics.pop()
    else
      love.graphics.draw(sprite, dx, dy, 0, s, s)
    end
    if isIridescent or isAOE then
      love.graphics.setShader(prevShader)
      end
    end
    -- Hit flash: additive white overlay passes similar to battle sprites
    if self.flashTime > 0 then
      local base = self.flashTime / math.max(0.0001, (config.blocks and config.blocks.flashDuration) or 0.08)
      local a = math.min(1, base * ((config.blocks and config.blocks.flashAlphaScale) or 1))
      local passes = math.max(1, (config.blocks and config.blocks.flashPasses) or 1)
      love.graphics.setBlendMode("add")
      love.graphics.setColor(1, 1, 1, a * alpha) -- Flash remains white for proper visual feedback
      for i = 1, passes do
        if rotation ~= 0 then
          love.graphics.push()
          love.graphics.translate(centerX, centerY)
          love.graphics.rotate(rotation)
          love.graphics.translate(-centerX, -centerY)
          love.graphics.draw(sprite, dx, dy, 0, s, s)
          love.graphics.pop()
        else
          love.graphics.draw(sprite, dx, dy, 0, s, s)
        end
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
    local rotation = self.dropRotation or 0
    local centerX = self.cx + xOffset
    local centerY = self.cy + yOffset
    -- Apply bob scale for spore blocks (visual effect only)
    local bobScale = (self.kind == "spore" and self.bobScale) or 1.0
    local scaledW = w * bobScale
    local scaledH = h * bobScale
    spriteDrawWidth = scaledW
    spriteDrawHeight = scaledH
    local scaledX = centerX - scaledW * 0.5
    local scaledY = centerY - scaledH * 0.5
    if rotation ~= 0 then
      love.graphics.push()
      love.graphics.translate(centerX, centerY)
      love.graphics.rotate(rotation)
      love.graphics.translate(-centerX, -centerY)
      love.graphics.rectangle("fill", scaledX, scaledY, scaledW, scaledH, 4, 4)
      love.graphics.setColor(
        (theme.colors.blockOutline[1] or 1) * brightnessMultiplier,
        (theme.colors.blockOutline[2] or 1) * brightnessMultiplier,
        (theme.colors.blockOutline[3] or 1) * brightnessMultiplier,
        (theme.colors.blockOutline[4] or 1) * alpha
      )
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", scaledX, scaledY, scaledW, scaledH, 4, 4)
      love.graphics.pop()
    else
      love.graphics.rectangle("fill", scaledX, scaledY, scaledW, scaledH, 4, 4)
      love.graphics.setColor(
        (theme.colors.blockOutline[1] or 1) * brightnessMultiplier,
        (theme.colors.blockOutline[2] or 1) * brightnessMultiplier,
        (theme.colors.blockOutline[3] or 1) * brightnessMultiplier,
        (theme.colors.blockOutline[4] or 1) * alpha
      )
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", scaledX, scaledY, scaledW, scaledH, 4, 4)
    end
    love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, alpha)
    if self.flashTime > 0 then
      local base = self.flashTime / math.max(0.0001, (config.blocks and config.blocks.flashDuration) or 0.08)
      local a = math.min(1, base * ((config.blocks and config.blocks.flashAlphaScale) or 1))
      local passes = math.max(1, (config.blocks and config.blocks.flashPasses) or 1)
      love.graphics.setBlendMode("add")
      love.graphics.setColor(1, 1, 1, a * alpha) -- Flash remains white for proper visual feedback
      for i = 1, passes do
        if rotation ~= 0 then
          love.graphics.push()
          love.graphics.translate(centerX, centerY)
          love.graphics.rotate(rotation)
          love.graphics.translate(-centerX, -centerY)
          love.graphics.rectangle("fill", scaledX, scaledY, scaledW, scaledH, 4, 4)
          love.graphics.pop()
        else
          love.graphics.rectangle("fill", scaledX, scaledY, scaledW, scaledH, 4, 4)
        end
      end
      love.graphics.setBlendMode("alpha")
      love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, alpha)
    end
  end
  
  local flameConfig = (config.blocks and config.blocks.multiplierFlame) or {}
  if self.kind == "multiplier" and flameConfig.enabled ~= false then
    local flameShader = MultiplierFlameShader and MultiplierFlameShader.getShader and MultiplierFlameShader.getShader()
    if flameShader then
      local visualWidth = spriteDrawWidth or w
      local visualHeight = spriteDrawHeight or h
      if visualWidth and visualHeight and visualWidth > 0 and visualHeight > 0 then
        local width = math.max(1, visualWidth * (flameConfig.widthScale or 1.0))
        local height = math.max(1, visualHeight * (flameConfig.heightScale or 1.0))
        local lift = flameConfig.lift or 0
        local offsetX = flameConfig.offsetX or 0
        local centerX = self.cx + xOffset
        local topEdge = (self.cy + yOffset) - visualHeight * 0.5
        local rectX = centerX - width * 0.5 + offsetX
        local rectY = topEdge - height - lift
        local shaderOriginX, shaderOriginY = rectX, rectY
        local shaderWidth, shaderHeight = width, height
        if love.graphics.transformPoint then
          local sx1, sy1 = love.graphics.transformPoint(rectX, rectY)
          local sx2, sy2 = love.graphics.transformPoint(rectX + width, rectY + height)
          shaderOriginX = math.min(sx1, sx2)
          shaderOriginY = math.min(sy1, sy2)
          shaderWidth = math.max(1e-3, math.abs(sx2 - sx1))
          shaderHeight = math.max(1e-3, math.abs(sy2 - sy1))
        end
        flameShader:send("u_time", love.timer.getTime())
        flameShader:send("u_timeOffset", self.flameTimeOffset or 0)
        flameShader:send("u_rectOrigin", { shaderOriginX, shaderOriginY })
        flameShader:send("u_rectSize", { shaderWidth, shaderHeight })
        flameShader:send("u_intensity", flameConfig.intensity or 1.0)
        love.graphics.push("all")
        love.graphics.setShader(flameShader)
        love.graphics.setBlendMode(flameConfig.blendMode or "add")
        love.graphics.setColor(1, 1, 1, alpha * (flameConfig.alpha or 1.0))
        love.graphics.rectangle("fill", rectX, rectY, width, height)
        love.graphics.pop()
      end
    end
  end
  
  -- Draw value text label on blocks (attack or armor)
  local valueText = nil
  local cornerLabel = nil
  local iconToUse = nil
  if self.kind == "damage" or self.kind == "attack" then
    valueText = "+1"
    iconToUse = ICON_ATTACK
  elseif self.kind == "crit" then
    valueText = "x2"
    cornerLabel = "x2"
    iconToUse = ICON_ATTACK
  elseif self.kind == "multiplier" then
    local dmgMult = (config.score and config.score.powerCritMultiplier) or 4
    valueText = "x" .. tostring(dmgMult)
    cornerLabel = valueText
    iconToUse = ICON_ATTACK
  elseif self.kind == "armor" then
    -- Armor value from config by HP (fallback to +3)
    local rewardByHp = (config.armor and config.armor.rewardByHp) or {}
    local hp = self.hp or 1
    local baseArmor = rewardByHp[hp] or rewardByHp[1] or 3
    local armorGain = RelicSystem.applyArmorReward(baseArmor, {
      hp = hp,
      block = self,
      context = "label",
    })
    armorGain = math.floor(armorGain + 0.5)
    valueText = "+" .. tostring(armorGain)
    iconToUse = ICON_ARMOR
  elseif self.kind == "potion" then
    -- Heal value from config (fallback to +8)
    local healAmount = (config.heal and config.heal.potionHeal) or 8
    valueText = "+" .. tostring(healAmount)
    iconToUse = ICON_HEAL
  end
  
  if iconToUse then
    -- Use theme font height to size the icon consistently with previous layout
    local baseFont = theme.fonts.base or love.graphics.getFont()
    love.graphics.setFont(baseFont)
    local baseTextHeight = baseFont:getHeight()
    local textScale = 0.7
    local textHeight = baseTextHeight * textScale
    local iconSize = textHeight * 0.9 * 0.85 * 0.85 * 1.3
    local iconW, iconH = iconToUse:getDimensions()
    local iconScale = iconSize / math.max(iconW, iconH)
    -- Center icon horizontally; keep slight vertical lift (armor a touch higher)
    local iconYOffset = (self.kind == "armor") and -7 or -6
    local iconXOffset = (self.kind == "armor") and 2 or ((self.kind == "potion") and 2 or 0)
    local iconX = math.floor(self.cx - iconSize * 0.5 + iconXOffset + 0.5)
    local iconY = math.floor(self.cy + yOffset - iconSize * 0.5 + iconYOffset + 0.5)
    love.graphics.push("all")
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, alpha * 0.5)
    local shadowRemovalShader = getShadowRemovalShader()
    if shadowRemovalShader then
      love.graphics.setShader(shadowRemovalShader)
    else
      love.graphics.setColor(0, 0, 0, alpha * 0.5)
    end
    love.graphics.draw(iconToUse, iconX, iconY, 0, iconScale, iconScale, 0, 0)
    love.graphics.setShader()
    love.graphics.pop()
  end
  
  -- Draw small top-right corner label for crit/multiplier (e.g., x2, x4)
  if cornerLabel then
    local labelRoot = (config.blocks and config.blocks.cornerLabel) or {}
    local labelCfg = labelRoot[self.kind] or labelRoot
    local font = (theme.fonts and (theme.fonts.small or theme.fonts.base)) or love.graphics.getFont()
    love.graphics.setFont(font)
    local textW = font:getWidth(cornerLabel)
    local textH = font:getHeight()
    local scale = labelCfg.scale or 1.1
    local centerX = self.cx + xOffset
    local centerY = self.cy + yOffset
    local offsetX = labelCfg.offsetX or 0
    local offsetY = labelCfg.offsetY or 0
    local drawX = math.floor(centerX + offsetX + 0.5)
    local drawY = math.floor(centerY + offsetY + 0.5)
    local outlineWidth = math.max(0, labelCfg.outlineWidth or 2)
    local outlineColor = labelCfg.outlineColor or labelRoot.outlineColor or { 1.0, 0.9, 0.2, 1.0 }
    local textColorDark = labelCfg.textColorDark or labelRoot.textColorDark or { 0.35, 0.0, 0.0, 1.0 }
    local textColorBright = labelCfg.textColorBright or labelRoot.textColorBright or { 0.9, 0.1, 0.1, 1.0 }
    local tweenSpeed = labelCfg.tweenSpeed or labelRoot.tweenSpeed or 2.5
    local t = (love.timer.getTime and love.timer.getTime() or os.clock()) * tweenSpeed
    local mix = 0.5 + 0.5 * math.sin(t)
    local textColor = {
      textColorDark[1] + (textColorBright[1] - textColorDark[1]) * mix,
      textColorDark[2] + (textColorBright[2] - textColorDark[2]) * mix,
      textColorDark[3] + (textColorBright[3] - textColorDark[3]) * mix,
      textColorDark[4] + (textColorBright[4] - textColorDark[4]) * mix,
    }

    local offsets = {
      { -outlineWidth, 0 },
      { outlineWidth, 0 },
      { 0, -outlineWidth },
      { 0, outlineWidth },
      { -outlineWidth, -outlineWidth },
      { outlineWidth, -outlineWidth },
      { -outlineWidth, outlineWidth },
      { outlineWidth, outlineWidth },
    }

    love.graphics.setColor(
      outlineColor[1] or 1,
      outlineColor[2] or 0.9,
      outlineColor[3] or 0.2,
      (outlineColor[4] or 1) * alpha
    )
    for _, offset in ipairs(offsets) do
      love.graphics.print(
        cornerLabel,
        drawX + offset[0 + 1],
        drawY + offset[1 + 1],
        0,
        scale,
        scale,
        textW * 0.5,
        textH * 0.5
      )
    end

    love.graphics.setColor(textColor[1] or 0, textColor[2] or 0, textColor[3] or 0, (textColor[4] or 1) * alpha)
    love.graphics.print(
      cornerLabel,
      drawX,
      drawY,
      0,
      scale,
      scale,
      textW * 0.5,
      textH * 0.5
    )
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

-- Calcify this block (make it indestructible for specified number of turns, or permanently if turns is nil)
function Block:calcify(turns)
  if not self.alive then return end
  self.calcified = true
  -- If turns is nil, set to a very large number to make it permanent for the battle
  self.calcifiedTurnsRemaining = turns or math.huge
end

-- Remove calcify effect (called at end of turn)
function Block:uncalcify()
  self.calcified = false
  self.calcifiedTurnsRemaining = 0
end

-- Decrement calcify turns (called at end of enemy turn)
function Block:decrementCalcifyTurns()
  -- Only decrement if turns remaining is not infinite (math.huge)
  if self.calcified and self.calcifiedTurnsRemaining and self.calcifiedTurnsRemaining ~= math.huge and self.calcifiedTurnsRemaining > 0 then
    self.calcifiedTurnsRemaining = self.calcifiedTurnsRemaining - 1
    if self.calcifiedTurnsRemaining <= 0 then
      self:uncalcify()
    end
  end
end

function Block:destroy()
  if not self.alive then return end
  self.alive = false
  if self.fixture then pcall(function() self.fixture:destroy() end) end
  if self.body then pcall(function() self.body:destroy() end) end
  if self.onDestroyed then self.onDestroyed(self) end
end

return Block


