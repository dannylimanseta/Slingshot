local config = require("config")
local theme = require("theme")
local math2d = require("utils.math2d")
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
    soulThisTurn = 0, -- count of soul blocks hit this turn
    aoeThisTurn = false, -- true if any AOE blocks were hit this turn
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
    projectileId = "qi_orb", -- default projectile ID
    topBar = TopBar.new(),
  }, GameplayScene)
end

function GameplayScene:load(bounds, projectileId, battleProfile)
  local width = (bounds and bounds.w) or love.graphics.getWidth()
  local height = (bounds and bounds.h) or love.graphics.getHeight()
  self.world = love.physics.newWorld(0, 0, true)
  self.world:setCallbacks(function(a, b, contact) self:beginContact(a, b, contact) end, nil, nil, nil)

  -- Walls (static) - account for top bar
  local topBarHeight = (config.playfield and config.playfield.topBarHeight) or 60
  local halfW, halfH = width * 0.5, height * 0.5
  self.wallBody = love.physics.newBody(self.world, 0, 0, "static")
  local left = love.physics.newEdgeShape(0, topBarHeight, 0, height)
  local right = love.physics.newEdgeShape(width, topBarHeight, width, height)
  local top = love.physics.newEdgeShape(0, topBarHeight, width, topBarHeight)
  local bottomSensor = love.physics.newEdgeShape(0, height, width, height)
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

  self.blocks = BlockManager.new()
  -- Load formation from battle profile (or use default random)
  local formationConfig = (battleProfile and battleProfile.blockFormation) or nil
  self.blocks:loadFormation(self.world, width, height, formationConfig)
  self.projectileId = projectileId or "qi_orb" -- Store projectile ID
  self.shooter = Shooter.new(width * 0.5, height - config.shooter.spawnYFromBottom, self.projectileId)
  -- Give shooter access to TurnManager for turn-based display
  if self.shooter and self.shooter.setTurnManager and self.turnManager then
    self.shooter:setTurnManager(self.turnManager)
  end
  self.particles = ParticleManager.new()

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
      if self.particles then
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
    self.shooter:update(dt, bounds)
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
end

