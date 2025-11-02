local theme = require("theme")
local config = require("config")
local Trail = require("utils.trail")
local GameplayScene = require("scenes.GameplayScene")
local BattleScene = require("scenes.BattleScene")
local TurnManager = require("core.TurnManager")
local TurnActions = require("systems.TurnActions")
local ProjectileCard = require("ui.ProjectileCard")
local LayoutManager = require("managers.LayoutManager")
local battle_profiles = require("data.battle_profiles")
local TopBar = require("ui.TopBar")

-- Utility: radial gradient image for glow (alpha falls off toward edge)
-- Shared with Ball entity for consistency
local function makeRadialGlow(diameter)
  local data = love.image.newImageData(diameter, diameter)
  local cx = (diameter - 1) * 0.5
  local cy = (diameter - 1) * 0.5
  local r = diameter * 0.5 - 0.5
  data:mapPixel(function(x, y)
    local dx = x - cx
    local dy = y - cy
    local dist = math.sqrt(dx * dx + dy * dy)
    local t = math.min(1, math.max(0, dist / r))
    local a = (1 - t)
    a = a * a -- quadratic falloff for softer edge
    return 1, 1, 1, a
  end)
  return love.graphics.newImage(data)
end

local SplitScene = {}
SplitScene.__index = SplitScene

function SplitScene.new()
  return setmetatable({ 
    left = nil, 
    right = nil, 
    -- Turn management system
    turnManager = nil,
    -- Projectile card UI
    projectileCard = nil,
    currentProjectileId = "qi_orb", -- Default projectile
    _prevProjectileId = nil, -- Track previous projectile for fade detection
    tooltipFadeTimer = 0, -- Timer for tooltip fade animation
    tooltipFadeDuration = 0.3, -- Duration of fade animation in seconds
    -- Layout management for dynamic canvas width
    layoutManager = LayoutManager.new(),
    _lastCenterW = nil, -- Track width changes for wall updates
    -- Edge glow effects
    edgeGlowImage = nil,
    edgeGlowLeftTimer = 0,
    edgeGlowRightTimer = 0,
    edgeGlowLeftY = 0, -- Y position of left edge bounce
    edgeGlowRightY = 0, -- Y position of right edge bounce
    edgeGlowDuration = 0.3, -- Duration of glow effect in seconds
    -- Left boundary damage effect
    boundaryLeftDamageTimer = 0, -- Timer for left boundary fade-in when player takes damage
    boundaryLeftDamageDuration = 0.5, -- Duration of fade-in effect
    -- Screenshake for full screen
    shakeTime = 0,
    shakeDuration = 0,
    shakeMagnitude = 0,
    -- Victory/defeat detection flags
    _victoryDetected = false,
    _defeatDetected = false,
    _returnToMapTimer = 0,
    topBar = TopBar.new(),
  }, SplitScene)
end

