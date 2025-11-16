local config = require("config")
local Trail = require("utils.trail")
local BattleState = require("core.BattleState")

local EnemySkills = {}

local function createBorderFragments(x, y, w, h, gap, radius)
  local fragments = {}
  local fragmentCount = 24
  local barCenterX = x + w * 0.5
  local barCenterY = y + h * 0.5
  local borderW = w + gap * 2
  local borderH = h + gap * 2
  local borderX = x - gap
  local borderY = y - gap

  for i = 1, fragmentCount do
    local t = (i - 1) / fragmentCount
    local px, py

    if t < 0.25 then
      local edgeT = (t / 0.25)
      px = borderX + borderW * edgeT
      py = borderY
    elseif t < 0.5 then
      local edgeT = ((t - 0.25) / 0.25)
      px = borderX + borderW
      py = borderY + borderH * edgeT
    elseif t < 0.75 then
      local edgeT = ((t - 0.5) / 0.25)
      px = borderX + borderW * (1 - edgeT)
      py = borderY + borderH
    else
      local edgeT = ((t - 0.75) / 0.25)
      px = borderX
      py = borderY + borderH * (1 - edgeT)
    end

    local dx = px - barCenterX
    local dy = py - barCenterY
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > 0 then
      dx = dx / dist
      dy = dy / dist
    end
    local angle = math.atan2(dy, dx)

    local speed = (120 + love.math.random() * 80) * 0.6
    local angleOffset = (love.math.random() - 0.5) * 0.5
    local vx = math.cos(angle + angleOffset) * speed
    local vy = math.sin(angle + angleOffset) * speed

    local baseLength = 8 + love.math.random() * 12
    local fragLength = baseLength * 0.6 * 0.8

    local variation = love.math.random()
    if variation < 0.3 then
      fragLength = fragLength * (0.4 + love.math.random() * 0.3)
    elseif variation < 0.7 then
      fragLength = fragLength * (0.9 + love.math.random() * 0.2)
    else
      fragLength = fragLength * (1.1 + love.math.random() * 0.3)
    end

    table.insert(fragments, {
      x = px,
      y = py,
      vx = vx,
      vy = vy,
      rotation = angle + math.pi * 0.5 + (love.math.random() - 0.5) * 0.3,
      rotationSpeed = (love.math.random() - 0.5) * 8,
      lifetime = 0.5,
      maxLifetime = 0.5,
      length = fragLength,
      progress = 1.0,
    })
  end

  return fragments
end

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

function EnemySkills.performArmorGain(scene, enemy, enemyIndex, amount)
  amount = amount or 5

  scene._attackingEnemyIndex = enemyIndex
  local prevArmor = enemy.armor or 0
  if not scene.prevEnemyArmor[enemyIndex] then
    scene.prevEnemyArmor[enemyIndex] = prevArmor
  end

  BattleState.addEnemyArmor(enemyIndex, amount)

  local state = scene.battleState or BattleState.get()
  if state and state.enemies and state.enemies[enemyIndex] then
    enemy.armor = state.enemies[enemyIndex].armor or 0
  end

  local enemyX, enemyY = scene:getEnemyCenterPivot(enemyIndex, scene._lastBounds)
  if enemyX and enemyY then
    table.insert(scene.popups, {
      x = enemyX,
      y = enemyY,
      kind = "armor",
      value = amount,
      t = config.battle.popupLifetime or 0.8,
      who = "enemy",
      enemyIndex = enemyIndex,
    })
  end
end

local function findEnemyIndex(scene, enemy)
  for i, e in ipairs(scene.enemies or {}) do
    if e == enemy then
      return i
    end
  end
  return 1
end

function EnemySkills.performCalcify(scene, enemy, blockCount)
  blockCount = blockCount or 3
  local enemyIndex = findEnemyIndex(scene, enemy)
  scene._attackingEnemyIndex = enemyIndex

  local enemyX, enemyY = scene:getEnemyCenterPivot(enemyIndex, scene._lastBounds)
  if not enemyX or not enemyY then
    if scene.turnManager then
      scene.turnManager:emit("enemy_calcify_blocks", { count = blockCount })
    end
    return
  end

  scene._calcifySequence = {
    timer = 0,
    phase = "selecting",
    enemy = enemy,
    enemyX = enemyX,
    enemyY = enemyY,
    blockCount = blockCount,
    particles = {},
    selectedBlocks = nil,
  }

  if scene.turnManager then
    scene.turnManager:emit("enemy_calcify_request_blocks", {
      count = blockCount,
      enemyX = enemyX,
      enemyY = enemyY,
    })
  end
