local config = require("config")
local theme = require("theme")
local MapManager = require("managers.MapManager")
local moonshine = require("external.moonshine")
local ShaderCache = require("utils.ShaderCache")

local TILT_SHIFT_SHADER_SOURCE = [[
extern Image blurred;
extern float focusStart;
extern float focusEnd;
extern float maxBlurAmount;

vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen_coords) {
  vec4 sharp = Texel(texture, uv);
  vec4 blurredSample = Texel(blurred, uv);

  // Calculate distance from center (0.5 = middle of screen)
  float dist = abs(uv.y - 0.5);
  
  // Use smoothstep for smooth transition (no branches = fewer variants)
  float blend = smoothstep(focusStart, focusEnd, dist) * maxBlurAmount;

  // Mix sharp and blurred based on blend factor
  return mix(sharp, blurredSample, blend) * color;
}
]]

local LENS_DISTORTION_SHADER_SOURCE = [[
extern float strength;
extern float zoom;

vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen_coords) {
  // Convert to normalized coordinates centered at (0, 0)
  vec2 center = vec2(0.5, 0.5);
  vec2 coord = uv - center;
  
  // Calculate distance from center
  float dist = length(coord);
  
  // Apply barrel distortion (positive strength = barrel, negative = pincushion)
  // Using a simple polynomial model: r' = r * (1 + strength * r^2)
  float r = dist;
  float r2 = r * r;
  float distortion = 1.0 + strength * r2;
  
  // Apply zoom (scale factor)
  coord *= distortion * zoom;
  
  // Convert back to texture coordinates
  vec2 distortedUV = coord + center;
  
  // Clamp UV coordinates to prevent sampling outside texture bounds
  distortedUV = clamp(distortedUV, vec2(0.0, 0.0), vec2(1.0, 1.0));
  
  // Sample the texture at the distorted coordinates
  return Texel(texture, distortedUV) * color;
}
]]

local MapRenderer = {}
MapRenderer.__index = MapRenderer

function MapRenderer.new()
  local renderer = setmetatable({
    _tiltShiftEnabled = false,
    _tiltShiftEffect = nil,
    _tiltShiftShader = nil,
    _tiltShiftWorldCanvas = nil,
    _tiltShiftBlurCanvas = nil,
    _tiltShiftEffectWidth = nil,
    _tiltShiftEffectHeight = nil,
    _lensDistortionEnabled = false,
    _lensDistortionShader = nil,
    _lensDistortionCanvas = nil,
  }, MapRenderer)

  renderer:_initializeTiltShift()
  renderer:_initializeLensDistortion()

  return renderer
end

function MapRenderer:_initializeTiltShift()
  local settings = config.map and config.map.tiltShift
  if not (settings and settings.enabled) then
    self._tiltShiftEnabled = false
    return
  end

  local supportsCanvas = true
  if type(love.graphics.isSupported) == "function" then
    supportsCanvas = love.graphics.isSupported("canvas")
  end

  if not supportsCanvas then
    self._tiltShiftEnabled = false
    return
  end

  local shader, shaderErr = ShaderCache.get("map_tilt_shift", TILT_SHIFT_SHADER_SOURCE)
  if not shader then
    if shaderErr then
      print("[MapRenderer] Failed to compile tilt shift shader:", shaderErr)
    end
    self._tiltShiftEnabled = false
    return
  end

  local effectOk, effect = pcall(function()
    return moonshine(moonshine.effects.gaussianblur)
  end)

  if not effectOk or not effect then
    self._tiltShiftEnabled = false
    return
  end

  self._tiltShiftShader = shader
  self._tiltShiftEffect = effect

  self._tiltShiftEnabled = true
  self:_updateTiltShiftUniforms()
  self:_updateBlurSettings()
end

function MapRenderer:_updateBlurSettings()
  if not (self._tiltShiftEnabled and self._tiltShiftEffect) then
    return
  end

  local settings = config.map and config.map.tiltShift or {}
  local blurSigma = settings.blurSigma or 5.0
  if self._tiltShiftEffect.gaussianblur then
    self._tiltShiftEffect.gaussianblur.sigma = blurSigma
  end
end

function MapRenderer:_initializeLensDistortion()
  local settings = config.map and config.map.lensDistortion
  if not (settings and settings.enabled) then
    self._lensDistortionEnabled = false
    return
  end

  local supportsCanvas = true
  if type(love.graphics.isSupported) == "function" then
    supportsCanvas = love.graphics.isSupported("canvas")
  end

  if not supportsCanvas then
    self._lensDistortionEnabled = false
    return
  end

  local shader, shaderErr = ShaderCache.get("map_lens_distortion", LENS_DISTORTION_SHADER_SOURCE)
  if not shader then
    if shaderErr then
      print("[MapRenderer] Failed to compile lens distortion shader:", shaderErr)
    end
    self._lensDistortionEnabled = false
    return
  end

  self._lensDistortionShader = shader
  self._lensDistortionEnabled = true
  self:_updateLensDistortionUniforms()
