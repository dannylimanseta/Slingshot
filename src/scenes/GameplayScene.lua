local config = require("config")
local theme = require("theme")
local math2d = require("utils.math2d")
local playfield = require("utils.playfield")
local BlockManager = require("managers.BlockManager")
local Ball = require("entities.Ball")
local Shooter = require("entities.Shooter")
local ParticleManager = require("managers.ParticleManager")
local ProjectileManager = require("managers.ProjectileManager")
local TopBar = require("ui.TopBar")

local GameplayScene = {}
GameplayScene.__index = GameplayScene

function GameplayScene.new()
  return setmetatable({
    blocks = nil,
    ball = nil, -- single ball (for backward compatibility) or nil when using balls array
    balls = {}, -- array of balls for spread shot
    shooter = nil,
    world = nil,
    particles = nil,
    canShoot = true,
    turnsTaken = 0,
    score = 0,
    displayScore = 0,
    armorThisTurn = 0,
    healThisTurn = 0,
    destroyedThisTurn = 0,
    blocksHitThisTurn = 0, -- Track total blocks hit this turn
    guideAlpha = 1,
    aimStartX = 0,
    aimStartY = 0,
    isAiming = false,
    cursorX = 0,
    cursorY = 0,
    popups = {},
    critThisTurn = 0, -- count of crit blocks hit this turn
    multiplierThisTurn = 0, -- count of multiplier blocks hit this turn
    aoeThisTurn = false, -- true if any AOE blocks were hit this turn
    pierceThisTurn = false, -- true if pierce orb was used this turn
    blockHitSequence = {}, -- Array of {damage, kind} for each block hit this turn (for animated damage display)
    baseDamageThisTurn = 0, -- Base damage from the orb/projectile at the start of the turn
    _prevCanShoot = true,
    turnManager = nil, -- reference to TurnManager (set by SplitScene)
    -- Combo tracking for multi-block shake
    comboCount = 0,
    comboTimeout = 0,
    lastHitTime = 0,
    -- Track blocks hit this frame to prevent duplicate rewards from multistrike
    _blocksHitThisFrame = {},
    -- Screenshake
    shakeMagnitude = 0,
    shakeDuration = 0,
    shakeTime = 0,
    projectileId = "strike", -- default projectile ID
    topBar = TopBar.new(),
    -- Block hover tooltip tracking
    hoveredBlock = nil,
    hoverTime = 0,
    lastHoveredBlock = nil,
  }, GameplayScene)
end

function GameplayScene:load(bounds, projectileId, battleProfile)
  local width = (bounds and bounds.w) or love.graphics.getWidth()
  local height = (bounds and bounds.h) or love.graphics.getHeight()
  self.world = love.physics.newWorld(0, 0, true)
  self.world:setCallbacks(
    function(a, b, contact) self:beginContact(a, b, contact) end,
    function(a, b, contact) self:preSolve(a, b, contact) end,
    function(a, b, contact) self:postSolve(a, b, contact) end,
    nil
  )

  -- Calculate grid bounds to match editor exactly
  local gridStartX, gridEndX = playfield.calculateGridBounds(width, height)
  
  -- Walls (static) - account for top bar and use grid boundaries
  local topBarHeight = (config.playfield and config.playfield.topBarHeight) or 60
  local halfW, halfH = width * 0.5, height * 0.5
  self.wallBody = love.physics.newBody(self.world, 0, 0, "static")
  local left = love.physics.newEdgeShape(gridStartX, topBarHeight, gridStartX, height)
  local right = love.physics.newEdgeShape(gridEndX, topBarHeight, gridEndX, height)
  local top = love.physics.newEdgeShape(gridStartX, topBarHeight, gridEndX, topBarHeight)
  local bottomSensor = love.physics.newEdgeShape(gridStartX, height, gridEndX, height)
  local fL = love.physics.newFixture(self.wallBody, left)
  local fR = love.physics.newFixture(self.wallBody, right)
  local fT = love.physics.newFixture(self.wallBody, top)
  local fB = love.physics.newFixture(self.wallBody, bottomSensor)
  fL:setUserData({ type = "wall", side = "left" })
  fR:setUserData({ type = "wall", side = "right" })
  fT:setUserData({ type = "wall" })
  fB:setUserData({ type = "bottom" })
  fB:setSensor(true)
  -- Store fixtures for wall updates
  self.wallFixtures = { left = fL, right = fR, top = fT, bottom = fB }
  -- Store grid bounds for aim guide and other calculations
  self.gridStartX = gridStartX
  self.gridEndX = gridEndX

  self.blocks = BlockManager.new()
  -- Load formation from battle profile (or use default random)
  local formationConfig = (battleProfile and battleProfile.blockFormation) or nil
  self.blocks:loadFormation(self.world, width, height, formationConfig)
  self.projectileId = projectileId or "strike" -- Store projectile ID
  -- Center shooter within grid bounds
  local shooterX = (gridStartX + gridEndX) * 0.5
  self.shooter = Shooter.new(shooterX, height - config.shooter.spawnYFromBottom, self.projectileId)
  -- Give shooter access to TurnManager for turn-based display
  if self.shooter and self.shooter.setTurnManager and self.turnManager then
    self.shooter:setTurnManager(self.turnManager)
  end
  self.particles = ParticleManager.new()
  -- Black hole effect state
  self.blackHoles = {}

  -- Load popup icons
  do
    self.iconAttack, self.iconArmor = nil, nil
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

  -- Hook block destroy events to particles
  for _, b in ipairs(self.blocks.blocks) do
    b.onDestroyed = function()
      if self.particles and not b._suckedByBlackHole then
        -- Get block color based on kind
        local blockColor = theme.colors.block -- default (damage blocks)
        if b.kind == "armor" then
          blockColor = theme.colors.blockArmor
        elseif b.kind == "crit" then
          -- Use gold/yellow color for crit blocks
          blockColor = { 1.0, 0.85, 0.3, 1 }
        end
        self.particles:emitExplosion(b.cx, b.cy, blockColor)
      end
      self.destroyedThisTurn = (self.destroyedThisTurn or 0) + 1
    end
  end
end

