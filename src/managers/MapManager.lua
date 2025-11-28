local config = require("config")
local EncounterManager = require("core.EncounterManager")
local Progress = require("core.Progress")

local MapManager = {}
MapManager.__index = MapManager

MapManager.TileType = {
  GROUND = "ground",
  TREE = "tree",
  STONE = "stone",
  ENEMY = "enemy",
  REST = "rest",
  EVENT = "event",
  MERCHANT = "merchant",
    TREASURE = "treasure",
}

local function coordKey(x, y)
  return x .. "," .. y
end

function MapManager.new()
  return setmetatable({
    grid = {},
    gridWidth = 0,
    gridHeight = 0,
    playerGridX = 0,
    playerGridY = 0,
    previousGridX = nil,
    previousGridY = nil,
    playerTargetGridX = nil,
    playerTargetGridY = nil,
    sprites = {},
    seed = nil,
  }, MapManager)
end

function MapManager:loadSprites()
  self.sprites = {
    ground = {
      love.graphics.newImage("assets/images/map/ground_1.png"),
      love.graphics.newImage("assets/images/map/ground_2.png"),
    },
    tree = {
      love.graphics.newImage("assets/images/map/tree_1.png"),
      love.graphics.newImage("assets/images/map/tree_2.png"),
      love.graphics.newImage("assets/images/map/tree_3.png"),
      love.graphics.newImage("assets/images/map/tree_4.png"),
    },
    stone = {
      love.graphics.newImage("assets/images/map/stone_1.png"),
      love.graphics.newImage("assets/images/map/stone_2.png"),
      love.graphics.newImage("assets/images/map/stone_3.png"),
    },
    enemy = {
      love.graphics.newImage("assets/images/map/enemy_1.png"), -- Regular enemy (70%)
    },
    rest = love.graphics.newImage("assets/images/map/rest_1.png"),
    event = love.graphics.newImage("assets/images/map/event_1.png"),
  }

  -- Load elite enemy sprite with error handling
  local okElite, eliteSprite = pcall(love.graphics.newImage, "assets/images/map/enemy_elite_1.png")
  if okElite and eliteSprite then
    self.sprites.enemy[2] = eliteSprite -- Elite enemy (30%)
  else
    -- Fallback to regular enemy sprite if elite sprite doesn't exist
    self.sprites.enemy[2] = self.sprites.enemy[1]
  end

  local ok, merchantSprite = pcall(love.graphics.newImage, "assets/images/map/merchant_1.png")
  if ok and merchantSprite then
    self.sprites.merchant = merchantSprite
  else
    self.sprites.merchant = self.sprites.event
  end
    local ok2, treasureSprite = pcall(love.graphics.newImage, "assets/images/map/treasure_1.png")
    if ok2 and treasureSprite then
      self.sprites.treasure = treasureSprite
    else
      self.sprites.treasure = self.sprites.event
    end
end

function MapManager:initRandom(seed)
  self.seed = seed or math.random(1000000)
  math.randomseed(self.seed)
end

function MapManager:random(min, max)
  return math.random(min, max)
end

function MapManager:randomFloat()
  return math.random()
end

function MapManager:isValidGrid(x, y)
  return x >= 1 and x <= self.gridWidth and y >= 1 and y <= self.gridHeight
end

function MapManager:getTile(x, y)
  if not self:isValidGrid(x, y) then
    return nil
  end
  return self.grid[y] and self.grid[y][x]
end

function MapManager:setTile(x, y, tileData)
  if not self:isValidGrid(x, y) then
    return false
  end
  if not self.grid[y] then
    self.grid[y] = {}
  end
  self.grid[y][x] = tileData
  return true
end

function MapManager:isTraversable(x, y)
  local tile = self:getTile(x, y)
  if not tile then
    return false
  end
  return tile.type == MapManager.TileType.GROUND
    or tile.type == MapManager.TileType.ENEMY
    or tile.type == MapManager.TileType.REST
    or tile.type == MapManager.TileType.EVENT
      or tile.type == MapManager.TileType.MERCHANT
      or tile.type == MapManager.TileType.TREASURE
end

function MapManager:_fillWithTrees()
  self.grid = {}
  local treeVariants = self.sprites.tree and #self.sprites.tree or 0
  for y = 1, self.gridHeight do
    self.grid[y] = {}
    for x = 1, self.gridWidth do
      self.grid[y][x] = {
        type = MapManager.TileType.TREE,
        spriteVariant = nil,
        decoration = nil,
        decorationVariant = treeVariants > 0 and self:random(1, treeVariants) or nil,
      }
    end
  end
end

function MapManager:_shuffle(list)
  for i = #list, 2, -1 do
    local j = self:random(1, i)
    list[i], list[j] = list[j], list[i]
  end
end

function MapManager:_neighbors(x, y)
  return {
    { x - 1, y },
    { x + 1, y },
    { x, y - 1 },
    { x, y + 1 },
  }
end

function MapManager:_turnDirection(dx, dy)
  if dx ~= 0 then
    return self:randomFloat() < 0.5 and { 0, 1 } or { 0, -1 }
  end
  return self:randomFloat() < 0.5 and { 1, 0 } or { -1, 0 }
