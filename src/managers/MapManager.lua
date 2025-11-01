local MapManager = {}
MapManager.__index = MapManager

-- Tile types
MapManager.TileType = {
  GROUND = "ground",
  TREE = "tree",
  STONE = "stone",
  ENEMY = "enemy",
  REST = "rest",
}

function MapManager.new()
  return setmetatable({
    grid = {}, -- 2D array: grid[y][x] = tile data
    gridWidth = 0,
    gridHeight = 0,
    playerGridX = 0,
    playerGridY = 0,
    previousGridX = nil, -- last grid position before a move
    previousGridY = nil,
    playerTargetGridX = nil,
    playerTargetGridY = nil,
    sprites = {}, -- cached sprites
    seed = nil, -- random seed for generation
  }, MapManager)
end

-- Load all map sprites
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
    enemy = love.graphics.newImage("assets/images/map/enemy_1.png"),
    rest = love.graphics.newImage("assets/images/map/rest_1.png"),
  }
end

-- Initialize random with seed
function MapManager:initRandom(seed)
  self.seed = seed or math.random(1000000)
  math.randomseed(self.seed)
end

-- Get random integer in range [min, max]
function MapManager:random(min, max)
  return math.random(min, max)
end

-- Get random float in range [0, 1]
function MapManager:randomFloat()
  return math.random()
end

-- Check if coordinates are within grid bounds
function MapManager:isValidGrid(x, y)
  return x >= 1 and x <= self.gridWidth and y >= 1 and y <= self.gridHeight
end

-- Get tile at grid coordinates
function MapManager:getTile(x, y)
  if not self:isValidGrid(x, y) then return nil end
  return self.grid[y] and self.grid[y][x]
end

-- Set tile at grid coordinates
function MapManager:setTile(x, y, tileData)
  if not self:isValidGrid(x, y) then return false end
  if not self.grid[y] then self.grid[y] = {} end
  self.grid[y][x] = tileData
  return true
end

-- Check if tile is traversable
function MapManager:isTraversable(x, y)
  local tile = self:getTile(x, y)
  if not tile then return false end
  return tile.type == MapManager.TileType.GROUND or tile.type == MapManager.TileType.ENEMY or tile.type == MapManager.TileType.REST
end

-- Count neighbors of a specific type (4-directional)
function MapManager:countNeighbors(x, y, isTypeFunc)
  local count = 0
  local neighbors = {
    {x - 1, y},
    {x + 1, y},
    {x, y - 1},
    {x, y + 1},
  }
  
  for _, pos in ipairs(neighbors) do
    if isTypeFunc(pos[1], pos[2]) then
      count = count + 1
    end
  end
  
  return count
end

-- Count neighbors in 8 directions (including diagonals)
function MapManager:countNeighbors8(x, y, isTypeFunc)
  local count = 0
  for dy = -1, 1 do
    for dx = -1, 1 do
      if dx ~= 0 or dy ~= 0 then
        if isTypeFunc(x + dx, y + dy) then
          count = count + 1
        end
      end
    end
  end
  return count
end

-- Flood fill to find all connected traversable tiles
function MapManager:floodFill(startX, startY, visited)
  visited = visited or {}
  local key = startX .. "," .. startY
  
  if visited[key] or not self:isTraversable(startX, startY) then
    return visited
  end
  
  visited[key] = true
  
  -- Recursively check neighbors
  local neighbors = {
    {startX - 1, startY},
    {startX + 1, startY},
    {startX, startY - 1},
    {startX, startY + 1},
  }
  
  for _, pos in ipairs(neighbors) do
    self:floodFill(pos[1], pos[2], visited)
  end
  
  return visited
end