end

function MapRenderer:_updateLensDistortionUniforms()
  if not (self._lensDistortionEnabled and self._lensDistortionShader) then
    return
  end

  local settings = config.map and config.map.lensDistortion or {}
  local strength = settings.strength or 0.15
  local zoom = settings.zoom or 1.0

  self._lensDistortionShader:send("strength", strength)
  self._lensDistortionShader:send("zoom", zoom)
end

function MapRenderer:_ensureLensDistortionResources(vw, vh)
  if not self._lensDistortionEnabled then
    return
  end

  if not self._lensDistortionCanvas
    or self._lensDistortionCanvas:getWidth() ~= vw
    or self._lensDistortionCanvas:getHeight() ~= vh then
    self._lensDistortionCanvas = love.graphics.newCanvas(vw, vh)
  end
end

function MapRenderer:_updateTiltShiftUniforms()
  if not (self._tiltShiftEnabled and self._tiltShiftShader) then
    return
  end

  local settings = config.map and config.map.tiltShift or {}
  local focusCenter = settings.focusCenter or 0.5
  local focusRange = settings.focusRange or 0.25
  local focusFeather = settings.focusFeather or 0.2
  local maxBlurAmount = settings.maxBlurAmount or 1.0

  -- Calculate focus zone boundaries (distance from center where blur starts/ends)
  -- focusRange is half-height of sharp band, focusFeather is transition zone
  local focusStart = math.max(0.0, focusRange)
  local focusEnd = math.max(focusStart + 0.001, focusRange + focusFeather)

  self._tiltShiftShader:send("focusStart", focusStart)
  self._tiltShiftShader:send("focusEnd", focusEnd)
  self._tiltShiftShader:send("maxBlurAmount", math.max(0.0, math.min(1.0, maxBlurAmount)))
end

function MapRenderer:_ensureTiltShiftResources(vw, vh)
  if not self._tiltShiftEnabled then
    return
  end

  local canvasDirty = false
  if not self._tiltShiftWorldCanvas
    or self._tiltShiftWorldCanvas:getWidth() ~= vw
    or self._tiltShiftWorldCanvas:getHeight() ~= vh then
    self._tiltShiftWorldCanvas = love.graphics.newCanvas(vw, vh)
    canvasDirty = true
  end

  if not self._tiltShiftBlurCanvas
    or self._tiltShiftBlurCanvas:getWidth() ~= vw
    or self._tiltShiftBlurCanvas:getHeight() ~= vh then
    self._tiltShiftBlurCanvas = love.graphics.newCanvas(vw, vh)
    canvasDirty = true
  end

  if canvasDirty and self._tiltShiftShader and self._tiltShiftBlurCanvas then
    self._tiltShiftShader:send("blurred", self._tiltShiftBlurCanvas)
  end

  if self._tiltShiftEffect
    and (self._tiltShiftEffectWidth ~= vw or self._tiltShiftEffectHeight ~= vh) then
    self._tiltShiftEffect.resize(vw, vh)
    self._tiltShiftEffectWidth = vw
    self._tiltShiftEffectHeight = vh
  end
end

function MapRenderer:draw(scene)
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight

  local usedTiltShift = self:_renderTiltShift(scene, vw, vh)
  
  -- If lens distortion is enabled, we need to capture the current render to a canvas
  if self._lensDistortionEnabled and not usedTiltShift then
    -- Tilt shift wasn't used, so capture the world layer to canvas for lens distortion
    self:_captureWorldLayerForDistortion(scene, vw, vh)
  end

  -- Apply lens distortion as post-process (works with or without tilt shift)
  self:_applyLensDistortion(vw, vh)

  self:_drawOverlays(scene, vw, vh)
end