function GameplayScene:update(dt, bounds)
  -- Clear blocks hit this frame (reset each frame to prevent duplicate hits)
  self._blocksHitThisFrame = {}
  
  if self.world then self.world:update(dt) end
  
  -- Correct pierce orb positions after physics step (if needed)
  if self.ball and self.ball.alive and self.ball.pierce and self.ball._needsPositionCorrection then
    self:_correctPiercePosition(self.ball)
  end
  if self.balls and #self.balls > 0 then
    for _, ball in ipairs(self.balls) do
      if ball and ball.alive and ball.pierce and ball._needsPositionCorrection then
        self:_correctPiercePosition(ball)
      end
    end
  end
  
  -- Update single ball (backward compatibility)
  if self.ball and self.ball.alive then self.ball:update(dt, { bounds = bounds }) end
  
  -- Update multiple balls (spread shot)
  if self.balls and #self.balls > 0 then
    for i = #self.balls, 1, -1 do
      local ball = self.balls[i]
      if ball and ball.alive then
        ball:update(dt, { bounds = bounds })
      else
        -- Remove dead balls
        table.remove(self.balls, i)
      end
    end
  end
  
  -- Failsafe: if the ball tunnels past the bottom sensor, destroy it
  -- Turn will end automatically when no balls are alive
  do
    -- Single ball check
    if self.ball and self.ball.alive and self.ball.body then
      local bx, by = self.ball.body:getX(), self.ball.body:getY()
      local height = (bounds and bounds.h) or love.graphics.getHeight()
      local margin = 16 -- small buffer beyond bottom edge
      if by > height + margin then
        self.ball:destroy()
      end
    end
    
    -- Multiple balls check (spread shot)
    if self.balls and #self.balls > 0 then
      local height = (bounds and bounds.h) or love.graphics.getHeight()
      local margin = 16
      for i = #self.balls, 1, -1 do
        local ball = self.balls[i]
        if ball and ball.alive and ball.body then
          local bx, by = ball.body:getX(), ball.body:getY()
          if by > height + margin then
            ball:destroy()
            table.remove(self.balls, i)
          end
        end
      end
    end
  end
  if self.blocks and self.blocks.update then
    self.blocks:update(dt)
  end
  -- Update black hole effects (pull + swirl nearby blocks and destroy when close)
  if self.blackHoles and #self.blackHoles > 0 then
    local aliveEffects = {}
    local cfg = (config.gameplay and config.gameplay.blackHole) or {}
    local radius = cfg.radius or 96
    local duration = cfg.duration or 1.8
    local suckSpeed = cfg.suckSpeed or 220
    local swirlBase = cfg.swirlSpeed or 240
    for _, hole in ipairs(self.blackHoles) do
      hole.t = (hole.t or 0) + dt
      -- Open (ease-out), hold, then close (ease-in) for longer block removal window
      local u = math.max(0, math.min(1, (hole.t or 0) / math.max(1e-6, duration)))
      local openFrac = cfg.openFrac or 0.25
      local closeFrac = cfg.closeFrac or 0.35
      local r
      if u < openFrac then
        -- Ease-out open
        local x = u / math.max(1e-6, openFrac)
        local easeOut = 1 - (1 - x) * (1 - x)
        r = radius * easeOut
      elseif u <= 1 - closeFrac then
        -- Hold fully open
        r = radius
      else
        -- Ease-in close
        local x = (u - (1 - closeFrac)) / math.max(1e-6, closeFrac)
        local easeIn = x * x
        r = radius * (1 - easeIn)
      end
      hole.r = r
      if self.blocks and self.blocks.blocks then
        for _, b in ipairs(self.blocks.blocks) do
          if b and b.alive then
            local dx = hole.x - b.cx
            local dy = hole.y - b.cy
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist <= r then
              -- Assign a per-block speed variance (+/- 20%) once
              if not b._bhSpeedMul then
                b._bhSpeedMul = 0.8 + love.math.random() * 0.4
              end
              -- Assign swirl properties once
              if not b._bhSwirlDir then
                b._bhSwirlDir = (love.math.random() < 0.5) and -1 or 1
                b._bhSwirlSpeed = swirlBase * (0.8 + love.math.random() * 0.4) -- +/-20%
                -- Rotation setup (radians/sec), +/- 40% variance
                b._bhTwistSpeed = (2.0 + love.math.random() * 2.0) * b._bhSwirlDir * (0.8 + love.math.random() * 0.4)
                b._bhTwistAngle = b._bhTwistAngle or 0
                -- Capture base size to shrink toward center
                b._bhBaseTargetSize = b._bhBaseTargetSize or b.targetSize
              end
              local ndx = (dist > 0) and (dx / dist) or 0
              local ndy = (dist > 0) and (dy / dist) or 0
              -- Tangent (perpendicular) unit vector
              local tdx, tdy = -ndy, ndx
              -- Strength scales with proximity (more swirl near center)
              local proximity = 1 - math.min(1, dist / math.max(1e-6, r))
              -- Ease-in: slow at start, faster near center
              -- Use a milder curve: start at 0.3, ramp up to 1.0 near center
              local easeIn = 0.3 + 0.7 * (proximity * proximity)
              local radialMove = suckSpeed * (b._bhSpeedMul or 1) * easeIn * dt
              local swirlMove = (b._bhSwirlSpeed or swirlBase) * (0.2 + 0.8 * proximity) * easeIn * dt
              -- Compose motion: radial inwards + tangential swirl
              local stepX = ndx * radialMove + tdx * swirlMove * (b._bhSwirlDir or 1)
              local stepY = ndy * radialMove + tdy * swirlMove * (b._bhSwirlDir or 1)
              -- Clamp so we don't overshoot
              if (stepX * stepX + stepY * stepY) > (dist * dist) then
                -- Normalize step to distance
                local sm = math.sqrt(stepX * stepX + stepY * stepY)
                if sm > 0 then
                  stepX = stepX / sm * dist
                  stepY = stepY / sm * dist
                end
              end
              b.cx = b.cx + stepX
              b.cy = b.cy + stepY
              b.pendingResize = true
              -- Continuous shader twist while flying in (scaled by proximity)
              if b._bhTwistSpeed then
                b._bhTwistAngle = (b._bhTwistAngle or 0) + b._bhTwistSpeed * (0.4 + 0.6 * proximity) * dt
              end
              -- Increase black tint as it approaches the hole
              do
                local t = 1 - math.min(1, dist / math.max(1e-6, r))
                b._bhTint = math.max(b._bhTint or 0, t)
              end
              -- Shrink toward the center (mild warp)
              if b._bhBaseTargetSize then
                local shrink = 1 - 0.35 * (1 - math.min(1, dist / math.max(1e-6, r)))
                local newTarget = math.max(4, b._bhBaseTargetSize * shrink)
                if math.abs(newTarget - b.targetSize) > 0.1 then
                  b.targetSize = newTarget
                  b.pendingResize = true
                end
              end
              if dist <= 8 then
                b._suckedByBlackHole = true -- suppress particle explosion
                b:destroy()
              end
            end
          end
        end
      end
      if (hole.t or 0) < duration then
        table.insert(aliveEffects, hole)
      end
    end
    self.blackHoles = aliveEffects
  end
  -- Aim guide fade toward canShoot state
  do
    local guide = (config.shooter and config.shooter.aimGuide) or {}
    local k = guide.fadeSpeed or 6
    local target = self.canShoot and 1 or 0
    local delta = (target - (self.guideAlpha or 0))
    local step = math.min(1, math.max(-1, k * dt))
    self.guideAlpha = (self.guideAlpha or 0) + delta * step
    if self.guideAlpha < 0 then self.guideAlpha = 0 end
    if self.guideAlpha > 1 then self.guideAlpha = 1 end
  end
  self._prevCanShoot = self.canShoot
  if self.particles then self.particles:update(dt) end
  if self.shooter then
    -- Pass grid bounds to shooter for movement clamping
    local shooterBounds = bounds or {}
    if self.gridStartX and self.gridEndX then
      shooterBounds.gridStartX = self.gridStartX
      shooterBounds.gridEndX = self.gridEndX
    end
    self.shooter:update(dt, shooterBounds)
  end
  -- Update block popups
  do
    local alive = {}
    for _, p in ipairs(self.popups) do
      p.t = p.t - dt
      if p.t > 0 then table.insert(alive, p) end
    end
    self.popups = alive
  end
  
  -- Update combo timeout (reset combo if too much time passes between hits)
  if self.comboTimeout > 0 then
    self.comboTimeout = self.comboTimeout - dt
    if self.comboTimeout <= 0 then
      self.comboCount = 0
    end
  end
  
  -- Update screenshake
  if self.shakeTime > 0 then
    self.shakeTime = self.shakeTime - dt
    if self.shakeTime <= 0 then
      self.shakeTime = 0
      self.shakeMagnitude = 0
    end
  end
  
  -- Update block hover detection for tooltips
  self.hoveredBlock = nil
  if self.blocks and self.blocks.blocks then
    local scaleMul = config.blocks.spriteScale or 1
    local baseSize = config.blocks.baseSize or 24
    local blockSize = baseSize * scaleMul
    local halfSize = blockSize * 0.5
    
    for _, block in ipairs(self.blocks.blocks) do
      if block and block.alive then
        local x, y, w, h = block:getAABB()
        -- Check if cursor is within block bounds
        if self.cursorX >= x and self.cursorX <= x + w and
           self.cursorY >= y and self.cursorY <= y + h then
          self.hoveredBlock = block
          break
        end
      end
    end
  end
  
  -- Update hover time
  if self.hoveredBlock == self.lastHoveredBlock and self.hoveredBlock then
    -- Same block, accumulate time
    self.hoverTime = self.hoverTime + dt
  else
    -- Different block or no block, reset timer
    self.hoverTime = 0
    self.lastHoveredBlock = self.hoveredBlock
  end
