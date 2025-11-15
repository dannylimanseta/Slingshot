local config = require("config")

local EnemyController = {}

local function computeEnemyLungeOffset(scene, enemy)
  if not enemy or not enemy.lungeTime or enemy.lungeTime <= 0 then
    return 0
  end

  local lungeDuration = config.battle.lungeDuration or 0
  local returnDuration = config.battle.lungeReturnDuration or 0
  local distance = config.battle.lungeDistance or 0

  if enemy.lungeTime < lungeDuration then
    return distance * (enemy.lungeTime / math.max(0.0001, lungeDuration))
  elseif enemy.lungeTime < lungeDuration + returnDuration then
    local t = (enemy.lungeTime - lungeDuration) / math.max(0.0001, returnDuration)
    return distance * (1 - t)
  else
    return 0
  end
end

function EnemyController.computeLayout(scene, bounds)
  local fallbackBounds = scene._lastBounds
  local w = (bounds and bounds.w) or (fallbackBounds and fallbackBounds.w) or love.graphics.getWidth()
  local h = (bounds and bounds.h) or (fallbackBounds and fallbackBounds.h) or love.graphics.getHeight()
  local center = (bounds and bounds.center) or (fallbackBounds and fallbackBounds.center) or nil

  local centerX = center and center.x or math.floor(w * 0.5) - math.floor((w * 0.5) * 0.5)
  local centerW = center and center.w or math.floor(w * 0.5)
  local rightStart = centerX + centerW
  local rightWidth = math.max(0, w - rightStart)

  local r = 24
  local yOffset = (config.battle and config.battle.positionOffsetY) or 0
  local baselineY = h * 0.55 + r + yOffset

  local layout = {
    w = w,
    baselineY = baselineY,
    rightStart = rightStart,
    rightWidth = rightWidth,
    radius = r,
    entries = {},
  }

  if not scene.enemies or #scene.enemies == 0 then
    return layout
  end

  local battleProfile = scene._battleProfile or {}
  local gapCfg = battleProfile.enemySpacing
  local enemyCount = #scene.enemies
  local gap
  if type(gapCfg) == "table" then
    gap = gapCfg[enemyCount] or gapCfg.default or 0
  else
    gap = gapCfg or -20
  end

  local enemyWidths = {}
  local enemyScales = {}
  local totalWidth = 0

  for i, enemy in ipairs(scene.enemies) do
    local scaleCfg = enemy.spriteScale or (config.battle and (config.battle.enemySpriteScale or config.battle.spriteScale)) or 4
    local scale = 1
    if enemy.img then
      local ih = enemy.img:getHeight()
      scale = ((2 * r) / math.max(1, ih)) * scaleCfg * (enemy.scaleMul or 1)
    end
    enemyScales[i] = scale

    local width = enemy.img and (enemy.img:getWidth() * scale) or (r * 2)
    enemyWidths[i] = width

    totalWidth = totalWidth + width
    if i < enemyCount then
      totalWidth = totalWidth + gap
    end
  end

  local centerXPos = rightStart + rightWidth * 0.5
  local startX = centerXPos - totalWidth * 0.5 - 70

  for i, enemy in ipairs(scene.enemies) do
    local enemyX = startX
    for j = 1, i - 1 do
      enemyX = enemyX + enemyWidths[j] + gap
    end
    enemyX = enemyX + enemyWidths[i] * 0.5

    local centerXPosEnemy = enemyX - computeEnemyLungeOffset(scene, enemy)
    local spriteHeight = enemy.img and (enemy.img:getHeight() * enemyScales[i]) or (r * 2)
    local halfHeight = spriteHeight * 0.5
    local halfWidth = enemyWidths[i] * 0.5

    layout.entries[i] = {
      centerX = centerXPosEnemy,
      centerY = baselineY - halfHeight,
      halfWidth = halfWidth,
      halfHeight = halfHeight,
      hitY = baselineY - halfHeight * 0.7,
      boundingTop = baselineY - spriteHeight,
    }
  end

  return layout
end

