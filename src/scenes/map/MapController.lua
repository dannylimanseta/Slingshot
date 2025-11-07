local config = require("config")

local MapController = {}
MapController.__index = MapController

function MapController.new(scene)
  return setmetatable({ scene = scene }, MapController)
end

-- Helpers copied from MapScene, adapted to operate on scene state
function MapController:_dirFromKey(key)
  if key == "w" then return 0, -1 end
  if key == "s" then return 0, 1 end
  if key == "a" then return -1, 0 end
  if key == "d" then return 1, 0 end
  return nil
end

function MapController:_setHeldMove(key)
  local scene = self.scene
  local dx, dy = self:_dirFromKey(key)
  if dx then
    scene._heldMoveKey = key
    scene._heldDirX, scene._heldDirY = dx, dy
    scene._holdElapsed = 0
    scene._repeatElapsed = 0
    scene._hasFiredInitialRepeat = false
  end
end

function MapController:_attemptMoveBy(dx, dy)
  local s = self.scene
  if s.isMoving then return false end
  if not s.daySystem:canMove() then return false end
  local currentGridX = s.mapManager.playerGridX
  local currentGridY = s.mapManager.playerGridY
  if currentGridX == 0 or currentGridY == 0 then return false end
  local targetGridX = currentGridX + dx
  local targetGridY = currentGridY + dy
  if not s.mapManager:canMoveTo(targetGridX, targetGridY) then return false end
  if not s.daySystem:useMove() then return false end
  local targetWorldX, targetWorldY = s.mapManager:gridToWorld(
    targetGridX,
    targetGridY,
    s.gridSize,
    s.offsetX,
    s.offsetY
  )
  s.playerTargetX = targetWorldX
  s.playerTargetY = targetWorldY
  s.isMoving = true
  s._movementTime = 0
  if targetWorldX > s.playerWorldX then
    s.playerFacingRight = true
  elseif targetWorldX < s.playerWorldX then
    s.playerFacingRight = false
  end
  s.mapManager:movePlayerTo(targetGridX, targetGridY)
  return true
end

function MapController:keypressed(key, scancode, isRepeat)
  local s = self.scene
  if key == "p" and not isRepeat then
    -- Open encounter selection menu
    return "open_encounter_select"
  end
  
  if key == "space" and not s.daySystem:canMove() and not s.isMoving then
    s._endDayPressed = true
    s._endDaySpinTime = 0
    s._endDayFadeOutTime = 0
    s._endDayFadeOutAlpha = 1
    s.daySystem:advanceDay()
    return
  end

  if not isRepeat then
    self:_setHeldMove(key)
  end

  if s.isMoving or not s.daySystem:canMove() then
    return
  end

  local currentGridX = s.mapManager.playerGridX
  local currentGridY = s.mapManager.playerGridY
  if currentGridX == 0 or currentGridY == 0 then return end

  local targetGridX, targetGridY = currentGridX, currentGridY
  if key == "w" or key == "up" then
    targetGridY = currentGridY - 1
  elseif key == "s" or key == "down" then
    targetGridY = currentGridY + 1
  elseif key == "a" or key == "left" then
    targetGridX = currentGridX - 1
    s.playerFacingRight = false
  elseif key == "d" or key == "right" then
    targetGridX = currentGridX + 1
    s.playerFacingRight = true
  else
    return
  end

  if s.mapManager:canMoveTo(targetGridX, targetGridY) then
    if s.daySystem:useMove() then
      local targetWorldX, targetWorldY = s.mapManager:gridToWorld(
        targetGridX,
        targetGridY,
        s.gridSize,
        s.offsetX,
        s.offsetY
      )
      s.playerTargetX = targetWorldX
      s.playerTargetY = targetWorldY
      s.isMoving = true
      s._movementTime = 0
      if targetWorldX > s.playerWorldX then
        s.playerFacingRight = true
      elseif targetWorldX < s.playerWorldX then
        s.playerFacingRight = false
      end
      s.mapManager:movePlayerTo(targetGridX, targetGridY)
    end
  end
end

function MapController:keyreleased(key)
  local s = self.scene
  if s._heldMoveKey and key == s._heldMoveKey then
    s._heldMoveKey = nil
    s._heldDirX, s._heldDirY = 0, 0
    s._holdElapsed = 0
    s._repeatElapsed = 0
    s._hasFiredInitialRepeat = false
  end
end