end

function EnemySkills.performCharge(scene, enemy, armorBlockCount)
  armorBlockCount = armorBlockCount or 3
  local enemyIndex = findEnemyIndex(scene, enemy)
  scene._attackingEnemyIndex = enemyIndex

  enemy.chargeReady = true

  if scene.turnManager then
    scene.turnManager:emit("enemy_charge_spawn_armor_blocks", { count = armorBlockCount })
  end
end

function EnemySkills.performSpore(scene, enemy, sporeCount)
  sporeCount = sporeCount or 2
  local enemyIndex = findEnemyIndex(scene, enemy)
  scene._attackingEnemyIndex = enemyIndex

  local enemyX, enemyY = scene:getEnemyCenterPivot(enemyIndex, scene._lastBounds)
  if not enemyX or not enemyY then
    if scene.turnManager then
      scene.turnManager:emit("enemy_spore_spawn_blocks", { count = sporeCount })
    end
    return
  end

  scene._sporeSequence = {
    timer = 0,
    phase = "selecting",
    enemy = enemy,
    enemyX = enemyX,
    enemyY = enemyY,
    sporeCount = sporeCount,
    particles = {},
    targets = nil,
  }

  if scene.turnManager then
    scene.turnManager:emit("enemy_spore_request_positions", {
      count = sporeCount,
      enemyX = enemyX,
      enemyY = enemyY,
    })
  end
end

function EnemySkills.performHeal(scene, enemy, targetIndex, amount)
  amount = amount or 12
  local enemyIndex = findEnemyIndex(scene, enemy)
  scene._attackingEnemyIndex = enemyIndex

  local targetEnemy = nil
  if targetIndex and scene.enemies and scene.enemies[targetIndex] then
    targetEnemy = scene.enemies[targetIndex]
  end
  if not targetEnemy or targetEnemy.hp <= 0 or targetEnemy.disintegrating then
    targetEnemy = enemy
    targetIndex = enemyIndex
  end

  local oldHP = targetEnemy.hp
  local maxHP = targetEnemy.maxHP or 100
  local newHP = math.min(maxHP, oldHP + amount)
  local actualHeal = newHP - oldHP

  if actualHeal > 0 then
    BattleState.applyEnemyDamage(targetIndex, -actualHeal)
    local state = scene.battleState or BattleState.get()
    if state and state.enemies and state.enemies[targetIndex] then
      targetEnemy.hp = state.enemies[targetIndex].hp or targetEnemy.hp
    end

    local menderX, menderY = scene:getEnemyCenterPivot(enemyIndex, scene._lastBounds)
    local targetX, targetY = scene:getEnemyCenterPivot(targetIndex, scene._lastBounds)

    if menderX and menderY and targetX and targetY then
      scene._healSequence = {
        timer = 0,
        phase = "animating",
        particles = {},
        targetIndex = targetIndex,
      }

      local eyeOffsetY = -15
      local eyeOffsetX = 8
      local eyePositions = {
        { x = menderX - eyeOffsetX, y = menderY + eyeOffsetY },
        { x = menderX + eyeOffsetX, y = menderY + eyeOffsetY },
      }

      for _, eyePos in ipairs(eyePositions) do
        local dx = targetX - eyePos.x
        local dy = targetY - eyePos.y
        local dist = math.sqrt(dx * dx + dy * dy)
        local arcHeight = math.max(60, dist * 0.6)
        local randomVariation = (love.math.random() - 0.5) * 20

        local cp1x = eyePos.x + dx * 0.2
        local cp1y = eyePos.y - arcHeight - randomVariation
        local cp2x = eyePos.x + dx * 0.8
        local cp2y = eyePos.y + dy * 0.3 - arcHeight * 0.3

        local trail = Trail.new({
          enabled = true,
          width = 20,
          taperPower = 1.2,
          softness = 0.3,
          colorStart = { 0.8, 1.0, 0.4, 0.9 },
          colorEnd = { 0.6, 0.9, 0.3, 0.3 },
          additive = true,
          sampleInterval = 0.01,
          maxPoints = 35,
        })

        table.insert(scene._healSequence.particles, {
          x = eyePos.x,
          y = eyePos.y,
          startX = eyePos.x,
          startY = eyePos.y,
          targetX = targetX,
          targetY = targetY,
          cp1x = cp1x,
          cp1y = cp1y,
          cp2x = cp2x,
          cp2y = cp2y,
          trail = trail,
          progress = 0,
          speed = 1.0,
          hit = false,
        })
      end
    end

    scene.enemyHealGlowTimer[targetIndex] = 1.0

    if targetX and targetY then
      table.insert(scene.popups, {
        x = targetX,
        y = targetY,
        kind = "heal",
        value = actualHeal,
        t = config.battle.popupLifetime or 0.8,
        who = "enemy",
        enemyIndex = targetIndex,
      })
    end
  end
