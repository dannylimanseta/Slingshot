local theme = require("theme")
local config = require("config")
local Trail = require("utils.trail")
local GameplayScene = require("scenes.GameplayScene")
local BattleScene = require("scenes.BattleScene")
local TurnManager = require("core.TurnManager")
local TurnActions = require("systems.TurnActions")
local ProjectileCard = require("ui.ProjectileCard")
local LayoutManager = require("managers.LayoutManager")

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
    finisher = nil, -- single finisher (backward compatibility)
    finishers = {}, -- array of finishers for spread shot
    playerTurnDelay = 0, -- Delay timer before showing "PLAYER'S TURN" after enemy attack
    -- New turn management system (integrated alongside old system for gradual migration)
    turnManager = nil,
    _usingTurnManager = false, -- Flag to enable/disable new system
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
  }, SplitScene)
end

function SplitScene:load()
  local w, h = love.graphics.getDimensions()
  local centerRect = self.layoutManager:getCenterRect(w, h)
  self.left = GameplayScene.new()
  self.right = BattleScene.new()
  self.left:load({ x = 0, y = 0, w = centerRect.w, h = h }, self.currentProjectileId)
  self.right:load({ x = centerRect.w, y = 0, w = w - centerRect.w, h = h })
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


  -- When the enemy finishes its move, respawn blocks in the left pane
  self.right.onEnemyTurnResolved = function()
    if not self.left then return end
    local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
    local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
    local centerRect = self.layoutManager:getCenterRect(vw, vh)
    -- Convert to left local bounds (0..centerW) for spawn queries
    if self.left.respawnDestroyedBlocks then
      self.left:respawnDestroyedBlocks({ x = 0, y = 0, w = centerRect.w, h = vh })
    end
    -- Re-enable shooting now that the enemy has moved
    self.left.canShoot = true
    -- Queue "PLAYER'S TURN" indicator with delay after enemy attack completes
    self.playerTurnDelay = 0.3
  end
  
  -- Initialize TurnManager (optional, runs alongside old system)
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
  if self.turnManager then
    self.turnManager:startPlayerTurn()
  else
    -- Fallback to old method if TurnManager not available
    if self.right and self.right.showPlayerTurn then
      self.right:showPlayerTurn()
    end
  end
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
  
  -- Enable shooting exactly when the "PLAYER'S TURN" indicator becomes visible
  self.turnManager:on("turn_indicator_shown", function(data)
    if data and data.text == "PLAYER'S TURN" then
      if self.left then
        self.left.canShoot = true
      end
    end
  end)
  
  -- Apply damage event (when player turn ends)
  self.turnManager:on("apply_damage", function(data)
    if data.target == "enemy" and self.right and self.right.onPlayerTurnEnd then
      local turnData = self.turnManager:getTurnData()
      -- Call the old method but only pass damage (armor will be handled separately)
      self.right:onPlayerTurnEnd(data.amount, turnData.armor or 0)
    end
  end)
  
  -- Show armor popup event
  self.turnManager:on("show_armor_popup", function(data)
    -- This is already handled by BattleScene's onPlayerTurnEnd via pendingArmor
    -- No additional action needed here
  end)
  
  -- Check victory event
  self.turnManager:on("check_victory", function()
    if self.right and self.right.state == "win" then
      self.turnManager:transitionTo(TurnManager.States.VICTORY)
    end
  end)
  
  -- Start enemy turn event (triggered after player turn resolving)
  self.turnManager:on("start_enemy_turn", function()
    -- BattleScene will handle armor popup timing, then call startEnemyTurn when ready
    -- For now, we'll have BattleScene trigger this after its timing logic
  end)
  
  -- Enemy attack event
  self.turnManager:on("enemy_attack", function(data)
    if self.right and self.right.performEnemyAttack then
      self.right:performEnemyAttack(data.min, data.max)
    end
  end)
  
  -- Check defeat event
  self.turnManager:on("check_defeat", function()
    if self.right and self.right.state == "lose" then
      self.turnManager:transitionTo(TurnManager.States.DEFEAT)
    end
  end)
  
  -- Spawn blocks event (do not enable shooting here; wait for indicator)
  self.turnManager:on("spawn_blocks", function(data)
    if self.left and self.left.respawnDestroyedBlocks then
      local vw = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
      local vh = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
      local centerRect = self.layoutManager:getCenterRect(vw, vh)
      self.left:respawnDestroyedBlocks({ x = 0, y = 0, w = centerRect.w, h = vh })
    end
  end)
  
  -- Player turn start transition is now sequenced by TurnManager's enemy turn actions.
  -- We intentionally avoid auto-calling startPlayerTurn() here to prevent loops.
