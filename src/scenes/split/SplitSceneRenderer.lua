-- SplitSceneRenderer.lua
-- Handles all rendering/drawing logic for SplitScene

local theme = require("theme")
local config = require("config")
local playfield = require("utils.playfield")

local SplitSceneRenderer = {}

--- Draw background image (cover mode)
---@param scene table SplitScene instance
---@param w number Screen width
---@param h number Screen height
function SplitSceneRenderer.drawBackground(scene, w, h)
  love.graphics.clear(theme.colors.background)
  
  if scene.bgImage then
    local iw, ih = scene.bgImage:getWidth(), scene.bgImage:getHeight()
    if iw > 0 and ih > 0 then
      local sx = w / iw
      local sy = h / ih
      local s = math.max(sx, sy)
      local dx = (w - iw * s) * 0.5
      local dy = (h - ih * s) * 0.5
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(scene.bgImage, dx, dy, 0, s, s)
      love.graphics.setColor(1, 1, 1, 1)
    end
  end
end

--- Draw left boundary with damage effect
---@param scene table SplitScene instance
---@param gridStartXAbsolute number Left grid edge X position
---@param h number Screen height
function SplitSceneRenderer.drawLeftBoundary(scene, gridStartXAbsolute, h)
  if not scene.boundaryLeft then return end
  
  local iw, ih = scene.boundaryLeft:getWidth(), scene.boundaryLeft:getHeight()
  if iw <= 0 or ih <= 0 then return end
  
  local scale = h / ih -- Scale to match canvas height
  local widthScale = scale * 1.1 -- Increase width by 10%
  local scaledWidth = iw * widthScale
  
  -- Calculate fade-in alpha for damage effect
  local baseAlpha = 0.1
  local damageAlpha = 0
  if scene.boundaryLeftDamageTimer > 0 then
    -- Smooth fade: quick fade in (first 20%), hold briefly, then smooth fade out
    local progress = 1 - (scene.boundaryLeftDamageTimer / scene.boundaryLeftDamageDuration)
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
  
  -- Align right edge of image to left grid edge (origin at top-right, extends leftward, 100px up)
  love.graphics.draw(scene.boundaryLeft, gridStartXAbsolute, -100, 0, widthScale, scale, scaledWidth, 0)
end

--- Draw right boundary
---@param scene table SplitScene instance
---@param gridEndXAbsolute number Right grid edge X position
---@param h number Screen height
function SplitSceneRenderer.drawRightBoundary(scene, gridEndXAbsolute, h)
  if not scene.boundaryRight then return end
  
  local iw, ih = scene.boundaryRight:getWidth(), scene.boundaryRight:getHeight()
  if iw <= 0 or ih <= 0 then return end
  
  local scale = h / ih -- Scale to match canvas height
  local widthScale = scale * 1.1 -- Increase width by 10%
  
  love.graphics.setColor(1, 1, 1, 0.1)
  -- Align left edge of image to right grid edge (extends rightward, 100px up)
  love.graphics.draw(scene.boundaryRight, gridEndXAbsolute, -100, 0, widthScale, scale)
end

