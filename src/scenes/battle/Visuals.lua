local config = require("config")
local theme = require("theme")
local Bar = require("ui.Bar")
local ImpactSystem = require("scenes.battle.ImpactSystem")

local Visuals = {}

-- Calculate enemy positions dynamically based on count (1-3 enemies)
-- Returns array of {x, y, scale} for each enemy
local function calculateEnemyPositions(scene, rightStart, rightWidth, baselineY, r)
  local enemies = scene.enemies or {}
  local enemyCount = #enemies
  if enemyCount == 0 then return {} end
  
  -- Calculate scales for all enemies
  local enemyScales = {}
  local enemyWidths = {}
  local totalWidth = 0
  -- Get gap from battle profile or use default
  local battleProfile = scene._battleProfile or {}
  -- Gap between enemies (in pixels). Supports count-specific tables.
  local gapCfg = battleProfile.enemySpacing
  local gap
  if type(gapCfg) == "table" then
    gap = gapCfg[enemyCount] or gapCfg.default or 0
  else
    gap = gapCfg or -20
  end
  
  for i, enemy in ipairs(enemies) do
    local scaleCfg = enemy.spriteScale or (config.battle and (config.battle.enemySpriteScale or config.battle.spriteScale)) or 4
    local scale = 1
    if enemy.img then
      local ih = enemy.img:getHeight()
      scale = ((2 * r) / math.max(1, ih)) * scaleCfg * (enemy.scaleMul or 1)
    end
    enemyScales[i] = scale
    enemyWidths[i] = enemy.img and (enemy.img:getWidth() * scale) or (r * 2)
    totalWidth = totalWidth + enemyWidths[i]
    if i < enemyCount then
      totalWidth = totalWidth + gap -- Add gap between enemies
    end
  end
  
  -- Calculate starting X position (center enemies in right side area)
  local centerX = rightStart + rightWidth * 0.5
  local startX = centerX - totalWidth * 0.5 - 70 -- Shift enemies left by 70px
  
  -- Calculate positions for each enemy
  local positions = {}
  local currentX = startX
  
  for i, enemy in ipairs(enemies) do
    local x = currentX + enemyWidths[i] * 0.5 + 40 -- shift enemies right by 40px
    currentX = currentX + enemyWidths[i] + (i < enemyCount and gap or 0)
    table.insert(positions, {
      x = x,
      y = baselineY,
      scale = enemyScales[i],
      width = enemyWidths[i],
      enemy = enemy
    })
  end
  
  return positions
end

local function drawCenteredText(text, x, y, w)
  theme.printfWithOutline(text, x, y, w, "center", theme.colors.uiText[1], theme.colors.uiText[2], theme.colors.uiText[3], theme.colors.uiText[4], 2)
end

local function drawBarGlow(x, y, w, h, alpha)
  local gap = 3
  local radius = 8
  alpha = alpha or 1.0
  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x - gap, y - gap, w + gap * 2, h + gap * 2, radius, radius)
  love.graphics.setColor(1, 1, 1, 1)
end