end

-- Helper function to end player turn using TurnManager
function SplitScene:endPlayerTurnWithTurnManager()
  if not self.turnManager then return false end
  local state = self.turnManager:getState()
  if state ~= TurnManager.States.PLAYER_TURN_ACTIVE then return false end
  
  -- Collect turn data
  local turnScore = self.left and self.left.score or 0
  local mult = (config.score and config.score.critMultiplier) or 2
  local critCount = (self.left and self.left.critThisTurn) or 0
  if critCount > 0 then
    turnScore = turnScore * (mult ^ critCount)
  end
  local armor = self.left and self.left.armorThisTurn or 0
  local blocksDestroyed = self.left and self.left.destroyedThisTurn or 0
  
  -- End the turn using TurnManager
  self.turnManager:endPlayerTurn({
    score = turnScore,
    armor = armor,
    crits = critCount,
    blocksDestroyed = blocksDestroyed,
  })
  
  return true
end

function SplitScene:resize(width, height)
  local centerRect = self.layoutManager:getCenterRect(width, height)
  if self.left and self.left.resize then self.left:resize(centerRect.w, height) end
  if self.right and self.right.resize then self.right:resize(width - centerRect.w, height) end
  -- Update walls if width changed significantly
  if self._lastCenterW and math.abs(centerRect.w - self._lastCenterW) > 1 then
    if self.left and self.left.updateWalls then
      self.left:updateWalls(centerRect.w, height)
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
  local w = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
  local h = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
  local centerRect = self.layoutManager:getCenterRect(w, h)
  local centerW = centerRect.w
  local centerX = centerRect.x

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
  love.graphics.setColor(1, 1, 1, 0.1)
  
  if self.boundaryLeft then
    local iw, ih = self.boundaryLeft:getWidth(), self.boundaryLeft:getHeight()
    if iw > 0 and ih > 0 then
      local scale = h / ih -- Scale to match canvas height
      local widthScale = scale * 1.1 -- Increase width by 10%
      local scaledWidth = iw * widthScale
      -- Align right edge of image to left canvas edge (origin at top-right, extends leftward, 100px up)
      love.graphics.draw(self.boundaryLeft, centerX, -100, 0, widthScale, scale, scaledWidth, 0)
    end
  end
  
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
  
  -- Left edge glow (aligned to right of boundary_left)
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

  -- Draw multiple finishers (spread shot)
  if self.finishers and #self.finishers > 0 then
    for _, finisher in ipairs(self.finishers) do
      if finisher and finisher.active then
        if finisher.trail then finisher.trail:draw() end
        
        local x, y = finisher.x, finisher.y
        local radius = finisher.radius or 6
        
        -- Glow behind finisher
        do
          local g = config.ball.glow
          if g and g.enabled and finisher.glowImg then
            love.graphics.push("all")
            love.graphics.setBlendMode("add")
            
            -- Outer glow layer
            if g.outerGlow and g.outerGlow.enabled then
              local outer = g.outerGlow
              local outerCol = outer.color or { 0.3, 0.8, 1, 0.2 }
              local outerAlpha = outerCol[4] or 0.2
              love.graphics.setColor(outerCol[1] or 1, outerCol[2] or 1, outerCol[3] or 1, outerAlpha)
              local iw, ih = finisher.glowImg:getWidth(), finisher.glowImg:getHeight()
              local outerS = ((radius * ((outer.radiusScale or 7.0))) * 2) / math.max(1, iw)
              love.graphics.draw(finisher.glowImg, x, y, 0, outerS, outerS, iw * 0.5, ih * 0.5)
            end
            
            -- Main glow layer
            local col = g.color or { 0.3, 0.8, 1, 0.7 }
            local alpha = col[4] or 0.7
            if g.pulse and finisher.glowT then
              local p = (math.sin(finisher.glowT * (g.pulseSpeed or 1.6)) * 0.5 + 0.5) * (g.pulseAmount or 0.2)
              alpha = math.max(0, math.min(1.5, alpha + p))
            end
            love.graphics.setColor(col[1] or 1, col[2] or 1, col[3] or 1, alpha)
            local iw, ih = finisher.glowImg:getWidth(), finisher.glowImg:getHeight()
            local s = ((radius * ((g.radiusScale or 4.5))) * 2) / math.max(1, iw)
            love.graphics.draw(finisher.glowImg, x, y, 0, s, s, iw * 0.5, ih * 0.5)
            
            love.graphics.pop()
          end
        end
        
        -- Draw finisher projectile core
        love.graphics.push("all")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setBlendMode("add")
        love.graphics.circle("fill", x, y, radius)
        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.pop()
      end
    end
  end

  -- Draw single finisher projectile on top if active (backward compatibility)
  if self.finisher and self.finisher.active then
    if self.finisher.trail then self.finisher.trail:draw() end
    
    local x, y = self.finisher.x, self.finisher.y
    local radius = self.finisher.radius or 6
    
    -- Glow behind finisher (multi-layered for stronger illumination)
    do
      local g = config.ball.glow
      if g and g.enabled and self.finisher.glowImg then
        love.graphics.push("all")
        love.graphics.setBlendMode("add")
        
        -- Outer glow layer (softer, larger for ambient illumination)
        if g.outerGlow and g.outerGlow.enabled then
          local outer = g.outerGlow
          local outerCol = outer.color or { 0.3, 0.8, 1, 0.2 }
          local outerAlpha = outerCol[4] or 0.2
          love.graphics.setColor(outerCol[1] or 1, outerCol[2] or 1, outerCol[3] or 1, outerAlpha)
          local iw, ih = self.finisher.glowImg:getWidth(), self.finisher.glowImg:getHeight()
          local outerS = ((radius * ((outer.radiusScale or 7.0))) * 2) / math.max(1, iw)
          love.graphics.draw(self.finisher.glowImg, x, y, 0, outerS, outerS, iw * 0.5, ih * 0.5)
        end
        
        -- Main glow layer (brighter, closer to projectile)
        local col = g.color or { 0.3, 0.8, 1, 0.7 }
        local alpha = col[4] or 0.7
        if g.pulse and self.finisher.glowT then
          local p = (math.sin(self.finisher.glowT * (g.pulseSpeed or 1.6)) * 0.5 + 0.5) * (g.pulseAmount or 0.2)
          alpha = math.max(0, math.min(1.5, alpha + p)) -- Allow higher alpha for stronger glow
        end
        love.graphics.setColor(col[1] or 1, col[2] or 1, col[3] or 1, alpha)
        local iw, ih = self.finisher.glowImg:getWidth(), self.finisher.glowImg:getHeight()
        local s = ((radius * ((g.radiusScale or 4.5))) * 2) / math.max(1, iw)
        love.graphics.draw(self.finisher.glowImg, x, y, 0, s, s, iw * 0.5, ih * 0.5)
        
        love.graphics.pop()
      end
    end
    
    -- Draw finisher projectile core
    love.graphics.push("all")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("add")
    love.graphics.circle("fill", x, y, radius)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.pop()
  end

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
    
    -- Draw black overlay (0.2 alpha)
    love.graphics.setColor(0, 0, 0, 0.2 * alpha)
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
  
  -- Draw projectile card at bottom-left
  if self.projectileCard then
    -- Determine which projectile to show based on turn number (even = spread shot)
    local ProjectileManager = require("managers.ProjectileManager")
    local projectileIdToShow = self.currentProjectileId or "qi_orb"
    
    -- Check if spread shot should be active (even turn numbers)
    if self.turnManager and self.turnManager.getTurnNumber then
      local turnNumber = self.turnManager:getTurnNumber()
      if turnNumber % 2 == 0 then
        -- Even turn = spread shot
        projectileIdToShow = "spread_shot"
      else
        -- Odd turn = regular projectile
        projectileIdToShow = self.currentProjectileId or "qi_orb"
      end
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
end

