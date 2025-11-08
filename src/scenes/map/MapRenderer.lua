local config = require("config")
local theme = require("theme")
local MapManager = require("managers.MapManager")

local MapRenderer = {}
MapRenderer.__index = MapRenderer

function MapRenderer.new()
  return setmetatable({}, MapRenderer)
end

function MapRenderer:draw(scene)
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight

  love.graphics.clear(theme.colors.background)
  love.graphics.push()
  love.graphics.translate(-scene.cameraX + vw * 0.5, -scene.cameraY + vh * 0.5)

  do
    local px, py = scene.playerWorldX, scene.playerWorldY
    if scene.playerGlow and px and py then
      local gw, gh = scene.playerGlow:getDimensions()
      local glowTiles = (config.map and config.map.playerGlow and config.map.playerGlow.tileScale) or 11.2
      local glowSize = scene.gridSize * glowTiles
      local glowScale = glowSize / math.max(gw, gh)
      love.graphics.setColor(1, 1, 1, 0.9)
      love.graphics.draw(scene.playerGlow, px, py, 0, glowScale, glowScale, gw * 0.5, gh * 0.5)
    end
  end

  local gridSize = scene.gridSize
  local sprites = scene.mapManager.sprites
  local oversize = 1.3

  local padding = gridSize * 2
  local minTileX = math.max(1, math.floor((scene.cameraX - vw * 0.5 - padding - scene.offsetX) / gridSize) + 1)
  local maxTileX = math.min(scene.mapManager.gridWidth, math.ceil((scene.cameraX + vw * 0.5 + padding - scene.offsetX) / gridSize) + 1)
  local minTileY = math.max(1, math.floor((scene.cameraY - vh * 0.5 - padding - scene.offsetY) / gridSize) + 1)
  local maxTileY = math.min(scene.mapManager.gridHeight, math.ceil((scene.cameraY + vh * 0.5 + padding - scene.offsetY) / gridSize) + 1)

  local drawQueue = {}
  local px, py = scene.playerWorldX, scene.playerWorldY

  local restSites = {}
  for y = minTileY, maxTileY do
    for x = minTileX, maxTileX do
      local tile = scene.mapManager:getTile(x, y)
      if tile and tile.type == MapManager.TileType.REST then
        local worldX = scene.offsetX + (x - 1) * gridSize
        local worldY = scene.offsetY + (y - 1) * gridSize
        table.insert(restSites, {x = worldX, y = worldY})
      end
    end
  end

  local fogConfig = config.map.distanceFog
  local lightingConfig = config.map.restLighting
  local function calculateAlpha(worldX, worldY)
    local baseAlpha = 1.0
    if fogConfig.enabled then
      local dx = worldX - px
      local dy = worldY - py
      local distance = math.sqrt(dx * dx + dy * dy)
      if distance <= fogConfig.fadeStartRadius then
        baseAlpha = 1.0
      elseif distance >= fogConfig.fadeEndRadius then
        baseAlpha = fogConfig.minAlpha
      else
        local fadeRange = fogConfig.fadeEndRadius - fogConfig.fadeStartRadius
        local fadeProgress = (distance - fogConfig.fadeStartRadius) / fadeRange
        baseAlpha = 1.0 - fadeProgress * (1.0 - fogConfig.minAlpha)
      end
    end
    if lightingConfig.enabled then
      local maxLightBoost = 0
      for _, restSite in ipairs(restSites) do
        local dx = worldX - restSite.x
        local dy = worldY - restSite.y
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance <= lightingConfig.glowRadius then
          local lightStrength = 1.0 - (distance / lightingConfig.glowRadius)
          local lightBoost = lightStrength * lightingConfig.lightIntensity
          maxLightBoost = math.max(maxLightBoost, lightBoost)
        end
      end
      baseAlpha = math.min(1.0, baseAlpha + maxLightBoost)
    end
    return baseAlpha
  end

  local function addToQueue(worldY, worldX, drawFunc, isPlayer)
    local alpha = isPlayer and 1.0 or calculateAlpha(worldX, worldY)
    table.insert(drawQueue, {
      y = worldY,
      draw = function()
        local originalSetColor = love.graphics.setColor
        love.graphics.setColor = function(r, g, b, a)
          a = a or 1.0
          originalSetColor(r, g, b, a * alpha)
        end
        drawFunc()
        love.graphics.setColor = originalSetColor
      end
    })
  end

  for y = minTileY, maxTileY do
    for x = minTileX, maxTileX do
      local tile = scene.mapManager:getTile(x, y)
      if tile then
        local worldX = scene.offsetX + (x - 1) * gridSize
        local worldY = scene.offsetY + (y - 1) * gridSize

        if tile.type == MapManager.TileType.GROUND or tile.type == MapManager.TileType.ENEMY or tile.type == MapManager.TileType.REST or tile.type == MapManager.TileType.MERCHANT or tile.type == MapManager.TileType.EVENT or tile.type == MapManager.TileType.TREASURE then
          if tile.spriteVariant then
            local sprite = sprites.ground[tile.spriteVariant]
            if sprite then
              addToQueue(worldY, worldX, function()
                love.graphics.setColor(1, 1, 1, 1)
                local sx = (gridSize * oversize) / sprite:getWidth()
                local sy = (gridSize * oversize) / sprite:getHeight()
                local ox = (gridSize * (oversize - 1)) * 0.5
                local oy = (gridSize * (oversize - 1)) * 0.5
                love.graphics.draw(sprite, worldX - ox, worldY - oy, 0, sx, sy)
              end, false)
            end
          end

          if tile.type == MapManager.TileType.ENEMY then
            local sprite = sprites.enemy
            if sprite then
              addToQueue(worldY, worldX, function()
                love.graphics.setColor(1, 1, 1, 1)
                local baseSx = (gridSize * oversize) / sprite:getWidth()
                local baseSy = (gridSize * oversize) / sprite:getHeight()
                local bobConfig = config.map.enemyBob
                local phaseOffset = (x + y * 100) * bobConfig.phaseVariation
                local heightScale = 1 + math.sin(scene._treeSwayTime * bobConfig.speed * 2 * math.pi + phaseOffset) * bobConfig.heightVariation
                local sx = baseSx
                local sy = baseSy * heightScale
                local ox = (gridSize * (oversize - 1)) * 0.5
                local oy = (gridSize * (oversize - 1)) * 0.5
                local spriteW, spriteH = sprite:getDimensions()
                local pivotX = spriteW * 0.5
                local pivotY = spriteH
                local pivotWorldX = worldX - ox + spriteW * 0.5 * baseSx
                local pivotWorldY = worldY - oy + spriteH * baseSy
                love.graphics.draw(sprite, pivotWorldX, pivotWorldY, 0, sx, sy, pivotX, pivotY)
              end, false)
            end
          elseif tile.type == MapManager.TileType.REST then
            local sprite = sprites.rest
            if sprite then
              local baseSx = (gridSize * oversize) / sprite:getWidth()
              local baseSy = (gridSize * oversize) / sprite:getHeight()
              local ox = (gridSize * (oversize - 1)) * 0.5
              local oy = (gridSize * (oversize - 1)) * 0.5
              local spriteW, spriteH = sprite:getDimensions()
              local pivotX = spriteW * 0.5
              local pivotY = spriteH
              local centerWorldX = worldX - ox + spriteW * 0.5 * baseSx
              local centerWorldY = worldY - oy + spriteH * baseSy
              local spriteCenterY = worldY + gridSize * 0.5
              if scene.restGlow then
                local lightingConfig = config.map.restLighting
                local phaseOffset = (x + y * 100) * 0.5
                local pulsateTime = scene._treeSwayTime * lightingConfig.pulsateSpeed * 2 * math.pi + phaseOffset
                local sizeMultiplier = 1.0 + math.sin(pulsateTime) * lightingConfig.pulsateSizeVariation
                local baseAlpha = 0.4
                local alphaVariation = math.sin(pulsateTime * 0.7) * lightingConfig.pulsateAlphaVariation
                local glowAlpha = math.max(0.2, math.min(0.6, baseAlpha + alphaVariation))
                addToQueue(worldY - 0.01, centerWorldX, function()
                  local prevBlendMode = love.graphics.getBlendMode()
                  love.graphics.setBlendMode("add")
                  love.graphics.setColor(1, 1, 1, glowAlpha)
                  local baseGlowSize = lightingConfig.glowRadius * 2
                  local glowSize = baseGlowSize * sizeMultiplier
                  local glowW, glowH = scene.restGlow:getDimensions()
                  local glowScale = glowSize / math.max(glowW, glowH)
                  love.graphics.draw(scene.restGlow, centerWorldX, spriteCenterY, 0, glowScale, glowScale, glowW * 0.5, glowH * 0.5)
                  love.graphics.setBlendMode(prevBlendMode)
                end, false)
              end
              addToQueue(worldY, worldX, function()
                love.graphics.setColor(1, 1, 1, 1)
                local bobConfig = config.map.restBob
                local phaseOffset = (x + y * 100) * bobConfig.phaseVariation
                local time = scene._treeSwayTime * bobConfig.speed * 2 * math.pi + phaseOffset
                local heightScale = 1 + math.sin(time) * bobConfig.heightVariation
                local skewX = math.sin(time) * bobConfig.maxShear
                local sx = baseSx
                local sy = baseSy * heightScale
                love.graphics.push()
                love.graphics.translate(centerWorldX, centerWorldY)
                love.graphics.shear(skewX, 0)
                love.graphics.translate(-pivotX * sx, -pivotY * sy)
                love.graphics.draw(sprite, 0, 0, 0, sx, sy)
                love.graphics.pop()
              end, false)
            end
          elseif tile.type == MapManager.TileType.MERCHANT then
            local sprite = sprites.merchant or sprites.event
            if sprite then
              addToQueue(worldY, worldX, function()
                love.graphics.setColor(1, 1, 1, 1)
                local baseSx = (gridSize * oversize) / sprite:getWidth()
                local baseSy = (gridSize * oversize) / sprite:getHeight()
                local bobConfig = config.map.restBob
                local phaseOffset = (x + y * 100) * bobConfig.phaseVariation * 0.4
                local time = scene._treeSwayTime * (bobConfig.speed * 0.55) * 2 * math.pi + phaseOffset
                local heightScale = 1 + math.sin(time) * (bobConfig.heightVariation * 0.6)
                local skewX = math.sin(time * 0.5) * (bobConfig.maxShear * 0.4)
                local sx = baseSx
                local sy = baseSy * heightScale
                local ox = (gridSize * (oversize - 1)) * 0.5
                local oy = (gridSize * (oversize - 1)) * 0.5
                local spriteW, spriteH = sprite:getDimensions()
                local pivotX = spriteW * 0.5
                local pivotY = spriteH
                local centerWorldX = worldX - ox + spriteW * 0.5 * baseSx
                local centerWorldY = worldY - oy + spriteH * baseSy
                love.graphics.push()
                love.graphics.translate(centerWorldX, centerWorldY)
                love.graphics.shear(skewX, 0)
                love.graphics.translate(-pivotX * sx, -pivotY * sy)
                love.graphics.draw(sprite, 0, 0, 0, sx, sy)
                love.graphics.pop()
              end, false)
            end
          elseif tile.type == MapManager.TileType.EVENT then
            local sprite = sprites.event
            if sprite then
              addToQueue(worldY, worldX, function()
                love.graphics.setColor(1, 1, 1, 1)
                local baseSx = (gridSize * oversize) / sprite:getWidth()
                local baseSy = (gridSize * oversize) / sprite:getHeight()
                local bobConfig = config.map.restBob
                local phaseOffset = (x + y * 100) * bobConfig.phaseVariation
                local eventSpeed = bobConfig.speed * 0.7
                local time = scene._treeSwayTime * eventSpeed * 2 * math.pi + phaseOffset
                local heightScale = 1 + math.sin(time) * bobConfig.heightVariation
                local skewX = math.sin(time) * bobConfig.maxShear
                local sx = baseSx
                local sy = baseSy * heightScale
                local ox = (gridSize * (oversize - 1)) * 0.5
                local oy = (gridSize * (oversize - 1)) * 0.5
                local spriteW, spriteH = sprite:getDimensions()
                local pivotX = spriteW * 0.5
                local pivotY = spriteH
                local centerWorldX = worldX - ox + spriteW * 0.5 * baseSx
                local centerWorldY = worldY - oy + spriteH * baseSy
                love.graphics.push()
                love.graphics.translate(centerWorldX, centerWorldY)
                love.graphics.shear(skewX, 0)
                love.graphics.translate(-pivotX * sx, -pivotY * sy)
                love.graphics.draw(sprite, 0, 0, 0, sx, sy)
                love.graphics.pop()
              end, false)
            end
          elseif tile.type == MapManager.TileType.TREASURE then
            local sprite = sprites.treasure or sprites.event
            if sprite then
              addToQueue(worldY, worldX, function()
                love.graphics.setColor(1, 1, 1, 1)
                local baseSx = (gridSize * oversize) / sprite:getWidth()
                local baseSy = (gridSize * oversize) / sprite:getHeight()
                local bobConfig = config.map.restBob
                local phaseOffset = (x + y * 100) * bobConfig.phaseVariation
                local time = scene._treeSwayTime * (bobConfig.speed * 0.85) * 2 * math.pi + phaseOffset
                local heightScale = 1 + math.sin(time) * (bobConfig.heightVariation * 0.8)
                local sx = baseSx
                local sy = baseSy * heightScale
                local ox = (gridSize * (oversize - 1)) * 0.5
                local oy = (gridSize * (oversize - 1)) * 0.5
                local spriteW, spriteH = sprite:getDimensions()
                local pivotX = spriteW * 0.5
                local pivotY = spriteH
                local centerWorldX = worldX - ox + spriteW * 0.5 * baseSx
                local centerWorldY = worldY - oy + spriteH * baseSy
                love.graphics.push()
                love.graphics.translate(centerWorldX, centerWorldY)
                love.graphics.translate(-pivotX * sx, -pivotY * sy)
                love.graphics.draw(sprite, 0, 0, 0, sx, sy)
                love.graphics.pop()
              end, false)
            end
          end
        end

        if tile.type == MapManager.TileType.STONE then
          local sprite = sprites.stone[tile.decorationVariant or 1]
          if sprite then
            addToQueue(worldY, worldX, function()
              love.graphics.setColor(1, 1, 1, 1)
              local sx = (gridSize * oversize) / sprite:getWidth()
              local sy = (gridSize * oversize) / sprite:getHeight()
              local ox = (gridSize * (oversize - 1)) * 0.5
              local oy = (gridSize * (oversize - 1)) * 0.5
              love.graphics.draw(sprite, worldX - ox, worldY - oy, 0, sx, sy)
            end, false)
          else
            addToQueue(worldY, worldX, function()
              love.graphics.setColor(0.3, 0.3, 0.3, 1)
              love.graphics.rectangle("fill", worldX, worldY, gridSize, gridSize)
            end, false)
          end
        elseif tile.type == MapManager.TileType.TREE then
          local sprite = sprites.tree[tile.decorationVariant or 1]
          if sprite then
            addToQueue(worldY, worldX, function()
              love.graphics.setColor(1, 1, 1, 1)
              local sx = (gridSize * oversize) / sprite:getWidth()
              local sy = (gridSize * oversize) / sprite:getHeight()
              local ox = (gridSize * (oversize - 1)) * 0.5
              local oy = (gridSize * (oversize - 1)) * 0.5
              local swayConfig = config.map.treeSway
              local phaseOffset = (x + y * 100) * swayConfig.phaseVariation
              local time = scene._treeSwayTime * swayConfig.speed * 2 * math.pi + phaseOffset
              local swayAngle = math.sin(time) * swayConfig.maxAngle
              local skewX = math.sin(time) * swayConfig.maxShear
              local spriteW, spriteH = sprite:getDimensions()
              local pivotX = spriteW * 0.5
              local pivotY = spriteH
              love.graphics.push()
              love.graphics.translate(worldX - ox + pivotX * sx, worldY - oy + pivotY * sy)
              love.graphics.shear(skewX, 0)
              love.graphics.rotate(swayAngle)
              love.graphics.translate(-pivotX * sx, -pivotY * sy)
              love.graphics.draw(sprite, 0, 0, 0, sx, sy)
              love.graphics.pop()
            end, false)
          else
            addToQueue(worldY, worldX, function()
              love.graphics.setColor(0.2, 0.4, 0.2, 1)
              love.graphics.rectangle("fill", worldX, worldY, gridSize, gridSize)
            end, false)
          end
        end
      end
    end
  end

  addToQueue(py, px, function()
    if scene.playerSprite then
      local spriteSize = scene.gridSize * 0.8 * 1.5
      local spriteW, spriteH = scene.playerSprite:getDimensions()
      local scale = spriteSize / math.max(spriteW, spriteH)
      local bobOffset = 0
      if scene.isMoving then
        local bobConfig = config.map.playerBob
        bobOffset = -math.sin(scene._movementTime * bobConfig.speed * 2 * math.pi) * bobConfig.amplitude
      end
      local verticalOffset = config.map.playerVerticalOffset or 0
      love.graphics.setColor(1, 1, 1, 1)
      local scaleX = scene.playerFacingRight and scale or -scale
      love.graphics.draw(scene.playerSprite, px, py + verticalOffset + bobOffset, 0, scaleX, scale, spriteW * 0.5, spriteH)
    else
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.circle("fill", px, py, 12)
      love.graphics.setColor(0, 0, 0, 1)
      love.graphics.circle("line", px, py, 12)
    end
  end, true)

  table.sort(drawQueue, function(a, b) return a.y < b.y end)
  for _, item in ipairs(drawQueue) do
    item.draw()
  end

  love.graphics.pop()

  self:drawUI(scene)
  if scene.topBar then
    scene.topBar:draw()
  end