end

function EnemySkills.performShockwave(scene, enemy)
  local enemyIndex = findEnemyIndex(scene, enemy)
  scene._attackingEnemyIndex = enemyIndex
  enemy.jumpTime = 1e-6

  scene._shockwaveSequence = {
    timer = 0,
    phase = "jump",
    enemy = enemy,
    smokeTimer = 0,
    smokeDuration = 0.8,
  }
end

function EnemySkills.startCalcifyAnimation(scene, enemyX, enemyY, blockPositions)
  if not scene._calcifySequence then return end
  local seq = scene._calcifySequence
  seq.selectedBlocks = blockPositions
  seq.phase = "animating"
  seq.timer = 0

  for _, blockPos in ipairs(blockPositions) do
    local dx = blockPos.x - enemyX
    local dy = blockPos.y - enemyY
    local dist = math.sqrt(dx * dx + dy * dy)
    local perpX = -dy / math.max(0.001, dist)
    local perpY = dx / math.max(0.001, dist)
    local curveAmount = dist * 0.5
    local randomOffset1 = (love.math.random() - 0.5) * 1.2
    local randomOffset2 = (love.math.random() - 0.5) * 1.2
    local swerveAmount = dist * 0.25
    local swerveDir = love.math.random() > 0.5 and 1 or -1

    local cp1x = enemyX + dx * 0.25 + perpX * curveAmount * (1 + randomOffset1) * swerveDir
    local cp1y = enemyY + dy * 0.25 + perpY * curveAmount * (1 + randomOffset1) * swerveDir

    local cp2x = enemyX + dx * 0.75 + perpX * curveAmount * (1 - randomOffset2) * -swerveDir + perpX * swerveAmount * 0.3
    local cp2y = enemyY + dy * 0.75 + perpY * curveAmount * (1 - randomOffset2) * -swerveDir + perpY * swerveAmount * 0.3

    local trail = Trail.new({
      enabled = true,
      width = 24,
      taperPower = 1.2,
      softness = 0.3,
      colorStart = { 1, 1, 1, 0.9 },
      colorEnd = { 0.9, 0.9, 0.95, 0.4 },
      additive = true,
      sampleInterval = 0.01,
      maxPoints = 40,
    })

    table.insert(seq.particles, {
      x = enemyX,
      y = enemyY,
      startX = enemyX,
      startY = enemyY,
      targetX = blockPos.x,
      targetY = blockPos.y,
      block = blockPos.block,
      cp1x = cp1x,
      cp1y = cp1y,
      cp2x = cp2x,
      cp2y = cp2y,
      trail = trail,
      progress = 0,
      speed = 0.96,
      hit = false,
    })
  end
end

