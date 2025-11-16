-- VisualEffects: Handles visual effects like screenshake, tooltips, popups, aim guide
-- Extracted from GameplayScene to improve maintainability

local config = require("config")
local theme = require("theme")
local math2d = require("utils.math2d")

local VisualEffects = {}
VisualEffects.__index = VisualEffects

function VisualEffects.new()
  return setmetatable({
    -- Screenshake
    shakeMagnitude = 0,
    shakeDuration = 0,
    shakeTime = 0,
    
    -- Popups
    popups = {},
    
    -- Damage numbers (per block)
    damageNumbers = {}, -- { [block] = { damage = 0, x = 0, y = 0, t = 0, ... } }
    
    -- Tooltips
    hoveredBlock = nil,
    hoverTime = 0,
    lastHoveredBlock = nil,
    cursorX = 0,
    cursorY = 0,
    
    -- Aim guide
    guideAlpha = 1,
    aimStartX = 0,
    aimStartY = 0,
    
    -- Icons
    iconAttack = nil,
    iconArmor = nil,
  }, VisualEffects)
end

function VisualEffects:loadAssets()
  -- Load popup icons
  local imgs = (config.assets and config.assets.images) or {}
  
  if imgs.icon_attack then
    local ok, img = pcall(love.graphics.newImage, imgs.icon_attack)
    if ok then self.iconAttack = img end
  end
  
  if imgs.icon_armor then
    local ok, img = pcall(love.graphics.newImage, imgs.icon_armor)
    if ok then self.iconArmor = img end
  end
end

-- ============================================================================
-- SCREENSHAKE
-- ============================================================================

function VisualEffects:triggerShake(magnitude, duration)
  self.shakeMagnitude = magnitude or 2
  self.shakeDuration = duration or 0.15
  self.shakeTime = self.shakeDuration
end

function VisualEffects:updateScreenshake(dt)
  if self.shakeTime > 0 then
    self.shakeTime = self.shakeTime - dt
    if self.shakeTime <= 0 then
      self.shakeTime = 0
      self.shakeMagnitude = 0
    end
  end
end

function VisualEffects:applyScreenshake()
  if self.shakeTime > 0 and self.shakeDuration > 0 then
    local t = self.shakeTime / self.shakeDuration
    local ease = t * t
    local mag = self.shakeMagnitude * ease
    local ox = (love.math.random() * 2 - 1) * mag
    local oy = (love.math.random() * 2 - 1) * mag
    love.graphics.translate(ox, oy)
  end
end

-- ============================================================================
-- DAMAGE NUMBERS
-- ============================================================================