function MapController:mousepressed(x, y, button)
  local s = self.scene
  if button ~= 1 then return end
  if not s.daySystem:canMove() then
    if s.endDayBtnRect then
      local r = s.endDayBtnRect
      if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
        s._endDayPressed = true
        s._endDaySpinTime = 0
        s._endDayFadeOutTime = 0
        s._endDayFadeOutAlpha = 1
        s.daySystem:advanceDay()
        return
      end
    end
    return
  end
  if s.isMoving then return end

  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  local worldX = x + s.cameraX - vw * 0.5
  local worldY = y + s.cameraY - vh * 0.5
  local gridX, gridY = s.mapManager:worldToGrid(worldX, worldY, s.gridSize, s.offsetX, s.offsetY)
  if s.mapManager:canMoveTo(gridX, gridY) then
    if s.daySystem:useMove() then
      local targetWorldX, targetWorldY = s.mapManager:gridToWorld(
        gridX,
        gridY,
        s.gridSize,
        s.offsetX,
        s.offsetY
      )
      s.playerTargetX = targetWorldX
      s.playerTargetY = targetWorldY
      s.isMoving = true
      s._movementTime = 0
      if targetWorldX > s.playerWorldX then
        s.playerFacingRight = true
      elseif targetWorldX < s.playerWorldX then
        s.playerFacingRight = false
      end
      s.mapManager:movePlayerTo(gridX, gridY)
    end
  end
end

function MapController:mousemoved(x, y)
  local s = self.scene
  s._mouseX = x
  s._mouseY = y
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  local worldX = x + s.cameraX - vw * 0.5
  local worldY = y + s.cameraY - vh * 0.5
  local gridX, gridY = s.mapManager:worldToGrid(worldX, worldY, s.gridSize, s.offsetX, s.offsetY)
  if s.mapManager:isValidGrid(gridX, gridY) then
    s.selectedGridX = gridX
    s.selectedGridY = gridY
  else
    s.selectedGridX = nil
    s.selectedGridY = nil
  end
end

function MapController:resize(width, height)
  local s = self.scene
  local vw = config.video.virtualWidth
  local vh = config.video.virtualHeight
  local mapWidth = s.mapManager.gridWidth * s.gridSize
  local mapHeight = s.mapManager.gridHeight * s.gridSize
  s.offsetX = (vw - mapWidth) * 0.5
  s.offsetY = (vh - mapHeight) * 0.5
  local px, py = s.mapManager:getPlayerWorldPosition(s.gridSize, s.offsetX, s.offsetY)
  s.playerWorldX = px
  s.playerWorldY = py
  if s._clampCameraToMap then s:_clampCameraToMap() end
end