function MapRenderer:_renderTiltShift(scene, vw, vh)
  if not (self._tiltShiftEnabled and self._tiltShiftEffect and self._tiltShiftShader) then
    return false
  end

  -- Get supersampling factor and render canvases at supersampled resolution for crisp graphics
  local supersamplingFactor = _G.supersamplingFactor or 1
  local canvasW = vw * supersamplingFactor
  local canvasH = vh * supersamplingFactor

  self:_ensureTiltShiftResources(canvasW, canvasH)
  if not (self._tiltShiftWorldCanvas and self._tiltShiftBlurCanvas) then
    return false
  end

  self:_updateTiltShiftUniforms()
  self:_updateBlurSettings()

  self:_renderWorldToCanvas(scene, vw, vh, supersamplingFactor)
  self:_renderBlurredCanvas()

  -- If lens distortion is enabled, render tilt shift result to a canvas for post-processing
  -- Otherwise, draw directly to screen
  if self._lensDistortionEnabled then
    self:_ensureLensDistortionResources(canvasW, canvasH)
    if self._lensDistortionCanvas then
      love.graphics.push("all")
      love.graphics.setCanvas(self._lensDistortionCanvas)
      love.graphics.clear(theme.colors.background)
      love.graphics.origin()
      love.graphics.scale(supersamplingFactor, supersamplingFactor)
      
      love.graphics.setColor(1, 1, 1, 1)
      
      -- Send blurred texture to shader before using it
      if self._tiltShiftShader and self._tiltShiftBlurCanvas then
        self._tiltShiftShader:send("blurred", self._tiltShiftBlurCanvas)
      end
      
      love.graphics.setShader(self._tiltShiftShader)
      
      -- Draw canvas scaled down by supersamplingFactor
      love.graphics.draw(self._tiltShiftWorldCanvas, 0, 0, 0, 
        1 / supersamplingFactor, 1 / supersamplingFactor)
      love.graphics.setShader()
      
      love.graphics.pop()
    end
  else
    love.graphics.clear(theme.colors.background)
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Send blurred texture to shader before using it
    if self._tiltShiftShader and self._tiltShiftBlurCanvas then
      self._tiltShiftShader:send("blurred", self._tiltShiftBlurCanvas)
    end
    
    love.graphics.setShader(self._tiltShiftShader)
    
    -- Draw canvas scaled down by supersamplingFactor so when global transform scales it up,
    -- it ends up at the correct size (1/supersamplingFactor * supersamplingFactor = 1)
    love.graphics.draw(self._tiltShiftWorldCanvas, 0, 0, 0, 
      1 / supersamplingFactor, 1 / supersamplingFactor)
    love.graphics.setShader()
  end

  return true
end

function MapRenderer:_captureWorldLayerForDistortion(scene, vw, vh)
  if not self._lensDistortionEnabled then
    return
  end

  local supersamplingFactor = _G.supersamplingFactor or 1
  local canvasW = vw * supersamplingFactor
  local canvasH = vh * supersamplingFactor

  self:_ensureLensDistortionResources(canvasW, canvasH)
  if not self._lensDistortionCanvas then
    return
  end

  love.graphics.push("all")
  love.graphics.setCanvas(self._lensDistortionCanvas)
  love.graphics.clear(theme.colors.background)
  love.graphics.origin()
  love.graphics.scale(supersamplingFactor, supersamplingFactor)
  
  -- Draw world layer to canvas
  self:_drawWorldLayer(scene, vw, vh)
  
  love.graphics.pop()
end

function MapRenderer:_applyLensDistortion(vw, vh)
  if not (self._lensDistortionEnabled and self._lensDistortionShader) then
    return
  end

  local sourceCanvas = self._lensDistortionCanvas
  if not sourceCanvas then
    return
  end

  -- Apply lens distortion shader to the canvas
  self:_updateLensDistortionUniforms()
  
  love.graphics.clear(theme.colors.background)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setShader(self._lensDistortionShader)
  
  -- Get supersampling factor
  local supersamplingFactor = _G.supersamplingFactor or 1
  
  -- Draw the canvas with distortion applied
  love.graphics.draw(sourceCanvas, 0, 0, 0, 
    1 / supersamplingFactor, 1 / supersamplingFactor)
  love.graphics.setShader()
end

function MapRenderer:_renderWorldToCanvas(scene, vw, vh, supersamplingFactor)
  -- Save current transform state
  love.graphics.push("all")
  love.graphics.setCanvas(self._tiltShiftWorldCanvas)
  love.graphics.clear(theme.colors.background)
  
  -- Reset transform - canvas rendering is independent of global transform
  love.graphics.origin()
  
  -- Apply supersampling scale so world renders at full resolution in the canvas
  love.graphics.scale(supersamplingFactor, supersamplingFactor)
  
  -- Draw world layer - coordinates are in virtual space, scale handles upscaling
  self:_drawWorldLayer(scene, vw, vh)
  love.graphics.pop()
end

function MapRenderer:_renderBlurredCanvas()
  if not (self._tiltShiftEffect and self._tiltShiftBlurCanvas and self._tiltShiftWorldCanvas) then
    return
  end

  love.graphics.push("all")
  love.graphics.setCanvas(self._tiltShiftBlurCanvas)
  love.graphics.clear(0, 0, 0, 0)
  
  -- Reset transform to identity for blur effect
  love.graphics.origin()
  
  -- Apply blur effect via Moonshine chain
  self._tiltShiftEffect(function()
    love.graphics.setColor(1, 1, 1, 1)
    -- Draw the sharp canvas - Moonshine will blur it
    love.graphics.draw(self._tiltShiftWorldCanvas, 0, 0)
  end)
  love.graphics.pop()