--- Draw edge glow effects when ball hits edges
---@param scene table SplitScene instance
---@param gridStartXAbsolute number Left grid edge X position
---@param gridEndXAbsolute number Right grid edge X position
---@param h number Screen height
function SplitSceneRenderer.drawEdgeGlows(scene, gridStartXAbsolute, gridEndXAbsolute, h)
  love.graphics.push("all")
  love.graphics.setScissor() -- Disable scissor
  love.graphics.setBlendMode("add") -- Use additive blending for glows
  
  -- Left edge glow
  if scene.edgeGlowLeftTimer > 0 then
    local glowAlpha = (scene.edgeGlowLeftTimer / scene.edgeGlowDuration) * 0.8
    
    if scene.edgeGlowImage then
      local iw, ih = scene.edgeGlowImage:getWidth(), scene.edgeGlowImage:getHeight()
      if iw > 0 and ih > 0 then
        local scale = (h / ih) * 0.5 -- Reduce size by 50%
        love.graphics.setColor(1, 1, 1, glowAlpha)
        -- Flip horizontally (negative x-scale) with origin at top-right for x, center for y
        love.graphics.draw(scene.edgeGlowImage, gridStartXAbsolute, scene.edgeGlowLeftY, 0, -scale, scale, 0, ih * 0.5)
      end
    else
      -- Fallback: draw a simple rectangle if image doesn't load
      love.graphics.setColor(1, 0.5, 0, glowAlpha)
      love.graphics.rectangle("fill", gridStartXAbsolute - 20, scene.edgeGlowLeftY, 20, h)
    end
  end
  
  -- Right edge glow
  if scene.edgeGlowRightTimer > 0 then
    local glowAlpha = (scene.edgeGlowRightTimer / scene.edgeGlowDuration) * 0.8
    
    if scene.edgeGlowImage then
      local iw, ih = scene.edgeGlowImage:getWidth(), scene.edgeGlowImage:getHeight()
      if iw > 0 and ih > 0 then
        local scale = (h / ih) * 0.5 -- Reduce size by 50%
        love.graphics.setColor(1, 1, 1, glowAlpha)
        -- Don't flip - draw normally so it extends rightward outward
        love.graphics.draw(scene.edgeGlowImage, gridEndXAbsolute, scene.edgeGlowRightY, 0, scale, scale, 0, ih * 0.5)
      end
    else
      -- Fallback: draw a simple rectangle if image doesn't load
      love.graphics.setColor(1, 0.5, 0, glowAlpha)
      love.graphics.rectangle("fill", gridEndXAbsolute, scene.edgeGlowRightY, 20, h)
    end
  end
  
  love.graphics.pop()
end

--- Draw turn indicator overlay (banner + text)
---@param scene table SplitScene instance
---@param w number Screen width
---@param h number Screen height
---@param centerRect table Center rectangle from layout manager
function SplitSceneRenderer.drawTurnIndicator(scene, w, h, centerRect)
  if not scene.right or not scene.right.turnIndicator then return end
  
  local lifetime = scene.right.turnIndicator.duration or 1.5
  local t = scene.right.turnIndicator.t / lifetime -- 1 -> 0
  local fadeInEnd = 0.85
  local fadeOutStart = 0.15
  
  -- Calculate alpha with fade in and fade out
  local alpha = 1.0
  if t > fadeInEnd then
    local fadeInProgress = (1.0 - t) / (1.0 - fadeInEnd)
    alpha = fadeInProgress
  elseif t < fadeOutStart then
    alpha = t / fadeOutStart
  else
    alpha = 1.0
  end
  
  -- Draw black band image
  if scene.blackBandImage then
    local bandW, bandH = scene.blackBandImage:getDimensions()
    local baseScaleX = w / bandW
    local scaleX = baseScaleX * 1.5 -- Increase size by 50%
    
    -- Calculate height scale
    local heightScale = SplitSceneRenderer.calculateBandHeightScale(t, fadeInEnd, fadeOutStart)
    
    local scaleY = scaleX * heightScale
    local scaledH = bandH * scaleY
    local bandY = (h - scaledH) * 0.5
    local bandX = (w - (bandW * scaleX)) * 0.5
    
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(scene.blackBandImage, bandX, bandY, 0, scaleX, scaleY)
    love.graphics.setColor(1, 1, 1, 1)
  else
    -- Fallback to black overlay
    love.graphics.setColor(0, 0, 0, 0.6 * alpha)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 1, 1, 1)
  end
  
  -- Pop-in scale animation (easeOutBack)
  local scale = 1.0
  if t > 0.7 then
    local popT = (1.0 - t) / 0.3
    local c1, c3 = 1.70158, 2.70158
    local u = (popT - 1)
    scale = 1 + c3 * (u * u * u) + c1 * (u * u)
  end
  
  SplitSceneRenderer.drawTurnIndicatorText(scene, w, h, centerRect, t, alpha, scale)
end