end

-- Public: respawn blocks based on last turn's destroyed count
-- If destroyed <= 2 and > 0, respawn exactly 1 block.
-- If destroyed > 2, respawn 1-2 blocks at random.
-- If destroyed <= 0, respawn 0 blocks.
function GameplayScene:respawnDestroyedBlocks(bounds, count)
  if not (self.blocks and self.blocks.addRandomBlocks) then return end
  local width = (bounds and bounds.w) or love.graphics.getWidth()
  local height = (bounds and bounds.h) or love.graphics.getHeight()
  
  -- Count available empty spaces
  local availableSpaces = 0
  if self.blocks.countAvailableSpaces then
    availableSpaces = self.blocks:countAvailableSpaces(width, height)
  end
  
  -- Only spawn blocks if there are available spaces
  if availableSpaces <= 0 then return end
  
  -- Determine desired spawn count based on destroyed count
  local destroyed = tonumber(count or 0) or 0
  if destroyed <= 0 then return end
  
  local desiredSpawn
  if destroyed <= 2 then
    desiredSpawn = 1
  else
    desiredSpawn = love.math.random(1, 2)
  end
  
  -- Limit spawn count to available spaces (never spawn more than available)
  local toSpawn = math.min(desiredSpawn, availableSpaces) -- But limit to available spaces
  
  if toSpawn <= 0 then return end
  
  local newBlocks = self.blocks:addRandomBlocks(self.world, width, height, toSpawn)
  for _, nb in ipairs(newBlocks) do
    nb.onDestroyed = function()
      if self.particles and not nb._suckedByBlackHole then
        -- Get block color based on kind
        local blockColor = theme.colors.block -- default (damage blocks)
        if nb.kind == "armor" then
          blockColor = theme.colors.blockArmor
        elseif nb.kind == "crit" then
          -- Use gold/yellow color for crit blocks
          blockColor = { 1.0, 0.85, 0.3, 1 }
        end
        self.particles:emitExplosion(nb.cx, nb.cy, blockColor)
      end
      self.destroyedThisTurn = (self.destroyedThisTurn or 0) + 1
    end
  end
  self.destroyedThisTurn = 0
end