end

function MapManager:_recordPathTile(x, y, pathTiles, pathSet)
  if not self:isValidGrid(x, y) then
    return false
  end
  local key = coordKey(x, y)
  if not pathSet[key] then
    table.insert(pathTiles, { x = x, y = y })
    pathSet[key] = true
  end
  local tile = self:getTile(x, y)
  if tile then
    tile.type = MapManager.TileType.GROUND
    tile.spriteVariant = nil
    tile.decoration = nil
  end
  return true
end

function MapManager:_countPathNeighbors(x, y, pathSet)
  local count = 0
  local neighbors = self:_neighbors(x, y)
  for _, pos in ipairs(neighbors) do
    if pathSet[coordKey(pos[1], pos[2])] then
      count = count + 1
    end
  end
  return count
end

function MapManager:_buildAnchorList(pathTiles)
  local anchors = {}
  for _, pos in ipairs(pathTiles) do
    table.insert(anchors, {
      x = pos.x,
      y = pos.y,
      key = coordKey(pos.x, pos.y),
    })
  end
  return anchors
end

function MapManager:_selectLoopTarget(x, y, anchorList, minDistance)
  minDistance = minDistance or 3
  local bestDist = math.huge
  local shortlist = {}

  for _, anchor in ipairs(anchorList) do
    local dist = math.abs(anchor.x - x) + math.abs(anchor.y - y)
    if dist >= minDistance then
      if dist < bestDist then
        bestDist = dist
        shortlist = { anchor }
      elseif dist == bestDist or dist <= bestDist + 2 then
        table.insert(shortlist, anchor)
      end
    end
  end

  if #shortlist == 0 then
    if minDistance > 1 then
      return self:_selectLoopTarget(x, y, anchorList, minDistance - 1)
    end
    if #anchorList == 0 then
      return nil
    end
    return anchorList[self:random(1, #anchorList)]
  end

  return shortlist[self:random(1, #shortlist)]
end

function MapManager:_chooseCorridorTargets(startX, startY, corridorCfg)
  local edgeMargin = (corridorCfg and corridorCfg.edgeMargin) or 2
  local segmentCount = math.max(1, (corridorCfg and corridorCfg.mainSegmentCount) or 3)

  local candidates = {
    { x = self.gridWidth - edgeMargin, y = self:random(edgeMargin, self.gridHeight - edgeMargin) },
    { x = edgeMargin, y = self:random(edgeMargin, self.gridHeight - edgeMargin) },
    { x = self:random(edgeMargin, self.gridWidth - edgeMargin), y = self.gridHeight - edgeMargin },
    { x = self:random(edgeMargin, self.gridWidth - edgeMargin), y = edgeMargin },
  }

  local best = candidates[1]
  local bestDist = -math.huge
  for _, candidate in ipairs(candidates) do
    local dist = math.abs(candidate.x - startX) + math.abs(candidate.y - startY)
    if dist > bestDist then
      best = candidate
      bestDist = dist
    end
  end

  local targets = {}
  if segmentCount > 1 then
    for segment = 1, segmentCount - 1 do
      local t = segment / segmentCount
      local tx = math.floor(startX + (best.x - startX) * t + self:random(-1, 1))
      local ty = math.floor(startY + (best.y - startY) * t + self:random(-1, 1))
      tx = math.max(edgeMargin, math.min(self.gridWidth - edgeMargin, tx))
      ty = math.max(edgeMargin, math.min(self.gridHeight - edgeMargin, ty))
      table.insert(targets, { x = tx, y = ty })
    end
  end
  table.insert(targets, best)

  return targets
end

function MapManager:_carveDirectedPath(currentX, currentY, targetX, targetY, pathTiles, pathSet, corridorCfg)
  local jitterChance = (corridorCfg and corridorCfg.jitterChance) or 0.25
  local maxStraightLength = (corridorCfg and corridorCfg.maxStraightLength) or 5
  local attempts = self.gridWidth * self.gridHeight * 4
  
  -- Track consecutive moves in the same direction (actual movement direction, not target direction)
  local lastDirX, lastDirY = nil, nil
  local straightCount = 0

  while (currentX ~= targetX or currentY ~= targetY) and attempts > 0 do
    attempts = attempts - 1
    self:_recordPathTile(currentX, currentY, pathTiles, pathSet)

    local dx = targetX - currentX
    local dy = targetY - currentY
    local options = {}
    local primaryOptions = {}
    local perpendicularOptions = {}

    -- Determine primary direction options (towards target)
    if dx ~= 0 then
      local stepX = dx > 0 and 1 or -1
      for _ = 1, 3 do
        table.insert(primaryOptions, { currentX + stepX, currentY })
      end
      -- Perpendicular options (vertical)
      table.insert(perpendicularOptions, { currentX, currentY + 1 })
      table.insert(perpendicularOptions, { currentX, currentY - 1 })
    end

    if dy ~= 0 then
      local stepY = dy > 0 and 1 or -1
      for _ = 1, 3 do
        table.insert(primaryOptions, { currentX, currentY + stepY })
      end
      -- Perpendicular options (horizontal)
      table.insert(perpendicularOptions, { currentX + 1, currentY })
      table.insert(perpendicularOptions, { currentX - 1, currentY })
    end

    -- If we've been going straight too long, prioritize perpendicular movement
    local forceTurn = false
    if lastDirX ~= nil and lastDirY ~= nil and straightCount >= maxStraightLength then
      forceTurn = true
    end

    if forceTurn then
      -- Force a turn: only use perpendicular options
      for _, opt in ipairs(perpendicularOptions) do
        table.insert(options, opt)
      end
      -- If no perpendicular options, fall back to primary (but this shouldn't happen often)
      if #options == 0 then
        for _, opt in ipairs(primaryOptions) do
          table.insert(options, opt)
        end
      end
    else
      -- Normal behavior: mix primary and perpendicular based on jitterChance
      for _, opt in ipairs(primaryOptions) do
        table.insert(options, opt)
      end
      if self:randomFloat() < jitterChance then
        for _, opt in ipairs(perpendicularOptions) do
          table.insert(options, opt)
        end
      end
    end

    if #options == 0 then
      -- Fallback: use primary options if no perpendicular options available
      for _, opt in ipairs(primaryOptions) do
        table.insert(options, opt)
      end
    end

    if #options == 0 then
      break
    end

    local filtered = {}
    for _, opt in ipairs(options) do
      if self:isValidGrid(opt[1], opt[2]) then
        table.insert(filtered, opt)
      end
    end

    if #filtered == 0 then
      break
    end

    local choice = filtered[self:random(1, #filtered)]
    local newDirX = choice[1] - currentX
    local newDirY = choice[2] - currentY
    
    -- Update direction tracking based on actual movement
    if newDirX ~= 0 or newDirY ~= 0 then
      if lastDirX == newDirX and lastDirY == newDirY then
        -- Still going same direction
        straightCount = straightCount + 1
      else
        -- Changed direction
        lastDirX = newDirX
        lastDirY = newDirY
        straightCount = 1
      end
    end
    
    currentX, currentY = choice[1], choice[2]
  end

  self:_recordPathTile(targetX, targetY, pathTiles, pathSet)
  return targetX, targetY
end

function MapManager:_carveLoopBranch(originX, originY, lengthMin, lengthMax, corridorCfg, pathTiles, pathSet, anchorList)
  local length = self:random(math.max(2, lengthMin), math.max(lengthMin, lengthMax))
  local directions = {
    { 1, 0 },
    { -1, 0 },
    { 0, 1 },
    { 0, -1 },
  }
  local dir = directions[self:random(1, #directions)]
  local turnChance = (corridorCfg and corridorCfg.branchTurnChance) or 0.3
  local x, y = originX, originY
  local branchTiles = {}

  for _ = 1, length do
    local nx, ny = x + dir[1], y + dir[2]
    if not self:isValidGrid(nx, ny) then
      break
    end
    if not self:_recordPathTile(nx, ny, pathTiles, pathSet) then
      break
    end
    table.insert(branchTiles, { x = nx, y = ny })
    x, y = nx, ny

    if self:randomFloat() < turnChance then
      local newDir = self:_turnDirection(dir[1], dir[2])
      dir = { newDir[1], newDir[2] }
    end
  end

  if #branchTiles == 0 then
    return
  end

  local endpoint = branchTiles[#branchTiles]
  local target = self:_selectLoopTarget(endpoint.x, endpoint.y, anchorList, 3)
  if target then
    self:_carveDirectedPath(endpoint.x, endpoint.y, target.x, target.y, pathTiles, pathSet, corridorCfg)
  end
end

function MapManager:_buildPathNetwork(startX, startY, genConfig)
  local corridorCfg = genConfig and genConfig.corridor or nil
  local pathTiles = {}
  local pathSet = {}

  self:_recordPathTile(startX, startY, pathTiles, pathSet)

  local targets = self:_chooseCorridorTargets(startX, startY, corridorCfg)
  local currentX, currentY = startX, startY
  for _, target in ipairs(targets) do
    currentX, currentY = self:_carveDirectedPath(currentX, currentY, target.x, target.y, pathTiles, pathSet, corridorCfg)
  end

  local branchCount = math.max(0, corridorCfg and corridorCfg.branchCount or 0)
  local branchLengthMin = corridorCfg and corridorCfg.branchLengthMin or 3
  local branchLengthMax = corridorCfg and corridorCfg.branchLengthMax or branchLengthMin

  local anchorList = self:_buildAnchorList(pathTiles)

  if branchCount > 0 and #pathTiles > 2 then
    for _ = 1, branchCount do
      if #pathTiles < 2 then
        break
      end
      local originIndex = self:random(2, #pathTiles)
      local origin = pathTiles[originIndex]
      local anchorSnapshot = {}
      for _, anchor in ipairs(anchorList) do
        table.insert(anchorSnapshot, anchor)
      end
      self:_carveLoopBranch(origin.x, origin.y, branchLengthMin, branchLengthMax, corridorCfg, pathTiles, pathSet, anchorSnapshot)
      anchorList = self:_buildAnchorList(pathTiles)
    end
  end

  local widenChance = corridorCfg and corridorCfg.widenChance or 0
  if widenChance > 0 then
    local initialCount = #pathTiles
    for i = 1, initialCount do
      local pos = pathTiles[i]
      for _, neighbor in ipairs(self:_neighbors(pos.x, pos.y)) do
        if self:isValidGrid(neighbor[1], neighbor[2]) then
          if self:randomFloat() < widenChance then
            self:_recordPathTile(neighbor[1], neighbor[2], pathTiles, pathSet)
          end
        end
      end
    end
  end

  return pathTiles, pathSet
end

function MapManager:_applyGroundDecorations(pathTiles, genConfig)
  local chance = (genConfig and genConfig.groundSpriteChance) or 0
  local variants = self.sprites.ground and #self.sprites.ground or 0
  if chance <= 0 or variants == 0 then
    return
  end

  for _, pos in ipairs(pathTiles) do
    local tile = self:getTile(pos.x, pos.y)
    if tile then
      if self:randomFloat() < chance then
        tile.spriteVariant = self:random(1, variants)
      else
        tile.spriteVariant = nil
      end
    end
  end
end

function MapManager:_isFarEnough(x, y, positions, minSpacing)
  if not positions or minSpacing <= 0 then
    return true
  end
  for _, pos in ipairs(positions) do
    local dist = math.abs(pos.x - x) + math.abs(pos.y - y)
    if dist < minSpacing then
      return false
    end
  end
  return true
end

function MapManager:_placeNodeGroup(nodeType, pathTiles, groupCfg, occupied, placed, avoid)
  local minCount = groupCfg and groupCfg.min or 0
  local maxCount = groupCfg and groupCfg.max or minCount
  if maxCount <= 0 then
    return placed
  end
  local minSpacing = groupCfg and groupCfg.minSpacing or 0
  local minDistance = groupCfg and (groupCfg.minDistanceFromStart or groupCfg.minDistance) or 0
  local avoidList = avoid or {}

  local candidates = {}
  for _, pos in ipairs(pathTiles) do
    local key = coordKey(pos.x, pos.y)
    if not occupied[key] then
      local dist = math.abs(pos.x - self.playerGridX) + math.abs(pos.y - self.playerGridY)
      if dist >= minDistance then
        table.insert(candidates, { x = pos.x, y = pos.y, key = key })
      end
    end
  end

  if #candidates == 0 then
    return placed
  end

  self:_shuffle(candidates)

  local target = math.min(maxCount, #candidates)
  target = math.max(target, math.min(minCount, #candidates))

  local results = placed or {}
  local placedCount = #results
  local spacing = minSpacing

  while placedCount < target and spacing >= 0 do
    local placedThisPass = false
    for _, candidate in ipairs(candidates) do
      if not occupied[candidate.key]
        and self:_isFarEnough(candidate.x, candidate.y, results, spacing)
        and self:_isFarEnough(candidate.x, candidate.y, avoidList, spacing)
      then
        local tile = self:getTile(candidate.x, candidate.y)
        if tile then
          tile.type = nodeType
          tile.spriteVariant = nil
          tile.decoration = nil
          table.insert(results, { x = candidate.x, y = candidate.y })
          occupied[candidate.key] = true
          placedCount = placedCount + 1
          placedThisPass = true
          if placedCount >= target then
            break
          end
        end
      end
    end

    if placedCount >= target then
      break
    end

    if not placedThisPass then
      spacing = spacing - 1
    end
  end

  return results
end

function MapManager:_findDeadEnds(pathTiles, pathSet)
  local deadEnds = {}
  for _, pos in ipairs(pathTiles) do
    local key = coordKey(pos.x, pos.y)
    if pathSet[key] and not (pos.x == self.playerGridX and pos.y == self.playerGridY) then
      if self:_countPathNeighbors(pos.x, pos.y, pathSet) <= 1 then
        table.insert(deadEnds, { x = pos.x, y = pos.y, key = key })
      end
    end
  end
  return deadEnds
end

local function manhattanDistance(ax, ay, bx, by)
  return math.abs(ax - bx) + math.abs(ay - by)
end

function MapManager:_enforceEventGrouping(eventPositions, occupied, minSpacing)
  minSpacing = math.max(3, minSpacing or 0)
  if #eventPositions <= 1 then
    return eventPositions
  end

  table.sort(eventPositions, function(a, b)
    return manhattanDistance(a.x, a.y, self.playerGridX, self.playerGridY) < manhattanDistance(b.x, b.y, self.playerGridX, self.playerGridY)
  end)

  local kept = {}
  local keptLookup = {}

  for _, pos in ipairs(eventPositions) do
    local shouldKeep = true
    for _, keptPos in ipairs(kept) do
      if manhattanDistance(pos.x, pos.y, keptPos.x, keptPos.y) <= minSpacing then
        shouldKeep = false
        break
      end
    end

    if shouldKeep then
      table.insert(kept, pos)
      keptLookup[pos.key] = true
    else
      occupied[pos.key] = nil
      local tile = self:getTile(pos.x, pos.y)
      if tile then
        tile.type = MapManager.TileType.GROUND
        tile.spriteVariant = nil
        tile.decoration = nil
      end
    end
  end
  return kept
end

function MapManager:_placeTreasures(pathTiles, pathSet, occupied, count)
  -- Configurable count and spacing
  local treasCfg = (config.map and config.map.generation and config.map.generation.treasure) or nil
  local minSpacing = math.max(6, treasCfg and treasCfg.minSpacing or 12)
  count = count or (treasCfg and treasCfg.count) or 5
  local deadEnds = self:_findDeadEnds(pathTiles, pathSet)
  if #deadEnds == 0 then
    deadEnds = {}
  end

  local candidates = {}
  for _, deadEnd in ipairs(deadEnds) do
    if not occupied[deadEnd.key] then
      local dist = math.abs(deadEnd.x - self.playerGridX) + math.abs(deadEnd.y - self.playerGridY)
      table.insert(candidates, {
        x = deadEnd.x,
        y = deadEnd.y,
        key = deadEnd.key,
        distance = dist,
      })
    end
  end

  table.sort(candidates, function(a, b)
    return a.distance > b.distance
  end)

  local results = {}
  local placed = 0
  for _, candidate in ipairs(candidates) do
    if placed >= count then
      break
    end
    local tile = self:getTile(candidate.x, candidate.y)
    if tile and self:_isFarEnough(candidate.x, candidate.y, results, minSpacing) then
      tile.type = MapManager.TileType.TREASURE
      tile.spriteVariant = nil
      tile.decoration = nil
      occupied[candidate.key] = true
      table.insert(results, { x = candidate.x, y = candidate.y })
      placed = placed + 1
    end
  end

  -- Fallback: if not enough dead-ends exist, place on furthest corridor tiles
  if placed < count then
    local corridorCandidates = {}
    for _, pos in ipairs(pathTiles) do
      local key = coordKey(pos.x, pos.y)
      if not occupied[key] then
        local neighborCount = self:_countPathNeighbors(pos.x, pos.y, pathSet)
        -- Prefer corridor tiles (degree 2) over hubs; exclude the start tile
        local isStart = (pos.x == self.playerGridX and pos.y == self.playerGridY)
        if not isStart and neighborCount == 2 then
          local dist = math.abs(pos.x - self.playerGridX) + math.abs(pos.y - self.playerGridY)
          table.insert(corridorCandidates, {
            x = pos.x, y = pos.y, key = key, distance = dist
          })
        end
      end
    end
    table.sort(corridorCandidates, function(a, b)
      return a.distance > b.distance
    end)
    for _, cand in ipairs(corridorCandidates) do
      if placed >= count then break end
      local tile = self:getTile(cand.x, cand.y)
      if tile and self:_isFarEnough(cand.x, cand.y, results, minSpacing) then
        tile.type = MapManager.TileType.TREASURE
        tile.spriteVariant = nil
        tile.decoration = nil
        occupied[cand.key] = true
        table.insert(results, { x = cand.x, y = cand.y })
        placed = placed + 1
      end
    end
  end

  return results
end

function MapManager:_placeEvents(pathTiles, pathSet, groupCfg, occupied, avoid)
  local minCount = groupCfg and groupCfg.min or 0
  local maxCount = groupCfg and groupCfg.max or minCount

  local results = {}
  local configSpacing = groupCfg and groupCfg.minSpacing or 0
  local minSpacing = math.max(3, configSpacing)
  local minDistance = groupCfg and (groupCfg.minDistanceFromStart or groupCfg.minDistance) or 0
  local avoidList = avoid or {}

  local deadEnds = self:_findDeadEnds(pathTiles, pathSet)
  self:_shuffle(deadEnds)

  for _, deadEnd in ipairs(deadEnds) do
    if not occupied[deadEnd.key] then
      local dist = math.abs(deadEnd.x - self.playerGridX) + math.abs(deadEnd.y - self.playerGridY)
      if dist >= minDistance then
        if self:_isFarEnough(deadEnd.x, deadEnd.y, results, minSpacing)
          and self:_isFarEnough(deadEnd.x, deadEnd.y, avoidList, minSpacing)
        then
          local tile = self:getTile(deadEnd.x, deadEnd.y)
          if tile then
            tile.type = MapManager.TileType.EVENT
            tile.spriteVariant = nil
            tile.decoration = nil
            occupied[deadEnd.key] = true
            table.insert(results, { x = deadEnd.x, y = deadEnd.y, key = deadEnd.key })
          end
        end
      end
    end
  end

  local generalCandidates = {}
  for _, pos in ipairs(pathTiles) do
    local key = coordKey(pos.x, pos.y)
    if not occupied[key] then
      local dist = math.abs(pos.x - self.playerGridX) + math.abs(pos.y - self.playerGridY)
      if dist >= minDistance then
        if self:_countPathNeighbors(pos.x, pos.y, pathSet) > 1 then
          table.insert(generalCandidates, { x = pos.x, y = pos.y, key = key })
        end
      end
    end
  end

  self:_shuffle(generalCandidates)

  local desired = maxCount
  if desired < #results then
    desired = #results
  else
    desired = math.max(desired, math.min(minCount, #results + #generalCandidates))
  end

  local spacing = minSpacing
  while #results < desired and spacing >= 3 do
    local placedThisPass = false
    for _, candidate in ipairs(generalCandidates) do
      if not candidate.used
        and not occupied[candidate.key]
        and self:_isFarEnough(candidate.x, candidate.y, results, spacing)
        and self:_isFarEnough(candidate.x, candidate.y, avoidList, spacing)
      then
        local tile = self:getTile(candidate.x, candidate.y)
        if tile then
          tile.type = MapManager.TileType.EVENT
          tile.spriteVariant = nil
          tile.decoration = nil
          occupied[candidate.key] = true
          candidate.used = true
          table.insert(results, { x = candidate.x, y = candidate.y, key = candidate.key })
          placedThisPass = true
          if #results >= desired then
            break
          end
        end
      end
    end

    if #results >= desired then
      break
    end

    if not placedThisPass then
      if spacing <= 3 then
        break
      end
      spacing = spacing - 1
      if spacing < 3 then
        spacing = 3
      end
    end
  end

  return results
end

function MapManager:_placeEnemies(pathTiles, pathSet, groupCfg, occupied)
  local minCount = groupCfg and groupCfg.min or 0
  local maxCount = groupCfg and groupCfg.max or minCount
  if maxCount <= 0 then
    return {}
  end

  local minSpacing = groupCfg and groupCfg.minSpacing or 0
  local minDistance = groupCfg and (groupCfg.minDistanceFromStart or groupCfg.minDistance) or 0

  local chokepoints = {}
  local generalCandidates = {}

  for _, pos in ipairs(pathTiles) do
    local key = coordKey(pos.x, pos.y)
    if not occupied[key] then
      local dist = math.abs(pos.x - self.playerGridX) + math.abs(pos.y - self.playerGridY)
      if dist >= minDistance then
        local tile = self:getTile(pos.x, pos.y)
        if tile then
          if self:_countPathNeighbors(pos.x, pos.y, pathSet) == 2 then
            table.insert(chokepoints, { x = pos.x, y = pos.y, key = key })
          else
            table.insert(generalCandidates, { x = pos.x, y = pos.y, key = key })
          end
        end
      end
    end
  end

  self:_shuffle(chokepoints)
  self:_shuffle(generalCandidates)

  local candidates = {}
  for _, cand in ipairs(chokepoints) do
    table.insert(candidates, cand)
  end
  for _, cand in ipairs(generalCandidates) do
    table.insert(candidates, cand)
  end

  local target = math.min(maxCount, #candidates)
  target = math.max(target, math.min(minCount, #candidates))

  local results = {}
  local placedCount = 0
  local spacing = minSpacing

  while placedCount < target and spacing >= 0 do
    local placedThisPass = false
    for _, candidate in ipairs(candidates) do
      if not candidate.used and not occupied[candidate.key] and self:_isFarEnough(candidate.x, candidate.y, results, spacing) then
        local tile = self:getTile(candidate.x, candidate.y)
        if tile then
          tile.type = MapManager.TileType.ENEMY
          -- Randomly assign sprite variant: 30% elite (variant 2), 70% regular (variant 1)
          if love.math.random() < 0.3 then
            tile.spriteVariant = 2 -- Elite enemy
          else
            tile.spriteVariant = 1 -- Regular enemy
          end
          tile.decoration = nil
          occupied[candidate.key] = true
          candidate.used = true
          table.insert(results, { x = candidate.x, y = candidate.y })
          placedCount = placedCount + 1
          placedThisPass = true
          if placedCount >= target then
            break
          end
        end
      end
    end

    if placedCount >= target then
      break
    end

    if not placedThisPass then
      spacing = spacing - 1
    end
  end

  return results
end

function MapManager:_placeSpecialNodes(pathTiles, pathSet, genConfig)
  local occupied = {}
  occupied[coordKey(self.playerGridX, self.playerGridY)] = true

  local placements = {
    rest = {},
    merchant = {},
    event = {},
    enemy = {},
      treasure = {},
  }

  -- Place treasures first so they reserve the furthest dead-ends
  local treasCfg = (config.map and config.map.generation and config.map.generation.treasure) or nil
  local treasureCount = (treasCfg and treasCfg.count) or 5
  placements.treasure = self:_placeTreasures(pathTiles, pathSet, occupied, treasureCount)

  -- Events must avoid treasures
  placements.event = self:_placeEvents(pathTiles, pathSet, genConfig and genConfig.event or nil, occupied, placements.treasure)
    placements.event = self:_enforceEventGrouping(placements.event, occupied, 3)
  -- Rest must avoid treasures and events
  do
    local avoid = {}
    for _, p in ipairs(placements.treasure) do table.insert(avoid, p) end
    for _, p in ipairs(placements.event) do table.insert(avoid, p) end
    placements.rest = self:_placeNodeGroup(MapManager.TileType.REST, pathTiles, genConfig and genConfig.rest or nil, occupied, placements.rest, avoid)
  end
  -- Merchant must avoid treasures, events, and rest
  do
    local avoid = {}
    for _, p in ipairs(placements.treasure) do table.insert(avoid, p) end
    for _, p in ipairs(placements.event) do table.insert(avoid, p) end
    for _, p in ipairs(placements.rest) do table.insert(avoid, p) end
    placements.merchant = self:_placeNodeGroup(MapManager.TileType.MERCHANT, pathTiles, genConfig and genConfig.merchant or nil, occupied, placements.merchant, avoid)
  end
  placements.enemy = self:_placeEnemies(pathTiles, pathSet, genConfig and genConfig.enemy or nil, occupied)

  self:_applyTerrainVariations(pathTiles, occupied)

  return placements
end

function MapManager:generateMap(width, height, seed)
  self.gridWidth = width
  self.gridHeight = height
  self:initRandom(seed)

  self:_fillWithTrees()

  local startX = math.floor((width + 1) * 0.5)
  local startY = math.floor((height + 1) * 0.5)
  self.playerGridX = startX
  self.playerGridY = startY

  local pathTiles, pathSet = self:_buildPathNetwork(startX, startY, config.map.generation)
  self.pathTileCount = #pathTiles
  self:_applyGroundDecorations(pathTiles, config.map.generation)
  local placements = self:_placeSpecialNodes(pathTiles, pathSet, config.map.generation)
  self.nodeCounts = {
    rest = placements.rest and #placements.rest or 0,
    merchants = placements.merchant and #placements.merchant or 0,
    events = placements.event and #placements.event or 0,
    enemies = placements.enemy and #placements.enemy or 0,
      treasures = placements.treasure and #placements.treasure or 0,
  }

  self:_sealBordersWithTrees()

  -- Ensure start tile is marked as ground for safety
  local startTile = self:getTile(startX, startY)
  if startTile then
    startTile.type = MapManager.TileType.GROUND
  end

  self.playerTargetGridX = nil
  self.playerTargetGridY = nil
end

function MapManager:isReachableFromStart(targetX, targetY)
  if not self:isTraversable(targetX, targetY) then
    return false
  end

  local visited = {}
  local queue = { { self.playerGridX, self.playerGridY } }
  visited[coordKey(self.playerGridX, self.playerGridY)] = true

  while #queue > 0 do
    local current = table.remove(queue, 1)
    local cx, cy = current[1], current[2]

    if cx == targetX and cy == targetY then
      return true
    end

    for _, neighbor in ipairs(self:_neighbors(cx, cy)) do
      local nx, ny = neighbor[1], neighbor[2]
      local key = coordKey(nx, ny)
      if not visited[key] and self:isTraversable(nx, ny) then
        visited[key] = true
        table.insert(queue, { nx, ny })
      end
    end
  end

  return false
end

function MapManager:gridToWorld(x, y, gridSize, offsetX, offsetY)
  gridSize = gridSize or 64
  offsetX = offsetX or 0
  offsetY = offsetY or 0
  return offsetX + (x - 1) * gridSize + gridSize * 0.5, offsetY + (y - 1) * gridSize + gridSize * 0.5
end

function MapManager:worldToGrid(wx, wy, gridSize, offsetX, offsetY)
  gridSize = gridSize or 64
  offsetX = offsetX or 0
  offsetY = offsetY or 0
  local gx = math.floor((wx - offsetX) / gridSize) + 1
  local gy = math.floor((wy - offsetY) / gridSize) + 1
  return gx, gy
end

function MapManager:getPlayerWorldPosition(gridSize, offsetX, offsetY)
  return self:gridToWorld(self.playerGridX, self.playerGridY, gridSize, offsetX, offsetY)
end

function MapManager:canMoveTo(gridX, gridY)
  if not self:isTraversable(gridX, gridY) then
    return false
  end
  if gridX == self.playerGridX and gridY == self.playerGridY then
    return false
  end
  local dx = math.abs(gridX - self.playerGridX)
  local dy = math.abs(gridY - self.playerGridY)
  return (dx == 1 and dy == 0) or (dx == 0 and dy == 1)
end

function MapManager:movePlayerTo(gridX, gridY)
  if self:canMoveTo(gridX, gridY) then
    self.previousGridX = self.playerGridX
    self.previousGridY = self.playerGridY
    self.playerTargetGridX = gridX
    self.playerTargetGridY = gridY
    return true
  end
  return false
end

function MapManager:completeMovement()
  if self.playerTargetGridX and self.playerTargetGridY then
    self.playerGridX = self.playerTargetGridX
    self.playerGridY = self.playerTargetGridY
    self.playerTargetGridX = nil
    self.playerTargetGridY = nil

    local tile = self:getTile(self.playerGridX, self.playerGridY)
    if tile and tile.type == MapManager.TileType.ENEMY then
      -- Check if this is an elite enemy node (spriteVariant == 2)
      local isElite = tile.spriteVariant == 2
      
      -- Get current difficulty level (for the next encounter)
      local currentDifficulty = Progress.peekDifficultyLevel()
      
      -- Try to find an encounter at the current difficulty, falling back to lower difficulties
      local encounterId = nil
      local tryDifficulty = currentDifficulty
      
      while tryDifficulty >= 1 and not encounterId do
        local filterFn = nil
        if isElite then
          filterFn = function(enc)
            local encDifficulty = enc.difficulty or 1
            return enc.elite == true and encDifficulty == tryDifficulty
          end
        else
          -- Normal enemy tile: exclude elite encounters, match difficulty
          filterFn = function(enc)
            local encDifficulty = enc.difficulty or 1
            return enc.elite ~= true and encDifficulty == tryDifficulty
          end
        end
        
        encounterId = EncounterManager.pickRandomEncounterId(filterFn)
        if not encounterId then
          tryDifficulty = tryDifficulty - 1
        end
      end
      
      if encounterId then
        EncounterManager.setEncounterById(encounterId)
      else
        EncounterManager.clearEncounter()
      end
      return true, "enemy"
    end

    if tile and tile.type == MapManager.TileType.EVENT then
		tile.type = MapManager.TileType.GROUND
		return false, "event_collected"
    end

    if tile and tile.type == MapManager.TileType.MERCHANT then
      tile.type = MapManager.TileType.GROUND
      return false, "merchant_visited"
    end

    if tile and tile.type == MapManager.TileType.TREASURE then
      tile.type = MapManager.TileType.GROUND
      return false, "treasure_collected"
    end

    if tile and tile.type == MapManager.TileType.REST then
      tile.type = MapManager.TileType.GROUND
      return false, "rest_visited"
    end
  end

  return false
end

function MapManager:isPlayerMoving()
  return self.playerTargetGridX ~= nil
end

function MapManager:getPlayerTargetWorldPosition(gridSize, offsetX, offsetY)
  if self.playerTargetGridX and self.playerTargetGridY then
    return self:gridToWorld(self.playerTargetGridX, self.playerTargetGridY, gridSize, offsetX, offsetY)
  end
  return nil, nil
end

function MapManager:calculateRecommendedDailyMoves(totalDays)
  totalDays = totalDays or (config.map and config.map.totalDays) or 30
  local pathCount = self.pathTileCount or (self.gridWidth * self.gridHeight)
  if pathCount <= 0 or totalDays <= 0 then
    return (config.map and config.map.movesPerDay) or 10
  end

  local enemyCount = (self.nodeCounts and self.nodeCounts.enemies) or 0
  local base = math.floor(pathCount / totalDays)
  local encounterBuffer = math.ceil((enemyCount / totalDays) * 3)
  local recommended = base + encounterBuffer + 3
  return math.max(8, math.min(12, recommended))
end

function MapManager:_sealBordersWithTrees()
  local treeVariants = self.sprites.tree and #self.sprites.tree or 0
  for x = 1, self.gridWidth do
    for _, borderY in ipairs({ 1, self.gridHeight }) do
      local tile = self:getTile(x, borderY)
      if tile then
        tile.type = MapManager.TileType.TREE
        tile.decorationVariant = treeVariants > 0 and self:random(1, treeVariants) or nil
        tile.decoration = nil
        tile.spriteVariant = nil
      end
    end
  end
  for y = 1, self.gridHeight do
    for _, borderX in ipairs({ 1, self.gridWidth }) do
      local tile = self:getTile(borderX, y)
      if tile then
        tile.type = MapManager.TileType.TREE
        tile.decorationVariant = treeVariants > 0 and self:random(1, treeVariants) or nil
        tile.decoration = nil
        tile.spriteVariant = nil
      end
    end
  end
end

function MapManager:_applyTerrainVariations(pathTiles, occupied)
  local treeVariants = self.sprites.tree and #self.sprites.tree or 0
  local stoneVariants = self.sprites.stone and #self.sprites.stone or 0
  if treeVariants <= 0 and stoneVariants <= 0 then
    return
  end

  local treeSlots = {}
  for y = 1, self.gridHeight do
    for x = 1, self.gridWidth do
      local key = coordKey(x, y)
      if not occupied[key] then
        local tile = self:getTile(x, y)
        if tile and tile.type == MapManager.TileType.TREE then
          table.insert(treeSlots, { x = x, y = y })
        end
      end
    end
  end

  if #treeSlots == 0 then
    return
  end

  self:_shuffle(treeSlots)

  local stoneCount = math.floor(#treeSlots * 0.15)
  local placedStones = 0

  for _, slot in ipairs(treeSlots) do
    local tile = self:getTile(slot.x, slot.y)
    if placedStones < stoneCount and stoneVariants > 0 then
      tile.type = MapManager.TileType.STONE
      tile.spriteVariant = nil
      tile.decorationVariant = self:random(1, stoneVariants)
      placedStones = placedStones + 1
    elseif treeVariants > 0 then
      tile.type = MapManager.TileType.TREE
      tile.spriteVariant = nil
      tile.decorationVariant = self:random(1, treeVariants)
    end
    tile.decoration = nil
  end
end

return MapManager