-- Find all disconnected regions of traversable tiles
function MapManager:findRegions()
  local regions = {}
  local visited = {}
  
  for y = 1, self.gridHeight do
    for x = 1, self.gridWidth do
      local key = x .. "," .. y
      if not visited[key] and self:isTraversable(x, y) then
        local region = self:floodFill(x, y, {})
        table.insert(regions, region)
        -- Mark all tiles in this region as visited
        for k, _ in pairs(region) do
          visited[k] = true
        end
      end
    end
  end
  
  return regions
end

-- Connect two regions by carving a path
function MapManager:connectRegions(region1, region2)
  -- Find closest points between regions
  local minDist = math.huge
  local closest1, closest2 = nil, nil
  
  for key1, _ in pairs(region1) do
    local x1, y1 = key1:match("(%d+),(%d+)")
    x1, y1 = tonumber(x1), tonumber(y1)
    
    for key2, _ in pairs(region2) do
      local x2, y2 = key2:match("(%d+),(%d+)")
      x2, y2 = tonumber(x2), tonumber(y2)
      
      local dist = math.abs(x1 - x2) + math.abs(y1 - y2)
      if dist < minDist then
        minDist = dist
        closest1 = {x1, y1}
        closest2 = {x2, y2}
      end
    end
  end
  
  if not closest1 or not closest2 then return end
  
  -- Carve a path using simple pathfinding (manhattan distance)
  local px, py = closest1[1], closest1[2]
  local tx, ty = closest2[1], closest2[2]
  
  -- Carve horizontal path
  while px ~= tx do
    self:setTile(px, py, {
      type = MapManager.TileType.GROUND,
      spriteVariant = nil, -- will be set later
      decoration = nil,
    })
    if px < tx then px = px + 1 else px = px - 1 end
  end
  
  -- Carve vertical path
  while py ~= ty do
    self:setTile(px, py, {
      type = MapManager.TileType.GROUND,
      spriteVariant = nil,
      decoration = nil,
    })
    if py < ty then py = py + 1 else py = py - 1 end
  end
end