function EnemyController.getSelectedEnemy(scene)
  if scene.selectedEnemyIndex and scene.enemies and scene.enemies[scene.selectedEnemyIndex] then
    return scene.enemies[scene.selectedEnemyIndex]
  end
  return nil
end

local function enemyAlive(enemy)
  return enemy and (enemy.hp > 0 or enemy.disintegrating or enemy.pendingDisintegration)
end

function EnemyController.selectNextEnemy(scene)
  if not scene.enemies or #scene.enemies == 0 then
    scene.selectedEnemyIndex = nil
    return
  end

  local startIndex = scene.selectedEnemyIndex or 1
  for i = 1, #scene.enemies do
    local checkIndex = ((startIndex + i - 1) % #scene.enemies) + 1
    if enemyAlive(scene.enemies[checkIndex]) then
      scene.selectedEnemyIndex = checkIndex
      return
    end
  end

  scene.selectedEnemyIndex = nil
end

function EnemyController.cycleEnemySelection(scene)
  if not scene.enemies or #scene.enemies == 0 then
    scene.selectedEnemyIndex = nil
    return
  end

  local startIndex = scene.selectedEnemyIndex or 1
  for i = 1, #scene.enemies do
    local checkIndex = ((startIndex + i - 1) % #scene.enemies) + 1
    if checkIndex ~= startIndex and enemyAlive(scene.enemies[checkIndex]) then
      scene.selectedEnemyIndex = checkIndex
      return
    end
  end

  if scene.selectedEnemyIndex then
    local currentEnemy = scene.enemies[scene.selectedEnemyIndex]
    if not enemyAlive(currentEnemy) then
      scene.selectedEnemyIndex = nil
    end
  end
end

function EnemyController.getEnemyCenterPivot(scene, enemyIndex, bounds)
  if not enemyIndex then
    return nil, nil
  end

  local layout = EnemyController.computeLayout(scene, bounds)
  local entry = layout.entries[enemyIndex]
  if not entry then
    return nil, nil
  end

  return entry.centerX, entry.centerY
end

function EnemyController.getAllEnemyHitPoints(scene, bounds)
  local hitPoints = {}
  local layout = EnemyController.computeLayout(scene, bounds)

  if not scene.enemies or #scene.enemies == 0 then
    return hitPoints
  end

  for i, enemy in ipairs(scene.enemies) do
    if enemyAlive(enemy) then
      local entry = layout.entries[i]
      if entry then
        table.insert(hitPoints, { x = entry.centerX, y = entry.hitY, enemyIndex = i })
      end
    end
  end

  return hitPoints
end

function EnemyController.getEnemyHitPoint(scene, bounds)
  local layout = EnemyController.computeLayout(scene, bounds)
  local selectedEnemy = EnemyController.getSelectedEnemy(scene)
  if selectedEnemy and scene.enemies and #scene.enemies > 0 then
    local enemyIndex = scene.selectedEnemyIndex
    local entry = layout.entries[enemyIndex]
    if entry then
      return entry.centerX, entry.hitY
    end
  else
    local fallbackX
    if layout.rightWidth > 0 then
      fallbackX = layout.rightStart + layout.rightWidth * 0.5
    else
      fallbackX = layout.w - 12 - layout.radius
    end
    return fallbackX, layout.baselineY - layout.radius * 0.7
  end
end

function EnemyController.handleMousePressed(scene, x, y, button, bounds)
  if button ~= 1 then return end

  if not scene.enemies or #scene.enemies == 0 then
    return
  end

  local layout = EnemyController.computeLayout(scene, bounds)
  local clickPadding = 30

  for i = #scene.enemies, 1, -1 do
    local enemy = scene.enemies[i]
    local entry = layout.entries[i]
    if enemy and entry then
      local left = entry.centerX - entry.halfWidth - clickPadding
      local right = entry.centerX + entry.halfWidth + clickPadding
      local top = entry.boundingTop - clickPadding
      local bottom = layout.baselineY + clickPadding

      if x >= left and x <= right and y >= top and y <= bottom then
        if enemyAlive(enemy) then
          scene.selectedEnemyIndex = i
          return
        end
      end
    end
  end
end

return EnemyController