function MapController:update(deltaTime)
  local s = self.scene
  s._treeSwayTime = s._treeSwayTime + deltaTime

  local cameraSpeed = config.map.cameraFollowSpeed
  local dx = s.targetCameraX - s.cameraX
  local dy = s.targetCameraY - s.cameraY
  s.cameraX = s.cameraX + dx * cameraSpeed * deltaTime
  s.cameraY = s.cameraY + dy * cameraSpeed * deltaTime

  if s.isMoving and s.playerTargetX and s.playerTargetY then
    s._movementTime = s._movementTime + deltaTime
    local moveSpeed = config.map.playerMoveSpeed
    local totalDistance = math.sqrt((s.playerTargetX - s.playerWorldX) ^ 2 + (s.playerTargetY - s.playerWorldY) ^ 2)
    if totalDistance > 0 then
      local moveDistance = moveSpeed * deltaTime
      local progress = moveDistance / totalDistance
      if progress >= 1 then
        s.playerWorldX = s.playerTargetX
        s.playerWorldY = s.playerTargetY
        s.playerTargetX = nil
        s.playerTargetY = nil
        s.isMoving = false
        s._movementTime = 0
        local battleTriggered, result = s.mapManager:completeMovement()
        if battleTriggered then
          s._returnGridX = s.mapManager.previousGridX or s.mapManager.playerGridX
          s._returnGridY = s.mapManager.previousGridY or s.mapManager.playerGridY
          s._enemyTileX = s.mapManager.playerGridX
          s._enemyTileY = s.mapManager.playerGridY
          s._battleTransitionDelay = 0
        elseif result == "event_collected" then
          local px2, py2 = s.mapManager:getPlayerWorldPosition(s.gridSize, s.offsetX, s.offsetY)
          s.playerWorldX = px2
          s.playerWorldY = py2
        elseif result == "merchant_visited" then
          local px3, py3 = s.mapManager:getPlayerWorldPosition(s.gridSize, s.offsetX, s.offsetY)
          s.playerWorldX = px3
          s.playerWorldY = py3
        end
      else
        local oldX = s.playerWorldX
        s.playerWorldX = s.playerWorldX + (s.playerTargetX - s.playerWorldX) * progress
        s.playerWorldY = s.playerWorldY + (s.playerTargetY - s.playerWorldY) * progress
        if s.playerTargetX > oldX then
          s.playerFacingRight = true
        elseif s.playerTargetX < oldX then
          s.playerFacingRight = false
        end
      end
    end
  end

  s.targetCameraX = s.playerWorldX
  s.targetCameraY = s.playerWorldY
  if s._clampCameraToMap then s:_clampCameraToMap(true) end
  if s._clampCameraToMap then s:_clampCameraToMap(false) end

  if s._battleTransitionDelay ~= nil then
    if s._battleTransitionDelay > 0 then
      s._battleTransitionDelay = s._battleTransitionDelay - deltaTime
      if s._battleTransitionDelay <= 0 then
        s._battleTransitionDelay = nil
        return "enter_battle"
      end
    else
      s._battleTransitionDelay = nil
      return "enter_battle"
    end
  end

  do
    local target = s.daySystem and (s.daySystem:canMove() and 0 or 1) or 0
    local speed = 6
    if target > s._endDayFadeAlpha then
      s._endDayFadeAlpha = math.min(1, s._endDayFadeAlpha + deltaTime * speed)
    else
      s._endDayFadeAlpha = target
      if target == 0 then
        local animating = s._endDayPressed and ((s._endDaySpinTime < s._endDaySpinDuration) or (s._endDayFadeOutTime < s._endDayFadeOutDuration))
        if not animating then
          s._endDayPressed = false
          s._endDaySpinTime = 0
          s._endDaySpinAngle = 0
          s._endDayFadeOutTime = 0
          s._endDayFadeOutAlpha = 1
        end
      end
    end
  end

  local isAnimating = s._endDayPressed and ((s._endDaySpinTime < s._endDaySpinDuration) or (s._endDayFadeOutTime < s._endDayFadeOutDuration))
  if (not s.daySystem:canMove()) or isAnimating then
    if isAnimating then
      s._endDayHovered = false
      s._endDayHoverScale = 1
    else
      local vw = config.video.virtualWidth
      local vh = config.video.virtualHeight
      local btnH = 42
      local gap = 12
      local font = require("theme").fonts.base or love.graphics.getFont()
      local textW = font:getWidth("END DAY")
      local contentH = btnH - 16
      local leftIconW = 0
      if s.endDayIcon then
        local iw, ih = s.endDayIcon:getDimensions()
        local baseScale = (contentH * 1.69) / math.max(iw, ih)
        leftIconW = iw * baseScale
      end
      local keyIconW = 0
      if s.keySpaceIcon then
        local iw, ih = s.keySpaceIcon:getDimensions()
        local keyScale = contentH * 0.68 / math.max(iw, ih)
        keyIconW = iw * keyScale
      end
      local btnMargin = 32
      local gap2 = 9
      local contentWidth = leftIconW + (s.endDayIcon and gap2 or 0) + textW + (s.keySpaceIcon and (gap2 + keyIconW) or 0)
      local btnW = math.floor(btnMargin + contentWidth * 0.8 + btnMargin + 0.5)
      local btnX = btnMargin
      local btnY = vh - btnH - btnMargin
      local hovered = s._mouseX >= btnX and s._mouseX <= btnX + btnW and s._mouseY >= btnY and s._mouseY <= btnY + btnH
      s._endDayHovered = hovered
      local targetScale = hovered and 1.5 or 1
      local tweenSpeed = 12
      local diff = targetScale - (s._endDayHoverScale or 1)
      s._endDayHoverScale = (s._endDayHoverScale or 1) + diff * math.min(1, tweenSpeed * deltaTime)
    end
  else
    s._endDayHoverScale = 1
    s._endDayHovered = false
  end

  if s._endDayPressed and s._endDaySpinTime < s._endDaySpinDuration then
    s._endDaySpinTime = s._endDaySpinTime + deltaTime
    local progress = math.min(1, s._endDaySpinTime / s._endDaySpinDuration)
    local eased = 1 - math.pow(1 - progress, 3)
    s._endDaySpinAngle = eased * math.pi
  end
  if s._endDayPressed and s._endDaySpinTime >= s._endDaySpinDuration then
    if s._endDayFadeOutTime < s._endDayFadeOutDuration then
      s._endDayFadeOutTime = s._endDayFadeOutTime + deltaTime
      local progress = math.min(1, s._endDayFadeOutTime / s._endDayFadeOutDuration)
      s._endDayFadeOutAlpha = 1 - progress
    end
  end

  -- Hold-to-move repeat
  if s._heldMoveKey then
    s._holdElapsed = (s._holdElapsed or 0) + deltaTime
    s._repeatElapsed = (s._repeatElapsed or 0) + deltaTime
    local repeatCfg = (config.map and config.map.movementRepeat) or { initialDelay = 0.35, interval = 0.12 }
    local canConsiderMove = (s._battleTransitionDelay == nil)
    if canConsiderMove and not s.isMoving and s.daySystem:canMove() then
      if not s._hasFiredInitialRepeat then
        if s._holdElapsed >= repeatCfg.initialDelay then
          local moved = self:_attemptMoveBy(s._heldDirX, s._heldDirY)
          s._hasFiredInitialRepeat = true
          s._repeatElapsed = 0
          if not moved then s._repeatElapsed = 0 end
        end
      else
        if s._repeatElapsed >= repeatCfg.interval then
          local moved = self:_attemptMoveBy(s._heldDirX, s._heldDirY)
          s._repeatElapsed = 0
          if not moved then s._repeatElapsed = 0 end
        end
      end
    end
  end

  return nil
end

return MapController