--- Calculate band height scale for turn indicator animation
function SplitSceneRenderer.calculateBandHeightScale(t, fadeInEnd, fadeOutStart)
  local heightScale = 1.0
  if t > fadeInEnd then
    -- Fade in phase: grow from 30% to 100% height
    local fadeInProgress = (1.0 - t) / (1.0 - fadeInEnd)
    local easedProgress = 1.0 - (1.0 - fadeInProgress) * (1.0 - fadeInProgress)
    local minHeightScale = 0.3
    heightScale = minHeightScale + (1.0 - minHeightScale) * easedProgress
  elseif t < fadeOutStart then
    -- Fade out phase: shrink from 105% to 30% height
    local fadeOutProgress = t / fadeOutStart
    local easedProgress = fadeOutProgress * fadeOutProgress
    local minHeightScale = 0.3
    local maxExpandedHeight = 1.05
    heightScale = minHeightScale + (maxExpandedHeight - minHeightScale) * easedProgress
  else
    -- Hold phase: continue expanding slowly from 100% to 105%
    local holdProgress = (t - fadeOutStart) / (fadeInEnd - fadeOutStart)
    local easedHoldProgress = 1.0 - (1.0 - holdProgress) * (1.0 - holdProgress)
    heightScale = 1.0 + (0.05 * easedHoldProgress)
  end
  return heightScale
end

--- Draw turn indicator text and decorations
function SplitSceneRenderer.drawTurnIndicatorText(scene, w, h, centerRect, t, alpha, scale)
  love.graphics.push()
  love.graphics.setFont(theme.fonts.jackpot or theme.fonts.large)
  local text = scene.right.turnIndicator.text
  local font = theme.fonts.jackpot or theme.fonts.large
  local textW = font:getWidth(text)
  local centerX = centerRect.x + centerRect.w * 0.5
  local centerY = h * 0.5 - 20
  
  -- Adjust text position based on turn type
  if text == "YOUR TURN" then
    centerY = centerY - 10
  elseif text == "ENEMY'S TURN" then
    centerY = centerY + 20
  end
  
  -- Calculate decor animation
  local baseDecorSpacing = 40
  local startDecorSpacing = 6
  local baseDecorScale = 0.7
  local decorExpandDuration = 0.35
  local decorProgress = math.min(1, math.max(0, (1 - t) / decorExpandDuration))
  local decorEase = 1 - (1 - decorProgress) * (1 - decorProgress) * (1 - decorProgress)
  local decorSpacing = startDecorSpacing + (baseDecorSpacing - startDecorSpacing) * decorEase
  local decorScale = baseDecorScale * (0.5 + 0.5 * decorEase)
  
  love.graphics.push()
  love.graphics.translate(centerX, centerY)
  love.graphics.scale(scale, scale)
  
  -- Draw decorative images on both sides of text
  if scene.decorImage then
    local decorW = scene.decorImage:getWidth()
    local decorH = scene.decorImage:getHeight()
    local scaledW = decorW * decorScale
    
    local leftCenterX = -textW * 0.5 - decorSpacing - scaledW * 0.5
    local rightCenterX = textW * 0.5 + decorSpacing + scaledW * 0.5
    
    love.graphics.setColor(1, 1, 1, alpha)
    
    -- Left decorative image
    love.graphics.push()
    love.graphics.translate(leftCenterX, 0)
    love.graphics.scale(decorScale, decorScale)
    love.graphics.draw(scene.decorImage, -decorW * 0.5, -decorH * 0.5)
    love.graphics.pop()
    
    -- Right decorative image (flipped horizontally)
    love.graphics.push()
    love.graphics.translate(rightCenterX, 0)
    love.graphics.scale(-decorScale, decorScale)
    love.graphics.draw(scene.decorImage, -decorW * 0.5, -decorH * 0.5)
    love.graphics.pop()
  end
  
  -- Draw text
  love.graphics.setColor(1, 1, 1, alpha)
  local textY = -font:getHeight() * 0.5
  love.graphics.print(text, -textW * 0.5, textY)
  
  -- Draw orb sprite and name below text for player turn
  if text == "YOUR TURN" then
    SplitSceneRenderer.drawPlayerTurnOrbInfo(scene, textY, font, alpha)
  end
  
  love.graphics.pop()
  
  love.graphics.setFont(theme.fonts.base)
  love.graphics.pop()