function GameplayScene:draw(bounds)
  local width = (bounds and bounds.w) or love.graphics.getWidth()
  local height = (bounds and bounds.h) or love.graphics.getHeight()

  -- Apply screenshake
  love.graphics.push()
  if self.shakeTime > 0 and self.shakeDuration > 0 then
    local t = self.shakeTime / self.shakeDuration
    local ease = t * t -- quadratic ease-out
    local mag = self.shakeMagnitude * ease
    local ox = (love.math.random() * 2 - 1) * mag
    local oy = (love.math.random() * 2 - 1) * mag
    love.graphics.translate(ox, oy)
  end

  -- Black hole visuals (below blocks)
  if self.blackHoles and #self.blackHoles > 0 then
    love.graphics.push("all")
    love.graphics.setBlendMode("alpha")
    for _, hole in ipairs(self.blackHoles) do
      local r = hole.r or 0
      love.graphics.setColor(0, 0, 0, 0.95)
      love.graphics.circle("fill", hole.x, hole.y, r)
    end
    love.graphics.pop()
  end

  -- Blocks
  self.blocks:draw()

  -- Black hole block tint overlay (above blocks)
  do
    if self.blocks and self.blocks.blocks then
      love.graphics.push("all")
      love.graphics.setBlendMode("alpha")
      for _, b in ipairs(self.blocks.blocks) do
        if b and b.alive and b._bhTint and b._bhTint > 0 then
          local x, y, w, h = b:getAABB()
          -- Expand tint overlay by 10% to cover edges during rotation
          local expand = math.max(w, h) * 0.1
          love.graphics.setColor(0, 0, 0, math.max(0, math.min(1, b._bhTint)) * 0.9)
          love.graphics.rectangle("fill", x - expand, y - expand, w + expand * 2, h + expand * 2, 4, 4)
        end
      end
      love.graphics.pop()
    end
  end

  -- Ball (single)
  if self.ball then self.ball:draw() end
  
  -- Balls (multiple for spread shot)
  if self.balls then
    for _, ball in ipairs(self.balls) do
      if ball then ball:draw() end
    end
  end

  -- Shooter
  if self.shooter then self.shooter:draw() end

  -- Particles
  if self.particles then self.particles:draw() end

  -- Block hit popups (crisp 2x font, with icons)
  if self.popups and #self.popups > 0 then
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
      -- Fade only in the last segment of lifetime
      local prog = 1 - (p.t / math.max(0.0001, lifetime)) -- 0..1
      local start = (config.score and config.score.blockPopupFadeStart) or 0.7
      local mul = (config.score and config.score.blockPopupFadeMultiplier) or 1
      local alpha
      if prog <= start then
        alpha = 1
      else
        local frac = (prog - start) / math.max(1e-6, (1 - start)) -- 0..1 within fade window
        local scaled = frac / math.max(1e-6, mul) -- mul <1 fades faster
        alpha = math.max(0, 1 - scaled)
      end
      love.graphics.push()
      love.graphics.translate(fx, fy)
      love.graphics.scale(0.7, 0.7)
      love.graphics.translate(-fx, -fy)
      -- Draw text first, then icon to the right
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

  -- Always-on dotted aim guide (rotates with mouse)
  do
    local guide = (config.shooter and config.shooter.aimGuide) or {}
    if guide.enabled then
      local mx, my
      if self.shooter then
        local sx, sy = self.shooter:getMuzzle()
        self.aimStartX, self.aimStartY = sx, sy
      end
      mx = self.cursorX; my = self.cursorY
      local dx = (mx or self.aimStartX) - self.aimStartX
      local dy = (my or self.aimStartY) - self.aimStartY
      local ndx, ndy = math2d.normalize(dx, dy)
      if ndx == 0 and ndy == 0 then ndx, ndy = 0, -1 end

      local length = guide.length or 600
      local spacing = math.max(4, guide.dotSpacing or 16)
      local baseR = math.max(1, guide.dotRadius or 2)
      -- Pierce orbs have 2x thicker guide
      local r = isPierce and (baseR * 2.0) or baseR
      local totalSteps = math.max(1, math.floor(length / spacing))
      local fade = guide.fade ~= false
      local aStart = (guide.alphaStart ~= nil) and guide.alphaStart or 1.0
      local aEnd = (guide.alphaEnd ~= nil) and guide.alphaEnd or 0.0

      -- Check projectile type for special aim guide behavior
      local isTwinStrike = false
      local isPierce = false
      if self.shooter and self.shooter.getCurrentProjectileId then
        local projectileId = self.shooter:getCurrentProjectileId()
        isTwinStrike = (projectileId == "twin_strike")
        isPierce = (projectileId == "pierce")
      end

      -- Compute first bounce against blocks and top/left/right walls (ignore bottom sensor)
      local function firstBounce(originX, originY, dirX, dirY)
        local tHit = math.huge
        local hitX, hitY = nil, nil
        local nX, nY = 0, 0 -- normal
        local ballR = (config.ball and config.ball.radius) or 0
        local function considerHit(t, hx, hy, nx, ny)
          if t > 1e-4 and t < tHit then
            tHit = t; hitX = hx; hitY = hy; nX = nx; nY = ny
          end
        end
        -- Ray vs AABB helper using slab method (returns tmin and normal)
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
          if tmin <= 1e-6 then
            -- If starting inside or grazing, use tmax but treat as no hit for our guide
            return nil
          end
          return tmin, nx, ny
        end
        -- Check blocks (use physics AABB, expanded by ball radius)
        if self.blocks and self.blocks.blocks then
          for _, b in ipairs(self.blocks.blocks) do
            if b and b.alive then
              local rx, ry, rw, rh
              rx, ry, rw, rh = b:getAABB()
              if type(rx) == "number" and type(ry) == "number" and type(rw) == "number" and type(rh) == "number" then
                local tmin, nx, ny = rayAABB(originX, originY, dirX, dirY, rx - ballR, ry - ballR, rw + 2 * ballR, rh + 2 * ballR)
                if tmin then
                  considerHit(tmin, originX + dirX * tmin, originY + dirY * tmin, nx, ny)
                end
              end
            end
          end
        end
        -- Left wall at gridStartX + ballR (matching editor grid)
        local gridStartX = self.gridStartX or 0
        local gridEndX = self.gridEndX or width
        if dirX < 0 then
          local t = ((gridStartX + ballR) - originX) / dirX
          if t > 1e-4 then
            local y = originY + dirY * t
            if y >= 0 and y <= height and t < tHit then
              considerHit(t, gridStartX + ballR, y, 1, 0)
            end
          end
        end
        -- Right wall at gridEndX - ballR (matching editor grid)
        if dirX > 0 then
          local t = ((gridEndX - ballR) - originX) / dirX
          if t > 1e-4 then
            local y = originY + dirY * t
            if y >= 0 and y <= height and t < tHit then
              considerHit(t, gridEndX - ballR, y, -1, 0)
            end
          end
        end
        -- Top wall at y = topBarHeight (matching editor grid)
        local topBarHeight = (config.playfield and config.playfield.topBarHeight) or 60
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

      -- Function to draw a single aim guide trajectory
      local function drawAimGuide(dirX, dirY)
      local remaining = length
      local ox, oy = self.aimStartX, self.aimStartY
      local drawnSteps = 0

      if isPierce then
        -- Pierce orbs: draw straight line only (no bounce prediction)
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
          alpha = alpha * (self.guideAlpha or 1)
          love.graphics.setColor(1, 1, 1, alpha)
          love.graphics.circle("fill", px, py, r)
        end
      else
        -- Regular orbs: draw with bounce prediction
        local hitT, hx, hy, nx, ny = firstBounce(ox, oy, dirX, dirY)
      local leg1 = remaining
      if hitT and hitT > 0 then leg1 = math.min(remaining, hitT) end

      -- Draw first leg dotted
      do
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
          alpha = alpha * (self.guideAlpha or 1)
          love.graphics.setColor(1, 1, 1, alpha)
          love.graphics.circle("fill", px, py, r)
        end
        drawnSteps = drawnSteps + steps
      end
      remaining = math.max(0, remaining - leg1)

      -- Draw reflected second leg if we hit a wall and have remaining length
      if hitT and remaining > 0 then
          local rx, ry = dirX, dirY
        -- Reflect direction across normal: r = v - 2*(v·n)*n
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
          alpha = alpha * (self.guideAlpha or 1)
          love.graphics.setColor(1, 1, 1, alpha)
          love.graphics.circle("fill", px, py, r)
          end
        end
      end
      end
      
      -- Draw aim guide(s)
      if isTwinStrike then
        -- Twin Strike: draw both mirrored trajectories
        drawAimGuide(ndx, ndy)      -- Original direction
        drawAimGuide(-ndx, ndy)     -- Mirrored on x-axis
      else
        -- Normal: single trajectory
        drawAimGuide(ndx, ndy)
      end
      
      love.graphics.setColor(1, 1, 1, 1)
    end
  end
  
  love.graphics.pop() -- Pop screenshake transform (must be last, after all drawing)
  
  -- Draw block tooltip if hovering for >0.3s (outside screenshake transform)
  if self.hoveredBlock and self.hoverTime >= 0.3 then
    local block_types = require("data.block_types")
    local blockType = block_types.getByKey(self.hoveredBlock.kind)
    if blockType and blockType.description then
      local x, y, w, h = self.hoveredBlock:getAABB()
      local baseTooltipY = y - 10 -- Base position above block (lowered from -20)
      
      -- Calculate tooltip size with reduced font
      local font = theme.fonts.base
      love.graphics.setFont(font)
      -- Build tooltip text
      local text
      if self.hoveredBlock.kind == "multiplier" then
        -- Use configured damage multiplier, e.g., x4 damage
        local dmgMult = (config.score and config.score.powerCritMultiplier) or 4
        text = "x" .. tostring(dmgMult) .. " damage"
      elseif self.hoveredBlock.kind == "crit" then
        -- Force lowercase x2 wording
        text = "x2 damage"
      else
        -- Extract description without block name prefix and remove parentheses
        local fullDescription = blockType.description
        text = fullDescription
        -- Remove prefix before opening parenthesis (e.g., "Basic damage block " from "Basic damage block (+1 damage)")
        local parenStart = fullDescription:find("%(")
        if parenStart then
          text = fullDescription:sub(parenStart)
          -- Remove opening and closing parentheses
          text = text:gsub("^%(", ""):gsub("%)$", "")
        end
        -- Apply sentence capitalization (capitalize first letter, lowercase rest)
        if #text > 0 then
          text = text:sub(1, 1):upper() .. text:sub(2):lower()
        end
      end
      
      -- Add "(calcified)" suffix if block is calcified
      if self.hoveredBlock.calcified then
        text = text .. " (calcified)"
      end
      -- Calculate text size at 65% scale (reduced from 75%)
      local baseTextW = font:getWidth(text)
      local baseTextH = font:getHeight()
      local textScale = 0.5
      local textW = baseTextW * textScale -- 65% width for display
      local textH = baseTextH * textScale -- 65% height for display
      local padding = 8
      -- Tooltip width matches scaled text width
      local tooltipW = textW + padding * 2
      local tooltipH = textH + padding * 2
      
      -- Calculate tooltip X position (centered on block by default)
      local tooltipX = x + w * 0.5
      
      -- Clamp tooltip to canvas bounds to prevent cropping
      local canvasLeft = 0
      local canvasRight = bounds and bounds.w or love.graphics.getWidth()
      local tooltipLeft = tooltipX - tooltipW * 0.5
      local tooltipRight = tooltipX + tooltipW * 0.5
      
      -- Adjust tooltip X if it would go off the edges
      if tooltipLeft < canvasLeft then
        tooltipX = canvasLeft + tooltipW * 0.5
      elseif tooltipRight > canvasRight then
        tooltipX = canvasRight - tooltipW * 0.5
      end
      
      -- Fade in tooltip (smooth appearance)
      local fadeProgress = math.min(1.0, (self.hoverTime - 0.3) / 0.3) -- Fade in over 0.3 seconds
      
      -- Bounce animation when fading in (small upward bounce)
      local bounceHeight = 8 -- pixels
      local bounceProgress = fadeProgress
      -- Use ease-out bounce curve
      local c1, c3 = 1.70158, 2.70158
      local u = (bounceProgress - 1)
      local bounce = 1 + c3 * (u * u * u) + c1 * (u * u)
      local bounceOffset = (1 - bounce) * bounceHeight
      local tooltipY = baseTooltipY - bounceOffset
      
      -- Draw tooltip background
      love.graphics.setColor(0, 0, 0, 0.85 * fadeProgress)
      love.graphics.rectangle("fill", tooltipX - tooltipW * 0.5, tooltipY - tooltipH, tooltipW, tooltipH, 4, 4)
      
      -- Draw tooltip border
      love.graphics.setColor(1, 1, 1, 0.3 * fadeProgress)
      love.graphics.setLineWidth(1)
      love.graphics.rectangle("line", tooltipX - tooltipW * 0.5, tooltipY - tooltipH, tooltipW, tooltipH, 4, 4)
      
      -- Draw tooltip text at 75% scale
      love.graphics.push()
      love.graphics.translate(tooltipX - tooltipW * 0.5 + padding, tooltipY - tooltipH + padding)
      love.graphics.scale(textScale, textScale)
      love.graphics.setColor(1, 1, 1, fadeProgress)
      -- Text wrap width accounts for scale
      local textWrapWidth = (tooltipW - padding * 2) / textScale
      love.graphics.printf(text, 0, 0, textWrapWidth, "left")
      love.graphics.pop()
      
      love.graphics.setColor(1, 1, 1, 1)
    end
  end
  
  -- Draw top bar on top (z-order)
  if self.topBar and not self.disableTopBar then
    self.topBar:draw()
  end
