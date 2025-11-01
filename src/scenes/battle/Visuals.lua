local config = require("config")
local theme = require("theme")
local Bar = require("ui.Bar")
local ImpactSystem = require("scenes.battle.ImpactSystem")

local Visuals = {}

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

  local playerLunge = lungeOffset(scene.playerLungeTime, (scene.impactInstances and #scene.impactInstances > 0))
  local enemyLunge = lungeOffset(scene.enemyLungeTime, false)

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
  local enemyKB = 0
  for _, event in ipairs(scene.enemyKnockbackEvents or {}) do
    if event.startTime then
      enemyKB = enemyKB + knockbackOffset(event.startTime)
    end
  end
  enemyKB = enemyKB + knockbackOffset(scene.enemyKnockbackTime)
  local curPlayerX = playerX + playerLunge - playerKB
  local curEnemyX = enemyX - enemyLunge + enemyKB

  local playerScaleCfg = (config.battle and (config.battle.playerSpriteScale or config.battle.spriteScale)) or 1
  local enemyScaleCfg = (config.battle and (config.battle.enemySpriteScale or config.battle.spriteScale)) or 1
  local playerScale = 1
  local enemyScale = 1
  if scene.playerImg then
    local ih = scene.playerImg:getHeight()
    playerScale = ((2 * r) / math.max(1, ih)) * playerScaleCfg * (scene.playerScaleMul or 1)
  end
  if scene.enemyImg then
    local ih = scene.enemyImg:getHeight()
    enemyScale = ((2 * r) / math.max(1, ih)) * enemyScaleCfg * (scene.enemyScaleMul or 1)
  end

  local playerHalfH = scene.playerImg and ((scene.playerImg:getHeight() * playerScale) * 0.5) or r
  local enemyHalfH = scene.enemyImg and ((scene.enemyImg:getHeight() * enemyScale) * 0.5) or r

  local barH = 12
  local playerBarW = math.max(120, math.min(220, leftWidth - pad * 2)) * 0.7
  local enemyBarW = math.max(120, math.min(220, rightWidth - pad * 2)) * 0.7

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
  if enemyBarW > 0 and scene.state ~= "win" then
    local enemyBarX = enemyX - enemyBarW * 0.5

    local barAlpha = 1.0
    if scene.enemyDisintegrating then
      local cfg = config.battle.disintegration or {}
      local duration = cfg.duration or 1.5
      local progress = math.min(1, (scene.enemyDisintegrationTime or 0) / duration)
      barAlpha = math.max(0, 1.0 - (progress / 0.7))
    end

    if barAlpha > 0 then
      love.graphics.push()
      love.graphics.setColor(1, 1, 1, barAlpha)

      if (scene.enemyArmor or 0) > 0 then
        drawBarGlow(enemyBarX, barY, enemyBarW, barH)
      end

      love.graphics.setColor(0, 0, 0, 0.35 * barAlpha)
      love.graphics.rectangle("fill", enemyBarX, barY, enemyBarW, barH, 6, 6)
      local barColor = { 153/255, 224/255, 122/255 }
      local ratio = 0
      local maxHP = config.battle.enemyMaxHP
      local currentHP = scene.displayEnemyHP or scene.enemyHP
      if maxHP > 0 then ratio = math.max(0, math.min(1, currentHP / maxHP)) end
      if ratio > 0 then
        love.graphics.setColor(barColor[1], barColor[2], barColor[3], barAlpha)
        love.graphics.rectangle("fill", enemyBarX, barY, enemyBarW * ratio, barH, 6, 6)
      end
      love.graphics.setColor(0.25, 0.25, 0.25, barAlpha)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", enemyBarX, barY, enemyBarW, barH, 6, 6)
      do
        local font = theme.fonts.base
        love.graphics.setFont(font)
        local cur = math.max(0, math.floor(currentHP or 0))
        local mx = math.max(0, math.floor(maxHP or 0))
        local text = tostring(cur) .. "/" .. tostring(mx)
        local tw = font:getWidth(text)
        local th = font:getHeight()
        local tx = enemyBarX + (enemyBarW - tw) * 0.5
        local ty = barY + (barH - th) * 0.5
        theme.drawTextWithOutline(text, tx, ty, 1, 1, 1, 0.95 * barAlpha, 2)
      end
      love.graphics.setColor(theme.colors.uiText[1], theme.colors.uiText[2], theme.colors.uiText[3], theme.colors.uiText[4] * barAlpha)
      drawCenteredText("Enemy", enemyBarX, barY + barH + 6, enemyBarW)
      love.graphics.pop()
      love.graphics.setColor(1, 1, 1, 1)
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
    scene.fogShader:send("u_resolution", {w, h})
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
    love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, drawAlpha)
    love.graphics.draw(scene.playerImg, curPlayerX, baselineY, tilt, sx, sy, iw * 0.5, ih)
    if scene.playerFlash and scene.playerFlash > 0 then
      local base = scene.playerFlash / math.max(0.0001, config.battle.hitFlashDuration)
      local a = math.min(1, base * ((config.battle and config.battle.hitFlashAlphaScale) or 1))
      local passes = (config.battle and config.battle.hitFlashPasses) or 1
      love.graphics.setBlendMode("add")
      love.graphics.setColor(1, 1, 1, a * (drawAlpha or 1))
      for i = 1, math.max(1, passes) do
        love.graphics.draw(scene.playerImg, curPlayerX, baselineY, scene.playerRotation or 0, sx, sy, iw * 0.5, ih)
      end
      love.graphics.setBlendMode("alpha")
      love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, drawAlpha)
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

  -- Enemy sprite or fallback (skip if win)
  if scene.enemyImg and scene.state ~= "win" then
    local iw, ih = scene.enemyImg:getWidth(), scene.enemyImg:getHeight()
    local s = enemyScale
    local bobA = (config.battle and config.battle.idleBobScaleY) or 0
    local bobF = (config.battle and config.battle.idleBobSpeed) or 1
    local bob = 1 + bobA * (0.5 - 0.5 * math.cos(2 * math.pi * bobF * (scene.idleT or 0)))
    local sx, sy = s, s * bob
    local tilt = scene.enemyRotation or 0
    if scene.enemyDisintegrating and scene.disintegrationShader then
      local cfg = config.battle.disintegration or {}
      local duration = cfg.duration or 1.5
      local progress = math.min(1, (scene.enemyDisintegrationTime or 0) / duration)
      local noiseScale = cfg.noiseScale or 20
      local thickness = cfg.thickness or 0.25
      local lineColor = cfg.lineColor or {1.0, 0.3, 0.1, 1.0}
      local colorIntensity = cfg.colorIntensity or 2.0
      love.graphics.setShader(scene.disintegrationShader)
      scene.disintegrationShader:send("u_time", scene.enemyDisintegrationTime)
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
      brightnessMultiplier = 1 + math.sin(scene.enemyPulseTime or 0) * variation
    end
    love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, 1)
    love.graphics.draw(scene.enemyImg, curEnemyX, baselineY, tilt, sx, sy, iw * 0.5, ih)
    if scene.enemyDisintegrating and scene.disintegrationShader then
      love.graphics.setShader()
    end
    if scene.enemyFlash and scene.enemyFlash > 0 and not scene.enemyDisintegrating then
      local base = scene.enemyFlash / math.max(0.0001, config.battle.hitFlashDuration)
      local a = math.min(1, base * ((config.battle and config.battle.hitFlashAlphaScale) or 1))
      local passes = (config.battle and config.battle.hitFlashPasses) or 1
      love.graphics.setBlendMode("add")
      love.graphics.setColor(1, 1, 1, a)
      for i = 1, math.max(1, passes) do
        love.graphics.draw(scene.enemyImg, curEnemyX, baselineY, scene.enemyRotation or 0, sx, sy, iw * 0.5, ih)
      end
      love.graphics.setBlendMode("alpha")
      love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, 1)
    end
  elseif scene.state ~= "win" then
    local brightnessMultiplier = 1
    local pulseConfig = config.battle.pulse
    if pulseConfig and (pulseConfig.enabled ~= false) then
      local variation = pulseConfig.brightnessVariation or 0.08
      brightnessMultiplier = 1 + math.sin(scene.enemyPulseTime or 0) * variation
    end
    if scene.enemyFlash and scene.enemyFlash > 0 then
      love.graphics.setColor(brightnessMultiplier, brightnessMultiplier, brightnessMultiplier, 1)
    else
      love.graphics.setColor(0.9 * brightnessMultiplier, 0.2 * brightnessMultiplier, 0.2 * brightnessMultiplier, 1)
    end
    love.graphics.circle("fill", curEnemyX, baselineY - r, r)
    love.graphics.setColor(1, 1, 1, 1)
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
    local baseTop = (p.who == "enemy") and (baselineY - (scene.enemyImg and (scene.enemyImg:getHeight() * enemyScale) or (2 * r)))
                                   or (baselineY - (scene.playerImg and (scene.playerImg:getHeight() * playerScale) or (2 * r)))
    local bounce = singleSoftBounce(math.min(1, prog))
    local height = (config.battle and config.battle.popupBounceHeight) or 60
    local y = baseTop - 20 - bounce * height
    local x = (p.who == "enemy") and curEnemyX or curPlayerX
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
    if p.who == "player" and p.kind ~= "armor" then
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