end

--- Draw orb info during player turn indicator
function SplitSceneRenderer.drawPlayerTurnOrbInfo(scene, textY, font, alpha)
  local ProjectileManager = require("managers.ProjectileManager")
  local projectileId = "strike"
  if scene.left and scene.left.shooter and scene.left.shooter.getCurrentProjectileId then
    projectileId = scene.left.shooter:getCurrentProjectileId()
  elseif scene.currentProjectileId then
    projectileId = scene.currentProjectileId
  end
  
  local projectile = ProjectileManager.getProjectile(projectileId)
  if not projectile then return end
  
  local spriteSpacing = 30
  local spriteY = textY + font:getHeight() * 0.5 + spriteSpacing + 50
  
  if projectile.icon then
    local ok, orbImg = pcall(love.graphics.newImage, projectile.icon)
    if ok and orbImg then
      local spriteSize = 64
      local spriteW, spriteH = orbImg:getWidth(), orbImg:getHeight()
      local spriteScale = spriteSize / math.max(spriteW, spriteH)
      
      love.graphics.setColor(1, 1, 1, alpha)
      love.graphics.draw(orbImg, 0, spriteY, 0, spriteScale, spriteScale, spriteW * 0.5, spriteH * 0.5)
      
      -- Draw orb name below sprite
      love.graphics.setFont(scene._smallFont)
      
      local orbName = projectile.name or projectileId
      local nameW = scene._smallFont:getWidth(orbName)
      local nameY = spriteY + spriteSize * 0.5 + 15
      
      love.graphics.setColor(1, 1, 1, alpha)
      love.graphics.print(orbName, -nameW * 0.5, nameY)
    end
  end
end

--- Draw projectile card UI
---@param scene table SplitScene instance
---@param w number Screen width
---@param h number Screen height
function SplitSceneRenderer.drawProjectileCard(scene, w, h)
  if not scene.projectileCard then return end
  
  local ProjectileManager = require("managers.ProjectileManager")
  local projectileIdToShow = "strike"
  
  if scene.left and scene.left.shooter and scene.left.shooter.getCurrentProjectileId then
    projectileIdToShow = scene.left.shooter:getCurrentProjectileId()
  else
    projectileIdToShow = scene.currentProjectileId or "strike"
  end
  
  if not projectileIdToShow then return end
  
  local cardMargin = 32
  local cardX = cardMargin
  
  local projectile = ProjectileManager.getProjectile(projectileIdToShow)
  local cardH = 90
  if projectile and scene.projectileCard.calculateHeight then
    cardH = scene.projectileCard:calculateHeight(projectile)
  end
  local cardY = h - cardH - cardMargin
  
  -- Calculate fade alpha
  local fadeAlpha = 1.0
  if scene.tooltipFadeTimer > 0 then
    local fadeProgress = scene.tooltipFadeTimer / scene.tooltipFadeDuration
    if fadeProgress > 0.5 then
      fadeAlpha = (fadeProgress - 0.5) * 2
    else
      fadeAlpha = 1 - (fadeProgress * 2)
    end
  end
  
  scene.projectileCard:draw(cardX, cardY, projectileIdToShow, fadeAlpha)
end

--- Draw guide lines (debug)
---@param centerX number Center X position
---@param centerW number Center width
---@param h number Screen height
function SplitSceneRenderer.drawGuideLines(centerX, centerW, h)
  love.graphics.setColor(1, 1, 1, 0.0)
  love.graphics.setLineWidth(2)
  love.graphics.line(centerX, 0, centerX, h)
  love.graphics.line(centerX + centerW, 0, centerX + centerW, h)
  love.graphics.setColor(1, 1, 1, 1)
end

return SplitSceneRenderer