end

function MapRenderer:_drawOverlays(scene, vw, vh)
  -- Draw darkening overlay when player runs out of turns (using tweened alpha)
  local darkeningConfig = config.map.noTurnsDarkening
  if darkeningConfig and darkeningConfig.enabled and scene._darkeningAlpha and scene._darkeningAlpha > 0 then
    local color = darkeningConfig.color or {0, 0, 0}
    love.graphics.setColor(color[1], color[2], color[3], scene._darkeningAlpha)
    love.graphics.rectangle("fill", 0, 0, vw, vh)
  end

  -- Draw day indicator overlay and text (same style as turn indicators)
  if scene.dayIndicator then
    local lifetime = 1.0
    local t = scene.dayIndicator.t / lifetime -- 1 -> 0
    local fadeStart = 0.4 -- Start fading at 40% of lifetime
    local alpha = 1.0
    if t < fadeStart then
      alpha = t / fadeStart
    end

    love.graphics.setColor(0, 0, 0, 0.6 * alpha)
    love.graphics.rectangle("fill", 0, 0, vw, vh)
    love.graphics.setColor(1, 1, 1, 1)

    local scale = 1.0
    if t > 0.7 then
      local popT = (1.0 - t) / 0.3 -- 0 -> 1
      local c1, c3 = 1.70158, 2.70158
      local u = (popT - 1)
      scale = 1 + c3 * (u * u * u) + c1 * (u * u)
    end

    love.graphics.push()
    love.graphics.setFont(theme.fonts.jackpot or theme.fonts.large)
    local text = scene.dayIndicator.text
    local font = theme.fonts.jackpot or theme.fonts.large
    local textW = font:getWidth(text)
    local centerX = vw * 0.5
    local centerY = vh * 0.5 - 50 -- Shifted up by 50px

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

    if scene.decorImage then
      local decorW = scene.decorImage:getWidth()
      local decorH = scene.decorImage:getHeight()
      local scaledW = decorW * decorScale
      local scaledH = decorH * decorScale

      local leftCenterX = -textW * 0.5 - decorSpacing - scaledW * 0.5
      local rightCenterX = textW * 0.5 + decorSpacing + scaledW * 0.5

      love.graphics.setColor(1, 1, 1, alpha)

      love.graphics.push()
      love.graphics.translate(leftCenterX, 0)
      love.graphics.scale(decorScale, decorScale)
      love.graphics.draw(scene.decorImage, -decorW * 0.5, -decorH * 0.5)
      love.graphics.pop()

      love.graphics.push()
      love.graphics.translate(rightCenterX, 0)
      love.graphics.scale(-decorScale, decorScale)
      love.graphics.draw(scene.decorImage, -decorW * 0.5, -decorH * 0.5)
      love.graphics.pop()
    end

    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.print(text, -textW * 0.5, -font:getHeight() * 0.5)
    love.graphics.pop()

    love.graphics.setFont(theme.fonts.base)
    love.graphics.pop()
  end

  self:drawUI(scene)
  if scene.topBar then
    scene.topBar:draw()
  end

  if scene.drawUI then
    scene:drawUI()
  end
end

function MapRenderer:_drawWorldLayer(scene, vw, vh)
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
            -- Get sprite variant (1 = regular, 2 = elite, default to 1)
            local spriteVariant = tile.spriteVariant or 1
            local sprite = sprites.enemy[spriteVariant] or sprites.enemy[1]
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
      local spriteSize = scene.gridSize * 0.8 * 1.5 * 0.9
      local spriteW, spriteH = scene.playerSprite:getDimensions()
      local scale = spriteSize / math.max(spriteW, spriteH)
      local bobOffset = 0
      if scene.isMoving then
        local bobConfig = config.map.playerBob
        bobOffset = -math.sin(scene._movementTime * bobConfig.speed * 2 * math.pi) * bobConfig.amplitude
      end
      local verticalOffset = config.map.playerVerticalOffset or 0
      
      -- Draw player glow 2 below the player (before player sprite for z-order)
      if scene.playerGlow2 then
        local gw2, gh2 = scene.playerGlow2:getDimensions()
        local glowTiles2 = (config.map and config.map.playerGlow2 and config.map.playerGlow2.tileScale) or 11.2
        local glowSize2 = scene.gridSize * glowTiles2 * 0.3  -- Reduce size by 50%
        local glowScale2 = glowSize2 / math.max(gw2, gh2)
        local glowOffsetY = scene.gridSize * 0.2 - 30  -- Offset below the player, shifted up by 50px
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.draw(scene.playerGlow2, px, py + verticalOffset + bobOffset + glowOffsetY, 0, glowScale2, glowScale2, gw2 * 0.5, gh2 * 0.5)
      end
      
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


