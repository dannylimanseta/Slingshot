local config = require("config")
local theme = require("theme")
local Bar = require("ui.Bar")
local ImpactSystem = require("scenes.battle.ImpactSystem")
local TurnManager = require("core.TurnManager")

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
    -- Default lunge
    local enemyLunge = lungeOffset(enemy.lungeTime, false)
    -- Charged lunge override: windup backwards then forward further
    if enemy.chargeLungeTime and enemy.chargeLungeTime > 0 and enemy.chargeLunge then
      -- Ease-in-ease-out function (smoothstep)
      local function easeInOut(t)
        return t * t * (3 - 2 * t)
      end
      
      local t = enemy.chargeLungeTime
      local w = enemy.chargeLunge.windupDuration or 0.55
      local f = enemy.chargeLunge.forwardDuration or 0.2
      local rret = enemy.chargeLunge.returnDuration or 0.2
      local back = enemy.chargeLunge.backDistance or ((config.battle and config.battle.lungeDistance) or 80) * 0.6
      local fwd = enemy.chargeLunge.forwardDistance or ((config.battle and config.battle.lungeDistance) or 80) * 2.8
      local leftward = 0 -- positive = toward player (left), negative = away (right)
      if t < w then
        -- Windup: move right (negative leftward) with ease-in-ease-out
        local p = t / math.max(0.0001, w)
        p = easeInOut(p)
        leftward = -back * p
      elseif t < w + f then
        -- Charge forward: move left with ease-in-ease-out
        local p = (t - w) / math.max(0.0001, f)
        p = easeInOut(p)
        leftward = fwd * p
      else
        -- Return to origin with ease-in-ease-out
        local p = (t - w - f) / math.max(0.0001, rret)
        p = easeInOut(p)
        leftward = fwd * (1 - p)
      end
      pos.curX = pos.x - leftward -- apply charged leftward offset
    else
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

        -- Enemy name will be drawn after fog shader to appear above it
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

  -- Draw enemy names after fog shader (so they appear above it)
  love.graphics.setFont(theme.fonts.base) -- Use smaller font for enemy names
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
        local enemyLabel = (enemy and enemy.name) or (i == 1 and "Enemy" or ("Enemy " .. i))
        love.graphics.setColor(theme.colors.uiText[1], theme.colors.uiText[2], theme.colors.uiText[3], theme.colors.uiText[4] * barAlpha)
        -- Use smaller scale for enemy names (0.7x)
        love.graphics.push()
        love.graphics.translate(enemyBarX + enemyBarW * 0.5, barY + barH + 6)
        love.graphics.scale(0.7, 0.7)
        love.graphics.translate(-enemyBarW * 0.5, 0)
        theme.printfWithOutline(enemyLabel, 0, 0, enemyBarW, "center", theme.colors.uiText[1], theme.colors.uiText[2], theme.colors.uiText[3], theme.colors.uiText[4] * barAlpha, 2)
        love.graphics.pop()
        love.graphics.setColor(1, 1, 1, 1)
      end
    end
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
        
        -- Update selector alpha based on turn phase (fade out during enemy turn)
        do
          local turnManager = scene.turnManager
          local tmState = turnManager and turnManager:getState() or nil
          local isEnemyTurn = tmState == TurnManager.States.ENEMY_TURN_START
            or tmState == TurnManager.States.ENEMY_TURN_ACTIVE
            or tmState == TurnManager.States.ENEMY_TURN_RESOLVING
          local targetAlpha = isEnemyTurn and 0.0 or 1.0
          local now = love.timer.getTime()
          local last = scene._selectorAlphaTime or now
          local dtAlpha = math.min(0.05, now - last)
          scene._selectorAlphaTime = now
          local speed = 6.0
          scene._selectorAlpha = scene._selectorAlpha or 1.0
          local delta = targetAlpha - scene._selectorAlpha
          scene._selectorAlpha = scene._selectorAlpha + delta * math.min(1, speed * dtAlpha)
        end
        
        -- Draw glow behind selected enemy (before any transformations)
        local enemyY = pos.curY or pos.y -- Use curY if available (for jump animation)
        if scene.selectedEnemyIndex == i and scene.glowSelectedImg then
          local glowAlpha = 1.0
          if enemy.disintegrating then
            local cfg = config.battle.disintegration or {}
            local duration = cfg.duration or 1.5
            local progress = math.min(1, (enemy.disintegrationTime or 0) / duration)
            glowAlpha = math.max(0, 1.0 - (progress / 0.7))
          end
          -- Apply selector fade alpha (during enemy turn)
          glowAlpha = glowAlpha * (scene._selectorAlpha or 1.0)
          
          if glowAlpha > 0 then
            local glowImg = scene.glowSelectedImg
            local glowW, glowH = glowImg:getWidth(), glowImg:getHeight()
            -- Use constant scale for consistent positioning across all enemies
            local constantGlowWidth = 100 -- Fixed width in pixels
            local glowScale = (constantGlowWidth / glowW) * 1.5 -- 1.5x size increase
            
            -- Bobbing animation: same as selected indicator
            local bobSpeed = 1.0 -- Speed of bobbing (slowed down by 50%)
            local bobAmplitude = 1 -- Amplitude in pixels (reduced for subtler movement)
            local bobOffset = math.sin((scene.idleT or 0) * bobSpeed * 2 * math.pi) * bobAmplitude
            
            love.graphics.push("all")
            love.graphics.setBlendMode("add")
            love.graphics.setColor(1, 1, 1, glowAlpha * 0.6) -- Reduced opacity to 0.6
            -- Position glow from bottom-center pivot to match enemy sprite pivot (iw * 0.5, ih)
            -- Shift down by 12px and apply bobbing animation
            -- Increase width and height by 20%
            love.graphics.draw(glowImg, pos.curX, enemyY + 19 + bobOffset, 0, glowScale * 1.2, glowScale * 1.2, glowW * 0.5, glowH)
            love.graphics.pop()
          end
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
          love.graphics.translate(pos.curX, enemyY)
          love.graphics.shear(skewX, 0)
          love.graphics.translate(-pos.curX, -enemyY)
        end
        
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
          -- Apply darkening to non-attacking enemies
          local darkness = 0.0
          if scene._attackingEnemyIndex and scene._attackingEnemyIndex ~= i then
            darkness = scene._nonAttackingEnemyDarkness or 0.0
          end
          -- Darken to 30% brightness at max darkness (more visible)
          local darkenMultiplier = 1.0 - (darkness * 0.7) -- darkness 1.0 = 30% brightness
          local finalBrightness = brightnessMultiplier * darkenMultiplier
          
          love.graphics.setColor(finalBrightness, finalBrightness, finalBrightness, 1)
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
            -- Restore darkening after flash
            local darkness = 0.0
            if scene._attackingEnemyIndex and scene._attackingEnemyIndex ~= i then
              darkness = scene._nonAttackingEnemyDarkness or 0.0
            end
            local darkenMultiplier = 1.0 - (darkness * 0.7)
            local finalBrightness = brightnessMultiplier * darkenMultiplier
            love.graphics.setColor(finalBrightness, finalBrightness, finalBrightness, 1)
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

  -- Draw smoke effect for shockwave attack (around enemy base when landing)
  if scene._shockwaveSequence and scene._shockwaveSequence.smokeTimer and scene._shockwaveSequence.smokeTimer > 0 and scene.smokeImage then
    local seq = scene._shockwaveSequence
    local enemy = seq.enemy
    if enemy then
      -- Find enemy position
      for i, pos in ipairs(enemyPositions) do
        if pos.enemy == enemy then
          local enemyY = pos.curY or pos.y -- Bottom of sprite (pivot point)
          local enemyX = pos.curX or pos.x
          local enemyHeight = 0
          if enemy.img then
            local spriteHeight = enemy.img:getHeight()
            local baseScale = pos.scale
            local bobA = (config.battle and config.battle.idleBobScaleY) or 0
            local maxBobScale = 1 + bobA
            local maxScaleY = baseScale * maxBobScale
            enemyHeight = spriteHeight * maxScaleY
          end
          
          -- Position smoke at base of enemy (bottom of sprite)
          local smokeBaseY = enemyY -- Base of enemy sprite
          
          -- Calculate smoke animation progress (0 to 1)
          local progress = seq.smokeTimer / seq.smokeDuration
          
          -- Fade in and out: quick fade in (0-0.2), hold (0.2-0.6), fade out (0.6-1.0)
          local alpha = 1.0
          if progress < 0.2 then
            -- Fade in quickly
            alpha = progress / 0.2
          elseif progress > 0.6 then
            -- Fade out
            alpha = 1.0 - ((progress - 0.6) / 0.4)
          end
          
          -- Scale: start small, grow, then shrink slightly
          local baseScale = 0.6
          local maxScale = 1.2
          local scale = baseScale
          if progress < 0.5 then
            -- Grow from baseScale to maxScale
            scale = baseScale + (maxScale - baseScale) * (progress / 0.5)
          else
            -- Slightly shrink from maxScale (reduced shrinkage - only to 95% of baseScale instead of 80%)
            scale = maxScale - (maxScale - baseScale * 0.95) * ((progress - 0.5) / 0.5)
          end
          
          -- Draw multiple smoke puffs around the base for better effect
          local smokeImg = scene.smokeImage
          local smokeW, smokeH = smokeImg:getWidth(), smokeImg:getHeight()
          local numPuffs = 5
          -- Increased spread radius - wider distribution around enemy base
          local baseSpreadRadius = 50 -- Base spread radius in pixels
          local spreadRadius = baseSpreadRadius * (0.8 + progress * 0.4) -- Expands over time
          
          love.graphics.push("all")
          love.graphics.setBlendMode("alpha")
          
          for j = 1, numPuffs do
            -- Distribute puffs around the enemy base in a wider circle
            local angle = (j / numPuffs) * 2 * math.pi
            -- Add slight random offset for more natural distribution
            local angleOffset = (j % 2 == 0) and 0.15 or -0.15 -- Alternate puffs slightly offset
            local finalAngle = angle + angleOffset
            
            -- Horizontal spread (full circle)
            local offsetX = math.cos(finalAngle) * spreadRadius
            -- Vertical spread (less vertical, more horizontal emphasis)
            local offsetY = math.sin(finalAngle) * spreadRadius * 0.6
            
            -- Slight rotation variation per puff
            local rotation = finalAngle + progress * 0.5
            
            -- Individual puff scale variation
            local puffScale = scale * (0.8 + (j % 3) * 0.1)
            
            love.graphics.setColor(1, 1, 1, alpha * 0.7) -- Slightly transparent
            love.graphics.draw(
              smokeImg,
              enemyX + offsetX,
              smokeBaseY + offsetY,
              rotation,
              puffScale,
              puffScale,
              smokeW * 0.5,
              smokeH * 0.5
            )
          end
          
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.pop()
          
          break -- Only draw for the shockwave enemy
        end
      end
    end
  end

  -- Draw charge puffs for enemies that are currently using the Charge skill
  do
    local puffL = scene.puffImageLeft
    local puffR = scene.puffImageRight
    if puffL or puffR then
      local t = (scene.idleT or 0)
      local speed = 0.8 -- cycles per second
      local cycle = (t * speed) % 1.0
      local baseAlpha = 0.9
      local maxRise = 40 -- pixels upwards
      local horizOffset = 20 -- horizontal offset from enemy center
      
      for i, pos in ipairs(enemyPositions) do
        local enemy = pos.enemy
        local intent = enemy and enemy.intent
        local isCharging = intent and intent.type == "skill" and intent.skillType == "charge"
        if isCharging then
          local enemyY = pos.curY or pos.y
          local enemyTopY
          if enemy.img then
            local spriteHeight = enemy.img:getHeight()
            local baseScale = pos.scale
            local bobA = (config.battle and config.battle.idleBobScaleY) or 0
            local maxBobScale = 1 + bobA
            enemyTopY = enemyY - spriteHeight * baseScale * maxBobScale
          else
            enemyTopY = enemyY - r * 2
          end
          
          local function drawPuff(img, dir)
            if not img then return end
            -- dir = -1 for left, 1 for right
            local phase = (dir == -1) and 0 or 0.5
            local p = (cycle + phase) % 1.0
            -- Quick fade-in, then fade-out over the cycle
            local fadeIn = 0.2
            local alpha
            if p < fadeIn then
              alpha = baseAlpha * (p / fadeIn)
            else
              local outP = (p - fadeIn) / math.max(0.0001, (1.0 - fadeIn))
              alpha = baseAlpha * (1.0 - outP)
            end
            if alpha <= 0 then return end
            local rise = maxRise * p
            local dx = horizOffset * dir * (0.5 + 0.5 * p)
              local x = pos.curX + dx
              if dir == -1 then
                -- Shift left puff further to the left for clearer separation
                x = x - 90
              end
            -- Base height a bit above the boar's head, shifted further down for better visibility
            local y = enemyTopY + 80 - rise
            
            local iw, ih = img:getWidth(), img:getHeight()
            local scale = 0.8
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.draw(img, x, y, 0, scale * dir, scale, iw * 0.5, ih * 0.5)
          end
          
          drawPuff(puffL, -1)
          drawPuff(puffR, 1)
          love.graphics.setColor(1, 1, 1, 1)
        end
      end
    end
  end

  -- Draw enemy intents (above enemy sprites, with fade animation)
  local turnManager = scene.turnManager
  local isPlayerTurn = turnManager and (
    turnManager:getState() == TurnManager.States.PLAYER_TURN_START or
    turnManager:getState() == TurnManager.States.PLAYER_TURN_ACTIVE
  )
  
  -- Draw intents if they exist and have fade time (allows fade out after player turn)
  for i, pos in ipairs(enemyPositions) do
    local enemy = pos.enemy
    if enemy and enemy.intent and enemy.intentFadeTime and enemy.intentFadeTime > 0 and enemy.hp > 0 and not enemy.disintegrating then
      local intentIcon = nil
      if enemy.intent.type == "attack" then
        intentIcon = scene.iconIntentAttack
      elseif enemy.intent.type == "armor" then
        intentIcon = scene.iconIntentArmor
      elseif enemy.intent.type == "skill" then
        intentIcon = scene.iconIntentSkill
      end
      
      if intentIcon then
        local iconW, iconH = intentIcon:getWidth(), intentIcon:getHeight()
        local iconScale = 0.34 -- Scale factor for intent icons (reduced by 15% from 0.4)
        local enemyY = pos.curY or pos.y -- This is the BOTTOM of the sprite (pivot point)
        
        -- Calculate enemy sprite height accounting for scaling and bobbing animation
        local enemyHeight
        if enemy.img then
          local spriteHeight = enemy.img:getHeight()
          local baseScale = pos.scale
          -- Account for maximum bobbing animation height (bob can increase scale)
          local bobA = (config.battle and config.battle.idleBobScaleY) or 0
          local maxBobScale = 1 + bobA -- Maximum bob scale factor
          local maxScaleY = baseScale * maxBobScale
          enemyHeight = spriteHeight * maxScaleY
        else
          enemyHeight = r * 2
        end
        
        -- Position icon above enemy sprite
        -- enemyY is the bottom of the sprite, so top is enemyY - enemyHeight
        local enemyTop = enemyY - enemyHeight -- Top edge of enemy sprite (at max bob height)
        local iconY = enemyTop - iconH * iconScale * 0.5 - 20 -- 20px gap above enemy top
        
        -- Calculate fade alpha (0 to 1)
        local fadeInDuration = 0.3
        local alpha = math.min(1, enemy.intentFadeTime / fadeInDuration)
        
        -- Bobbing animation for intent icons
        local bobSpeed = 1.2
        local bobAmplitude = 2
        local phaseOffset = (i - 1) * math.pi * 0.3
        local bobOffset = math.sin((scene.idleT or 0) * bobSpeed * 2 * math.pi + phaseOffset) * bobAmplitude
        
        -- Calculate text to display beside the icon
        local valueText = nil
        local isChargeSkill = (enemy.intent.type == "skill" and enemy.intent.skillType == "charge")
        local isShockwaveSkill = (enemy.intent.type == "skill" and enemy.intent.skillType == "shockwave")
        if isChargeSkill then
          -- Show charging label for boar Charge skill
          valueText = "Charging..."
        elseif isShockwaveSkill and enemy.intent.damage then
          -- Show damage for shockwave skill
          valueText = tostring(enemy.intent.damage)
        elseif enemy.intent.type == "attack" and enemy.intent.damage then
          -- Show fixed damage (e.g., shockwave)
          valueText = tostring(enemy.intent.damage)
        elseif enemy.intent.type == "attack" and enemy.intent.damageMin and enemy.intent.damageMax then
          -- Show damage range for normal attacks
          valueText = enemy.intent.damageMin == enemy.intent.damageMax and 
            tostring(enemy.intent.damageMin) or 
            (tostring(enemy.intent.damageMin) .. "-" .. tostring(enemy.intent.damageMax))
        elseif enemy.intent.type == "armor" and enemy.intent.amount then
          valueText = tostring(enemy.intent.amount)
        elseif enemy.intent.type == "skill" and enemy.intent.effect then
          -- Could show skill name or effect, for now skip
        end
        
        -- Calculate total width of icon + gap + text for centering
        -- Use exact measured text width for accurate centering
        local textW = 0
        local textH = 0
        if valueText then
          local font = love.graphics.getFont()
          textW = font:getWidth(valueText) -- Exact pixel width of "Charging..." or other text
          textH = font:getHeight()
        end
        
        local iconWidth = iconW * iconScale
        local gapWidth = valueText and 6 or 0 -- 6px gap between icon and text
        local totalWidth = iconWidth + gapWidth + textW -- Total bundle width
        
        -- To center: enemyCenterX = iconX + (gapWidth + textW) / 2
        -- Therefore: iconX = enemyCenterX - (gapWidth + textW) / 2
        local enemyCenterX = pos.curX or pos.x -- Enemy sprite center X (pivot point)
        -- Optional nudge to compensate for sprite visual padding; only apply for charge label
        local isBoarSprite = enemy and (enemy.name == "Deranged Boar" or (enemy.spritePath and enemy.spritePath:find("enemy_boar")))
        local nudgeX = isChargeSkill and (isBoarSprite and 44 or 12) or 0
        local iconX
        if isChargeSkill and valueText and textW > 0 then
          -- Center the text visually on the enemy, then place the icon to the left
          local textCenterX = enemyCenterX + nudgeX
          -- love.print draws from left baseline; convert center to left X
          local textXLeft = textCenterX - textW * 0.5
          -- Icon sits to the left of text by gap
          iconX = textXLeft - gapWidth - iconWidth * 0.5
        else
          -- Default: center the bundle span (icon + gap + text) over enemy
          iconX = enemyCenterX - (gapWidth + textW) * 0.5 + nudgeX
        end
        
        -- Draw icon with fade
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(intentIcon, iconX, iconY + bobOffset, 0, iconScale, iconScale, iconW * 0.5, iconH * 0.5)
        
        -- Draw text if available
        if valueText then
          -- Position text
          local textX
          if isChargeSkill and textW > 0 then
            -- Use the same centered text position as above
            local textCenterX = (pos.curX or pos.x) + nudgeX
            textX = textCenterX - textW * 0.5
          else
            -- Default: text to the right of the icon
            local iconRightEdge = iconX + iconWidth * 0.5
            textX = iconRightEdge + gapWidth
          end
          -- Align text center with icon center (love.graphics.print uses baseline, so adjust)
          local iconCenterY = iconY + bobOffset -- Icon center Y
          local textY = iconCenterY + textH * -0.28 -- Adjust for text baseline to center with icon
          
          -- Draw text in white with fade
          love.graphics.setColor(1, 1, 1, alpha)
          love.graphics.print(valueText, textX, textY)
        end
        
        love.graphics.setColor(1, 1, 1, 1) -- Reset color
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
          -- Apply selector fade alpha (during enemy turn)
          barAlpha = barAlpha * (scene._selectorAlpha or 1.0)
          local indicatorImg = scene.selectedIndicatorImg
          local indicatorW, indicatorH = indicatorImg:getWidth(), indicatorImg:getHeight()
          -- Use constant width instead of scaling based on enemy sprite size
          local constantIndicatorWidth = 120 -- Fixed width in pixels (2x size)
          local indicatorScale = constantIndicatorWidth / indicatorW
          
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
    -- Skip drawing popups that are still in start delay (for black hole attacks)
    if p.startDelay and p.startDelay > 0 then
      goto skip_popup
    end
    
    -- For animated damage popups, use the actual lifetime stored in t, otherwise use default
    local life = math.max(0.0001, p.kind == "animated_damage" and (p.originalLifetime or p.t) or config.battle.popupLifetime)
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
    elseif p.kind == "animated_damage" and p.sequence and #p.sequence > 0 then
      -- Display current step in animated damage sequence
      local sequenceIndex = p.sequenceIndex or 1
      local currentStep = p.sequence[sequenceIndex]
      if currentStep then
        local displayText = currentStep.text or ""
        
        -- Use DCC275 color (220, 194, 117) for multiplier steps, otherwise use default white
        local stepR, stepG, stepB = r1, g1, b1
        if currentStep.isMultiplier then
          stepR, stepG, stepB = 220/255, 194/255, 117/255
        end
        
        -- Apply shake and rotation for final step with exclamation
        local shakeX = p.shakeOffsetX or 0
        local shakeY = p.shakeOffsetY or 0
        local rotation = p.shakeRotation or 0
        local centerX = x
        
        -- Calculate bounce offset for step changes (ease-out-back curve)
        local bounceOffset = 0
        if p.bounceTimer then
          local bounceDuration = 0.3 -- Duration of bounce animation in seconds
          local bounceProgress = math.min(1, p.bounceTimer / bounceDuration)
          if bounceProgress > 0 then
            -- Ease-out-back curve (same as block popups)
            local c1, c3 = 1.70158, 2.70158
            local u = (bounceProgress - 1)
            local bounce = 1 + c3 * (u * u * u) + c1 * (u * u)
            local bounceHeight = 25 -- Height of bounce in pixels
            bounceOffset = (1 - bounce) * bounceHeight -- Negative offset (upward)
          end
        end
        
        local centerY = y - 40 + bounceOffset
        
        -- Check if we're on the final step with exclamation to apply rotation
        local isFinalStep = (sequenceIndex == #p.sequence)
        local finalStep = p.sequence[#p.sequence]
        local hasExclamation = finalStep and finalStep.text and string.find(finalStep.text, "!") ~= nil
        
        -- Handle multiplier text with sequential character bounces
        if currentStep.isMultiplier and p.charBounceTimers then
          -- Parse multiplier text (e.g., "5x2" into "5", "x", "2")
          local multiplierText = displayText
          local firstNum, xChar, secondNum = multiplierText:match("^(%d+)(x)(%d+)$")
          
          if firstNum and xChar and secondNum then
            -- Initialize multiplier target if not set
            if not p.multiplierTarget then
              p.multiplierTarget = tonumber(secondNum)
            end
            
            -- Calculate character bounce offsets
            -- Use longer duration for multiplier animation to ensure it completes
            local charBounceDuration = 0.4 -- Longer duration to ensure animation completes
            local charBounceHeight = 25
            local charOffsets = {}
            
            for i = 1, 3 do
              local charTimer = p.charBounceTimers[i] or 0
              local charProgress = math.min(1, charTimer / charBounceDuration)
              if charProgress > 0 then
                local c1, c3 = 1.70158, 2.70158
                local u = (charProgress - 1)
                local bounce = 1 + c3 * (u * u * u) + c1 * (u * u)
                charOffsets[i] = (1 - bounce) * charBounceHeight
              else
                charOffsets[i] = 0
              end
            end
            
            -- Show final multiplier number directly (no animation)
            local displaySecondNum = tostring(p.multiplierTarget)
            
            -- Get font for measuring
            local font = theme.fonts.large
            love.graphics.setFont(font)
            
            -- Calculate positions for each character
            -- Use target multiplier for width calculation to prevent layout shift
            local targetSecondNum = tostring(p.multiplierTarget)
            local firstNumW = font:getWidth(firstNum)
            local xCharW = font:getWidth(xChar)
            local secondNumW = font:getWidth(targetSecondNum) -- Use target width for stable layout
            local totalWidth = firstNumW + xCharW + secondNumW
            
            local startX = centerX - totalWidth * 0.5
            local firstNumX = startX + firstNumW * 0.5
            local xCharX = startX + firstNumW + xCharW * 0.5
            local secondNumX = startX + firstNumW + xCharW + secondNumW * 0.5
            
            -- Draw each character with its own bounce offset
            local baseY = centerY + shakeY
            
            -- Draw first number
            love.graphics.push()
            if isFinalStep and hasExclamation and p.shakeTime then
              love.graphics.translate(firstNumX + shakeX, baseY)
              love.graphics.rotate(rotation)
              love.graphics.translate(-firstNumW * 0.5, charOffsets[1])
            else
              love.graphics.translate(firstNumX + shakeX, baseY + charOffsets[1])
            end
            theme.printfWithOutline(firstNum, -firstNumW * 0.5, 0, firstNumW, "center", stepR, stepG, stepB, alpha, 2)
            love.graphics.pop()
            
            -- Draw "x" character
            love.graphics.push()
            if isFinalStep and hasExclamation and p.shakeTime then
              love.graphics.translate(xCharX + shakeX, baseY)
              love.graphics.rotate(rotation)
              love.graphics.translate(-xCharW * 0.5, charOffsets[2])
            else
              love.graphics.translate(xCharX + shakeX, baseY + charOffsets[2])
            end
            theme.printfWithOutline(xChar, -xCharW * 0.5, 0, xCharW, "center", stepR, stepG, stepB, alpha, 2)
            love.graphics.pop()
            
            -- Draw second number (animated)
            love.graphics.push()
            if isFinalStep and hasExclamation and p.shakeTime then
              love.graphics.translate(secondNumX + shakeX, baseY)
              love.graphics.rotate(rotation)
              love.graphics.translate(-secondNumW * 0.5, charOffsets[3])
            else
              love.graphics.translate(secondNumX + shakeX, baseY + charOffsets[3])
            end
            theme.printfWithOutline(displaySecondNum, -secondNumW * 0.5, 0, secondNumW, "center", stepR, stepG, stepB, alpha, 2)
            love.graphics.pop()
          else
            -- Fallback: draw normally if parsing fails
            local textWidth = math.max(120, theme.fonts.large:getWidth(displayText) + 20)
            if isFinalStep and hasExclamation and p.shakeTime then
              love.graphics.push()
              love.graphics.translate(centerX + shakeX, centerY + shakeY)
              love.graphics.rotate(rotation)
              love.graphics.translate(-textWidth * 0.5, 0)
              theme.printfWithOutline(displayText, 0, 0, textWidth, "center", stepR, stepG, stepB, alpha, 2)
              love.graphics.pop()
            else
              theme.printfWithOutline(displayText, centerX - textWidth * 0.5 + shakeX, centerY + shakeY, textWidth, "center", stepR, stepG, stepB, alpha, 2)
            end
          end
        else
          -- Non-multiplier text: draw normally
          local textWidth = math.max(120, theme.fonts.large:getWidth(displayText) + 20) -- Dynamic width with padding
          
          if isFinalStep and hasExclamation and p.shakeTime then
            -- Draw with rotation around center point
            love.graphics.push()
            love.graphics.translate(centerX + shakeX, centerY + shakeY)
            love.graphics.rotate(rotation)
            love.graphics.translate(-textWidth * 0.5, 0)
            theme.printfWithOutline(displayText, 0, 0, textWidth, "center", stepR, stepG, stepB, alpha, 2)
            love.graphics.pop()
          else
            -- Draw without rotation, just apply shake
            theme.printfWithOutline(displayText, centerX - textWidth * 0.5 + shakeX, centerY + shakeY, textWidth, "center", stepR, stepG, stepB, alpha, 2)
          end
        end
      end
    else
      theme.printfWithOutline(p.text or "", x - 40, y - 40, 80, "center", r1, g1, b1, alpha, 2)
    end
    
    ::skip_popup::
  end
  love.graphics.setFont(theme.fonts.base)

  love.graphics.pop()
  love.graphics.setColor(1, 1, 1, 1)
end

return Visuals