function VisualEffects:addDamageNumber(block, totalDamage)
  if not block or not block.alive then return end
  
  -- Get block position
  local x, y, w, h = block:getAABB()
  local blockX = x + w * 0.5
  local blockY = y
  
  -- Check if we already have a damage number for this block
  local existing = self.damageNumbers[block]
  if existing then
    -- Update existing damage number with latest total (don't accumulate, replace)
      existing.damage = totalDamage
      existing.t = (config.score and config.score.damageNumberLifetime) or 2.5 -- Reset timer
      existing.startY = blockY -- Update position
      existing.x = blockX
      existing.y = blockY
      existing.bounceScale = 1.0 -- Reset bounce
      existing.bounceVelocity = -300 -- Reset bounce velocity (faster)
      existing.hasLanded = false -- Reset landing state
  else
    -- Create new damage number
    self.damageNumbers[block] = {
      damage = totalDamage,
      x = blockX,
      y = blockY,
      startY = blockY,
      t = (config.score and config.score.damageNumberLifetime) or 2.5,
      bounceScale = 1.0,
      bounceVelocity = -300, -- Faster initial upward velocity
      gravity = 1000, -- Increased gravity for faster fall
      hasLanded = false, -- Track if number has hit the ground
    }
  end
end

function VisualEffects:updateDamageNumbers(dt)
  local toRemove = {}
  for block, num in pairs(self.damageNumbers) do
    -- Continue updating even if block is destroyed - let fade complete naturally
    if not block then
      table.insert(toRemove, block)
    else
      num.t = num.t - dt
      
      -- Update fall physics (no bounce - just fall and stop)
      if num.bounceVelocity < 0 then
        num.bounceVelocity = num.bounceVelocity + num.gravity * dt
        num.y = num.y + num.bounceVelocity * dt
        
        -- Stop when hitting ground (no bounce)
        if num.y >= num.startY then
          num.y = num.startY
          num.bounceVelocity = 0
          num.hasLanded = true
        end
      end
      
      -- Remove immediately when landing - no fade animation
      if num.hasLanded and not num._removing then
        num._removing = true
        table.insert(toRemove, block)
      end
      
      -- Update bounce scale (for pop effect)
      if num.t > 0 then
        local lifetime = (config.score and config.score.damageNumberLifetime) or 2.5
        local prog = 1 - (num.t / lifetime)
        -- Scale up then down for pop effect
        if prog < 0.2 then
          num.bounceScale = 1.0 + (prog / 0.2) * 0.3 -- Scale up to 1.3
        else
          num.bounceScale = 1.3 - ((prog - 0.2) / 0.8) * 0.3 -- Scale down to 1.0
        end
      end
      
      -- Remove if expired (only remove when timer runs out, not when block is destroyed)
      if num.t <= 0 then
        table.insert(toRemove, block)
      end
    end
  end
  
  -- Clean up removed blocks
  for _, block in ipairs(toRemove) do
    self.damageNumbers[block] = nil
  end
end

function VisualEffects:drawDamageNumbers()
  if not self.damageNumbers then return end
  
  local font = theme.fonts.popup or theme.fonts.base
  love.graphics.setFont(font)
  
  for block, num in pairs(self.damageNumbers) do
    -- Draw even if block is destroyed - let fade complete visually
    if block and num.t > 0 then
      local text = tostring(num.damage)
      local textW = font:getWidth(text)
      local textH = font:getHeight()
      
      -- Calculate fade - fade only while falling (numbers removed immediately on landing)
      -- Reduce fade duration by 60% (fade 2.5x faster)
      local lifetime = (config.score and config.score.damageNumberLifetime) or 2.5
      local prog = 1 - (num.t / lifetime)
      -- Speed up fade by 2.5x (60% reduction = 40% of original time)
      prog = math.min(1.0, prog * 2.5) -- Clamp to 1.0 max
      -- Faster fade - use exponential curve to fade to 0 faster
      local alpha = math.max(0, 1 - (prog * prog * 1.5)) -- Quadratic fade, faster than linear
      
      -- Calculate position with bounce
      local drawX = math.floor(num.x - textW * 0.5)
      local drawY = math.floor(num.y - textH - 20) -- Offset above block
      
      -- Apply bounce scale
      love.graphics.push()
      love.graphics.translate(num.x, drawY)
      love.graphics.scale(num.bounceScale, num.bounceScale)
      love.graphics.translate(-num.x, -drawY)
      
      -- Draw with outline
      theme.drawTextWithOutline(text, drawX, drawY, 1, 1, 1, alpha, 2)
      
      love.graphics.pop()
    end
  end
  
  love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- POPUPS
-- ============================================================================

function VisualEffects:addPopup(x, y, text, kind)
  table.insert(self.popups, {
    x = x,
    y = y,
    text = text,
    kind = kind or "damage",
    t = (config.score and config.score.blockPopupLifetime) or 0.8
  })
end

function VisualEffects:updatePopups(dt)
  local alive = {}
  for _, p in ipairs(self.popups) do
    p.t = p.t - dt
    if p.t > 0 then
      table.insert(alive, p)
    end
  end
  self.popups = alive
end

function VisualEffects:drawPopups()
  if not self.popups or #self.popups == 0 then return end
  
  love.graphics.setFont(theme.fonts.popup or theme.fonts.base)
  
  local function singleSoftBounce(t)
    local c1, c3 = 1.70158, 2.70158
    local u = (t - 1)
    return 1 + c3 * (u * u * u) + c1 * (u * u)
  end
  
  for _, p in ipairs(self.popups) do
    local lifetime = (config.score and config.score.blockPopupLifetime) or 0.8
    local prog = 1 - (p.t / math.max(0.0001, lifetime))
    local bounce = singleSoftBounce(math.min(1, prog))
    local heightBounce = (config.score and config.score.blockPopupBounceHeight) or 40
    local y = p.y - 12 - bounce * heightBounce
    local fx = math.floor(p.x)
    local fy = math.floor(y)
    
    local font = theme.fonts.popup or theme.fonts.base
    local text = p.text or ""
    local tw = font:getWidth(text)
    local icon = (p.kind == "armor") and self.iconArmor or self.iconAttack
    local iconW, iconH, s = 0, 0, 1
    
    if icon then
      iconW, iconH = icon:getWidth(), icon:getHeight()
      s = (font:getHeight() * 0.8) / math.max(1, iconH)
    end
    
    local pad = (icon and 6) or 0
    local totalW = tw + pad + (icon and (iconW * s) or 0)
    local startX = fx - math.floor(totalW * 0.5)
    
    -- Calculate fade
    local start = (config.score and config.score.blockPopupFadeStart) or 0.7
    local mul = (config.score and config.score.blockPopupFadeMultiplier) or 1
    local alpha
    if prog <= start then
      alpha = 1
    else
      local frac = (prog - start) / math.max(1e-6, (1 - start))
      local scaled = frac / math.max(1e-6, mul)
      alpha = math.max(0, 1 - scaled)
    end
    
    love.graphics.push()
    love.graphics.translate(fx, fy)
    love.graphics.scale(0.7, 0.7)
    love.graphics.translate(-fx, -fy)
    
    theme.drawTextWithOutline(text, startX, fy, 1, 1, 1, alpha, 2)
    
    if icon then
      local ix = startX + tw + pad
      local iy = fy + (font:getAscent() - iconH * s) * 0.5 + 10
      love.graphics.setColor(1, 1, 1, alpha)
      love.graphics.draw(icon, ix, iy, 0, s, s)
    end
    
    love.graphics.pop()
  end
  
  love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- TOOLTIPS
-- ============================================================================

function VisualEffects:updateCursor(x, y)
  self.cursorX = x
  self.cursorY = y
end

function VisualEffects:updateTooltips(dt, blocks, bounds)
  self.hoveredBlock = nil
  
  if not blocks or not blocks.blocks then return end
  
  local scaleMul = config.blocks.spriteScale or 1
  local baseSize = config.blocks.baseSize or 24
  local blockSize = baseSize * scaleMul
  
  for _, block in ipairs(blocks.blocks) do
    if block and block.alive then
      local x, y, w, h = block:getAABB()
      if self.cursorX >= x and self.cursorX <= x + w and
         self.cursorY >= y and self.cursorY <= y + h then
        self.hoveredBlock = block
        break
      end
    end
  end
  
  if self.hoveredBlock == self.lastHoveredBlock and self.hoveredBlock then
    self.hoverTime = self.hoverTime + dt
  else
    self.hoverTime = 0
    self.lastHoveredBlock = self.hoveredBlock
  end
end

function VisualEffects:drawTooltip(bounds)
  if not self.hoveredBlock or self.hoverTime < 0.3 then return end
  
  local block_types = require("data.block_types")
  local blockType = block_types.getByKey(self.hoveredBlock.kind)
  if not blockType or not blockType.description then return end
  
  local x, y, w, h = self.hoveredBlock:getAABB()
  local baseTooltipY = y - 10
  
  local font = theme.fonts.base
  love.graphics.setFont(font)
  
  -- Build tooltip text
  local text
  if self.hoveredBlock.kind == "multiplier" then
    local dmgMult = (config.score and config.score.powerCritMultiplier) or 4
    text = "x" .. tostring(dmgMult) .. " damage"
  elseif self.hoveredBlock.kind == "crit" then
    text = "x2 damage"
  else
    local fullDescription = blockType.description
    text = fullDescription
    local parenStart = fullDescription:find("%(")
    if parenStart then
      text = fullDescription:sub(parenStart)
      text = text:gsub("^%(", ""):gsub("%)$", "")
    end
    if #text > 0 then
      text = text:sub(1, 1):upper() .. text:sub(2):lower()
    end
  end
  
  if self.hoveredBlock.calcified then
    text = text .. " (calcified)"
  end
  
  -- Calculate size
  local baseTextW = font:getWidth(text)
  local baseTextH = font:getHeight()
  local textScale = 0.65 -- Increased from 0.5
  local textW = baseTextW * textScale
  local textH = baseTextH * textScale
  local padding = 8
  local tooltipW = textW + padding * 2
  local tooltipH = textH + padding * 2
  
  -- Calculate position
  local tooltipX = x + w * 0.5
  
  -- Clamp to canvas bounds
  local canvasLeft = 0
  local canvasRight = bounds and bounds.w or love.graphics.getWidth()
  local tooltipLeft = tooltipX - tooltipW * 0.5
  local tooltipRight = tooltipX + tooltipW * 0.5
  
  if tooltipLeft < canvasLeft then
    tooltipX = canvasLeft + tooltipW * 0.5
  elseif tooltipRight > canvasRight then
    tooltipX = canvasRight - tooltipW * 0.5
  end
  
  -- Fade in
  local fadeProgress = math.min(1.0, (self.hoverTime - 0.3) / 0.3)
  
  -- Bounce animation
  local bounceHeight = 8
  local bounceProgress = fadeProgress
  local c1, c3 = 1.70158, 2.70158
  local u = (bounceProgress - 1)
  local bounce = 1 + c3 * (u * u * u) + c1 * (u * u)
  local bounceOffset = (1 - bounce) * bounceHeight
  local tooltipY = baseTooltipY - bounceOffset
  
  -- Draw background
  love.graphics.setColor(0, 0, 0, 0.85 * fadeProgress)
  love.graphics.rectangle("fill", tooltipX - tooltipW * 0.5, tooltipY - tooltipH, tooltipW, tooltipH, 4, 4)
  
  -- Draw border
  love.graphics.setColor(1, 1, 1, 0.3 * fadeProgress)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", tooltipX - tooltipW * 0.5, tooltipY - tooltipH, tooltipW, tooltipH, 4, 4)
  
  -- Draw text
  love.graphics.push()
  love.graphics.translate(tooltipX - tooltipW * 0.5 + padding, tooltipY - tooltipH + padding)
  love.graphics.scale(textScale, textScale)
  love.graphics.setColor(1, 1, 1, fadeProgress)
  local textWrapWidth = (tooltipW - padding * 2) / textScale
  love.graphics.printf(text, 0, 0, textWrapWidth, "left")
  love.graphics.pop()
  
  love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- AIM GUIDE
-- ============================================================================

function VisualEffects:updateAimGuide(dt, canShoot)
  local guide = (config.shooter and config.shooter.aimGuide) or {}
  local k = guide.fadeSpeed or 6
  local target = canShoot and 1 or 0
  local delta = (target - self.guideAlpha)
  local step = math.min(1, math.max(-1, k * dt))
  self.guideAlpha = self.guideAlpha + delta * step
  self.guideAlpha = math.max(0, math.min(1, self.guideAlpha))
end

function VisualEffects:setAimStart(x, y)
  self.aimStartX = x
  self.aimStartY = y
end

function VisualEffects:drawAimGuide(shooter, blocks, gridStartX, gridEndX, width, height)
  local guide = (config.shooter and config.shooter.aimGuide) or {}
  if not guide.enabled then return end
  
  -- Get current projectile type
  local isTwinStrike = false
  local isPierce = false
  if shooter and shooter.getCurrentProjectileId then
    local projectileId = shooter:getCurrentProjectileId()
    isTwinStrike = (projectileId == "twin_strike")
    isPierce = (projectileId == "pierce")
  end
  
  local mx = self.cursorX
  local my = self.cursorY
  local dx = mx - self.aimStartX
  local dy = my - self.aimStartY
  local ndx, ndy = math2d.normalize(dx, dy)
  if ndx == 0 and ndy == 0 then
    ndx, ndy = 0, -1
  end
  
  local length = guide.length or 600
  local spacing = math.max(4, guide.dotSpacing or 16)
  local baseR = math.max(1, guide.dotRadius or 2)
  local r = isPierce and (baseR * 2.0) or baseR
  local totalSteps = math.max(1, math.floor(length / spacing))
  local fade = guide.fade ~= false
  local aStart = (guide.alphaStart ~= nil) and guide.alphaStart or 1.0
  local aEnd = (guide.alphaEnd ~= nil) and guide.alphaEnd or 0.0
  
  -- Helper function to find first bounce
  local function firstBounce(originX, originY, dirX, dirY)
    local tHit = math.huge
    local hitX, hitY = nil, nil
    local nX, nY = 0, 0
    local ballR = (config.ball and config.ball.radius) or 0
    
    local function considerHit(t, hx, hy, nx, ny)
      if t > 1e-4 and t < tHit then
        tHit = t
        hitX = hx
        hitY = hy
        nX = nx
        nY = ny
      end
    end
    
    local function rayAABB(ox, oy, dx, dy, rx, ry, rw, rh)
      local tmin = -math.huge
      local tmax = math.huge
      local nx, ny = 0, 0
      
      if math.abs(dx) < 1e-8 then
        if ox < rx or ox > rx + rw then return nil end
      else
        local invDx = 1 / dx
        local tx1 = (rx - ox) * invDx
        local tx2 = (rx + rw - ox) * invDx
        local txmin = math.min(tx1, tx2)
        local txmax = math.max(tx1, tx2)
        if txmin > tmin then
          tmin = txmin
          nx = (dx > 0) and -1 or 1
          ny = 0
        end
        tmax = math.min(tmax, txmax)
        if tmin > tmax then return nil end
      end
      
      if math.abs(dy) < 1e-8 then
        if oy < ry or oy > ry + rh then return nil end
      else
        local invDy = 1 / dy
        local ty1 = (ry - oy) * invDy
        local ty2 = (ry + rh - oy) * invDy
        local tymin = math.min(ty1, ty2)
        local tymax = math.max(ty1, ty2)
        if tymin > tmin then
          tmin = tymin
          nx = 0
          ny = (dy > 0) and -1 or 1
        end
        tmax = math.min(tmax, tymax)
        if tmin > tmax then return nil end
      end
      
      if tmax < 0 then return nil end
      if tmin <= 1e-6 then return nil end
      
      return tmin, nx, ny
    end
    
    -- Check blocks
    if blocks and blocks.blocks then
      for _, b in ipairs(blocks.blocks) do
        if b and b.alive then
          local rx, ry, rw, rh = b:getAABB()
          if type(rx) == "number" and type(ry) == "number" and type(rw) == "number" and type(rh) == "number" then
            local tmin, nx, ny = rayAABB(originX, originY, dirX, dirY, rx - ballR, ry - ballR, rw + 2 * ballR, rh + 2 * ballR)
            if tmin then
              considerHit(tmin, originX + dirX * tmin, originY + dirY * tmin, nx, ny)
            end
          end
        end
      end
    end
    
    -- Check walls
    local topBarHeight = (config.playfield and config.playfield.topBarHeight) or 60
    
    if dirX < 0 then
      local t = ((gridStartX + ballR) - originX) / dirX
      if t > 1e-4 then
        local y = originY + dirY * t
        if y >= 0 and y <= height and t < tHit then
          considerHit(t, gridStartX + ballR, y, 1, 0)
        end
      end
    end
    
    if dirX > 0 then
      local t = ((gridEndX - ballR) - originX) / dirX
      if t > 1e-4 then
        local y = originY + dirY * t
        if y >= 0 and y <= height and t < tHit then
          considerHit(t, gridEndX - ballR, y, -1, 0)
        end
      end
    end
    
    if dirY < 0 then
      local t = ((topBarHeight + ballR) - originY) / dirY
      if t > 1e-4 then
        local x = originX + dirX * t
        if x >= gridStartX and x <= gridEndX and t < tHit then
          considerHit(t, x, topBarHeight + ballR, 0, 1)
        end
      end
    end
    
    if tHit == math.huge then return nil end
    return tHit, hitX, hitY, nX, nY
  end
  
  -- Draw aim guide trajectory
  local function drawAimGuide(dirX, dirY)
    local remaining = length
    local ox, oy = self.aimStartX, self.aimStartY
    local drawnSteps = 0
    
    if isPierce then
      -- Pierce: straight line only
      local steps = math.floor(remaining / spacing)
      for i = 1, steps do
        local t = i * spacing
        local px = ox + dirX * t
        local py = oy + dirY * t
        local idx = i
        local alpha = 1
        if fade then
          local frac = idx / totalSteps
          alpha = aStart + (aEnd - aStart) * math.min(1, math.max(0, frac))
        end
        alpha = alpha * self.guideAlpha
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.circle("fill", px, py, r)
      end
    else
      -- Regular: with bounce prediction
      local hitT, hx, hy, nx, ny = firstBounce(ox, oy, dirX, dirY)
      local leg1 = remaining
      if hitT and hitT > 0 then
        leg1 = math.min(remaining, hitT)
      end
      
      -- Draw first leg
      local steps = math.floor(leg1 / spacing)
      for i = 1, steps do
        local t = i * spacing
        local px = ox + dirX * t
        local py = oy + dirY * t
        local idx = drawnSteps + i
        local alpha = 1
        if fade then
          local frac = idx / totalSteps
          alpha = aStart + (aEnd - aStart) * math.min(1, math.max(0, frac))
        end
        alpha = alpha * self.guideAlpha
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.circle("fill", px, py, r)
      end
      drawnSteps = drawnSteps + steps
      remaining = math.max(0, remaining - leg1)
      
      -- Draw reflected second leg
      if hitT and remaining > 0 then
        local rx, ry = dirX, dirY
        local dot = rx * nx + ry * ny
        rx = rx - 2 * dot * nx
        ry = ry - 2 * dot * ny
        
        local steps = math.floor(remaining / spacing)
        for i = 1, steps do
          local t = i * spacing
          local px = hx + rx * t
          local py = hy + ry * t
          local idx = drawnSteps + i
          local alpha = 1
          if fade then
            local frac = idx / totalSteps
            alpha = aStart + (aEnd - aStart) * math.min(1, math.max(0, frac))
          end
          alpha = alpha * self.guideAlpha
          love.graphics.setColor(1, 1, 1, alpha)
          love.graphics.circle("fill", px, py, r)
        end
      end
    end
  end
  
  -- Draw aim guide(s)
  if isTwinStrike then
    drawAimGuide(ndx, ndy)
    drawAimGuide(-ndx, ndy)
  else
    drawAimGuide(ndx, ndy)
  end
  
  love.graphics.setColor(1, 1, 1, 1)
end

-- Update all visual effects
function VisualEffects:update(dt, canShoot, blocks, bounds)
  self:updateScreenshake(dt)
  self:updatePopups(dt)
  self:updateDamageNumbers(dt)
  self:updateTooltips(dt, blocks, bounds)
  self:updateAimGuide(dt, canShoot)
end

-- Draw all visual effects (with screenshake transform)
function VisualEffects:draw(shooter, blocks, gridStartX, gridEndX, width, height, bounds)
  love.graphics.push()
  self:applyScreenshake()
  
  self:drawPopups()
  self:drawDamageNumbers()
  self:drawAimGuide(shooter, blocks, gridStartX, gridEndX, width, height)
  
  love.graphics.pop()
  
  -- Draw tooltip outside screenshake transform
  self:drawTooltip(bounds)
end

return VisualEffects