-- Public: respawn 1-2 blocks every turn (fixed respawn rate)
function GameplayScene:respawnDestroyedBlocks(bounds)
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
  
  -- Limit spawn count to available spaces (never spawn more than available)
  local desiredSpawn = love.math.random(1, 2) -- Want to spawn 1 or 2 blocks
  local toSpawn = math.min(desiredSpawn, availableSpaces) -- But limit to available spaces
  
  if toSpawn <= 0 then return end
  
  local newBlocks = self.blocks:addRandomBlocks(self.world, width, height, toSpawn)
  for _, nb in ipairs(newBlocks) do
    nb.onDestroyed = function()
      if self.particles then
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

  -- Blocks
  self.blocks:draw()

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
      local r = math.max(1, guide.dotRadius or 2)
      local totalSteps = math.max(1, math.floor(length / spacing))
      local fade = guide.fade ~= false
      local aStart = (guide.alphaStart ~= nil) and guide.alphaStart or 1.0
      local aEnd = (guide.alphaEnd ~= nil) and guide.alphaEnd or 0.0

      -- Check if current projectile is twin_strike
      local isTwinStrike = false
      if self.shooter and self.shooter.getCurrentProjectileId then
        local projectileId = self.shooter:getCurrentProjectileId()
        isTwinStrike = (projectileId == "twin_strike")
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
        -- Left wall at x = 0 + ballR
        if dirX < 0 then
          local t = ((0 + ballR) - originX) / dirX
          if t > 1e-4 then
            local y = originY + dirY * t
            if y >= 0 and y <= height and t < tHit then
              considerHit(t, 0 + ballR, y, 1, 0)
            end
          end
        end
        -- Right wall at x = width - ballR
        if dirX > 0 then
          local t = ((width - ballR) - originX) / dirX
          if t > 1e-4 then
            local y = originY + dirY * t
            if y >= 0 and y <= height and t < tHit then
              considerHit(t, width - ballR, y, -1, 0)
            end
          end
        end
        -- Top wall at y = 0 + ballR
        if dirY < 0 then
          local t = ((0 + ballR) - originY) / dirY
          if t > 1e-4 then
            local x = originX + dirX * t
            if x >= 0 and x <= width and t < tHit then
              considerHit(t, x, 0 + ballR, 0, 1)
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
  
  -- Draw top bar on top (z-order)
  if self.topBar then
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
      self.critThisTurn = 0
      self.soulThisTurn = 0
      self.aoeThisTurn = false
      self.blocksHitThisTurn = 0
      -- Reset combo when new shot starts
      self.comboCount = 0
      self.comboTimeout = 0
      self.lastHitTime = 0
      
      -- Get current projectile ID from shooter based on turn rotation
      local projectileId = "qi_orb"
      if self.shooter and self.shooter.getCurrentProjectileId then
        projectileId = self.shooter:getCurrentProjectileId()
      else
        projectileId = self.projectileId or "qi_orb"
      end
      
      -- Get projectile data to determine behavior and sprite
      local projectileData = ProjectileManager.getProjectile(projectileId)
      local spritePath = nil
      if projectileData and projectileData.icon then
        spritePath = projectileData.icon
      end
      
      if projectileId == "twin_strike" then
        -- Twin Strike: spawn 2 mirrored projectiles (mirrored on x-axis)
        self.ball = nil -- Clear single ball
        self.balls = {}
        if not spritePath then
          spritePath = (config.assets.images.ball_3) or "assets/images/ball_3.png"
        end
        local maxBounces = 5
        
        -- First ball: original direction
        local ball1 = Ball.new(self.world, self.aimStartX, self.aimStartY, ndx, ndy, {
          maxBounces = maxBounces,
          spritePath = spritePath,
          onLastBounce = function(ball)
            ball:destroy()
          end
        })
        
        -- Second ball: mirrored on x-axis (flip x direction)
        local ball2 = Ball.new(self.world, self.aimStartX, self.aimStartY, -ndx, ndy, {
          maxBounces = maxBounces,
          spritePath = spritePath,
          onLastBounce = function(ball)
            ball:destroy()
          end
        })
        
        if ball1 then
          ball1.score = (config.score and config.score.baseSeed) or 0
          self.score = self.score + ball1.score
          table.insert(self.balls, ball1)
        end
        if ball2 then
          ball2.score = (config.score and config.score.baseSeed) or 0
          self.score = self.score + ball2.score
          table.insert(self.balls, ball2)
        end
      elseif projectileId == "spread_shot" then
        -- Spread shot: spawn multiple projectiles
        local spreadConfig = config.ball.spreadShot
        if spreadConfig and spreadConfig.enabled then
        self.ball = nil -- Clear single ball
        self.balls = {}
        local count = spreadConfig.count or 3
        local spreadAngle = spreadConfig.spreadAngle or 0.15
        local radiusScale = spreadConfig.radiusScale or 0.7
          if not spritePath then
            spritePath = spreadConfig.sprite or (config.assets.images.ball_2)
          end
        local maxBounces = spreadConfig.maxBounces or 3
        
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
            ball.score = (config.score and config.score.baseSeed) or 0
            self.score = self.score + ball.score
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
            self.ball.score = (config.score and config.score.baseSeed) or 0
            self.score = self.score + self.ball.score
          end
        end
      else
        -- Single projectile (regular shot)
        self.balls = {} -- Clear multiple balls
        self.ball = Ball.new(self.world, self.aimStartX, self.aimStartY, ndx, ndy, {
          spritePath = spritePath,
          onLastBounce = function(ball)
            -- Ball reached max bounces, destroy it - turn will end automatically
            ball:destroy()
          end
        })
        if self.ball then
          self.ball.score = (config.score and config.score.baseSeed) or 0
          self.score = self.score + self.ball.score
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
  self.projectileId = projectileId or "qi_orb"
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
  
  -- Create new walls with updated dimensions (account for top bar)
  local topBarHeight = (config.playfield and config.playfield.topBarHeight) or 60
  local left = love.physics.newEdgeShape(0, topBarHeight, 0, newHeight)
  local right = love.physics.newEdgeShape(newWidth, topBarHeight, newWidth, newHeight)
  local top = love.physics.newEdgeShape(0, topBarHeight, newWidth, topBarHeight)
  local bottomSensor = love.physics.newEdgeShape(0, newHeight, newWidth, newHeight)
  
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
  
  -- Update shooter position if needed
  if self.shooter then
    self.shooter.x = newWidth * 0.5
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
    ball:onBounce()
    -- Trigger edge glow effect for left/right walls
    local wallData = (aType == "wall" and a) or (bType == "wall" and b)
    if wallData and wallData.side and self.onEdgeHit then
      -- Get bounce position from contact
      local x, y = contact:getPositions()
      local bounceY = y or -200 -- Use contact y-position or default
      -- Call the callback to trigger glow effect with y-position
      pcall(function() self.onEdgeHit(wallData.side, bounceY) end)
    end
  end
  if ball and block then
    -- Early exit checks: block must be alive, not already hit, and not marked as hit this frame
    if not block.alive or block.hitThisFrame or self._blocksHitThisFrame[block] then
      -- Block already destroyed or already processed this frame, skip all processing
      ball:onBounce()
      return
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
    ball:onBounce()
    -- Award rewards: per-hit for all blocks. Crit sets a turn multiplier (2x total damage), Soul sets a turn multiplier (4x total damage)
    local perHit = (config.score and config.score.rewardPerHit) or 1
    local hitReward = perHit
    if block.kind == "crit" then
      self.critThisTurn = (self.critThisTurn or 0) + 1
    elseif block.kind == "soul" then
      -- Soul block gives x4 multiplier (count as soul block)
      self.soulThisTurn = (self.soulThisTurn or 0) + 1
    elseif block.kind == "aoe" then
      -- AOE block gives +3 bonus damage and marks attack as AOE
      local aoeReward = 3
      hitReward = hitReward + aoeReward
      self.aoeThisTurn = true
    end
    self.score = self.score + hitReward
    if block.kind == "armor" then
      local armorMap = config.armor and config.armor.rewardByHp or nil
      if armorMap then
        local hpBeforeHit = math.max(1, block.hp + 1) -- hp was decremented in hit()
        local reward = armorMap[math.max(1, math.min(3, hpBeforeHit))] or 0
        self.armorThisTurn = self.armorThisTurn + reward
      end
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

return GameplayScene