function EnemySkills.startSporeAnimation(scene, enemyX, enemyY, targetPositions)
  if not scene._sporeSequence then return end
  local seq = scene._sporeSequence
  seq.targets = targetPositions or {}
  seq.phase = "animating"
  seq.timer = 0
  seq.particles = {}

  for _, pos in ipairs(seq.targets) do
    local dx = pos.x - enemyX
    local dy = pos.y - enemyY
    local dist = math.sqrt(dx * dx + dy * dy)
    local perpX = -dy / math.max(0.001, dist)
    local perpY = dx / math.max(0.001, dist)
    local curveAmount = dist * 0.45
    local randomOffset1 = (love.math.random() - 0.5) * 1.0
    local randomOffset2 = (love.math.random() - 0.5) * 1.0
    local swerveAmount = dist * 0.22
    local swerveDir = love.math.random() > 0.5 and 1 or -1

    local cp1x = enemyX + dx * 0.25 + perpX * curveAmount * (1 + randomOffset1) * swerveDir
    local cp1y = enemyY + dy * 0.25 + perpY * curveAmount * (1 + randomOffset1) * swerveDir
    local cp2x = enemyX + dx * 0.75 + perpX * curveAmount * (1 - randomOffset2) * -swerveDir + perpX * swerveAmount * 0.3
    local cp2y = enemyY + dy * 0.75 + perpY * curveAmount * (1 - randomOffset2) * -swerveDir + perpY * swerveAmount * 0.3

    local trail = Trail.new({
      enabled = true,
      width = 22,
      taperPower = 1.2,
      softness = 0.35,
      colorStart = { 0.8, 0.4, 1.0, 0.9 },
      colorEnd = { 0.6, 0.3, 0.9, 0.35 },
      additive = true,
      sampleInterval = 0.01,
      maxPoints = 40,
    })

    table.insert(seq.particles, {
      x = enemyX,
      y = enemyY,
      startX = enemyX,
      startY = enemyY,
      targetX = pos.x,
      targetY = pos.y,
      cp1x = cp1x,
      cp1y = cp1y,
      cp2x = cp2x,
      cp2y = cp2y,
      trail = trail,
      progress = 0,
      speed = 0.98,
      hit = false,
    })
  end
end

local function updateCalcifySequence(scene, dt)
  local seq = scene._calcifySequence
  if not seq or seq.phase ~= "animating" then return end

  seq.timer = seq.timer + dt * 0.85
  local allHit = true
  for _, particle in ipairs(seq.particles) do
    if not particle.hit then
      allHit = false
      particle.progress = math.min(1.0, particle.progress + particle.speed * dt * 0.85)
      local t = particle.progress
      local mt = 1 - t
      local mt2 = mt * mt
      local mt3 = mt2 * mt
      local t2 = t * t
      local t3 = t2 * t

      particle.x = mt3 * particle.startX + 3 * mt2 * t * particle.cp1x + 3 * mt * t2 * particle.cp2x + t3 * particle.targetX
      particle.y = mt3 * particle.startY + 3 * mt2 * t * particle.cp1y + 3 * mt * t2 * particle.cp2y + t3 * particle.targetY

      if particle.trail then
        particle.trail:update(dt * 0.85, particle.x, particle.y)
      end

      local dx = particle.x - particle.targetX
      local dy = particle.y - particle.targetY
      local dist = math.sqrt(dx * dx + dy * dy)

      if dist < 10 or particle.progress >= 1.0 then
        particle.hit = true
        if particle.block then
          if particle.block.calcify then
            particle.block:calcify(nil)
          end
          if particle.block.triggerBounce then
            particle.block:triggerBounce()
          end
        end
      end
    else
      if particle.trail then
        particle.trail:update(dt * 0.85, particle.x, particle.y)
      end
    end
  end

  if allHit then
    if seq.timer >= 1.5 then
      scene._calcifySequence = nil
      if #scene._enemyAttackDelays == 0 then
        scene._attackingEnemyIndex = nil
      end
    end
  end
end

local function updateSporeSequence(scene, dt)
  local seq = scene._sporeSequence
  if not seq or seq.phase ~= "animating" then return end

  seq.timer = seq.timer + dt
  local allHit = true
  for _, p in ipairs(seq.particles or {}) do
    if not p.hit then
      allHit = false
      p.progress = math.min(1.0, p.progress + p.speed * dt)
      local t = p.progress
      local mt = 1 - t
      local mt2 = mt * mt
      local mt3 = mt2 * mt
      local t2 = t * t
      local t3 = t2 * t
      p.x = mt3 * p.startX + 3 * mt2 * t * p.cp1x + 3 * mt * t2 * p.cp2x + t3 * p.targetX
      p.y = mt3 * p.startY + 3 * mt2 * t * p.cp1y + 3 * mt * t2 * p.cp2y + t3 * p.targetY
      if p.trail then p.trail:update(dt, p.x, p.y) end

      local dx = p.x - p.targetX
      local dy = p.y - p.targetY
      if (dx * dx + dy * dy) < (10 * 10) or p.progress >= 1.0 then
        p.hit = true
        if scene.turnManager then
          scene.turnManager:emit("enemy_spore_spawn_block_at", { x = p.targetX, y = p.targetY })
        end
      end
    else
      if p.trail then p.trail:update(dt, p.x, p.y) end
    end
  end

  if allHit then
    if not seq.allHitTime then
      seq.allHitTime = seq.timer
    end
    if seq.timer >= (seq.allHitTime + 1.2) then
      scene._sporeSequence = nil
      if #scene._enemyAttackDelays == 0 then
        scene._attackingEnemyIndex = nil
      end
    end
  end