function SplitScene:load()
  -- Use virtual resolution from config (matches canvas size)
  local w = (config.video and config.video.virtualWidth) or 1280
  local h = (config.video and config.video.virtualHeight) or 720
  local centerRect = self.layoutManager:getCenterRect(w, h)
  self.left = GameplayScene.new()
  self.right = BattleScene.new()
  
  -- Get current battle profile and pass to GameplayScene for block formation
  local currentBattleType = self.layoutManager:getBattleType()
  local battleProfile = battle_profiles.getProfile(currentBattleType)
  
  self.left:load({ x = 0, y = 0, w = centerRect.w, h = h }, self.currentProjectileId, battleProfile)
  self.right:load({ x = centerRect.w, y = 0, w = w - centerRect.w, h = h }, battleProfile)
  self._lastCenterW = centerRect.w

  -- Increase current enemy size (runtime multiplier)
  if self.right and self.right.setEnemySprite then
    self.right:setEnemySprite(nil, 1.3)
  end

  -- Background image (optional)
  self.bgImage = nil
  local bgPath = (config.assets and config.assets.images and config.assets.images.background) or nil
  if bgPath then
    local ok, img = pcall(love.graphics.newImage, bgPath)
    if ok then self.bgImage = img end
  end

  -- Boundary images for left and right edges
  self.boundaryLeft = nil
  self.boundaryRight = nil
  local boundaryLeftPath = "assets/images/boundary_left.png"
  local boundaryRightPath = "assets/images/boundary_right.png"
  local okLeft, imgLeft = pcall(love.graphics.newImage, boundaryLeftPath)
  if okLeft then self.boundaryLeft = imgLeft end
  local okRight, imgRight = pcall(love.graphics.newImage, boundaryRightPath)
  if okRight then self.boundaryRight = imgRight end

  -- Edge glow image for ball hits
  self.edgeGlowImage = nil
  local edgeGlowPath = "assets/images/fx/edge_glow.png"
  local okGlow, imgGlow = pcall(love.graphics.newImage, edgeGlowPath)
  if okGlow then self.edgeGlowImage = imgGlow end


  -- Set up callback for when player takes damage
  self.right.onPlayerDamage = function()
    -- Trigger left boundary fade-in effect
    self.boundaryLeftDamageTimer = self.boundaryLeftDamageDuration
    -- Trigger screenshake
    self:triggerShake((config.battle and config.battle.shakeMagnitude) or 10, (config.battle and config.battle.shakeDuration) or 0.25)
  end

  -- Enemy turn resolved callback removed - handled by TurnManager events
  
  -- Initialize TurnManager
  self.turnManager = TurnManager.new()
  TurnActions.registerAll(self.turnManager)
  
  -- Give BattleScene access to TurnManager
  if self.right and self.right.setTurnManager then
    self.right:setTurnManager(self.turnManager)
  end
  
  -- Give GameplayScene access to TurnManager
  if self.left and self.left.setTurnManager then
    self.left:setTurnManager(self.turnManager)
  end

  -- Edge hit callback for glow effect
  if self.left then
    self.left.onEdgeHit = function(side, y)
      if side == "left" then
        self.edgeGlowLeftTimer = self.edgeGlowDuration
        self.edgeGlowLeftY = y or -200 -- Use bounce y-position or default
      elseif side == "right" then
        self.edgeGlowRightTimer = self.edgeGlowDuration
        self.edgeGlowRightY = y or -200 -- Use bounce y-position or default
      end
    end
  end
  
  
  -- Set up event handlers for TurnManager
  self:setupTurnManagerEvents()
  
  -- Initialize projectile card UI
  self.projectileCard = ProjectileCard.new()
  
  -- Show initial "PLAYER'S TURN" indicator at game start using TurnManager
  -- Start the first player turn
  self.turnManager:startPlayerTurn()
end

-- Set up TurnManager event handlers
function SplitScene:setupTurnManagerEvents()
  if not self.turnManager then return end
  
  -- Show turn indicator event
  self.turnManager:on("show_turn_indicator", function(data)
    if self.right and self.right.showTurnIndicator then
      -- Ensure we have valid data
      local text = data and data.text or "TURN"
      local duration = data and data.duration or 1.0
      self.right:showTurnIndicator(text, duration)
    end
  end)
  
  -- Enable shooting when player turn becomes active
  self.turnManager:on("state_enter", function(newState, previousState)
    if newState == TurnManager.States.PLAYER_TURN_ACTIVE then
      if self.left then
        self.left.canShoot = true
      end
    elseif newState == TurnManager.States.PLAYER_TURN_START then
      -- Disable shooting at start of turn (will be enabled when active)
      if self.left then
        self.left.canShoot = false
      end
    end
  end)
  
  -- Apply damage event (when player turn ends)
  self.turnManager:on("apply_damage", function(data)
    if data.target == "enemy" and self.right and self.right.onPlayerTurnEnd then
      local turnData = self.turnManager:getTurnData()
      -- Call the old method but only pass damage (armor will be handled separately)
      -- Pass AOE flag as third parameter
      self.right:onPlayerTurnEnd(data.amount, turnData.armor or 0, turnData.isAOE or false)
      -- Trigger screenshake for player attack
      self:triggerShake((config.battle and config.battle.shakeMagnitude) or 10, (config.battle and config.battle.shakeDuration) or 0.25)
    end
  end)
  
  -- Show armor popup event
  self.turnManager:on("show_armor_popup", function(data)
    -- This is already handled by BattleScene's onPlayerTurnEnd via pendingArmor
    -- No additional action needed here
  end)
  
  -- Check victory event
  self.turnManager:on("check_victory", function()
    if self.right and self.right.enemies then
      local allDefeated = true
      for _, enemy in ipairs(self.right.enemies) do
        if enemy.hp > 0 and not enemy.disintegrating then
          allDefeated = false
          break
        end
      end
      if allDefeated then
      self.turnManager:transitionTo(TurnManager.States.VICTORY)
      end
    end
  end)
  
  -- Enemy attack event (handled by BattleScene directly)
  
  -- Check defeat event
  self.turnManager:on("check_defeat", function()
    if self.right and self.right.playerHP and self.right.playerHP <= 0 then
      self.turnManager:transitionTo(TurnManager.States.DEFEAT)
    end
  end)
  
  -- Spawn blocks event
  self.turnManager:on("spawn_blocks", function(data)
    if self.left and self.left.respawnDestroyedBlocks then
      local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
      local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
      local centerRect = self.layoutManager:getCenterRect(vw, vh)
      self.left:respawnDestroyedBlocks({ x = 0, y = 0, w = centerRect.w, h = vh })
    end
  end)