end

-- Trigger screenshake
function GameplayScene:triggerShake(magnitude, duration)
  self.shakeMagnitude = magnitude or 2
  self.shakeDuration = duration or 0.15
  self.shakeTime = self.shakeDuration
end

function GameplayScene:mousepressed(x, y, button, bounds)
  -- Check if any balls are alive (single or multiple)
  local hasAliveBall = false
  if self.ball and self.ball.alive then
    hasAliveBall = true
  elseif self.balls then
    for _, ball in ipairs(self.balls) do
      if ball and ball.alive then
        hasAliveBall = true
        break
      end
    end
  end
  if button == 1 and self.canShoot and not hasAliveBall then
    if self.shooter then
      local sx, sy = self.shooter:getMuzzle()
      self.aimStartX = sx
      self.aimStartY = sy
    else
      local width = (bounds and bounds.w) or love.graphics.getWidth()
      local height = (bounds and bounds.h) or love.graphics.getHeight()
      self.aimStartX = width * 0.5
      self.aimStartY = height - config.ball.spawnYFromBottom
    end
    self.isAiming = true
  end
end

function GameplayScene:mousemoved(x, y, dx, dy, bounds)
  -- x, y are already local to pane from SplitScene routing
  self.cursorX, self.cursorY = x, y
end

function GameplayScene:mousereleased(x, y, button, bounds)
  -- Check if any balls are alive (single or multiple)
  local hasAliveBall = false
  if self.ball and self.ball.alive then
    hasAliveBall = true
  elseif self.balls then
    for _, ball in ipairs(self.balls) do
      if ball and ball.alive then
        hasAliveBall = true
        break
      end
    end
  end
  if button == 1 and self.isAiming and self.canShoot and not hasAliveBall then
    local dx = x - self.aimStartX
    local dy = y - self.aimStartY
    local ndx, ndy = math2d.normalize(dx, dy)
    if ndx ~= 0 or ndy ~= 0 then
      -- Reset score when the next shot is actually fired
      self.score = 0
      self.displayScore = 0
      self.armorThisTurn = 0
      self.healThisTurn = 0
      self.critThisTurn = 0
      self.multiplierThisTurn = 0
      self.aoeThisTurn = false
      self.pierceThisTurn = false
      self.blocksHitThisTurn = 0
      self.blockHitSequence = {} -- Reset block hit sequence for animated damage display
      self.baseDamageThisTurn = 0 -- Reset base damage for this turn
      -- Reset combo when new shot starts
      self.comboCount = 0
      self.comboTimeout = 0
      self.lastHitTime = 0
      
      -- Get current projectile ID from shooter based on turn rotation
      local projectileId = "strike"
      if self.shooter and self.shooter.getCurrentProjectileId then
        projectileId = self.shooter:getCurrentProjectileId()
      else
        projectileId = self.projectileId or "strike"
      end
      
      -- Get projectile data and effective stats to determine behavior and sprite
      local projectileData = ProjectileManager.getProjectile(projectileId)
      local effective = ProjectileManager.getEffective(projectileData)
      local spritePath = nil
      if projectileData and projectileData.icon then
        spritePath = projectileData.icon
      end
      
      if projectileId == "twin_strike" then
        -- Twin Strike: spawn 2 mirrored projectiles (mirrored on x-axis)
        self.ball = nil -- Clear single ball
        self.balls = {}
        if not spritePath then
          spritePath = (config.assets.images.ball_3) or "assets/images/orb_twin_strike.png"
        end
        local maxBounces = (effective and effective.maxBounces) or 5
        
        -- First ball: original direction
        local ball1 = Ball.new(self.world, self.aimStartX, self.aimStartY, ndx, ndy, {
          maxBounces = maxBounces,
          spritePath = spritePath,
          trailConfig = (config.ball and config.ball.twinStrike and config.ball.twinStrike.trail) or nil,
          onLastBounce = function(ball)
            ball:destroy()
          end
        })
        
        -- Second ball: mirrored on x-axis (flip x direction)
        local ball2 = Ball.new(self.world, self.aimStartX, self.aimStartY, -ndx, ndy, {
          maxBounces = maxBounces,
          spritePath = spritePath,
          trailConfig = (config.ball and config.ball.twinStrike and config.ball.twinStrike.trail) or nil,
          onLastBounce = function(ball)
            ball:destroy()
          end
        })
        if ball1 then ball1.projectileId = projectileId end
        if ball2 then ball2.projectileId = projectileId end
        
        local baseDmg = (effective and effective.baseDamage) or ((config.score and config.score.baseSeed) or 0)
        if ball1 then
          ball1.score = baseDmg
          self.score = self.score + ball1.score
          self.baseDamageThisTurn = self.baseDamageThisTurn + baseDmg -- Track base damage for animation
          table.insert(self.balls, ball1)
        end
        if ball2 then
          ball2.score = baseDmg
          self.score = self.score + ball2.score
          self.baseDamageThisTurn = self.baseDamageThisTurn + baseDmg -- Track base damage for animation
          table.insert(self.balls, ball2)
        end
      elseif projectileId == "multi_strike" then
        -- Spread shot: spawn multiple projectiles
        local spreadConfig = config.ball.spreadShot
        if spreadConfig and spreadConfig.enabled then
        self.ball = nil -- Clear single ball
        self.balls = {}
        local count = (effective and effective.count) or (spreadConfig.count or 3)
        local spreadAngle = spreadConfig.spreadAngle or 0.15
        local radiusScale = spreadConfig.radiusScale or 0.7
          if not spritePath then
            spritePath = spreadConfig.sprite or (config.assets.images.ball_2) or "assets/images/orb_multi_strike.png"
          end
        local maxBounces = (effective and effective.maxBounces) or (spreadConfig.maxBounces or 3)
        
        -- Calculate base angle from aim direction
        local baseAngle = math.atan2(ndy, ndx)
        
        -- Spawn projectiles in a spread pattern
        for i = 1, count do
          -- Calculate offset angle (centered around base angle)
          local offset = 0
          if count > 1 then
            offset = (i - (count + 1) / 2) * (spreadAngle / (count - 1))
          end
          local angle = baseAngle + offset
          local projDx = math.cos(angle)
          local projDy = math.sin(angle)
          
          local ball = Ball.new(self.world, self.aimStartX, self.aimStartY, projDx, projDy, {
            radius = config.ball.radius * radiusScale,
            maxBounces = maxBounces,
            spritePath = spritePath,
            trailConfig = spreadConfig.trail, -- Use spread shot trail config (green, smaller width)
            onLastBounce = function(ball)
              -- Ball reached max bounces, destroy it - turn will end automatically
              ball:destroy()
            end
          })
          
          if ball then
            ball.projectileId = projectileId
            local baseDmg = (effective and effective.baseDamage) or ((config.score and config.score.baseSeed) or 0)
            ball.score = baseDmg
            self.score = self.score + ball.score
            self.baseDamageThisTurn = self.baseDamageThisTurn + baseDmg -- Track base damage for animation
            table.insert(self.balls, ball)
            end
          end
        else
          -- Fallback to single projectile if spread shot config not available
          self.balls = {} -- Clear multiple balls
          self.ball = Ball.new(self.world, self.aimStartX, self.aimStartY, ndx, ndy, {
            spritePath = spritePath,
            onLastBounce = function(ball)
              ball:destroy()
            end
          })
          if self.ball then
            self.ball.projectileId = projectileId
            local baseDmg = (effective and effective.baseDamage) or ((config.score and config.score.baseSeed) or 0)
            self.ball.score = baseDmg
            self.score = self.score + self.ball.score
            self.baseDamageThisTurn = self.baseDamageThisTurn + baseDmg -- Track base damage for animation
          end
        end
      elseif projectileId == "pierce" then
        -- Pierce: single projectile that pierces through blocks
        self.balls = {} -- Clear multiple balls
        self.pierceThisTurn = true -- Track that pierce orb was used this turn
        local maxPierce = (effective and effective.maxPierce) or 6
        -- Pierce orbs are 2x larger
        local pierceRadiusScale = 2.0
        self.ball = Ball.new(self.world, self.aimStartX, self.aimStartY, ndx, ndy, {
          pierce = true,
          maxPierce = maxPierce,
          radius = config.ball.radius * pierceRadiusScale,
          spritePath = spritePath,
          onLastBounce = function(ball)
            -- Pierce orbs don't bounce, but this callback can be used for cleanup if needed
            ball:destroy()
          end
        })
        if self.ball then
          self.ball.projectileId = projectileId
          local baseDmg = (effective and effective.baseDamage) or ((config.score and config.score.baseSeed) or 0)
          self.ball.score = baseDmg
          self.score = self.score + self.ball.score
          self.baseDamageThisTurn = self.baseDamageThisTurn + baseDmg -- Track base damage for animation
        end
      elseif projectileId == "black_hole" then
        -- Black Hole: single projectile, spawns a black hole on first block hit
        self.balls = {} -- Clear multiple balls
        self.ball = Ball.new(self.world, self.aimStartX, self.aimStartY, ndx, ndy, {
          maxBounces = (effective and effective.maxBounces) or config.ball.maxBounces,
          spritePath = spritePath,
          onLastBounce = function(ball)
            ball:destroy()
          end
        })
        if self.ball then
          self.ball.projectileId = projectileId
          local baseDmg = (effective and effective.baseDamage) or ((config.score and config.score.baseSeed) or 0)
          self.ball.score = baseDmg
          self.score = self.score + self.ball.score
          self.baseDamageThisTurn = self.baseDamageThisTurn + baseDmg -- Track base damage for animation
        end
      else
        -- Single projectile (regular shot)
        self.balls = {} -- Clear multiple balls
        self.ball = Ball.new(self.world, self.aimStartX, self.aimStartY, ndx, ndy, {
          maxBounces = (effective and effective.maxBounces) or config.ball.maxBounces,
          spritePath = spritePath,
          onLastBounce = function(ball)
            -- Ball reached max bounces, destroy it - turn will end automatically
            ball:destroy()
          end
        })
        if self.ball then
          self.ball.projectileId = projectileId
          local baseDmg = (effective and effective.baseDamage) or ((config.score and config.score.baseSeed) or 0)
          self.ball.score = baseDmg
          self.score = self.score + self.ball.score
          self.baseDamageThisTurn = self.baseDamageThisTurn + baseDmg -- Track base damage for animation
        end
      end
      
      -- Spend the turn
      self.canShoot = false
      self.turnsTaken = self.turnsTaken + 1
    end
    self.isAiming = false
  end