-- Generate map using cellular automata
function MapManager:generateMap(width, height, seed)
  self.gridWidth = width
  self.gridHeight = height
  self.grid = {}
  self:initRandom(seed)
  
  -- Step 1: Initialize with random noise
  local config = require("config")
  local genConfig = config.map.generation
  local initialGroundChance = genConfig.initialGroundChance
  for y = 1, height do
    self.grid[y] = {}
    for x = 1, width do
      local isGround = self:randomFloat() < initialGroundChance
      self.grid[y][x] = {
        type = isGround and MapManager.TileType.GROUND or MapManager.TileType.STONE,
        spriteVariant = nil,
        decoration = nil,
      }
    end
  end
  
  -- Ensure starting area (corners and edges) have more ground tiles
  -- This guarantees the player can move initially
  local startAreaSize = 3
  for y = 1, math.min(startAreaSize, height) do
    for x = 1, math.min(startAreaSize, width) do
      if self:randomFloat() < 0.7 then -- 70% chance of ground in start area
        self:setTile(x, y, {
          type = MapManager.TileType.GROUND,
          spriteVariant = nil,
          decoration = nil,
        })
      end
    end
  end
  
  -- Step 2: Apply cellular automata rules (more organic, less path-like)
  local iterations = genConfig.cellularIterations
  for i = 1, iterations do
    local newGrid = {}
    for y = 1, height do
      newGrid[y] = {}
      for x = 1, width do
        local tile = self:getTile(x, y)
        
        -- Count ground neighbors (8-directional for more organic feel)
        local groundNeighbors = self:countNeighbors8(x, y, function(nx, ny)
          local t = self:getTile(nx, ny)
          return t and t.type == MapManager.TileType.GROUND
        end)
        
        -- More organic rules: less strict, more random
        -- Use 8-directional neighbors for smoother, less path-like terrain
        -- Random factor to break up perfect patterns
        local randomFactor = self:randomFloat()
        
        if groundNeighbors >= 5 then
          -- High neighbor count -> ground (with small random chance to stay stone)
          if randomFactor > 0.1 then
            newGrid[y][x] = {
              type = MapManager.TileType.GROUND,
              spriteVariant = nil,
              decoration = nil,
            }
          else
            -- Keep as stone occasionally for variation
            newGrid[y][x] = {
              type = MapManager.TileType.STONE,
              spriteVariant = nil,
              decoration = nil,
            }
          end
        elseif groundNeighbors <= 2 then
          -- Low neighbor count -> stone (with small random chance to become ground)
          if randomFactor > 0.15 then
            newGrid[y][x] = {
              type = MapManager.TileType.STONE,
              spriteVariant = nil,
              decoration = nil,
            }
          else
            -- Become ground occasionally for small clearings
            newGrid[y][x] = {
              type = MapManager.TileType.GROUND,
              spriteVariant = nil,
              decoration = nil,
            }
          end
        else
          -- Medium neighbor count (3-4): more random, less predictable
          if randomFactor < 0.4 then
            newGrid[y][x] = {
              type = MapManager.TileType.GROUND,
              spriteVariant = nil,
              decoration = nil,
            }
          else
            newGrid[y][x] = {
              type = MapManager.TileType.STONE,
              spriteVariant = nil,
              decoration = nil,
            }
          end
        end
      end
    end
    self.grid = newGrid
  end
  
  -- Step 3: Ensure connectivity (but less aggressively - only connect large isolated regions)
  local regions = self:findRegions()
  if #regions > 1 then
    -- Only connect regions that are significantly isolated (have reasonable size)
    -- Count tiles in each region
    local regionSizes = {}
    for i, region in ipairs(regions) do
      local size = 0
      for _ in pairs(region) do size = size + 1 end
      regionSizes[i] = size
    end
    
    -- Find the largest region (likely contains player start)
    local largestRegionIdx = 1
    local largestSize = regionSizes[1]
    for i = 2, #regions do
      if regionSizes[i] > largestSize then
        largestSize = regionSizes[i]
        largestRegionIdx = i
      end
    end
    
    -- Only connect other regions if they're reasonably large (at least 10 tiles)
    -- Small isolated pockets can remain - makes map more interesting
    for i = 1, #regions do
      if i ~= largestRegionIdx and regionSizes[i] >= 10 then
        self:connectRegions(regions[largestRegionIdx], regions[i])
      end
    end
  end
  
  -- Step 3.5: Bias obstacles toward TREES (visual preference)
  do
    local stoneToTreeChance = (genConfig and genConfig.stoneToTreeChance) or 0.9
    for y = 1, self.gridHeight do
      for x = 1, self.gridWidth do
        local tile = self:getTile(x, y)
        if tile and tile.type == MapManager.TileType.STONE then
          if self:randomFloat() < stoneToTreeChance then
            tile.type = MapManager.TileType.TREE
            tile.decorationVariant = self:random(1, #self.sprites.tree)
          end
        end
      end
    end
  end
  
  -- Step 4: Place player start position (before placing enemies to calculate distance)
  self:placePlayerStart()
  
  -- Step 5: Place decorations (trees and stones as obstacles)
  self:placeDecorations()
  
  -- Step 6: Place ground sprite decorations (sparingly)
  self:placeGroundDecorations()
  
  -- Step 7: Place rest nodes (sparingly)
  self:placeRestNodes()
  
  -- Step 8: Place enemies
  self:placeEnemies()
end

-- Place trees and stones as obstacles (non-traversable)
-- Trees spawn much more frequently than stones
function MapManager:placeDecorations()
  local config = require("config")
  local genConfig = config.map.generation
  
  -- Place stones FIRST (very few, very spread out) - before trees to avoid conflicts
  -- Stones are now extremely rare - only a handful per map
  local stoneAttempts = math.floor(self.gridWidth * self.gridHeight * genConfig.stoneDensity)
  for i = 1, stoneAttempts do
    local x = self:random(1, self.gridWidth)
    local y = self:random(1, self.gridHeight)
    
    -- Don't place stones on player starting position
    if x == self.playerGridX and y == self.playerGridY then
      -- Skip this iteration
    else
      local tile = self:getTile(x, y)
      if tile and tile.type == MapManager.TileType.GROUND then
        -- Check minimum spacing from other stones and trees (very strict)
        local tooClose = false
        for dy = -genConfig.minStoneSpacing, genConfig.minStoneSpacing do
          for dx = -genConfig.minStoneSpacing, genConfig.minStoneSpacing do
            local neighbor = self:getTile(x + dx, y + dy)
            if neighbor and (neighbor.type == MapManager.TileType.STONE or neighbor.type == MapManager.TileType.TREE) then
              tooClose = true
              break
            end
          end
          if tooClose then break end
        end
        
        -- Very strict conditions: must be far from everything AND pass low chance
        if not tooClose and self:randomFloat() < genConfig.stonePlaceChance then
          -- Convert to stone obstacle
          tile.type = MapManager.TileType.STONE
          tile.decorationVariant = self:random(1, #self.sprites.stone)
        end
      end
    end
  end
  
  -- Place trees SECOND (many more, can form dense forests)
  local treeAttempts = math.floor(self.gridWidth * self.gridHeight * genConfig.treeDensity)
  for i = 1, treeAttempts do
    local x = self:random(1, self.gridWidth)
    local y = self:random(1, self.gridHeight)
    
    -- Don't place trees on player starting position
    if x == self.playerGridX and y == self.playerGridY then
      -- Skip this iteration
    else
      local tile = self:getTile(x, y)
      if tile and tile.type == MapManager.TileType.GROUND then
        -- Check minimum spacing from other trees (if spacing > 0)
        local tooClose = false
        if genConfig.minTreeSpacing > 0 then
          for dy = -genConfig.minTreeSpacing, genConfig.minTreeSpacing do
            for dx = -genConfig.minTreeSpacing, genConfig.minTreeSpacing do
              local neighbor = self:getTile(x + dx, y + dy)
              if neighbor and neighbor.type == MapManager.TileType.TREE then
                tooClose = true
                break
              end
            end
            if tooClose then break end
          end
        end
        
        -- Very permissive placement: trees can spawn anywhere on ground tiles
        -- No restrictions based on neighbor count - allow dense forest clusters
        if not tooClose and self:randomFloat() < genConfig.treeEdgeChance then
          -- Convert to tree obstacle
          tile.type = MapManager.TileType.TREE
          tile.decorationVariant = self:random(1, #self.sprites.tree)
        end
      end
    end
  end
end

-- Place ground sprite decorations sparingly
function MapManager:placeGroundDecorations()
  local config = require("config")
  local genConfig = config.map.generation
  
  -- Only place ground decorations on ground tiles without other decorations
  for y = 1, self.gridHeight do
    for x = 1, self.gridWidth do
      local tile = self:getTile(x, y)
      if tile and tile.type == MapManager.TileType.GROUND and not tile.decoration then
        if self:randomFloat() < genConfig.groundSpriteChance then
          tile.spriteVariant = self:random(1, #self.sprites.ground)
        end
      end
    end
  end
end

-- Place rest nodes (traversable special tiles) sparingly across the map
function MapManager:placeRestNodes()
  local config = require("config")
  local gen = config.map.generation
  local restAttempts = math.floor(self.gridWidth * self.gridHeight * (gen.restDensity or 0.01))
  local minSpacing = (gen.minRestSpacing or 4)
  
  local placed = {}
  
  local function tooCloseToOtherRest(x, y)
    for i = 1, #placed do
      local p = placed[i]
      if math.abs(p[1] - x) <= minSpacing and math.abs(p[2] - y) <= minSpacing then
        return true
      end
    end
    return false
  end
  
  for i = 1, restAttempts do
    local x = self:random(1, self.gridWidth)
    local y = self:random(1, self.gridHeight)
    
    -- Must be ground and not too close to existing rests or player
    local tile = self:getTile(x, y)
    if tile and tile.type == MapManager.TileType.GROUND then
      if not tooCloseToOtherRest(x, y) then
        local distFromPlayer = math.abs(x - self.playerGridX) + math.abs(y - self.playerGridY)
        if distFromPlayer >= (gen.minRestDistanceFromPlayer or 5) then
          -- Place rest
          tile.type = MapManager.TileType.REST
          table.insert(placed, {x, y})
        end
      end
    end
  end
end

-- Check if a position is reachable from player start using BFS
function MapManager:isReachableFromStart(targetX, targetY)
  if not self:isTraversable(targetX, targetY) then
    return false
  end
  
  -- BFS to find path from player start to target
  local visited = {}
  local queue = {}
  local startKey = self.playerGridX .. "," .. self.playerGridY
  
  visited[startKey] = true
  table.insert(queue, {self.playerGridX, self.playerGridY})
  
  while #queue > 0 do
    local current = table.remove(queue, 1)
    local cx, cy = current[1], current[2]
    
    -- Check if we reached the target
    if cx == targetX and cy == targetY then
      return true
    end
    
    -- Check all 4-directional neighbors
    local neighbors = {
      {cx - 1, cy},
      {cx + 1, cy},
      {cx, cy - 1},
      {cx, cy + 1},
    }
    
    for _, pos in ipairs(neighbors) do
      local nx, ny = pos[1], pos[2]
      local key = nx .. "," .. ny
      
      if not visited[key] and self:isTraversable(nx, ny) then
        visited[key] = true
        table.insert(queue, {nx, ny})
      end
    end
  end
  
  return false
end

-- Find path from start to target and carve it if needed
function MapManager:ensurePathToPosition(targetX, targetY)
  if self:isReachableFromStart(targetX, targetY) then
    return true -- Already reachable
  end
  
  -- Use simple pathfinding: carve a manhattan path from target to start
  local currentX, currentY = targetX, targetY
  local startX, startY = self.playerGridX, self.playerGridY
  
  -- Simple manhattan path - move toward start position
  while currentX ~= startX or currentY ~= startY do
    -- Convert current tile to ground if it's not already traversable
    if self:isValidGrid(currentX, currentY) and not self:isTraversable(currentX, currentY) then
      self:setTile(currentX, currentY, {
        type = MapManager.TileType.GROUND,
        spriteVariant = nil,
        decoration = nil,
      })
    end
    
    -- Move toward start position (prefer horizontal movement first)
    if currentX < startX then
      currentX = currentX + 1
    elseif currentX > startX then
      currentX = currentX - 1
    elseif currentY < startY then
      currentY = currentY + 1
    elseif currentY > startY then
      currentY = currentY - 1
    else
      break
    end
    
    -- Convert tile at new position to ground if needed
    if self:isValidGrid(currentX, currentY) and not self:isTraversable(currentX, currentY) then
      self:setTile(currentX, currentY, {
        type = MapManager.TileType.GROUND,
        spriteVariant = nil,
        decoration = nil,
      })
    end
  end
  
  return true
end

-- Place enemies on traversable ground tiles and ensure they're all accessible
function MapManager:placeEnemies()
  local config = require("config")
  local genConfig = config.map.generation
  
  -- Collect all valid enemy positions (traversable ground tiles, far from start)
  local candidatePositions = {}
  for y = 1, self.gridHeight do
    for x = 1, self.gridWidth do
      local tile = self:getTile(x, y)
      if tile and tile.type == MapManager.TileType.GROUND then
        -- Check distance from start position
        local dist = math.abs(x - self.playerGridX) + math.abs(y - self.playerGridY)
        if dist >= genConfig.minEnemyDistance then
          table.insert(candidatePositions, {x, y})
        end
      end
    end
  end
  
  -- Shuffle candidates
  for i = #candidatePositions, 2, -1 do
    local j = self:random(1, i)
    candidatePositions[i], candidatePositions[j] = candidatePositions[j], candidatePositions[i]
  end
  
  -- Place enemies with minimum spacing
  local enemyCount = math.min(
    math.floor(#candidatePositions * genConfig.enemyDensity),
    genConfig.maxEnemies
  )
  
  local placedEnemies = {}
  local minEnemySpacing = genConfig.minEnemySpacing or 3
  
  for i = 1, #candidatePositions do
    if #placedEnemies >= enemyCount then
      break
    end
    
      local x, y = candidatePositions[i][1], candidatePositions[i][2]
      local tile = self:getTile(x, y)
    
    if tile and tile.type == MapManager.TileType.GROUND then
      -- Check minimum spacing from other enemies
      local tooClose = false
      if minEnemySpacing > 0 then
        for _, enemyPos in ipairs(placedEnemies) do
          local ex, ey = enemyPos[1], enemyPos[2]
          local dist = math.abs(x - ex) + math.abs(y - ey)
          if dist < minEnemySpacing then
            tooClose = true
            break
          end
        end
      end
      
      if not tooClose then
        tile.type = MapManager.TileType.ENEMY
        table.insert(placedEnemies, {x, y})
      end
    end
  end
  
  -- Ensure all placed enemies are accessible
  for _, enemyPos in ipairs(placedEnemies) do
    local ex, ey = enemyPos[1], enemyPos[2]
    if not self:isReachableFromStart(ex, ey) then
      -- Carve a path to make this enemy accessible
      self:ensurePathToPosition(ex, ey)
    end
  end
end

-- Check if a position has at least one traversable adjacent tile
function MapManager:hasTraversableNeighbor(x, y)
  local neighbors = {
    {x - 1, y},
    {x + 1, y},
    {x, y - 1},
    {x, y + 1},
  }
  
  for _, pos in ipairs(neighbors) do
    if self:isTraversable(pos[1], pos[2]) then
      return true
    end
  end
  
  return false
end

-- Place player start position at a traversable location with accessible neighbors
function MapManager:placePlayerStart()
  -- Prefer center of the map, then closest traversable tile to center
  local centerX = math.floor((self.gridWidth + 1) * 0.5)
  local centerY = math.floor((self.gridHeight + 1) * 0.5)

  local bestX, bestY
  local bestDist = math.huge

  for y = 1, self.gridHeight do
    for x = 1, self.gridWidth do
      local tile = self:getTile(x, y)
      if tile and tile.type == MapManager.TileType.GROUND and self:hasTraversableNeighbor(x, y) then
        local d = math.abs(x - centerX) + math.abs(y - centerY)
        if d < bestDist then
          bestDist = d
          bestX, bestY = x, y
        end
      end
    end
  end

  if bestX and bestY then
    self.playerGridX = bestX
    self.playerGridY = bestY
    return
  end
  
  -- Fallback: find any traversable ground tile (even without neighbors, we'll create them)
  for y = 1, self.gridHeight do
    for x = 1, self.gridWidth do
      if self:isTraversable(x, y) then
        local tile = self:getTile(x, y)
        if tile and tile.type == MapManager.TileType.GROUND then
          self.playerGridX = x
          self.playerGridY = y
          -- Ensure at least one adjacent tile is traversable
          self:ensurePlayerSpawnAccess()
          return
        end
      end
    end
  end
  
  -- Last resort: force create a spawn area at (1, 1)
  self:createSpawnArea(1, 1)
  self.playerGridX = 1
  self.playerGridY = 1
end

-- Ensure player spawn location has at least one traversable adjacent tile
function MapManager:ensurePlayerSpawnAccess()
  local x, y = self.playerGridX, self.playerGridY
  
  -- Check if already has traversable neighbor
  if self:hasTraversableNeighbor(x, y) then
    return
  end
  
  -- Try to convert an adjacent tile to ground (prioritize cardinal directions)
  local candidates = {
    {x + 1, y}, -- Right
    {x - 1, y}, -- Left
    {x, y + 1}, -- Down
    {x, y - 1}, -- Up
  }
  
  for _, pos in ipairs(candidates) do
    local nx, ny = pos[1], pos[2]
    if self:isValidGrid(nx, ny) then
      -- Convert to ground tile
      self:setTile(nx, ny, {
        type = MapManager.TileType.GROUND,
        spriteVariant = nil,
        decoration = nil,
      })
      return -- Created at least one accessible tile
    end
  end
end

-- Create a small spawn area (3x3 clearing) at specified coordinates
function MapManager:createSpawnArea(centerX, centerY)
  for dy = -1, 1 do
    for dx = -1, 1 do
      local x = centerX + dx
      local y = centerY + dy
      if self:isValidGrid(x, y) then
        self:setTile(x, y, {
          type = MapManager.TileType.GROUND,
          spriteVariant = nil,
          decoration = nil,
        })
      end
    end
  end
end

-- Convert grid coordinates to world coordinates
function MapManager:gridToWorld(x, y, gridSize, offsetX, offsetY)
  gridSize = gridSize or 64
  offsetX = offsetX or 0
  offsetY = offsetY or 0
  return offsetX + (x - 1) * gridSize + gridSize * 0.5, offsetY + (y - 1) * gridSize + gridSize * 0.5
end

-- Convert world coordinates to grid coordinates
function MapManager:worldToGrid(wx, wy, gridSize, offsetX, offsetY)
  gridSize = gridSize or 64
  offsetX = offsetX or 0
  offsetY = offsetY or 0
  local gx = math.floor((wx - offsetX) / gridSize) + 1
  local gy = math.floor((wy - offsetY) / gridSize) + 1
  return gx, gy
end

-- Get player world position
function MapManager:getPlayerWorldPosition(gridSize, offsetX, offsetY)
  return self:gridToWorld(self.playerGridX, self.playerGridY, gridSize, offsetX, offsetY)
end

-- Check if player can move to grid position
function MapManager:canMoveTo(gridX, gridY)
  if not self:isTraversable(gridX, gridY) then return false end
  if gridX == self.playerGridX and gridY == self.playerGridY then return false end
  
  -- Check if adjacent (4-directional movement)
  local dx = math.abs(gridX - self.playerGridX)
  local dy = math.abs(gridY - self.playerGridY)
  return (dx == 1 and dy == 0) or (dx == 0 and dy == 1)
end

-- Move player to grid position
function MapManager:movePlayerTo(gridX, gridY)
  if self:canMoveTo(gridX, gridY) then
    -- Remember previous position before starting movement (used to return after battle)
    self.previousGridX = self.playerGridX
    self.previousGridY = self.playerGridY
    self.playerTargetGridX = gridX
    self.playerTargetGridY = gridY
    return true
  end
  return false
end

-- Complete movement (called after animation)
function MapManager:completeMovement()
  if self.playerTargetGridX and self.playerTargetGridY then
    self.playerGridX = self.playerTargetGridX
    self.playerGridY = self.playerTargetGridY
    self.playerTargetGridX = nil
    self.playerTargetGridY = nil
    
    -- Check if we're on an enemy tile
    local tile = self:getTile(self.playerGridX, self.playerGridY)
    if tile and tile.type == MapManager.TileType.ENEMY then
      return true -- Signal battle
    end
  end
  return false
end

-- Check if player is moving
function MapManager:isPlayerMoving()
  return self.playerTargetGridX ~= nil
end

-- Get player target world position
function MapManager:getPlayerTargetWorldPosition(gridSize, offsetX, offsetY)
  if self.playerTargetGridX and self.playerTargetGridY then
    return self:gridToWorld(self.playerTargetGridX, self.playerTargetGridY, gridSize, offsetX, offsetY)
  end
  return nil, nil
end

return MapManager