end

local function updateHealSequence(scene, dt)
  local seq = scene._healSequence
  if not seq or seq.phase ~= "animating" then return end

  seq.timer = seq.timer + dt
  local allHit = true
  for _, particle in ipairs(seq.particles) do
    if not particle.hit then
      allHit = false
      particle.progress = math.min(1.0, particle.progress + particle.speed * dt)
      local t = particle.progress
      local mt = 1 - t
      local mt2 = mt * mt
      local mt3 = mt2 * mt
      local t2 = t * t
      local t3 = t2 * t

      particle.x = mt3 * particle.startX + 3 * mt2 * t * particle.cp1x + 3 * mt * t2 * particle.cp2x + t3 * particle.targetX
      particle.y = mt3 * particle.startY + 3 * mt2 * t * particle.cp1y + 3 * mt * t2 * particle.cp2y + t3 * particle.targetY

      if particle.trail then
        particle.trail:update(dt, particle.x, particle.y)
      end

      local dx = particle.x - particle.targetX
      local dy = particle.y - particle.targetY
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist < 15 or particle.progress >= 1.0 then
        particle.hit = true
      end
    else
      if particle.trail then
        particle.trail:update(dt, particle.x, particle.y)
      end
    end
  end

  if allHit then
    if seq.timer >= 1.2 then
      scene._healSequence = nil
      if #scene._enemyAttackDelays == 0 then
        scene._attackingEnemyIndex = nil
      end
    end
  end
end

local function updateShockwaveSequence(scene, dt)
  local seq = scene._shockwaveSequence
  if not seq then return end

  seq.timer = seq.timer + dt * 0.85

  local jumpDuration = 0.5
  local screenshakeDelay = 0.1
  local damageDelay = 0.1
  local blocksDelay = 0.1
  local blocksDropDuration = 0.6

  if seq.phase == "jump" then
    if seq.timer >= jumpDuration then
      seq.smokeTimer = 1e-6
      seq.phase = "screenshake"
      seq.timer = 0
    end
  elseif seq.phase == "screenshake" then
    if seq.timer >= screenshakeDelay then
      scene:triggerShake(30, 0.5)
      seq.phase = "damage"
      seq.timer = 0
    end
  elseif seq.phase == "damage" then
    if seq.timer >= damageDelay then
      local dmg = 6
     	local blocked, net = scene:_applyPlayerDamage(dmg)

      if net <= 0 then
        scene.armorIconFlashTimer = 0.5
        table.insert(scene.popups, { x = 0, y = 0, kind = "armor_blocked", t = config.battle.popupLifetime, who = "player" })
      else
        scene.playerFlash = config.battle.hitFlashDuration
        scene.playerKnockbackTime = 1e-6
        table.insert(scene.popups, { x = 0, y = 0, text = tostring(net), t = config.battle.popupLifetime, who = "player" })
        if scene.particles then
          local px, py = scene:getPlayerCenterPivot(scene._lastBounds)
          if px and py then
            scene.particles:emitHitBurst(px, py)
          end
        end
      end

      if scene.playerHP <= 0 then
        scene.state = "lose"
        if scene.turnManager then
          scene.turnManager:transitionTo(TurnManager.States.DEFEAT)
        end
      end

      seq.phase = "blocks"
      seq.timer = 0
    end
  elseif seq.phase == "blocks" then
    if seq.timer >= blocksDelay then
      if scene.turnManager then
        scene.turnManager:emit("enemy_shockwave_blocks")
      end
      seq.phase = "waiting_for_blocks"
      seq.timer = 0
    end
  elseif seq.phase == "waiting_for_blocks" then
    if seq.timer >= blocksDropDuration then
      scene._shockwaveSequence = nil
      if #scene._enemyAttackDelays == 0 then
        scene._attackingEnemyIndex = nil
      end
    end
  end

  if seq.smokeTimer and seq.smokeTimer > 0 then
    seq.smokeTimer = seq.smokeTimer + dt
    if seq.smokeTimer >= seq.smokeDuration then
      seq.smokeTimer = 0
    end
  end