end

-- Set the projectile ID for the shooter
function GameplayScene:setProjectile(projectileId)
  self.projectileId = projectileId or "strike"
  if self.shooter and self.shooter.setProjectile then
    self.shooter:setProjectile(self.projectileId)
  end
end

-- Update walls when canvas width changes (for tweening)
function GameplayScene:updateWalls(newWidth, newHeight)
  if not self.world or not self.wallBody then return end
  
  -- Destroy old wall fixtures
  if self.wallFixtures then
    for _, fixture in pairs(self.wallFixtures) do
      if fixture and fixture.destroy then
        fixture:destroy()
      end
    end
  end
  
  -- Calculate grid bounds to match editor exactly
  local gridStartX, gridEndX = playfield.calculateGridBounds(newWidth, newHeight)
  
  -- Create new walls with updated dimensions (account for top bar and use grid boundaries)
  local topBarHeight = (config.playfield and config.playfield.topBarHeight) or 60
  local left = love.physics.newEdgeShape(gridStartX, topBarHeight, gridStartX, newHeight)
  local right = love.physics.newEdgeShape(gridEndX, topBarHeight, gridEndX, newHeight)
  local top = love.physics.newEdgeShape(gridStartX, topBarHeight, gridEndX, topBarHeight)
  local bottomSensor = love.physics.newEdgeShape(gridStartX, newHeight, gridEndX, newHeight)
  
  local fL = love.physics.newFixture(self.wallBody, left)
  local fR = love.physics.newFixture(self.wallBody, right)
  local fT = love.physics.newFixture(self.wallBody, top)
  local fB = love.physics.newFixture(self.wallBody, bottomSensor)
  
  fL:setUserData({ type = "wall", side = "left" })
  fR:setUserData({ type = "wall", side = "right" })
  fT:setUserData({ type = "wall" })
  fB:setUserData({ type = "bottom" })
  fB:setSensor(true)
  
  self.wallFixtures = { left = fL, right = fR, top = fT, bottom = fB }
  -- Update stored grid bounds
  self.gridStartX = gridStartX
  self.gridEndX = gridEndX
  
  -- Update shooter position if needed (center within grid bounds)
  if self.shooter then
    self.shooter.x = (gridStartX + gridEndX) * 0.5
  end
end

function GameplayScene:_correctPiercePosition(ball)
  -- Correct position shifts for pierce orbs after physics step
  if not ball or not ball.pierce or not ball._piercePosition or not ball._initialDirection then
    return
  end
  
  local storedX = ball._piercePosition.x
  local storedY = ball._piercePosition.y
  local currentX = ball.body:getX()
  local currentY = ball.body:getY()
  
  -- Calculate vector from stored position to current position
  local dx = currentX - storedX
  local dy = currentY - storedY
  
  -- Project this vector onto the initial direction to get the correct position
  -- Projection: proj = (v · d) * d, where v is the vector and d is the direction
  local math2d = require("utils.math2d")
  local dirX = ball._initialDirection.x
  local dirY = ball._initialDirection.y
  local dot = dx * dirX + dy * dirY
  
  -- Calculate the correct position along the straight path
  local correctX = storedX + dirX * dot
  local correctY = storedY + dirY * dot
  
  -- Set the corrected position (world is unlocked now)
  ball.body:setPosition(correctX, correctY)
  
  -- Clear stored position and correction flag
  ball._piercePosition = nil
  ball._pierceTime = nil
  ball._needsPositionCorrection = false