local function pointInBounds(x, y, b)
  return x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h
end

function SplitScene:mousepressed(x, y, button)
  local w = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
  local h = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
  local centerRect = self.layoutManager:getCenterRect(w, h)
  local centerBounds = { x = centerRect.x, y = 0, w = centerRect.w, h = h }
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
  local centerBounds = { x = centerRect.x, y = 0, w = centerRect.w, h = h }
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
  local centerBounds = { x = centerRect.x, y = 0, w = centerRect.w, h = h }
  if pointInBounds(x, y, centerBounds) and self.left and self.left.mousemoved then
    self.left:mousemoved(x - centerBounds.x, y - centerBounds.y, dx, dy, centerBounds)
  elseif self.right and self.right.mousemoved then
    self.right:mousemoved(x, y, dx, dy, { x = 0, y = 0, w = w, h = h, center = centerRect.center })
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
  
  local w = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
  local h = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
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

  -- Update player turn delay timer
  if self.playerTurnDelay > 0 then
    self.playerTurnDelay = self.playerTurnDelay - dt
    if self.playerTurnDelay <= 0 then
      -- Delay finished, show "PLAYER'S TURN" indicator
      if self.right and self.right.showPlayerTurn then
        self.right:showPlayerTurn()
      end
      self.playerTurnDelay = 0
    end
  end

  -- Robust detection:
  -- - New shot started: left.canShoot == false and left.ball exists -> reset forward flag
  -- - Turn ended: left.canShoot == true and no ball and not forwarded -> send score
  self._leftTurnForwarded = self._leftTurnForwarded or false
  self._leftForwardTimer = self._leftForwardTimer or nil
  local canShoot = self.left and self.left.canShoot
  -- Check for single ball or multiple balls (spread shot)
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
  -- Check for pending finishers (single or multiple)
  local hasPendingFinishers = (self.left and self.left.finishers and #self.left.finishers > 0) or false
  local hasActiveFinisher = (self.finisher and self.finisher.active) or (self.finishers and #self.finishers > 0)

  -- Detect shot start (transition from inactive to active)
  self._prevShotActive = self._prevShotActive or false
  local shotActive = (canShoot == false and (hasBall or hasActiveFinisher or hasPendingFinishers))
  if shotActive and not self._prevShotActive then
    self._leftTurnForwarded = false
    self._leftForwardTimer = nil
    -- Start jackpot display on the right once per shot
    if self.right and self.right.startJackpotDisplay then
      self.right:startJackpotDisplay()
    end
  end
  self._prevShotActive = shotActive

  -- Turn ended, forward once after optional delay
  -- Must have no active balls, no active finishers, and no pending finishers
  -- canShoot will be false while turn is active, so we detect completion when all projectiles are done
  -- Also check that a shot was actually fired (canShoot is false, indicating turn started)
  local shotWasFired = (canShoot == false) -- If canShoot is false, a shot was fired
  if shotWasFired and not hasBall and not hasActiveFinisher and not hasPendingFinishers and self._leftTurnForwarded == false then
    if not self._leftForwardTimer then
      self._leftForwardTimer = (config.battle and config.battle.playerAttackDelay) or 0
    end
    if self._leftForwardTimer <= 0 then
      -- Finishers are handled separately, so we can proceed with ending the turn
      local finisherPending = false -- Already checked above
      if not finisherPending then
        -- Use TurnManager to end the turn
        if self:endPlayerTurnWithTurnManager() then
          self._leftTurnForwarded = true
          self._leftForwardTimer = nil
        else
          -- Fallback to old method if TurnManager not ready
          local turnScore = self.left and self.left.score or 0
          local mult = (config.score and config.score.critMultiplier) or 2
          local critCount = (self.left and self.left.critThisTurn) or 0
          if critCount > 0 then
            turnScore = turnScore * (mult ^ critCount)
          end
          local armor = self.left and self.left.armorThisTurn or 0
          if self.right and self.right.onPlayerTurnEnd then
            self.right:onPlayerTurnEnd(turnScore, armor)
          end
          self._leftTurnForwarded = true
          self._leftForwardTimer = nil
        end
      end
    else
      self._leftForwardTimer = self._leftForwardTimer - dt
    end
  end

  -- Start finisher(s) if requested by left scene
  -- Handle single finisher (backward compatibility)
  if self.left and self.left.finisherRequested and not (self.finisher and self.finisher.active) then
    local centerRect = self.layoutManager:getCenterRect(w, h)
    local startLocalX = self.left.finisherStartX or 0
    local startLocalY = self.left.finisherStartY or 0
    local startX = centerRect.x + startLocalX
    local startY = startLocalY
    local tx, ty = startX, startY
    if self.right and self.right.getEnemyHitPoint then
      local ntx, nty = self.right:getEnemyHitPoint({ x = 0, y = 0, w = w, h = h, center = centerRect.center })
      -- Validate target coordinates (check for valid numbers, not NaN/Inf)
      if type(ntx) == "number" and type(nty) == "number" and ntx == ntx and nty == nty and math.abs(ntx) ~= math.huge and math.abs(nty) ~= math.huge then
        tx, ty = ntx, nty
      end
    end
    self.finisher = {
      x = startX, y = startY, tx = tx, ty = ty, active = true,
      speed = (config.ball and (config.ball.finisherSpeed or (config.ball.speed or 1000))) or 1000,
      glowImg = makeRadialGlow(128),
      glowT = 0,
      radius = (config.ball and config.ball.radius) or 10.4, -- Match regular projectile size
      travelTime = 0, -- Track travel time for timeout
      lastDist = math.huge, -- Track distance to detect overshoot
    }
    self.finisher.trail = Trail.new(config.ball and config.ball.trail or nil)
    if self.finisher.trail and self.finisher.trail.addPoint then
      self.finisher.trail:addPoint(startX, startY)
    end
    self.left.finisherRequested = false
  end
  
  -- Handle multiple finishers (spread shot)
  if self.left and self.left.finishers and #self.left.finishers > 0 then
    local centerRect = self.layoutManager:getCenterRect(w, h)
    for _, finisherData in ipairs(self.left.finishers) do
      local startLocalX = finisherData.x or 0
      local startLocalY = finisherData.y or 0
      local startX = centerRect.x + startLocalX
      local startY = startLocalY
      local tx, ty = startX, startY
      if self.right and self.right.getEnemyHitPoint then
        local ntx, nty = self.right:getEnemyHitPoint({ x = 0, y = 0, w = w, h = h, center = centerRect.center })
        if type(ntx) == "number" and type(nty) == "number" and ntx == ntx and nty == nty and math.abs(ntx) ~= math.huge and math.abs(nty) ~= math.huge then
          tx, ty = ntx, nty
        end
      end
      
      -- Use smaller radius for spread shot finishers (30% smaller)
      local spreadConfig = config.ball.spreadShot
      local radiusScale = (spreadConfig and spreadConfig.radiusScale) or 0.7
      local baseRadius = (config.ball and config.ball.radius) or 10.4
      local finisherRadius = baseRadius * radiusScale
      
      local finisher = {
        x = startX, y = startY, tx = tx, ty = ty, active = true,
        speed = (config.ball and (config.ball.finisherSpeed or (config.ball.speed or 1000))) or 1000,
        glowImg = makeRadialGlow(128),
        glowT = 0,
        radius = finisherRadius,
        travelTime = 0,
        lastDist = math.huge,
      }
      -- Use spread shot trail config (green, smaller width) for spread shot finishers
      finisher.trail = Trail.new(spreadConfig and spreadConfig.trail or (config.ball and config.ball.trail or nil))
      if finisher.trail and finisher.trail.addPoint then
        finisher.trail:addPoint(startX, startY)
      end
      table.insert(self.finishers, finisher)
    end
    -- Clear the requests after creating finishers
    self.left.finishers = {}
  end

  -- Update multiple finishers (spread shot)
  if self.finishers and #self.finishers > 0 then
    local currentDt = love.timer.getDelta()
    local margin = 32
    local maxTravelTime = 3.0
    
    for i = #self.finishers, 1, -1 do
      local finisher = self.finishers[i]
      if not finisher or not finisher.active then
        table.remove(self.finishers, i)
      else
        local finisherDt = currentDt
        local remaining = finisherDt
        local sp = finisher.speed or 1000
        
        -- Initialize tracking variables if not present
        if not finisher.travelTime then
          finisher.travelTime = 0
          finisher.lastDist = math.huge
        end
        
        local hitTarget = false
        while remaining > 0 and finisher.active and not hitTarget do
          local step = math.min(remaining, 1 / 240)
          remaining = remaining - step
          finisher.travelTime = (finisher.travelTime or 0) + step
          
          -- Recompute target dynamically
          if self.right and self.right.getEnemyHitPoint then
            local centerRect = self.layoutManager:getCenterRect(w, h)
            local ntx, nty = self.right:getEnemyHitPoint({ x = 0, y = 0, w = w, h = h, center = centerRect.center })
            if type(ntx) == "number" and type(nty) == "number" and ntx == ntx and nty == nty and math.abs(ntx) ~= math.huge and math.abs(nty) ~= math.huge then
              finisher.tx = math.max(0, math.min(w, ntx))
              finisher.ty = math.max(0, math.min(h, nty))
            end
          end
          
          local fx, fy, tx, ty = finisher.x, finisher.y, finisher.tx, finisher.ty
          local dx, dy = tx - fx, ty - fy
          local dist = math.sqrt(dx * dx + dy * dy)
          
          -- Detect overshoot
          local overshootDetected = false
          if dist > (finisher.lastDist or math.huge) + (sp * step * 0.5) then
            overshootDetected = true
          end
          finisher.lastDist = dist
          
          -- Hit detection
          local hitThreshold = math.max(12, sp * step * 1.5)
          if dist <= hitThreshold or overshootDetected or dist <= 1e-6 then
            -- Play impact VFX for each finisher hit
            if self.right and self.right.playImpact then
              local blockCount = (self.left and self.left.blocksHitThisTurn) or 1
              local isCrit = (self.left and self.left.critThisTurn and self.left.critThisTurn > 0) or false
              self.right:playImpact(blockCount, isCrit)
            end
            finisher.active = false
            hitTarget = true
            table.remove(self.finishers, i)
          elseif dist > 1e-6 then
            -- Move finisher
            local nx, ny = dx / dist, dy / dist
            finisher.x = fx + nx * sp * step
            finisher.y = fy + ny * sp * step
          end
          
          if finisher.trail and finisher.trail.update then
            finisher.trail:update(step, finisher.x, finisher.y)
          end
          
          if finisher.glowT then
            finisher.glowT = finisher.glowT + step
          end
          
          -- Failsafe: timeout or out of bounds
          if finisher.travelTime >= maxTravelTime or
             finisher.x < -margin or finisher.x > w + margin or
             finisher.y < -margin or finisher.y > h + margin then
            finisher.active = false
            hitTarget = true
            table.remove(self.finishers, i)
          end
        end
      end
    end
    
    -- When all finishers have completed, end the turn
    if #self.finishers == 0 and not (self.finisher and self.finisher.active) then
      if not self._leftTurnForwarded then
        if self:endPlayerTurnWithTurnManager() then
          self._leftTurnForwarded = true
        else
          -- Fallback to old method
          local turnScore = self.left and self.left.score or 0
          local mult = (config.score and config.score.critMultiplier) or 2
          local critCount = (self.left and self.left.critThisTurn) or 0
          if critCount > 0 then
            turnScore = turnScore * (mult ^ critCount)
          end
          local armor = self.left and self.left.armorThisTurn or 0
          if self.right and self.right.onPlayerTurnEnd then
            self.right:onPlayerTurnEnd(turnScore, armor)
          end
          self._leftTurnForwarded = true
        end
        if self.left then
          self.left.finisherActive = false
          self.left.canShoot = false
          self.left.ball = nil
          self.left.balls = {}
        end
      end
    end
  end

  -- Update single finisher projectile (backward compatibility)
  if self.finisher and self.finisher.active then
    -- Get dt from love.timer (draw() doesn't receive dt parameter)
    local currentDt = love.timer.getDelta()
    local finisherDt = currentDt
    local remaining = finisherDt
    local sp = self.finisher.speed or 1000
    local margin = 32
    local maxTravelTime = 3.0 -- Maximum travel time before timeout (3 seconds)
    
    -- Initialize tracking variables if not present
    if not self.finisher.travelTime then
      self.finisher.travelTime = 0
      self.finisher.lastDist = math.huge
    end
    
    while remaining > 0 and self.finisher and self.finisher.active do
      local step = math.min(remaining, 1 / 240) -- substep to avoid tunneling
      remaining = remaining - step
      self.finisher.travelTime = (self.finisher.travelTime or 0) + step

      -- Recompute target dynamically to follow enemy motion (shake/lunge)
      if self.right and self.right.getEnemyHitPoint then
        local centerRect = self.layoutManager:getCenterRect(w, h)
        local ntx, nty = self.right:getEnemyHitPoint({ x = 0, y = 0, w = w, h = h, center = centerRect.center })
        -- Validate target coordinates (check for valid numbers, not NaN/Inf)
        if type(ntx) == "number" and type(nty) == "number" and ntx == ntx and nty == nty and math.abs(ntx) ~= math.huge and math.abs(nty) ~= math.huge then
          -- Clamp target within screen to avoid chasing off-screen coordinates
          self.finisher.tx = math.max(0, math.min(w, ntx))
          self.finisher.ty = math.max(0, math.min(h, nty))
        end
      end

      local fx, fy, tx, ty = self.finisher.x, self.finisher.y, self.finisher.tx, self.finisher.ty
      local dx, dy = tx - fx, ty - fy
      local dist = math.sqrt(dx * dx + dy * dy)

      -- Detect overshoot: if distance increased, we've passed the target
      local overshootDetected = false
      if dist > (self.finisher.lastDist or math.huge) + (sp * step * 0.5) then
        overshootDetected = true
      end
      self.finisher.lastDist = dist

      -- Hit detection: check if close enough OR overshot
      local hitThreshold = math.max(12, sp * step * 1.5) -- Increased threshold slightly
      if dist <= hitThreshold or overshootDetected then
        -- Play impact VFX immediately on hit
        if self.right and self.right.playImpact then
          local blockCount = (self.left and self.left.blocksHitThisTurn) or 1
          local isCrit = (self.left and self.left.critThisTurn and self.left.critThisTurn > 0) or false
          self.right:playImpact(blockCount, isCrit)
        end
        -- Impact: end turn using TurnManager
        if self:endPlayerTurnWithTurnManager() then
          self._leftTurnForwarded = true
        else
          -- Fallback to old method
          local turnScore = self.left and self.left.score or 0
          local mult = (config.score and config.score.critMultiplier) or 2
          local critCount = (self.left and self.left.critThisTurn) or 0
          if critCount > 0 then
            turnScore = turnScore * (mult ^ critCount)
          end
          local armor = self.left and self.left.armorThisTurn or 0
          if self.right and self.right.onPlayerTurnEnd then
            self.right:onPlayerTurnEnd(turnScore, armor)
          end
          self._leftTurnForwarded = true
        end
        self.finisher.active = false
        if self.left then
          self.left.finisherActive = false
          -- Defer enabling canShoot until enemy finishes move
          self.left.canShoot = false
          self.left.ball = nil
        end
        break
      end

      -- Only move if we have a valid direction
      if dist > 1e-6 then
        local nx, ny = dx / dist, dy / dist
        local nxStep = fx + nx * sp * step
        local nyStep = fy + ny * sp * step
        self.finisher.x = nxStep
        self.finisher.y = nyStep
      else
        -- If distance is effectively zero, trigger impact immediately
        if self.right and self.right.playImpact then
          local blockCount = (self.left and self.left.blocksHitThisTurn) or 1
          local isCrit = (self.left and self.left.critThisTurn and self.left.critThisTurn > 0) or false
          self.right:playImpact(blockCount, isCrit)
        end
        if self:endPlayerTurnWithTurnManager() then
          self._leftTurnForwarded = true
        else
          -- Fallback to old method
          local turnScore = self.left and self.left.score or 0
          local mult = (config.score and config.score.critMultiplier) or 2
          local critCount = (self.left and self.left.critThisTurn) or 0
          if critCount > 0 then
            turnScore = turnScore * (mult ^ critCount)
          end
          local armor = self.left and self.left.armorThisTurn or 0
          if self.right and self.right.onPlayerTurnEnd then
            self.right:onPlayerTurnEnd(turnScore, armor)
          end
          self._leftTurnForwarded = true
        end
        self.finisher.active = false
        if self.left then
          self.left.finisherActive = false
          self.left.canShoot = false
          self.left.ball = nil
        end
        break
      end

      if self.finisher.trail and self.finisher.trail.update then
        self.finisher.trail:update(step, self.finisher.x, self.finisher.y)
      end
      
      -- Advance glow time for finisher
      if self.finisher.glowT then
        self.finisher.glowT = self.finisher.glowT + step
      end

      -- Failsafe: timeout after max travel time
      if self.finisher.travelTime >= maxTravelTime then
        local turnScore = self.left and self.left.score or 0
        local mult = (config.score and config.score.critMultiplier) or 2
        local critCount = (self.left and self.left.critThisTurn) or 0
        if critCount > 0 then
          turnScore = turnScore * (mult ^ critCount)
        end
        local armor = self.left and self.left.armorThisTurn or 0
        -- Use TurnManager to end turn
        if not self:endPlayerTurnWithTurnManager() then
          -- Fallback to old method
          if self.right and self.right.onPlayerTurnEnd then
            self.right:onPlayerTurnEnd(turnScore, armor)
          end
        end
        self._leftTurnForwarded = true
        self.finisher.active = false
        if self.left then
          self.left.finisherActive = false
          self.left.canShoot = false
          self.left.ball = nil
        end
        break
      end

      -- Failsafe: if projectile leaves screen, resolve impact to avoid soft-lock
      if self.finisher.x < -margin or self.finisher.x > w + margin or self.finisher.y < -margin or self.finisher.y > h + margin then
        local turnScore = self.left and self.left.score or 0
        local mult = (config.score and config.score.critMultiplier) or 2
        local critCount = (self.left and self.left.critThisTurn) or 0
        if critCount > 0 then
          turnScore = turnScore * (mult ^ critCount)
        end
        local armor = self.left and self.left.armorThisTurn or 0
        -- Use TurnManager to end turn
        if not self:endPlayerTurnWithTurnManager() then
          -- Fallback to old method
          if self.right and self.right.onPlayerTurnEnd then
            self.right:onPlayerTurnEnd(turnScore, armor)
          end
        end
        self._leftTurnForwarded = true
        self.finisher.active = false
        if self.left then
          self.left.finisherActive = false
          -- Defer enabling canShoot until enemy finishes move
          self.left.canShoot = false
          self.left.ball = nil
        end
        break
      end
    end
  end

  -- Feed live score to battle jackpot while the player is aiming/shot is active
  if shotActive and self.right and self.right.setJackpotTarget then
    local liveScore = (self.left and self.left.score) or 0
    local critCount = (self.left and self.left.critThisTurn) or 0
    local mult = (config.score and config.score.critMultiplier) or 2
    local displayScore = liveScore * (critCount > 0 and (mult ^ critCount) or 1)
    self.right:setJackpotTarget(displayScore)
    if self.right.setJackpotCrit then
      self.right:setJackpotCrit(critCount > 0)
    end
  end

  -- Ensure TurnManager processes its action queue each frame
  if self.turnManager and self.turnManager.update then
    self.turnManager:update(dt)
  end
  
  -- Detect projectile changes and trigger fade animation
  local projectileIdToShow = self.currentProjectileId or "qi_orb"
  if self.turnManager and self.turnManager.getTurnNumber then
    local turnNumber = self.turnManager:getTurnNumber()
    if turnNumber % 2 == 0 then
      projectileIdToShow = "spread_shot"
    else
      projectileIdToShow = self.currentProjectileId or "qi_orb"
    end
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

return SplitScene