end

function MapRenderer:drawUI(scene)
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  scene.endDayBtnRect = nil
  local isAnimating = scene._endDayPressed and ((scene._endDaySpinTime < scene._endDaySpinDuration) or (scene._endDayFadeOutTime < scene._endDayFadeOutDuration))
  if (not scene.daySystem:canMove()) or isAnimating then
    local paddingX = 20
    local paddingY = 16
    local btnH = 42
    local cornerR = 6
    local gap = 9
    local label = "END DAY"
    local font = theme.fonts.base or love.graphics.getFont()
    love.graphics.setFont(font)
    local textW = font:getWidth(label)
    local contentH = btnH - 16
    local leftIconW, leftIconH = 0, 0
    local keyIconW, keyIconH = 0, 0
    local leftScale, keyScale = 1, 1
    local baseLeftScale = 1
    if scene.endDayIcon then
      local iw, ih = scene.endDayIcon:getDimensions()
      baseLeftScale = (contentH * 1.69) / math.max(iw, ih)
      leftScale = baseLeftScale * (scene._endDayHoverScale or 1)
      leftIconW = iw * baseLeftScale
      leftIconH = ih * baseLeftScale
    end
    if scene.keySpaceIcon then
      local iw, ih = scene.keySpaceIcon:getDimensions()
      keyScale = contentH * 0.68 / math.max(iw, ih)
      keyIconW = iw * keyScale
      keyIconH = ih * keyScale
    end
    local btnMargin = 32
    local btnInternalPad = 12
    local contentWidth = leftIconW + (scene.endDayIcon and gap or 0) + textW + (scene.keySpaceIcon and (gap + keyIconW) or 0)
    local btnW = math.floor(btnMargin + contentWidth * 0.8 + btnMargin + 0.5)
    local btnX = btnMargin
    local btnY = vh - btnH - btnMargin
    local baseAlpha = isAnimating and 1.0 or (scene._endDayFadeAlpha or 1)
    local a = baseAlpha * (scene._endDayFadeOutAlpha or 1)
    love.graphics.setColor(0.06, 0.07, 0.10, 0.92 * a)
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, cornerR, cornerR)
    love.graphics.setColor(1, 1, 1, 0.06 * a)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH, cornerR, cornerR)
    local cx = btnX + btnInternalPad
    local cy = btnY + btnH * 0.5
    if scene.endDayIcon then
      love.graphics.setColor(1, 1, 1, 0.95 * a)
      local iconW, iconH = scene.endDayIcon:getDimensions()
      local iconX = cx + 20
      love.graphics.push()
      love.graphics.translate(iconX, cy)
      love.graphics.rotate(scene._endDaySpinAngle or 0)
      love.graphics.draw(scene.endDayIcon, 0, 0, 0, leftScale, leftScale, iconW * 0.5, iconH * 0.5)
      love.graphics.pop()
      cx = cx + (iconW * baseLeftScale) + gap
    end
    local textAlpha = (scene._endDayHovered and 1.0 or 0.7) * a
    love.graphics.setColor(1, 1, 1, textAlpha)
    -- Center text vertically by accounting for font baseline/ascent, with small offset to shift down
    local currentFont = love.graphics.getFont()
    local textY = cy - currentFont:getAscent() + currentFont:getHeight() * 0.5 + 2
    love.graphics.print(label, cx, textY)
    cx = cx + textW
    if scene.keySpaceIcon then
      cx = cx + gap
      local keyAlpha = (scene._endDayHovered and 1.0 or 0.7) * a
      love.graphics.setColor(1, 1, 1, keyAlpha)
      love.graphics.draw(scene.keySpaceIcon, cx, cy, 0, keyScale, keyScale, 0, (scene.keySpaceIcon:getHeight() * 0.5))
    end
    scene.endDayBtnRect = { x = btnX, y = btnY, w = btnW, h = btnH }
  end
end

return MapRenderer