end

-- Helper function to end player turn using TurnManager
function SplitScene:endPlayerTurnWithTurnManager()
  local state = self.turnManager:getState()
  if state ~= TurnManager.States.PLAYER_TURN_ACTIVE then return false end
  
  -- Collect turn data
  local turnScore = self.left and self.left.score or 0
  local mult = (config.score and config.score.critMultiplier) or 2
  local critCount = (self.left and self.left.critThisTurn) or 0
  local soulCount = (self.left and self.left.soulThisTurn) or 0
  
  -- Apply crit multiplier (2x per crit)
  if critCount > 0 then
    turnScore = turnScore * (mult ^ critCount)
  end
  
  -- Apply soul multiplier (4x per soul block)
  if soulCount > 0 then
    local soulMult = 4
    turnScore = turnScore * (soulMult ^ soulCount)
  end
  
  local armor = self.left and self.left.armorThisTurn or 0
  local blocksDestroyed = self.left and self.left.destroyedThisTurn or 0
  local isAOE = (self.left and self.left.aoeThisTurn) or false
  
  -- End the turn using TurnManager
  self.turnManager:endPlayerTurn({
    score = turnScore,
    armor = armor,
    crits = critCount,
    blocksDestroyed = blocksDestroyed,
    isAOE = isAOE,
  })
  
  return true
end

function SplitScene:resize(width, height)
  -- Use virtual resolution from config for layout calculations (resize is called with window dimensions, but we work in virtual space)
  local w = (config.video and config.video.virtualWidth) or 1280
  local h = (config.video and config.video.virtualHeight) or 720
  local centerRect = self.layoutManager:getCenterRect(w, h)
  if self.left and self.left.resize then self.left:resize(centerRect.w, h) end
  if self.right and self.right.resize then self.right:resize(w - centerRect.w, h) end
  -- Update walls if width changed significantly
  if self._lastCenterW and math.abs(centerRect.w - self._lastCenterW) > 1 then
    if self.left and self.left.updateWalls then
      self.left:updateWalls(centerRect.w, h)
    end
    self._lastCenterW = centerRect.w
  end
end


local function withScissor(bounds, fn)
  love.graphics.push("all")
  love.graphics.setScissor(bounds.x, bounds.y, bounds.w, bounds.h)
  love.graphics.translate(bounds.x, bounds.y)
  fn()
  love.graphics.pop()
end