end

function EnemySkills.update(scene, dt)
  updateCalcifySequence(scene, dt)
  updateSporeSequence(scene, dt)
  updateHealSequence(scene, dt)
  updateShockwaveSequence(scene, dt)
end

local function drawParticles(particles, drawFn)
  if not particles then return end
  for _, particle in ipairs(particles) do
    drawFn(particle)
  end
end

local function drawCalcify(scene)
  if not scene._calcifySequence or not scene._calcifySequence.particles then return end
  for _, particle in ipairs(scene._calcifySequence.particles) do
    if particle.trail then
      particle.trail:draw()
    end
    if not particle.hit then
      love.graphics.setBlendMode("add")
      love.graphics.setColor(1, 1, 1, 0.15)
      love.graphics.circle("fill", particle.x, particle.y, 16)
      love.graphics.setColor(1, 1, 1, 0.25)
      love.graphics.circle("fill", particle.x, particle.y, 12)
      love.graphics.setColor(1, 1, 1, 0.4)
      love.graphics.circle("fill", particle.x, particle.y, 9)
      love.graphics.setColor(1, 1, 1, 0.6)
      love.graphics.circle("fill", particle.x, particle.y, 7)
      love.graphics.setColor(1, 1, 1, 0.95)
      love.graphics.circle("fill", particle.x, particle.y, 5)
      love.graphics.setBlendMode("alpha")
    end
  end
end

local function drawSpore(scene)
  if not scene._sporeSequence or not scene._sporeSequence.particles then return end
  for _, p in ipairs(scene._sporeSequence.particles) do
    if p.trail then p.trail:draw() end
    if not p.hit then
      love.graphics.setBlendMode("add")
      love.graphics.setColor(0.6, 0.3, 0.9, 0.16)
      love.graphics.circle("fill", p.x, p.y, 16)
      love.graphics.setColor(0.7, 0.35, 1.0, 0.26)
      love.graphics.circle("fill", p.x, p.y, 12)
      love.graphics.setColor(0.8, 0.4, 1.0, 0.42)
      love.graphics.circle("fill", p.x, p.y, 9)
      love.graphics.setColor(0.95, 0.7, 1.0, 0.95)
      love.graphics.circle("fill", p.x, p.y, 5)
      love.graphics.setBlendMode("alpha")
    end
  end
end

local function drawHeal(scene)
  if not scene._healSequence or not scene._healSequence.particles then return end
  for _, particle in ipairs(scene._healSequence.particles) do
    if particle.trail then
      particle.trail:draw()
    end
    if not particle.hit then
      love.graphics.setBlendMode("add")
      love.graphics.setColor(0.8, 1.0, 0.4, 0.15)
      love.graphics.circle("fill", particle.x, particle.y, 14)
      love.graphics.setColor(0.8, 1.0, 0.4, 0.25)
      love.graphics.circle("fill", particle.x, particle.y, 11)
      love.graphics.setColor(0.8, 1.0, 0.4, 0.4)
      love.graphics.circle("fill", particle.x, particle.y, 8)
      love.graphics.setColor(0.8, 1.0, 0.4, 0.6)
      love.graphics.circle("fill", particle.x, particle.y, 6)
      love.graphics.setColor(0.9, 1.0, 0.5, 0.95)
      love.graphics.circle("fill", particle.x, particle.y, 4)
      love.graphics.setBlendMode("alpha")
    end
  end
end

function EnemySkills.draw(scene)
  drawCalcify(scene)
  drawSpore(scene)
  drawHeal(scene)
end

function EnemySkills.createBorderFragments(...)
  return createBorderFragments(...)
end

function EnemySkills.knockbackOffset(...)
  return knockbackOffset(...)
end

return EnemySkills