end

function GameplayScene:preSolve(fixA, fixB, contact)
  -- Disable collision response for pierce orbs hitting blocks (they pierce through)
  -- With restitution=0 and direction maintained in update(), this ensures straight piercing
  local a = fixA and fixA:getUserData() or nil
  local b = fixB and fixB:getUserData() or nil
  local function getBall(x)
    return x and x.type == "ball" and x.ref or nil
  end
  local function getBlock(x)
    return x and x.type == "block" and x.ref or nil
  end
  
  local ball = getBall(a) or getBall(b)
  local block = getBlock(a) or getBlock(b)
  
  -- If a pierce orb hits a block, disable collision response (no bounce, pierces through)
  -- Store position and time before collision to prevent position shifts
  if ball and block and ball.pierce then
    if not ball._piercePosition then
      ball._piercePosition = { x = ball.body:getX(), y = ball.body:getY() }
      ball._pierceTime = love.timer.getTime()
    end
    contact:setEnabled(false)
  end
end

function GameplayScene:postSolve(fixA, fixB, contact)
  -- Mark pierce orbs that need position correction (can't modify physics during step)
  local a = fixA and fixA:getUserData() or nil
  local b = fixB and fixB:getUserData() or nil
  local function getBall(x)
    return x and x.type == "ball" and x.ref or nil
  end
  local function getBlock(x)
    return x and x.type == "block" and x.ref or nil
  end
  
  local ball = getBall(a) or getBall(b)
  local block = getBlock(a) or getBlock(b)
  
  -- Mark pierce orb for position correction after physics step
  if ball and block and ball.pierce and ball._piercePosition and ball._initialDirection then
    ball._needsPositionCorrection = true
  end
end

function GameplayScene:beginContact(fixA, fixB, contact)
  local a = fixA and fixA:getUserData() or nil
  local b = fixB and fixB:getUserData() or nil
  local function types(x)
    return x and x.type or nil
  end
  local function getBall(x)
    return x and x.type == "ball" and x.ref or nil
  end
  local function getBlock(x)
    return x and x.type == "block" and x.ref or nil
  end

  local aType, bType = types(a), types(b)
  local ball = getBall(a) or getBall(b)
  local block = getBlock(a) or getBlock(b)
  if ball and (aType == "wall" or bType == "wall") then
    -- Handle wall bounces
    local wallData = (aType == "wall" and a) or (bType == "wall" and b)
    
    if ball.pierce then
      -- Pierce orbs: destroy when hitting walls (they don't bounce)
      -- But only if the ball has moved away from spawn position AND has pierced at least one block
      -- This prevents immediate destruction when firing from the edge
      local bx, by = ball.body:getPosition()
      local dx = bx - (ball.spawnX or bx)
      local dy = by - (ball.spawnY or by)
      local distFromSpawn = math.sqrt(dx * dx + dy * dy)
      local hasPierced = (ball.pierces or 0) > 0
      -- Only destroy if moved at least 3 pixels from spawn AND has pierced at least one block
      -- This allows pierce orbs to travel through blocks even when fired from the edge
      if distFromSpawn >= 3 and hasPierced then
        ball:destroy()
      end
    else
      -- Regular orbs: normal bounce (restitution handles it)
    ball:onBounce()
    -- Trigger edge glow effect for left/right walls
    if wallData and wallData.side and self.onEdgeHit then
      local x, y = contact:getPositions()
        local bounceY = y or -200
      pcall(function() self.onEdgeHit(wallData.side, bounceY) end)
      end
    end
  end
  if ball and block then
    local destroyBallAfter = false
    -- Early exit checks: block must be alive, not already hit, and not marked as hit this frame
    if not block.alive or block.hitThisFrame or self._blocksHitThisFrame[block] then
      -- Block already destroyed or already processed this frame, skip all processing
      -- Pierce orbs don't bounce, so skip bounce call for them
      if not ball.pierce then
      ball:onBounce()
      end
      return
    end
    
    -- For pierce orbs, store position right before hitting the block
    if ball.pierce and not ball._piercePosition then
      ball._piercePosition = { x = ball.body:getX(), y = ball.body:getY() }
    end
    
    -- Mark block as hit this frame IMMEDIATELY to prevent race conditions (double check)
    self._blocksHitThisFrame[block] = true
    
    block:hit()
    -- Increment blocks hit this turn
    self.blocksHitThisTurn = (self.blocksHitThisTurn or 0) + 1
    
    -- Combo tracking: increment combo if hit within timeout window
    local currentTime = love.timer.getTime()
    local comboWindow = (config.gameplay and config.gameplay.comboWindow) or 0.5
    if currentTime - (self.lastHitTime or 0) < comboWindow then
      self.comboCount = (self.comboCount or 0) + 1
    else
      self.comboCount = 1 -- Start new combo
    end
    self.lastHitTime = currentTime
    self.comboTimeout = comboWindow
    
    -- Trigger screenshake for multi-block combos (2+ blocks)
    if self.comboCount >= 2 then
      local comboShake = config.gameplay and config.gameplay.comboShake or {}
      local baseMag = comboShake.baseMagnitude or 2
      local scalePerCombo = comboShake.scalePerCombo or 0.5
      local maxMagnitude = comboShake.maxMagnitude or 8
      local duration = comboShake.duration or 0.15
      
      local magnitude = math.min(maxMagnitude, baseMag + (self.comboCount - 2) * scalePerCombo)
      self:triggerShake(magnitude, duration)
    end
    
    local x, y = contact:getPositions()
    if x and y and self.particles then self.particles:emitSpark(x, y) end
    ball:onBlockHit() -- Trigger glow burst effect
    -- Black Hole: on first block hit spawn effect and end projectile
    if ball.projectileId == "black_hole" and not ball._blackHoleTriggered then
      ball._blackHoleTriggered = true
      local hx = x or (ball.body and select(1, ball.body:getPosition())) or block.cx
      local hy = y or (ball.body and select(2, ball.body:getPosition())) or block.cy
      self.blackHoles = self.blackHoles or {}
      table.insert(self.blackHoles, { x = hx, y = hy, t = 0, r = 0 })
      destroyBallAfter = true
    end
    
    -- Handle pierce vs bounce behavior
    if ball.pierce then
      -- Pierce orb: pierce through the block (no bounce)
      -- Velocity will be restored in postSolve to maintain straight path
      ball:onPierce()
    else
      -- Regular orb: bounce off the block
    ball:onBounce()
    end
    -- Award rewards: per-hit for all blocks. Crit sets a turn multiplier (2x total damage), Soul sets a turn multiplier (4x total damage)
    local perHit = (config.score and config.score.rewardPerHit) or 1
    local hitReward = perHit
    if block.kind == "crit" then
      self.critThisTurn = (self.critThisTurn or 0) + 1
    elseif block.kind == "multiplier" then
      -- Multiplier block marks this turn for damage multiplier
      self.multiplierThisTurn = (self.multiplierThisTurn or 0) + 1
    elseif block.kind == "aoe" then
      -- AOE block gives +3 bonus damage and marks attack as AOE
      local aoeReward = 3
      hitReward = hitReward + aoeReward
      self.aoeThisTurn = true
    elseif block.kind == "armor" then
      -- Armor blocks don't add damage, only grant armor
      hitReward = 0
    elseif block.kind == "potion" then
      -- Potion blocks don't add damage, only heal
      hitReward = 0
    end
    self.score = self.score + hitReward
    
    -- Track block hit for animated damage display (only track damage-dealing blocks)
    if block.kind == "damage" or block.kind == "attack" or block.kind == "crit" or block.kind == "multiplier" or block.kind == "aoe" then
      table.insert(self.blockHitSequence, {
        damage = hitReward,
        kind = block.kind
      })
    end
    if block.kind == "armor" then
      -- Armor block: grant armor from config by HP
      local rewardByHp = (config.armor and config.armor.rewardByHp) or {}
      local hp = (block and block.hp) or 1
      local armorGain = rewardByHp[hp] or rewardByHp[1] or 3
      self.armorThisTurn = self.armorThisTurn + armorGain
    elseif block.kind == "potion" then
      -- Potion block heals player based on config
      local healAmount = (config.heal and config.heal.potionHeal) or 8
      self.healThisTurn = self.healThisTurn + healAmount
    end
    if destroyBallAfter and ball and ball.alive then
      ball:destroy()
    end
  end
  if ball and (aType == "bottom" or bType == "bottom") then
    -- Ball hit bottom sensor, destroy it - turn will end automatically
    ball:destroy()
  end
end

-- Set TurnManager reference (called by SplitScene)
function GameplayScene:setTurnManager(turnManager)
  self.turnManager = turnManager
  -- Also pass it to shooter for turn-based display
  if self.shooter and self.shooter.setTurnManager then
    self.shooter:setTurnManager(turnManager)
  end
end

-- Reload blocks from battle profile (called when returning from formation editor)
function GameplayScene:reloadBlocks(battleProfile, bounds)
  if not self.blocks or not self.world then return end
  
  -- Clear existing blocks
  self.blocks:clearAll()
  
  -- Get bounds (use provided bounds or fallback to screen dimensions)
  local width = (bounds and bounds.w) or love.graphics.getWidth()
  local height = (bounds and bounds.h) or love.graphics.getHeight()
  
  -- Reload formation from battle profile
  local formationConfig = (battleProfile and battleProfile.blockFormation) or nil
  self.blocks:loadFormation(self.world, width, height, formationConfig)
end

-- Trigger block shake and drop effect (for enemy shockwave)
function GameplayScene:triggerBlockShakeAndDrop()
  if not self.blocks or not self.blocks.blocks then return end
  
  -- Get all alive blocks
  local aliveBlocks = {}
  for _, block in ipairs(self.blocks.blocks) do
    if block and block.alive then
      table.insert(aliveBlocks, block)
    end
  end
  
  if #aliveBlocks == 0 then return end
  
  -- Select 4-6 random blocks
  local count = love.math.random(4, 6)
  count = math.min(count, #aliveBlocks)
  
  -- Shuffle and select random blocks
  local selectedBlocks = {}
  local indices = {}
  for i = 1, #aliveBlocks do
    table.insert(indices, i)
  end
  
  -- Fisher-Yates shuffle
  for i = #indices, 1, -1 do
    local j = love.math.random(i)
    indices[i], indices[j] = indices[j], indices[i]
  end
  
  -- Select first 'count' blocks
  for i = 1, count do
    table.insert(selectedBlocks, aliveBlocks[indices[i]])
  end
  
  -- Trigger shake and drop on selected blocks
  for _, block in ipairs(selectedBlocks) do
    block.shakeTime = 0.6 -- Longer duration for visible shake and drop
    block.dropVelocity = 0 -- Start with zero velocity, gravity will accelerate downwards
    block.dropOffsetY = 0
    block.fadeAlpha = 1 -- Start fully visible
    block.shakeOffsetX = 0
    block.shakeOffsetY = 0
    -- Random rotation angle and speed for each block
    block.dropRotation = love.math.random() * math.pi * 2 -- Random initial rotation (0 to 2π)
    block.dropRotationSpeed = (love.math.random() * 2 - 1) * 3 -- Random rotation speed (-3 to 3 rad/s)
    -- Clear onDestroyed callback to prevent particle explosions - blocks should just drop and fade
    block.onDestroyed = nil
  end
end

-- Get positions of random blocks for calcify animation (returns array of {x, y, block})
function GameplayScene:getCalcifyBlockPositions(count)
  if not self.blocks or not self.blocks.blocks then return {} end
  
  count = count or 3
  
  -- Get all alive, non-calcified blocks
  local eligibleBlocks = {}
  for _, block in ipairs(self.blocks.blocks) do
    if block and block.alive and not block.calcified then
      table.insert(eligibleBlocks, block)
    end
  end
  
  if #eligibleBlocks == 0 then return {} end
  
  -- Select random blocks (up to count)
  local toSelect = math.min(count, #eligibleBlocks)
  local indices = {}
  for i = 1, #eligibleBlocks do
    table.insert(indices, i)
  end
  
  -- Fisher-Yates shuffle
  for i = #indices, 1, -1 do
    local j = love.math.random(i)
    indices[i], indices[j] = indices[j], indices[i]
  end
  
  -- Return positions of selected blocks
  local positions = {}
  for i = 1, toSelect do
    local block = eligibleBlocks[indices[i]]
    if block then
      table.insert(positions, {
        x = block.cx,
        y = block.cy,
        block = block, -- Store reference to block for later calcification
      })
    end
  end
  
  return positions
end

-- Calcify random blocks (for Stagmaw skill)
function GameplayScene:calcifyBlocks(count)
  if not self.blocks or not self.blocks.blocks then return end
  
  count = count or 3
  
  -- Get all alive, non-calcified blocks
  local eligibleBlocks = {}
  for _, block in ipairs(self.blocks.blocks) do
    if block and block.alive and not block.calcified then
      table.insert(eligibleBlocks, block)
    end
  end
  
  if #eligibleBlocks == 0 then return end
  
  -- Select random blocks (up to count)
  local toCalcify = math.min(count, #eligibleBlocks)
  local indices = {}
  for i = 1, #eligibleBlocks do
    table.insert(indices, i)
  end
  
  -- Fisher-Yates shuffle
  for i = #indices, 1, -1 do
    local j = love.math.random(i)
    indices[i], indices[j] = indices[j], indices[i]
  end
  
  -- Calcify selected blocks (permanently for the battle)
  for i = 1, toCalcify do
    local block = eligibleBlocks[indices[i]]
    if block and block.calcify then
      block:calcify(nil) -- Calcify permanently (nil = infinite turns)
    end
  end
end

-- Cleanup method: destroys all physics objects and clears references
function GameplayScene:unload()
  -- Destroy all balls (single ball and balls array)
  if self.ball and self.ball.alive then
    self.ball:destroy()
    self.ball = nil
  end
  
  if self.balls then
    for i = #self.balls, 1, -1 do
      local ball = self.balls[i]
      if ball and ball.alive then
        ball:destroy()
      end
      table.remove(self.balls, i)
    end
    self.balls = {}
  end
  
  -- Destroy all blocks via BlockManager
  if self.blocks and self.blocks.clearAll then
    self.blocks:clearAll()
  end
  self.blocks = nil
  
  -- Destroy wall fixtures (must be destroyed before body)
  if self.wallFixtures then
    for _, fixture in pairs(self.wallFixtures) do
      if fixture and fixture.destroy then
        pcall(function() fixture:destroy() end)
      end
    end
    self.wallFixtures = nil
  end
  
  -- Destroy wall body (must be destroyed before world)
  if self.wallBody and self.wallBody.destroy then
    pcall(function() self.wallBody:destroy() end)
    self.wallBody = nil
  end
  
  -- Clear world callbacks to prevent callbacks after cleanup
  if self.world then
    self.world:setCallbacks(nil, nil, nil, nil)
    self.world = nil
  end
  
  -- Clear other references
  self.shooter = nil
  self.particles = nil
  self.turnManager = nil
end

return GameplayScene