function SplitScene:draw()
  -- Always use virtual resolution from config (matches canvas size)
  local w = (config.video and config.video.virtualWidth) or 1280
  local h = (config.video and config.video.virtualHeight) or 720
  local centerRect = self.layoutManager:getCenterRect(w, h)
  local centerW = centerRect.w
  local centerX = centerRect.x - 100 -- Shift breakout canvas 100px to the left

  -- Apply screenshake as a camera translation (ease-out)
  love.graphics.push()
  if self.shakeTime > 0 and self.shakeDuration > 0 then
    local t = self.shakeTime / self.shakeDuration
    local ease = t * t -- quadratic ease-out
    local mag = self.shakeMagnitude * ease
    local ox = (love.math.random() * 2 - 1) * mag
    local oy = (love.math.random() * 2 - 1) * mag
    love.graphics.translate(ox, oy)
  end

  -- Background clear
  love.graphics.clear(theme.colors.background)

  -- Draw background image if available (cover)
  if self.bgImage then
    local iw, ih = self.bgImage:getWidth(), self.bgImage:getHeight()
    if iw > 0 and ih > 0 then
      local sx = w / iw
      local sy = h / ih
      local s = math.max(sx, sy)
      local dx = (w - iw * s) * 0.5
      local dy = (h - ih * s) * 0.5
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(self.bgImage, dx, dy, 0, s, s)
      love.graphics.setColor(1, 1, 1, 1)
    end
  end

  -- Draw battle scene across full screen first (so gameplay can overlay center)
  if self.right and self.right.draw then
    self.right:draw({ x = 0, y = 0, w = w, h = h, center = { x = centerX, w = centerW, h = h } })
  end

  -- Draw boundary images at left and right edges of breakout canvas (outside scissor so they extend outward)
  love.graphics.push("all")
  love.graphics.setBlendMode("add")
  
  -- Left boundary with damage effect
  if self.boundaryLeft then
    local iw, ih = self.boundaryLeft:getWidth(), self.boundaryLeft:getHeight()
    if iw > 0 and ih > 0 then
      local scale = h / ih -- Scale to match canvas height
      local widthScale = scale * 1.1 -- Increase width by 10%
      local scaledWidth = iw * widthScale
      
      -- Calculate fade-in alpha for damage effect
      local baseAlpha = 0.1
      local damageAlpha = 0
      if self.boundaryLeftDamageTimer > 0 then
        -- Smooth fade: quick fade in (first 20%), hold briefly, then smooth fade out
        local progress = 1 - (self.boundaryLeftDamageTimer / self.boundaryLeftDamageDuration)
        local fadeInEnd = 0.2
        local fadeOutStart = 0.4
        
        if progress <= fadeInEnd then
          -- Fade in: 0 to 1 over first 20% using ease-out curve
          local t = progress / fadeInEnd
          damageAlpha = 1 - (1 - t) * (1 - t) -- Ease-out quadratic
        elseif progress >= fadeOutStart then
          -- Fade out: 1 to 0 over last 60% using ease-in curve
          local t = (progress - fadeOutStart) / (1 - fadeOutStart)
          damageAlpha = 1 - t * t -- Ease-in quadratic (smooth fade to 0)
        else
          -- Hold at full intensity between fade in and fade out
          damageAlpha = 1
        end
      end
      
      -- Apply tint color #E0707E when damage effect is active, otherwise use white
      local r, g, b = 1, 1, 1
      if damageAlpha > 0 then
        -- Player damage color: #E0707E = RGB(224, 112, 126)
        r, g, b = 224/255, 112/255, 126/255
        -- Blend base alpha with damage alpha (max intensity when damageAlpha = 1)
        local totalAlpha = baseAlpha + damageAlpha * 0.9
        love.graphics.setColor(r, g, b, totalAlpha)
      else
        love.graphics.setColor(r, g, b, baseAlpha)
      end
      
      -- Align right edge of image to left canvas edge (origin at top-right, extends leftward, 100px up)
      love.graphics.draw(self.boundaryLeft, centerX, -100, 0, widthScale, scale, scaledWidth, 0)
    end
  end
  
  -- Right boundary (unchanged)
  love.graphics.setColor(1, 1, 1, 0.1)
  
  if self.boundaryRight then
    local iw, ih = self.boundaryRight:getWidth(), self.boundaryRight:getHeight()
    if iw > 0 and ih > 0 then
      local scale = h / ih -- Scale to match canvas height
      local widthScale = scale * 1.1 -- Increase width by 10%
      -- Align left edge of image to right canvas edge (extends rightward, 100px up)
      love.graphics.draw(self.boundaryRight, centerX + centerW, -100, 0, widthScale, scale)
    end
  end
  
  love.graphics.pop()

  -- Draw gameplay centered using scissor & local coordinates
  withScissor({ x = centerX, y = 0, w = centerW, h = h }, function()
    if self.left and self.left.draw then self.left:draw({ x = 0, y = 0, w = centerW, h = h }) end
  end)

  -- Draw edge glow effects when ball hits edges (after gameplay scene, outside scissor so they're not clipped)
  -- Push state to save scissor, then clear it
  love.graphics.push("all")
  love.graphics.setScissor() -- Disable scissor
  love.graphics.setBlendMode("add") -- Use additive blending for glows
  
  -- Left edge glow (aligned to left edge of shifted canvas)
  if self.edgeGlowLeftTimer > 0 then
    local glowAlpha = (self.edgeGlowLeftTimer / self.edgeGlowDuration) * 0.8 -- Fade from 0.8 to 0
    
    if self.edgeGlowImage then
      local iw, ih = self.edgeGlowImage:getWidth(), self.edgeGlowImage:getHeight()
      if iw > 0 and ih > 0 then
        local scale = (h / ih) * 0.5 -- Reduce size by 50%
        local scaledWidth = iw * scale
        love.graphics.setColor(1, 1, 1, glowAlpha)
        -- Align right edge of glow to left canvas edge (centerX)
        -- Flip horizontally (negative x-scale) with origin at top-right for x, center for y
        -- When flipped, origin (0, ih/2) becomes the right edge at center vertically
        -- Position at centerX and bounce y-position (y-position is now at center of glow)
        love.graphics.draw(self.edgeGlowImage, centerX, self.edgeGlowLeftY, 0, -scale, scale, 0, ih * 0.5)
      end
    else
      -- Fallback: draw a simple rectangle if image doesn't load
      love.graphics.setColor(1, 0.5, 0, glowAlpha)
      love.graphics.rectangle("fill", centerX - 20, self.edgeGlowLeftY, 20, h)
    end
  end
  
  -- Right edge glow (aligned to left of boundary_right, extends outward to the right)
  if self.edgeGlowRightTimer > 0 then
    local glowAlpha = (self.edgeGlowRightTimer / self.edgeGlowDuration) * 0.8 -- Fade from 0.8 to 0
    
    if self.edgeGlowImage then
      local iw, ih = self.edgeGlowImage:getWidth(), self.edgeGlowImage:getHeight()
      if iw > 0 and ih > 0 then
        local scale = (h / ih) * 0.5 -- Reduce size by 50%
        love.graphics.setColor(1, 1, 1, glowAlpha)
        -- Align left edge of glow to right canvas edge (centerX + centerW)
        -- Don't flip - draw normally so it extends rightward outward
        -- Position at bounce y-position (y-position is now at center of glow)
        -- Origin at (0, ih/2) so vertically centered
        love.graphics.draw(self.edgeGlowImage, centerX + centerW, self.edgeGlowRightY, 0, scale, scale, 0, ih * 0.5)
      end
    else
      -- Fallback: draw a simple rectangle if image doesn't load
      love.graphics.setColor(1, 0.5, 0, glowAlpha)
      love.graphics.rectangle("fill", centerX + centerW, self.edgeGlowRightY, 20, h)
    end
  end
  
  love.graphics.pop() -- Restore state

  -- Draw vertical guide lines marking center area (subtle)
  love.graphics.setColor(1, 1, 1, 0.0)
  love.graphics.setLineWidth(2)
  love.graphics.line(centerX, 0, centerX, h)
  love.graphics.line(centerX + centerW, 0, centerX + centerW, h)
  love.graphics.setColor(1, 1, 1, 1)

  -- Draw turn indicator overlay and text at highest z-depth (on top of everything)
  if self.right and self.right.turnIndicator then
    local lifetime = 1.0
    local t = self.right.turnIndicator.t / lifetime -- 1 -> 0
    local fadeStart = 0.4 -- Start fading at 40% of lifetime
    local alpha = 1.0
    if t < fadeStart then
      -- Fade out
      alpha = t / fadeStart
    end
    
    -- Draw black overlay (0.6 alpha)
    love.graphics.setColor(0, 0, 0, 0.6 * alpha)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Pop-in scale animation (easeOutBack)
    local scale = 1.0
    if t > 0.7 then
      local popT = (1.0 - t) / 0.3 -- 0 -> 1
      local c1, c3 = 1.70158, 2.70158
      local u = (popT - 1)
      scale = 1 + c3 * (u * u * u) + c1 * (u * u)
    end
    
    love.graphics.push()
    love.graphics.setFont(theme.fonts.jackpot or theme.fonts.large)
    local text = self.right.turnIndicator.text
    local font = theme.fonts.jackpot or theme.fonts.large
    local textW = font:getWidth(text)
    local centerRect = self.layoutManager:getCenterRect(w, h)
    local centerX = centerRect.x + centerRect.w * 0.5 -- Center of center area
    local centerY = h * 0.5 - 50 -- Shifted up by 50px
    
    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    love.graphics.scale(scale, scale)
    theme.drawTextWithOutline(text, -textW * 0.5, -font:getHeight() * 0.5, 1, 1, 1, alpha, 4)
    love.graphics.pop()
    
    love.graphics.setFont(theme.fonts.base)
    love.graphics.pop()
  end
  
  love.graphics.pop() -- Pop screenshake transform
  -- Draw projectile card at bottom-left
  if self.projectileCard then
    -- Get current projectile ID from shooter's rotation system
    local ProjectileManager = require("managers.ProjectileManager")
    local projectileIdToShow = "qi_orb"
    
    -- Get projectile ID from shooter if available (uses dynamic rotation)
    if self.left and self.left.shooter and self.left.shooter.getCurrentProjectileId then
      projectileIdToShow = self.left.shooter:getCurrentProjectileId()
      else
      -- Fallback to stored projectile ID
        projectileIdToShow = self.currentProjectileId or "qi_orb"
    end
    
    if projectileIdToShow then
      local cardMargin = 32 -- Increased padding from edges
      local cardX = cardMargin
      -- Calculate card height dynamically
      local projectile = ProjectileManager.getProjectile(projectileIdToShow)
      local cardH = 90 -- Default fallback
      if projectile and self.projectileCard.calculateHeight then
        cardH = self.projectileCard:calculateHeight(projectile)
      end
      local cardY = h - cardH - cardMargin
      
      -- Calculate fade alpha (fade out then fade in)
      local fadeAlpha = 1.0
      if self.tooltipFadeTimer > 0 then
        local fadeProgress = self.tooltipFadeTimer / self.tooltipFadeDuration
        -- Fade out in first half, fade in in second half
        if fadeProgress > 0.5 then
          fadeAlpha = (fadeProgress - 0.5) * 2 -- 0 to 1 from 0.5 to 0
        else
          fadeAlpha = 1 - (fadeProgress * 2) -- 1 to 0 from 0 to 0.5
        end
      end
      
      self.projectileCard:draw(cardX, cardY, projectileIdToShow, fadeAlpha)
    end
  end
  
  -- Draw top bar on top (z-order)
  if self.topBar then
    self.topBar:draw()
  end
end

local function pointInBounds(x, y, b)
  return x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h
end

function SplitScene:mousepressed(x, y, button)
  local w = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
  local h = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
  local centerRect = self.layoutManager:getCenterRect(w, h)
  local centerX = centerRect.x - 100 -- Shift breakout canvas 100px to the left
  local centerBounds = { x = centerX, y = 0, w = centerRect.w, h = h }
  if pointInBounds(x, y, centerBounds) and self.left and self.left.mousepressed then
    self.left:mousepressed(x - centerBounds.x, y - centerBounds.y, button, centerBounds)
  elseif self.right and self.right.mousepressed then
    -- Forward clicks outside center to battle scene with full-screen bounds
    self.right:mousepressed(x, y, button, { x = 0, y = 0, w = w, h = h, center = centerRect.center })
  end
end

function SplitScene:mousereleased(x, y, button)
  local w = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
  local h = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
  local centerRect = self.layoutManager:getCenterRect(w, h)
  local centerX = centerRect.x - 100 -- Shift breakout canvas 100px to the left
  local centerBounds = { x = centerX, y = 0, w = centerRect.w, h = h }
  if pointInBounds(x, y, centerBounds) and self.left and self.left.mousereleased then
    self.left:mousereleased(x - centerBounds.x, y - centerBounds.y, button, centerBounds)
  elseif self.right and self.right.mousereleased then
    self.right:mousereleased(x, y, button, { x = 0, y = 0, w = w, h = h, center = centerRect.center })
  end
end

function SplitScene:mousemoved(x, y, dx, dy)
  local w = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
  local h = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
  local centerRect = self.layoutManager:getCenterRect(w, h)
  local centerX = centerRect.x - 100 -- Shift breakout canvas 100px to the left
  local centerBounds = { x = centerX, y = 0, w = centerRect.w, h = h }
  if pointInBounds(x, y, centerBounds) and self.left and self.left.mousemoved then
    self.left:mousemoved(x - centerBounds.x, y - centerBounds.y, dx, dy, centerBounds)
  elseif self.right and self.right.mousemoved then
    self.right:mousemoved(x, y, dx, dy, { x = 0, y = 0, w = w, h = h, center = centerRect.center })
  end
end

function SplitScene:keypressed(key, scancode, isRepeat)
  if key == "p" then
    -- Signal to open formation editor
    return "open_formation_editor"
  elseif key == "escape" then
    -- Return to map (manual exit from battle)
    return "return_to_map"
  end
  -- Forward keypress to sub-scenes if needed
  if self.left and self.left.keypressed then
    self.left:keypressed(key, scancode, isRepeat)
  end
  if self.right and self.right.keypressed then
    self.right:keypressed(key, scancode, isRepeat)
  end
end

-- Bridge: when left turn ends, forward score to right
-- We detect the transition from canShoot=false to canShoot=true and ball=nil
function SplitScene:update(dt)
  -- Update layout manager (handles tweening)
  if self.layoutManager then
    self.layoutManager:update(dt)
  end

  -- Update edge glow timers
  if self.edgeGlowLeftTimer > 0 then
    self.edgeGlowLeftTimer = math.max(0, self.edgeGlowLeftTimer - dt)
  end
  if self.edgeGlowRightTimer > 0 then
    self.edgeGlowRightTimer = math.max(0, self.edgeGlowRightTimer - dt)
  end
  
  -- Update left boundary damage effect timer
  if self.boundaryLeftDamageTimer > 0 then
    self.boundaryLeftDamageTimer = math.max(0, self.boundaryLeftDamageTimer - dt)
  end
  
  -- Update screenshake timer
  if self.shakeTime > 0 then
    self.shakeTime = math.max(0, self.shakeTime - dt)
    if self.shakeTime <= 0 then
      self.shakeTime = 0
      self.shakeDuration = 0
      self.shakeMagnitude = 0
    end
  end
  
  -- Always use virtual resolution from config (matches canvas size)
  local w = (config.video and config.video.virtualWidth) or 1280
  local h = (config.video and config.video.virtualHeight) or 720
  local centerRect = self.layoutManager:getCenterRect(w, h)
  
  -- Update walls if width changed significantly (for smooth tweening)
  if self._lastCenterW and math.abs(centerRect.w - self._lastCenterW) > 1 then
    if self.left and self.left.updateWalls then
      self.left:updateWalls(centerRect.w, h)
    end
    self._lastCenterW = centerRect.w
  elseif not self._lastCenterW then
    self._lastCenterW = centerRect.w
  end

  -- Call sub-updates (battle gets full context + where center is)
  if self.left and self.left.update then self.left:update(dt, { x = 0, y = 0, w = centerRect.w, h = h }) end
  if self.right and self.right.update then self.right:update(dt, { x = 0, y = 0, w = w, h = h, center = centerRect.center }) end

  -- Detect turn end: when player turn is active and all balls are gone
  local canShoot = self.left and self.left.canShoot
  local hasSingleBall = (self.left and self.left.ball and self.left.ball.alive) and true or false
  local hasMultipleBalls = false
  if self.left and self.left.balls then
    for _, ball in ipairs(self.left.balls) do
      if ball and ball.alive then
        hasMultipleBalls = true
        break
      end
    end
  end
  local hasBall = hasSingleBall or hasMultipleBalls
  
  -- Detect shot start (transition from inactive to active)
  self._prevShotActive = self._prevShotActive or false
  local shotActive = (canShoot == false and hasBall)
  self._prevShotActive = shotActive

  -- Turn ended: player turn active, shot was fired, and no balls remain
  local turnState = self.turnManager:getState()
  local shotWasFired = (canShoot == false) -- If canShoot is false, a shot was fired
  if turnState == TurnManager.States.PLAYER_TURN_ACTIVE and shotWasFired and not hasBall then
    -- Trigger impact VFX
    if self.right and self.right.playImpact then
      local blockCount = (self.left and self.left.blocksHitThisTurn) or 1
      local isCrit = (self.left and self.left.critThisTurn and self.left.critThisTurn > 0) or false
      self.right:playImpact(blockCount, isCrit)
    end
    -- End the turn using TurnManager
    self:endPlayerTurnWithTurnManager()
  end

  -- (Jackpot feed removed)

  -- Ensure TurnManager processes its action queue each frame
  if self.turnManager and self.turnManager.update then
    self.turnManager:update(dt)
  end
  
  -- Detect projectile changes and trigger fade animation
  -- Get current projectile ID from shooter's rotation system
  local projectileIdToShow = "qi_orb"
  if self.left and self.left.shooter and self.left.shooter.getCurrentProjectileId then
    projectileIdToShow = self.left.shooter:getCurrentProjectileId()
  else
    -- Fallback to stored projectile ID
      projectileIdToShow = self.currentProjectileId or "qi_orb"
  end
  
  -- Check if projectile changed
  if projectileIdToShow ~= self._prevProjectileId then
    if self._prevProjectileId ~= nil then
      -- Projectile changed, start fade animation
      self.tooltipFadeTimer = self.tooltipFadeDuration
    end
    self._prevProjectileId = projectileIdToShow
  end
  
  -- Update fade timer
  if self.tooltipFadeTimer > 0 then
    self.tooltipFadeTimer = math.max(0, self.tooltipFadeTimer - dt)
  end
  
  -- Check for victory/defeat and return to map after delay
  -- Check for victory condition: all enemies defeated or BattleScene win state
  local isVictory = false
  if self.right then
    if self.right.state == "win" then
      isVictory = true
    elseif self.right.enemies then
      local allDefeated = true
      for _, enemy in ipairs(self.right.enemies) do
        if enemy.hp > 0 and not enemy.disintegrating then
          allDefeated = false
          break
        end
      end
      if allDefeated then
        isVictory = true
      end
    end
  end
  
  if isVictory then
    -- Only start timer if not already started
    if not self._victoryDetected then
      self._victoryDetected = true
      self._returnToMapTimer = 2.5 -- Wait for disintegration animation to complete
      -- Ensure TurnManager is in VICTORY state
      if self.turnManager then
        local state = self.turnManager:getState()
        if state ~= TurnManager.States.VICTORY then
          self.turnManager:transitionTo(TurnManager.States.VICTORY)
        end
      end
    end
  end
  
  -- Check for defeat condition: player HP at 0 or BattleScene lose state
  local isDefeat = false
  if self.right then
    -- Check multiple defeat conditions
    if (self.right.playerHP and self.right.playerHP <= 0) or
       (self.right.state == "lose") then
      isDefeat = true
    end
  end
  
  if isDefeat then
    -- Only start timer if not already started
    if not self._defeatDetected then
      self._defeatDetected = true
      self._returnToMapTimer = 2.0 -- Shorter delay for defeat
      -- Ensure TurnManager is in DEFEAT state
      if self.turnManager then
        local state = self.turnManager:getState()
        if state ~= TurnManager.States.DEFEAT then
          self.turnManager:transitionTo(TurnManager.States.DEFEAT)
        end
      end
    end
  end
  
  -- Return to map when timer expires
  if self._returnToMapTimer and self._returnToMapTimer > 0 then
    self._returnToMapTimer = self._returnToMapTimer - dt
    if self._returnToMapTimer <= 0 then
      -- Store victory status before resetting flags
      local wasVictory = self._victoryDetected
      -- Reset flags
      self._victoryDetected = false
      self._defeatDetected = false
      self._returnToMapTimer = 0
      -- Return victory status along with return signal
      return { type = "return_to_map", victory = wasVictory }
    end
  end
  
  return nil
end

-- Set the current projectile (updates both tooltip and shooter)
function SplitScene:setProjectile(projectileId)
  self.currentProjectileId = projectileId or "qi_orb"
  if self.left and self.left.setProjectile then
    self.left:setProjectile(projectileId)
  end
end

-- Set battle type (triggers tween to new canvas width)
-- @param battleType string - Battle type from battle_profiles.Types
-- @param duration number - Optional tween duration in seconds (default: 0.25)
function SplitScene:setBattleType(battleType, duration)
  if self.layoutManager then
    self.layoutManager:setBattleType(battleType, duration)
  end
end

-- Set canvas width factor directly (for testing/flexibility)
-- @param factor number - Width factor (0.0 to 1.0)
-- @param duration number - Optional tween duration in seconds (default: 0.25)
function SplitScene:setCanvasWidthFactor(factor, duration)
  if self.layoutManager then
    return self.layoutManager:setTargetFactor(factor, duration)
  end
  return false
end

-- Get current battle type
function SplitScene:getBattleType()
  if self.layoutManager then
    return self.layoutManager:getBattleType()
  end
  return nil
end

-- Trigger screenshake
function SplitScene:triggerShake(magnitude, duration)
  self.shakeMagnitude = magnitude or 10
  self.shakeDuration = duration or 0.25
  self.shakeTime = self.shakeDuration
end

-- Reload blocks from battle profile (called when returning from formation editor)
function SplitScene:reloadBlocks()
  if not self.left then return end
  
  -- Reload battle_profiles module to get updated data
  package.loaded["data.battle_profiles"] = nil
  battle_profiles = require("data.battle_profiles")
  
  -- Get current battle profile
  local currentBattleType = self.layoutManager:getBattleType()
  local battleProfile = battle_profiles.getProfile(currentBattleType)
  
  -- Get bounds for GameplayScene
  local w, h = love.graphics.getDimensions()
  local centerRect = self.layoutManager:getCenterRect(w, h)
  local bounds = { x = 0, y = 0, w = centerRect.w, h = h }
  
  -- Reload blocks in GameplayScene
  if self.left and self.left.reloadBlocks then
    self.left:reloadBlocks(battleProfile, bounds)
  end
end

return SplitScene