local function drawBorderFragments(fragments)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setLineWidth(2)
  for _, frag in ipairs(fragments) do
    local progress = frag.progress or (frag.lifetime / frag.maxLifetime)
    local easeOut = progress * progress
    local alpha = easeOut
    if alpha > 0 then
      love.graphics.push()
      love.graphics.translate(frag.x, frag.y)
      love.graphics.rotate(frag.rotation)
      love.graphics.setColor(1, 1, 1, alpha)
      love.graphics.line(0, 0, frag.length, 0)
      love.graphics.pop()
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function Visuals.draw(scene, bounds)
  local w, h
  if bounds and bounds.w and bounds.h then
    w = bounds.w
    h = bounds.h
  else
    w = love.graphics.getWidth()
    h = love.graphics.getHeight()
  end

  local pad = 12
  local center = bounds and bounds.center or nil
  local centerX = center and center.x or math.floor(w * 0.5) - math.floor((w * 0.5) * 0.5)
  local centerW = center and center.w or math.floor(w * 0.5)
  local leftWidth = math.max(0, centerX)
  local rightStart = centerX + centerW
  local rightWidth = math.max(0, w - rightStart)

  local r = 24
  local yOffset = (config.battle and config.battle.positionOffsetY) or 0
  local baselineY = h * 0.55 + r + yOffset
  local playerX = (leftWidth > 0) and (leftWidth * 0.5) or (pad + r)
  local enemyX = (rightWidth > 0) and (rightStart + rightWidth * 0.5) or (w - pad - r)

  love.graphics.setFont(theme.fonts.base)

  love.graphics.push()
  if scene.shakeTime and scene.shakeTime > 0 and scene.shakeDuration and scene.shakeDuration > 0 then
    local t = scene.shakeTime / scene.shakeDuration
    local ease = t * t
    local mag = scene.shakeMagnitude * ease
    local ox = (love.math.random() * 2 - 1) * mag
    local oy = (love.math.random() * 2 - 1) * mag
    love.graphics.translate(ox, oy)
  end

  local function lungeOffset(t, pauseActive)
    if not t or t <= 0 then return 0 end
    local d = config.battle.lungeDuration or 0
    local rdur = config.battle.lungeReturnDuration or 0
    local dist = config.battle.lungeDistance or 0
    if t < d then
      return dist * (t / math.max(0.0001, d))
    elseif pauseActive and t < d + rdur then
      return dist
    elseif t < d + rdur then
      local tt = (t - d) / math.max(0.0001, rdur)
      return dist * (1 - tt)
    else
      return 0
    end
  end

  local function jumpOffset(t)
    if not t or t <= 0 then return 0 end
    local jumpUpDuration = 0.3
    local jumpDownDuration = 0.2
    local jumpHeight = -60 -- Negative Y means upward (screen coordinates)
    if t < jumpUpDuration then
      -- Jumping up: ease-out curve
      local progress = t / jumpUpDuration
      local eased = 1 - (1 - progress) * (1 - progress) -- Quadratic ease-out
      return jumpHeight * eased
    elseif t < jumpUpDuration + jumpDownDuration then
      -- Landing down: ease-in curve
      local progress = (t - jumpUpDuration) / jumpDownDuration
      local eased = progress * progress -- Quadratic ease-in
      return jumpHeight * (1 - eased)
    else
      return 0
    end
  end

  local playerLunge = lungeOffset(scene.playerLungeTime, (scene.impactInstances and #scene.impactInstances > 0))

  local function knockbackOffset(t)
    if not t or t <= 0 then return 0 end
    local d = config.battle.knockbackDuration or 0
    local rdur = config.battle.knockbackReturnDuration or 0
    local dist = config.battle.knockbackDistance or 0
    if t < d then
      return dist * (t / math.max(0.0001, d))
    elseif t < d + rdur then
      local tt = (t - d) / math.max(0.0001, rdur)
      return dist * (1 - tt)
    else
      return 0
    end
  end
  local playerKB = knockbackOffset(scene.playerKnockbackTime)
  local curPlayerX = playerX + playerLunge - playerKB

  -- Calculate player scale
  local playerScaleCfg = (config.battle and (config.battle.playerSpriteScale or config.battle.spriteScale)) or 1
  local playerScale = 1
  if scene.playerImg then
    local ih = scene.playerImg:getHeight()
    playerScale = ((2 * r) / math.max(1, ih)) * playerScaleCfg * (scene.playerScaleMul or 1)
  end

  -- Calculate dynamic enemy positions
  local enemyPositions = calculateEnemyPositions(scene, rightStart, rightWidth, baselineY, r)
  
  -- Apply lunge, jump, and knockback offsets to enemy positions
  for i, pos in ipairs(enemyPositions) do
    local enemy = pos.enemy
    local enemyLunge = lungeOffset(enemy.lungeTime, false)
    local enemyJump = jumpOffset(enemy.jumpTime)
    local enemyKB = 0
    for _, event in ipairs(scene.enemyKnockbackEvents or {}) do
      if event.startTime then
        enemyKB = enemyKB + knockbackOffset(event.startTime)
      end
    end
    enemyKB = enemyKB + knockbackOffset(enemy.knockbackTime)
    pos.curX = pos.x - enemyLunge + enemyKB
    pos.curY = pos.y + enemyJump -- Apply jump offset to Y position
  end

  local playerHalfH = scene.playerImg and ((scene.playerImg:getHeight() * playerScale) * 0.5) or r

  local barH = 12
  local playerBarW = math.max(120, math.min(220, leftWidth - pad * 2)) * 0.56 -- Reduced by 20% (0.7 * 0.8 = 0.56)

  local barY = baselineY + 16

  if playerBarW > 0 then
    local playerBarX = playerX - playerBarW * 0.5
    scene.playerBarX = playerBarX
    scene.playerBarY = barY
    scene.playerBarW = playerBarW
    scene.playerBarH = barH

    if scene.borderFragments and #scene.borderFragments > 0 then
      drawBorderFragments(scene.borderFragments)
    end

    if (scene.playerArmor or 0) > 0 and (#scene.borderFragments == 0) then
      local alpha = 1.0
      if scene.borderFadeInTime and scene.borderFadeInDuration and scene.borderFadeInTime > 0 and scene.borderFadeInDuration > 0 then
        alpha = 1.0 - (scene.borderFadeInTime / scene.borderFadeInDuration)
      end
      drawBarGlow(playerBarX, barY, playerBarW, barH, alpha)
    end
    Bar:draw(playerBarX, barY, playerBarW, barH, scene.displayPlayerHP or scene.playerHP, config.battle.playerMaxHP, { 224/255, 112/255, 126/255 })
    love.graphics.setColor(1, 1, 1, 1)
  end
  -- Draw HP bars for all enemies
  for i, pos in ipairs(enemyPositions) do
    local enemy = pos.enemy
    if enemy.hp > 0 or enemy.disintegrating or enemy.pendingDisintegration then
      local enemyBarW = pos.width * 0.7 -- 70% of sprite width
      local enemyBarX = pos.curX - enemyBarW * 0.5
      
      local barAlpha = 1.0
      if enemy.disintegrating then
        local cfg = config.battle.disintegration or {}
        local duration = cfg.duration or 1.5
        local progress = math.min(1, (enemy.disintegrationTime or 0) / duration)
        barAlpha = math.max(0, 1.0 - (progress / 0.7))
      end

      if barAlpha > 0 then
        love.graphics.push()
        love.graphics.setColor(1, 1, 1, barAlpha)

        local barColor = { 153/255, 224/255, 122/255 }
        local maxHP = enemy.maxHP
        local currentHP = enemy.displayHP or enemy.hp
        Bar:draw(enemyBarX, barY, enemyBarW, barH, currentHP, maxHP, barColor, barAlpha)

        local enemyLabel = (enemy and enemy.name) or (i == 1 and "Enemy" or ("Enemy " .. i))
        love.graphics.setColor(theme.colors.uiText[1], theme.colors.uiText[2], theme.colors.uiText[3], theme.colors.uiText[4] * barAlpha)
        drawCenteredText(enemyLabel, enemyBarX, barY + barH + 6, enemyBarW)
        love.graphics.pop()
        love.graphics.setColor(1, 1, 1, 1)
      end
    end
  end

  if (scene.playerArmor or 0) > 0 and playerBarW > 0 then
    local valueStr = tostring(scene.playerArmor)
    local textW = theme.fonts.base:getWidth(valueStr)
    local iconW, iconH, s = 0, 0, 1
    if scene.iconArmor then
      iconW, iconH = scene.iconArmor:getWidth(), scene.iconArmor:getHeight()
      s = 20 / math.max(1, iconH)
    end
    local barLeftEdge = playerX - playerBarW * 0.5
    local armorSpacing = 8
    local startX = barLeftEdge - (textW + (scene.iconArmor and (iconW * s + 6) or 0) + armorSpacing)
    local y = barY + (barH - theme.fonts.base:getHeight()) * 0.5
    local flashAlpha = 1
    local flashScale = 1
    if scene.armorIconFlashTimer and scene.armorIconFlashTimer > 0 then
      local flashProgress = 1 - (scene.armorIconFlashTimer / 0.5)
      flashAlpha = 1 + math.sin(flashProgress * math.pi * 4) * 0.5
      flashAlpha = math.max(0.3, math.min(1.5, flashAlpha))
      flashScale = 1 + math.sin(flashProgress * math.pi * 2) * 0.2
    end
    if scene.iconArmor then
      local iconX = startX
      local iconY = y + (theme.fonts.base:getHeight() - iconH * s) * 0.5
      love.graphics.push()
      love.graphics.translate(iconX + iconW * s * 0.5, iconY + iconH * s * 0.5)
      love.graphics.scale(flashScale, flashScale)
      love.graphics.translate(-iconW * s * 0.5, -iconH * s * 0.5)
      love.graphics.setColor(1, 1, 1, flashAlpha)
      love.graphics.draw(scene.iconArmor, 0, 0, 0, s, s)
      love.graphics.pop()
      startX = startX + iconW * s + 6
    end
    love.graphics.setColor(1, 1, 1, 0.9)
    theme.drawTextWithOutline(valueStr, startX, y, 1, 1, 1, 0.9, 2)
    love.graphics.setColor(1, 1, 1, 1)
  end

  -- Fog effect behind sprites
  local fogConfig = config.battle.fog or {}
  if (fogConfig.enabled ~= false) and scene.fogShader then
    love.graphics.push("all")
    love.graphics.setBlendMode("alpha")
    love.graphics.setShader(scene.fogShader)
    scene.fogShader:send("u_time", scene.fogTime or 0)
    -- For shader resolution: use canvas dimensions scaled to match where the rectangle actually renders
    -- The rectangle is drawn at (0,0,w,h) on the canvas, but sc coordinates depend on Retina
    local currentCanvas = love.graphics.getCanvas()
    local logicalW, logicalH = love.graphics.getDimensions()
    local pixelW, pixelH = love.graphics.getPixelDimensions()
    
    -- Check if we're on a Retina display
    local isRetina = (pixelW > logicalW + 1) or (pixelH > logicalH + 1)
    
    -- With supersampling, we're always rendering to a canvas at supersampled resolution
    -- The shader coordinates (sc) are relative to the supersampled canvas
    local supersamplingFactor = _G.supersamplingFactor or 1
    scene.fogShader:send("u_resolution", {w * supersamplingFactor, h * supersamplingFactor})
    scene.fogShader:send("u_cloudDensity", fogConfig.cloudDensity or 0.15)
    scene.fogShader:send("u_noisiness", fogConfig.noisiness or 0.35)
    scene.fogShader:send("u_speed", fogConfig.speed or 0.1)
    scene.fogShader:send("u_cloudHeight", fogConfig.cloudHeight or 2.5)
    scene.fogShader:send("u_fogStartY", fogConfig.startY or 0.65)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setShader()
    love.graphics.pop()
  end

  -- Player sprite or fallback
  if scene.playerImg then
    local iw, ih = scene.playerImg:getWidth(), scene.playerImg:getHeight()
    local s = playerScale
    local bobA = (config.battle and config.battle.idleBobScaleY) or 0
    local bobF = (config.battle and config.battle.idleBobSpeed) or 1
    local bob = 1 + bobA * (0.5 - 0.5 * math.cos(2 * math.pi * bobF * (scene.idleT or 0)))
    local sx, sy = s, s * bob
    local tilt = scene.playerRotation or 0
    local drawAlpha = 1.0
    do
      local d = (config.battle and config.battle.lungeDuration) or 0
      local rdur = (config.battle and config.battle.lungeReturnDuration) or 0
      local t = scene.playerLungeTime or 0
      local impactsActive = (scene.impactInstances and #scene.impactInstances > 0)
      if t > 0 and (d > 0 or rdur > 0) then
        if t < d and d > 0 then
          local p = math.max(0, math.min(1, t / d))
          drawAlpha = 1.0 - p
        elseif impactsActive and t < d + rdur then
          drawAlpha = 0.0
        elseif t < d + rdur and rdur > 0 then
          local p = math.max(0, math.min(1, (t - d) / math.max(0.0001, rdur)))
          drawAlpha = p
        else
          drawAlpha = 1.0
        end
      end
    end
    local brightnessMultiplier = 1
    local pulseConfig = config.battle.pulse
    if pulseConfig and (pulseConfig.enabled ~= false) then
      local variation = pulseConfig.brightnessVariation or 0.08
      brightnessMultiplier = 1 + math.sin(scene.playerPulseTime or 0) * variation
    end
    if scene.playerFlash and scene.playerFlash > 0 and scene.whiteSilhouetteShader then
      -- Solid white silhouette (override base sprite)
      love.graphics.setShader(scene.whiteSilhouetteShader)
      scene.whiteSilhouetteShader:send("u_alpha", 1.0)
      love.graphics.setBlendMode("alpha")
      love.graphics.setColor(1, 1, 1, drawAlpha)
      love.graphics.draw(scene.playerImg, curPlayerX, baselineY, scene.playerRotation or 0, sx, sy, iw * 0.5, ih)
      love.graphics.setShader()
      love.graphics.setColor(1, 1, 1, 1)
    else
      love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, drawAlpha)
      love.graphics.draw(scene.playerImg, curPlayerX, baselineY, tilt, sx, sy, iw * 0.5, ih)
      if scene.playerFlash and scene.playerFlash > 0 then
        local base = scene.playerFlash / math.max(0.0001, config.battle.hitFlashDuration)
        local a = math.min(1, base * ((config.battle and config.battle.hitFlashAlphaScale) or 1)) * (drawAlpha or 1)
        local passes = (config.battle and config.battle.hitFlashPasses) or 1
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1, 1, 1, a)
        for i = 1, math.max(1, passes) do
          love.graphics.draw(scene.playerImg, curPlayerX, baselineY, scene.playerRotation or 0, sx, sy, iw * 0.5, ih)
        end
        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, drawAlpha)
      end
    end
  else
    local brightnessMultiplier = 1
    local pulseConfig = config.battle.pulse
    if pulseConfig and (pulseConfig.enabled ~= false) then
      local variation = pulseConfig.brightnessVariation or 0.08
      brightnessMultiplier = 1 + math.sin(scene.playerPulseTime or 0) * variation
    end
    if scene.playerFlash and scene.playerFlash > 0 then
      love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, 1)
    else
      love.graphics.setColor(0.2 * brightnessMultiplier, 0.8 * brightnessMultiplier, 0.3 * brightnessMultiplier, 1)
    end
    love.graphics.circle("fill", curPlayerX, baselineY - r, r)
    love.graphics.setColor(1, 1, 1, 1)
  end

  -- Speed streaks behind sprites
  do
    local cfg = config.battle and config.battle.speedStreaks
    if cfg and cfg.enabled and scene.lungeStreaks and #scene.lungeStreaks > 0 then
      love.graphics.push("all")
      love.graphics.setBlendMode("add")
      local thickness = cfg.thickness or 3
      for _, s in ipairs(scene.lungeStreaks) do
        local t = math.max(0, s.life / math.max(0.0001, s.maxLife))
        local alpha = (cfg.alpha or 0.45) * t
        if alpha > 0 then
          love.graphics.setColor(1, 1, 1, alpha)
          love.graphics.rectangle("fill", s.x - s.len, s.y - thickness * 0.5, s.len, thickness, 2, 2)
        end
      end
      love.graphics.pop()
    end
  end

  -- Draw enemy sprites (skip if win)
  for i, pos in ipairs(enemyPositions) do
    local enemy = pos.enemy
    if enemy.hp > 0 or enemy.disintegrating or enemy.pendingDisintegration then
      if enemy.img and scene.state ~= "win" then
        local iw, ih = enemy.img:getWidth(), enemy.img:getHeight()
        local s = pos.scale
        local bobA = (config.battle and config.battle.idleBobScaleY) or 0
        local bobF = (config.battle and config.battle.idleBobSpeed) or 1
        local phaseOffset = (i - 1) * math.pi * 0.5 -- Phase offset for variety between enemies
        local bob = 1 + bobA * (0.5 - 0.5 * math.cos(2 * math.pi * bobF * (scene.idleT or 0) + phaseOffset))
        local sx, sy = s, s * bob
        local tilt = enemy.rotation or 0
        
        if enemy.disintegrating and scene.disintegrationShader then
          local cfg = config.battle.disintegration or {}
          local duration = cfg.duration or 1.5
          local progress = math.min(1, (enemy.disintegrationTime or 0) / duration)
          local noiseScale = cfg.noiseScale or 20
          local thickness = cfg.thickness or 0.25
          local lineColor = cfg.lineColor or {1.0, 0.3, 0.1, 1.0}
          local colorIntensity = cfg.colorIntensity or 2.0
          love.graphics.setShader(scene.disintegrationShader)
          scene.disintegrationShader:send("u_time", enemy.disintegrationTime)
          scene.disintegrationShader:send("u_noiseScale", noiseScale)
          scene.disintegrationShader:send("u_thickness", thickness)
          scene.disintegrationShader:send("u_lineColor", lineColor)
          scene.disintegrationShader:send("u_colorIntensity", colorIntensity)
          scene.disintegrationShader:send("u_progress", progress)
        end
        
        local brightnessMultiplier = 1
        local pulseConfig = config.battle.pulse
        if pulseConfig and (pulseConfig.enabled ~= false) then
          local variation = pulseConfig.brightnessVariation or 0.08
          brightnessMultiplier = 1 + math.sin(enemy.pulseTime or 0) * variation
        end
        
        -- Calculate backward skew when hit (shear backwards)
        local skewX = 0
        if enemy.flash and enemy.flash > 0 and not enemy.disintegrating then
          local flashProgress = 1 - (enemy.flash / math.max(0.0001, config.battle.hitFlashDuration))
          -- Backward skew: negative shearX value, easing out as flash fades
          local maxSkew = -0.15 -- Backward lean amount
          skewX = maxSkew * (1 - flashProgress) * (1 - flashProgress) -- Quadratic ease-out
        end
        
        love.graphics.push()
        -- Apply skew around the sprite's bottom-center pivot point
        if skewX ~= 0 then
          local enemyY = pos.curY or pos.y
          love.graphics.translate(pos.curX, enemyY)
          love.graphics.shear(skewX, 0)
          love.graphics.translate(-pos.curX, -enemyY)
        end
        
        local enemyY = pos.curY or pos.y -- Use curY if available (for jump animation)
        if enemy.flash and enemy.flash > 0 and not enemy.disintegrating and scene.whiteSilhouetteShader then
          -- Solid white silhouette (override base sprite)
          love.graphics.setShader(scene.whiteSilhouetteShader)
          scene.whiteSilhouetteShader:send("u_alpha", 1.0)
          love.graphics.setBlendMode("alpha")
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.draw(enemy.img, pos.curX, enemyY, enemy.rotation or 0, sx, sy, iw * 0.5, ih)
          love.graphics.setShader()
          love.graphics.setColor(1, 1, 1, 1)
        else
          love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, 1)
          love.graphics.draw(enemy.img, pos.curX, enemyY, tilt, sx, sy, iw * 0.5, ih)

          if enemy.disintegrating and scene.disintegrationShader then
            love.graphics.setShader()
          end

          if enemy.flash and enemy.flash > 0 and not enemy.disintegrating then
            local base = enemy.flash / math.max(0.0001, config.battle.hitFlashDuration)
            local a = math.min(1, base * ((config.battle and config.battle.hitFlashAlphaScale) or 1))
            local passes = (config.battle and config.battle.hitFlashPasses) or 1
            love.graphics.setBlendMode("add")
            love.graphics.setColor(1, 1, 1, a)
            for j = 1, math.max(1, passes) do
              love.graphics.draw(enemy.img, pos.curX, enemyY, enemy.rotation or 0, sx, sy, iw * 0.5, ih)
            end
            love.graphics.setBlendMode("alpha")
            love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, 1)
          end
        end
        
        love.graphics.pop()
      elseif scene.state ~= "win" then
        -- Fallback circle if no sprite
        local brightnessMultiplier = 1
        local pulseConfig = config.battle.pulse
        if pulseConfig and (pulseConfig.enabled ~= false) then
          local variation = pulseConfig.brightnessVariation or 0.08
          brightnessMultiplier = 1 + math.sin(enemy.pulseTime or 0) * variation
        end
        if enemy.flash and enemy.flash > 0 then
          love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, 1)
        else
          love.graphics.setColor(0.9 * brightnessMultiplier, 0.2 * brightnessMultiplier, 0.2 * brightnessMultiplier, 1)
        end
        local enemyY = pos.curY or pos.y
        love.graphics.circle("fill", pos.curX, enemyY - r, r)
        love.graphics.setColor(1, 1, 1, 1)
      end
    end
  end

  -- Draw selection indicators above HP bars (after enemy sprites for higher z-order)
  if scene.selectedEnemyIndex and scene.selectedIndicatorImg then
    local selectedEnemy = scene.enemies and scene.enemies[scene.selectedEnemyIndex]
    if selectedEnemy and (selectedEnemy.hp > 0 or selectedEnemy.disintegrating or selectedEnemy.pendingDisintegration) then
      local selectedPos = enemyPositions[scene.selectedEnemyIndex]
      if selectedPos then
        local enemyBarW = selectedPos.width * 0.7 -- 70% of sprite width
        local enemyBarX = selectedPos.curX - enemyBarW * 0.5
        
        local barAlpha = 1.0
        if selectedEnemy.disintegrating then
          local cfg = config.battle.disintegration or {}
          local duration = cfg.duration or 1.5
          local progress = math.min(1, (selectedEnemy.disintegrationTime or 0) / duration)
          barAlpha = math.max(0, 1.0 - (progress / 0.7))
        end
        
        if barAlpha > 0 then
          local indicatorImg = scene.selectedIndicatorImg
          local indicatorW, indicatorH = indicatorImg:getWidth(), indicatorImg:getHeight()
          local indicatorScale = (enemyBarW * 0.9) / indicatorW -- Scale to 90% of HP bar width
          
          -- Bobbing animation: slight up and down movement
          local bobSpeed = 1.0 -- Speed of bobbing (slowed down by 50%)
          local bobAmplitude = 1 -- Amplitude in pixels (reduced for subtler movement)
          local bobOffset = math.sin((scene.idleT or 0) * bobSpeed * 2 * math.pi) * bobAmplitude
          
          -- Position below HP bar (shifted down more)
          local indicatorY = barY - (indicatorH * indicatorScale * 0.5) - 4 + bobOffset -- 4px gap above HP bar (shifted down)
          love.graphics.setColor(1, 1, 1, barAlpha) -- Use same alpha as HP bar
          love.graphics.draw(indicatorImg, selectedPos.curX, indicatorY, 0, indicatorScale, indicatorScale, indicatorW * 0.5, indicatorH * 0.5)
        end
      end
    end
  end

  -- Draw impacts between sprites and popups (maintain original z-order)
  ImpactSystem.draw(scene)

  -- Popups
  love.graphics.setFont(theme.fonts.large)
  local function singleSoftBounce(t)
    local c1, c3 = 1.70158, 2.70158
    local u = (t - 1)
    return 1 + c3 * (u * u * u) + c1 * (u * u)
  end
  for _, p in ipairs(scene.popups or {}) do
    local life = math.max(0.0001, config.battle.popupLifetime)
    local prog = 1 - math.max(0, p.t / life)
    local baseTop
    local x
    if p.who == "enemy" then
      -- Find enemy position from enemyPositions array
      local enemyIndex = p.enemyIndex or 1
      local pos = enemyPositions[enemyIndex]
      if pos then
        local enemy = pos.enemy
        baseTop = baselineY - (enemy.img and (enemy.img:getHeight() * pos.scale) or (2 * r))
        x = pos.curX
      else
        -- Fallback
        baseTop = baselineY - (2 * r)
        x = rightStart + rightWidth * 0.5
      end
    else
      baseTop = baselineY - (scene.playerImg and (scene.playerImg:getHeight() * playerScale) or (2 * r))
      x = curPlayerX
    end
    local bounce = singleSoftBounce(math.min(1, prog))
    local height = (config.battle and config.battle.popupBounceHeight) or 60
    local y = baseTop - 20 - bounce * height
    local start = (config.battle and config.battle.popupFadeStart) or 0.7
    local mul = (config.battle and config.battle.popupFadeMultiplier) or 0.5
    local alpha
    if prog <= start then
      alpha = 1
    else
      local frac = (prog - start) / math.max(1e-6, (1 - start))
      local scaled = frac / math.max(1e-6, mul)
      alpha = math.max(0, 1 - scaled)
    end
    local r1, g1, b1 = 1, 1, 1
    if p.who == "player" and p.kind ~= "armor" and p.kind ~= "heal" then
      r1, g1, b1 = 224/255, 112/255, 126/255
    end
    if p.kind == "armor" and scene.iconArmor then
      local valueStr = tostring(p.value or 0)
      local textW = theme.fonts.large:getWidth(valueStr)
      local iconW, iconH = scene.iconArmor:getWidth(), scene.iconArmor:getHeight()
      local s = 28 / math.max(1, iconH)
      local totalW = textW + iconW * s + 6
      local startX = x - totalW * 0.5
      love.graphics.setColor(r1, g1, b1, alpha)
      love.graphics.draw(scene.iconArmor, startX, y - 40 + (theme.fonts.large:getHeight() - iconH * s) * 0.5, 0, s, s)
      theme.printfWithOutline(valueStr, startX + iconW * s + 6, y - 40, totalW - (iconW * s + 6), "left", r1, g1, b1, alpha, 2)
    elseif p.kind == "heal" and scene.iconPotion then
      local valueStr = "+" .. tostring(p.value or 0)
      local textW = theme.fonts.large:getWidth(valueStr)
      local iconW, iconH = scene.iconPotion:getWidth(), scene.iconPotion:getHeight()
      local s = 28 / math.max(1, iconH)
      local totalW = textW + iconW * s + 6
      local startX = x - totalW * 0.5
      -- Heal popup uses green color #6EAD73
      r1, g1, b1 = 110/255, 173/255, 115/255
      love.graphics.setColor(r1, g1, b1, alpha)
      love.graphics.draw(scene.iconPotion, startX, y - 40 + (theme.fonts.large:getHeight() - iconH * s) * 0.5, 0, s, s)
      theme.printfWithOutline(valueStr, startX + iconW * s + 6, y - 40, totalW - (iconW * s + 6), "left", r1, g1, b1, alpha, 2)
    elseif p.kind == "armor_blocked" and scene.iconArmor then
      local iconW, iconH = scene.iconArmor:getWidth(), scene.iconArmor:getHeight()
      local s = 28 / math.max(1, iconH)
      local startX = x - (iconW * s) * 0.5
      love.graphics.setColor(1, 1, 1, alpha)
      love.graphics.draw(scene.iconArmor, startX, y - 40 + (theme.fonts.large:getHeight() - iconH * s) * 0.5, 0, s, s)
    else
      theme.printfWithOutline(p.text or "", x - 40, y - 40, 80, "center", r1, g1, b1, alpha, 2)
    end
  end
  love.graphics.setFont(theme.fonts.base)

  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, 1)
end

return Visuals


