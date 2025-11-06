local EncounterManager = require("core.EncounterManager")
local MapManager = {}
MapManager.__index = MapManager

-- Tile types
MapManager.TileType = {
  GROUND = "ground",
  TREE = "tree",
  STONE = "stone",
  ENEMY = "enemy",
  REST = "rest",
  TREASURE = "treasure",
  EVENT = "event",
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
    _pendingTreasureX = nil, -- treasure position when moving to protecting enemy
    _pendingTreasureY = nil,
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
    treasure = love.graphics.newImage("assets/images/map/treasure_1.png"),
    event = love.graphics.newImage("assets/images/map/event_1.png"),
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
  return tile.type == MapManager.TileType.GROUND or tile.type == MapManager.TileType.ENEMY or tile.type == MapManager.TileType.REST or tile.type == MapManager.TileType.TREASURE or tile.type == MapManager.TileType.EVENT
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
  
  -- Step 9: Place treasures (some protected by enemies)
  self:placeTreasures()
  
  -- Step 10: Place events (more common than treasures)
  self:placeEvents()
  
  -- Step 11: Final verification - ensure all enemies are accessible
  self:ensureAllEnemiesAccessible()
  
  -- Step 12: Ensure all treasures are protected by enemies
  self:ensureAllTreasuresProtected()
  
  -- Step 13: Final check - ensure newly placed protecting enemies are accessible
  self:ensureAllEnemiesAccessible()
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
  local minRests = gen.minRests or 2
  local maxRests = gen.maxRests or 6
  local minSpacing = (gen.minRestSpacing or 4)
  
  -- Collect all valid rest positions
  local candidatePositions = {}
  for y = 1, self.gridHeight do
    for x = 1, self.gridWidth do
      local tile = self:getTile(x, y)
      if tile and tile.type == MapManager.TileType.GROUND then
        local distFromPlayer = math.abs(x - self.playerGridX) + math.abs(y - self.playerGridY)
        if distFromPlayer >= (gen.minRestDistanceFromPlayer or 5) then
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
  
  local placed = {}
  local targetRestCount = math.min(maxRests, #candidatePositions)
  targetRestCount = math.max(targetRestCount, math.min(minRests, #candidatePositions))
  
  local function tooCloseToOtherRest(x, y)
    for i = 1, #placed do
      local p = placed[i]
      if math.abs(p[1] - x) <= minSpacing and math.abs(p[2] - y) <= minSpacing then
        return true
      end
    end
    return false
  end
  
  for i = 1, #candidatePositions do
    if #placed >= targetRestCount then
      break
    end
    
    local x, y = candidatePositions[i][1], candidatePositions[i][2]
    local tile = self:getTile(x, y)
    
    -- Must be ground and not too close to existing rests
    if tile and tile.type == MapManager.TileType.GROUND then
      if not tooCloseToOtherRest(x, y) then
        -- Place rest
        tile.type = MapManager.TileType.REST
        table.insert(placed, {x, y})
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
    -- But preserve enemy tiles (they're traversable but we don't want to remove them)
    if self:isValidGrid(currentX, currentY) then
      local tile = self:getTile(currentX, currentY)
      if tile and tile.type ~= MapManager.TileType.ENEMY and not self:isTraversable(currentX, currentY) then
        self:setTile(currentX, currentY, {
          type = MapManager.TileType.GROUND,
          spriteVariant = nil,
          decoration = nil,
        })
      end
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
    -- But preserve enemy tiles
    if self:isValidGrid(currentX, currentY) then
      local tile = self:getTile(currentX, currentY)
      if tile and tile.type ~= MapManager.TileType.ENEMY and not self:isTraversable(currentX, currentY) then
        self:setTile(currentX, currentY, {
          type = MapManager.TileType.GROUND,
          spriteVariant = nil,
          decoration = nil,
        })
      end
    end
  end
  
  return true
end

-- Final verification: ensure all enemies on the map are accessible from player start
function MapManager:ensureAllEnemiesAccessible()
  -- Collect all enemy positions on the map
  local allEnemies = {}
  for y = 1, self.gridHeight do
    for x = 1, self.gridWidth do
      local tile = self:getTile(x, y)
      if tile and tile.type == MapManager.TileType.ENEMY then
        table.insert(allEnemies, {x, y})
      end
    end
  end
  
  -- Ensure each enemy is reachable
  for _, enemyPos in ipairs(allEnemies) do
    local ex, ey = enemyPos[1], enemyPos[2]
    if not self:isReachableFromStart(ex, ey) then
      -- Carve a path to make this enemy accessible
      self:ensurePathToPosition(ex, ey)
    end
  end
end

-- Final verification: ensure all treasures are protected by enemies and only accessible through one path
function MapManager:ensureAllTreasuresProtected()
  -- Find all treasures on the map
  for y = 1, self.gridHeight do
    for x = 1, self.gridWidth do
      local tile = self:getTile(x, y)
      if tile and tile.type == MapManager.TileType.TREASURE then
        -- Find all traversable neighbors (potential paths to treasure)
        local neighbors = {
          {x - 1, y}, -- Left
          {x + 1, y}, -- Right
          {x, y - 1}, -- Up
          {x, y + 1}, -- Down
        }
        
        local traversablePaths = {}
        local enemyPath = nil
        
        -- Identify all traversable paths and find which one has an enemy
        for _, neighborPos in ipairs(neighbors) do
          local nx, ny = neighborPos[1], neighborPos[2]
          local neighborTile = self:getTile(nx, ny)
          if neighborTile and self:isTraversable(nx, ny) then
            table.insert(traversablePaths, {x = nx, y = ny, tile = neighborTile})
            if neighborTile.type == MapManager.TileType.ENEMY then
              enemyPath = {x = nx, y = ny, tile = neighborTile}
            end
          end
        end
        
        -- If there are multiple paths, we need to ensure only one path exists (with enemy)
        if #traversablePaths > 1 then
          -- Multiple paths exist - need to block all except one with enemy
          if enemyPath then
            -- We have an enemy on one path - block all other paths
            for _, path in ipairs(traversablePaths) do
              if path.x ~= enemyPath.x or path.y ~= enemyPath.y then
                -- Block this path
                path.tile.type = MapManager.TileType.TREE
                path.tile.decorationVariant = self:random(1, #self.sprites.tree)
                path.tile.decoration = nil
                path.tile.spriteVariant = nil
              end
            end
            tile.protected = true
          else
            -- No enemy found - place one on the first path and block others
            -- Use stored pathTile if available, otherwise use first traversable path
            local pathToUse = nil
            if tile.pathTile and tile.pathTile.x and tile.pathTile.y then
              -- Find the stored path tile in our traversable paths
              for _, path in ipairs(traversablePaths) do
                if path.x == tile.pathTile.x and path.y == tile.pathTile.y then
                  pathToUse = path
                  break
                end
              end
            end
            
            -- If stored path not found or not traversable, use first traversable path
            if not pathToUse and #traversablePaths > 0 then
              pathToUse = traversablePaths[1]
            end
            
            if pathToUse then
              -- Place enemy on chosen path
              pathToUse.tile.type = MapManager.TileType.ENEMY
              pathToUse.tile.decorationVariant = nil
              pathToUse.tile.decoration = nil
              pathToUse.tile.spriteVariant = nil
              
              -- Block all other paths
              for _, path in ipairs(traversablePaths) do
                if path.x ~= pathToUse.x or path.y ~= pathToUse.y then
                  path.tile.type = MapManager.TileType.TREE
                  path.tile.decorationVariant = self:random(1, #self.sprites.tree)
                  path.tile.decoration = nil
                  path.tile.spriteVariant = nil
                end
              end
              
              -- Update stored path tile
              tile.pathTile = {x = pathToUse.x, y = pathToUse.y}
              tile.protected = true
            end
          end
        elseif #traversablePaths == 1 then
          -- Only one path exists - ensure it has an enemy
          local path = traversablePaths[1]
          if path.tile.type ~= MapManager.TileType.ENEMY then
            -- Place enemy on the single path
            path.tile.type = MapManager.TileType.ENEMY
            path.tile.decorationVariant = nil
            path.tile.decoration = nil
            path.tile.spriteVariant = nil
            tile.protected = true
          else
            -- Already has enemy
            tile.protected = true
          end
          
          -- Update stored path tile
          tile.pathTile = {x = path.x, y = path.y}
        else
          -- No traversable paths - treasure is completely blocked (shouldn't happen, but handle it)
          -- This means the treasure is unreachable, which is fine for protection
          tile.protected = true
        end
      end
    end
  end
end

-- Find chokepoint positions (narrow paths with exactly 2 traversable neighbors)
function MapManager:findChokepoints(minDistance)
  minDistance = minDistance or 0
  local chokepoints = {}
  
  for y = 1, self.gridHeight do
    for x = 1, self.gridWidth do
      local tile = self:getTile(x, y)
      if tile and tile.type == MapManager.TileType.GROUND then
        -- Check distance from start position
        local dist = math.abs(x - self.playerGridX) + math.abs(y - self.playerGridY)
        if dist >= minDistance then
          -- Count traversable neighbors (all traversable types)
          local traversableCount = self:countTraversableNeighbors(x, y, false) -- false = count all traversable
          
          -- Chokepoints are tiles with exactly 2 traversable neighbors (narrow passages)
          -- These are natural bottlenecks where enemies would be strategically placed
          if traversableCount == 2 then
            table.insert(chokepoints, {x, y, chokepoint = true})
          end
        end
      end
    end
  end
  
  return chokepoints
end

-- Place enemies on traversable ground tiles and ensure they're all accessible
-- Prioritizes chokepoints (narrow paths) for strategic enemy placement
function MapManager:placeEnemies()
  local config = require("config")
  local genConfig = config.map.generation
  
  -- First, find chokepoint positions (narrow paths - strategic locations)
  local chokepoints = self:findChokepoints(genConfig.minEnemyDistance)
  
  -- Collect all valid enemy positions (traversable ground tiles, far from start)
  local candidatePositions = {}
  for y = 1, self.gridHeight do
    for x = 1, self.gridWidth do
      local tile = self:getTile(x, y)
      if tile and tile.type == MapManager.TileType.GROUND then
        -- Check distance from start position
        local dist = math.abs(x - self.playerGridX) + math.abs(y - self.playerGridY)
        if dist >= genConfig.minEnemyDistance then
          -- Check if this is already a chokepoint (avoid duplicates)
          local isChokepoint = false
          for _, cp in ipairs(chokepoints) do
            if cp[1] == x and cp[2] == y then
              isChokepoint = true
              break
            end
          end
          
          if not isChokepoint then
            table.insert(candidatePositions, {x, y, chokepoint = false})
          end
        end
      end
    end
  end
  
  -- Shuffle both lists separately
  for i = #chokepoints, 2, -1 do
    local j = self:random(1, i)
    chokepoints[i], chokepoints[j] = chokepoints[j], chokepoints[i]
  end
  
  for i = #candidatePositions, 2, -1 do
    local j = self:random(1, i)
    candidatePositions[i], candidatePositions[j] = candidatePositions[j], candidatePositions[i]
  end
  
  -- Combine: chokepoints first, then regular candidates
  local allCandidates = {}
  for _, cp in ipairs(chokepoints) do
    table.insert(allCandidates, cp)
  end
  for _, cand in ipairs(candidatePositions) do
    table.insert(allCandidates, cand)
  end
  
  -- Place enemies with minimum spacing
  local minEnemies = genConfig.minEnemies or 12
  local maxEnemies = genConfig.maxEnemies or 25
  local targetEnemyCount = math.min(
    math.floor(#allCandidates * genConfig.enemyDensity),
    maxEnemies
  )
  -- Ensure we meet minimum if possible
  targetEnemyCount = math.max(targetEnemyCount, math.min(minEnemies, #allCandidates))
  
  local placedEnemies = {}
  local minEnemySpacing = genConfig.minEnemySpacing or 3
  
  for i = 1, #allCandidates do
    if #placedEnemies >= targetEnemyCount then
      break
    end
    
    local x, y = allCandidates[i][1], allCandidates[i][2]
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

-- Count traversable neighbors (4-directional)
-- For treasure placement, we only count GROUND tiles (not REST, ENEMY, TREASURE)
-- This ensures we find true dead-ends with only ground paths
function MapManager:countTraversableNeighbors(x, y, onlyGround)
  onlyGround = onlyGround ~= false -- Default to true for treasure placement
  local count = 0
  local traversableNeighbors = {}
  local neighbors = {
    {x - 1, y}, -- Left
    {x + 1, y}, -- Right
    {x, y - 1}, -- Up
    {x, y + 1}, -- Down
  }
  
  for _, pos in ipairs(neighbors) do
    local nx, ny = pos[1], pos[2]
    local neighborTile = self:getTile(nx, ny)
    if neighborTile then
      local isCountable = false
      if onlyGround then
        -- Only count GROUND tiles
        isCountable = neighborTile.type == MapManager.TileType.GROUND
      else
        -- Count all traversable tiles
        isCountable = self:isTraversable(nx, ny)
      end
      
      if isCountable then
        count = count + 1
        table.insert(traversableNeighbors, {nx, ny})
      end
    end
  end
  
  return count, traversableNeighbors
end

-- Verify that a path tile is the ONLY way to reach a treasure position
-- Returns true if blocking the path tile makes the treasure unreachable (meaning it's the only path)
function MapManager:isPathTileUniqueChokepoint(treasureX, treasureY, pathX, pathY)
  -- Temporarily block the path tile
  local pathTile = self:getTile(pathX, pathY)
  if not pathTile then return false end
  
  local originalType = pathTile.type
  pathTile.type = MapManager.TileType.TREE -- Block it temporarily
  
  -- Check if treasure is still reachable from start
  local stillReachable = self:isReachableFromStart(treasureX, treasureY)
  
  -- Restore original type
  pathTile.type = originalType
  
  -- If NOT reachable when blocked, then this path is the ONLY way (perfect!)
  -- If still reachable, there's another path (not a true dead-end)
  return not stillReachable
end

-- Check if there is any enemy within a given Manhattan distance from (x, y)
function MapManager:hasEnemyWithin(x, y, minSpacing)
  minSpacing = minSpacing or 1
  for ty = 1, self.gridHeight do
    for tx = 1, self.gridWidth do
      local tile = self:getTile(tx, ty)
      if tile and tile.type == MapManager.TileType.ENEMY then
        local dist = math.abs(tx - x) + math.abs(ty - y)
        if dist < minSpacing then
          return true
        end
      end
    end
  end
  return false
end

-- Place treasures on the map, some protected by adjacent enemies
-- Treasures spawn in dead-ends with only one traversable path, with enemy blocking that path
function MapManager:placeTreasures()
  local config = require("config")
  local genConfig = config.map.generation
  
  -- First, find positions that are dead-ends (have exactly one traversable neighbor)
  -- These are ideal for treasure placement as they naturally have only one path
  local deadEndPositions = {}
  for y = 1, self.gridHeight do
    for x = 1, self.gridWidth do
      local tile = self:getTile(x, y)
      if tile and tile.type == MapManager.TileType.GROUND then
        -- Check distance from start position
        local dist = math.abs(x - self.playerGridX) + math.abs(y - self.playerGridY)
        if dist >= (genConfig.minTreasureDistance or 6) then
          -- Count traversable neighbors (only GROUND tiles to find true dead-ends)
          local traversableCount, traversableNeighbors = self:countTraversableNeighbors(x, y, true) -- onlyGround = true
          -- Only consider positions with exactly one traversable neighbor (dead-ends)
          if traversableCount == 1 then
            local pathTile = traversableNeighbors[1]
            -- Verify this path tile is truly the only way to reach this position
            if self:isPathTileUniqueChokepoint(x, y, pathTile[1], pathTile[2]) then
              table.insert(deadEndPositions, {
                x = x,
                y = y,
                pathTile = pathTile -- The single path to this position
              })
            end
          end
        end
      end
    end
  end
  
  -- If we don't have enough dead-ends, try to create them by blocking paths
  -- Find positions with 2 traversable neighbors and convert one to obstacle
  if #deadEndPositions < (genConfig.maxTreasures or 8) then
    local candidatePositions = {}
    for y = 1, self.gridHeight do
      for x = 1, self.gridWidth do
        local tile = self:getTile(x, y)
        if tile and tile.type == MapManager.TileType.GROUND then
          local dist = math.abs(x - self.playerGridX) + math.abs(y - self.playerGridY)
          if dist >= (genConfig.minTreasureDistance or 6) then
            local traversableCount, traversableNeighbors = self:countTraversableNeighbors(x, y, true) -- onlyGround = true
            -- Consider positions with 2 traversable neighbors (only counting GROUND tiles)
            if traversableCount == 2 then
              table.insert(candidatePositions, {
                x = x,
                y = y,
                neighbors = traversableNeighbors
              })
            end
          end
        end
      end
    end
    
    -- Shuffle and try to create dead-ends
    for i = #candidatePositions, 2, -1 do
      local j = self:random(1, i)
      candidatePositions[i], candidatePositions[j] = candidatePositions[j], candidatePositions[i]
    end
    
    for _, candidate in ipairs(candidatePositions) do
      if #deadEndPositions >= (genConfig.maxTreasures or 8) then
        break
      end
      
      -- Pick one neighbor to block (keep the other as the single path)
      local neighborToBlock = candidate.neighbors[self:random(1, 2)]
      local neighborToKeep = candidate.neighbors[1]
      if neighborToBlock == neighborToKeep then
        neighborToKeep = candidate.neighbors[2]
      end
      
      -- Convert the neighbor to a tree/stone obstacle to create dead-end
      local blockTile = self:getTile(neighborToBlock[1], neighborToBlock[2])
      if blockTile and blockTile.type == MapManager.TileType.GROUND then
        -- Temporarily block to check reachability
        blockTile.type = MapManager.TileType.TREE
        blockTile.decorationVariant = self:random(1, #self.sprites.tree)
        
        -- Verify the candidate position is still reachable via the other path
        local stillReachable = self:isReachableFromStart(candidate.x, candidate.y)
        if stillReachable then
          -- Verify that the remaining path tile is truly the only way (chokepoint)
          if self:isPathTileUniqueChokepoint(candidate.x, candidate.y, neighborToKeep[1], neighborToKeep[2]) then
            -- Position is now a true dead-end, add it
            table.insert(deadEndPositions, {
              x = candidate.x,
              y = candidate.y,
              pathTile = neighborToKeep
            })
          else
            -- There's still another path, revert the block
            blockTile.type = MapManager.TileType.GROUND
            blockTile.decorationVariant = nil
          end
        else
          -- Revert the block if it made the position unreachable
          blockTile.type = MapManager.TileType.GROUND
          blockTile.decorationVariant = nil
        end
      end
    end
  end
  
  -- Shuffle dead-end positions
  for i = #deadEndPositions, 2, -1 do
    local j = self:random(1, i)
    deadEndPositions[i], deadEndPositions[j] = deadEndPositions[j], deadEndPositions[i]
  end
  
  -- Place treasures with minimum spacing
  local minTreasures = genConfig.minTreasures or 4
  local maxTreasures = genConfig.maxTreasures or 10
  local treasureCount = math.min(
    #deadEndPositions,
    maxTreasures
  )
  -- Ensure we meet minimum if possible
  treasureCount = math.max(treasureCount, math.min(minTreasures, #deadEndPositions))
  
  local placedTreasures = {}
  local minTreasureSpacing = genConfig.minTreasureSpacing or 4
  local protectionChance = genConfig.treasureProtectionChance or 0.9
  
  for i = 1, #deadEndPositions do
    if #placedTreasures >= treasureCount then
      break
    end
    
    local pos = deadEndPositions[i]
    local x, y = pos.x, pos.y
    local tile = self:getTile(x, y)
    
    if tile and tile.type == MapManager.TileType.GROUND then
      -- Check minimum spacing from other treasures
      local tooClose = false
      if minTreasureSpacing > 0 then
        for _, treasurePos in ipairs(placedTreasures) do
          local tx, ty = treasurePos.x, treasurePos.y
          local dist = math.abs(x - tx) + math.abs(y - ty)
          if dist < minTreasureSpacing then
            tooClose = true
            break
          end
        end
      end
      
      if not tooClose then
        -- Block all adjacent tiles except the path tile to ensure only one opening
        local allNeighbors = {
          {x - 1, y}, -- Left
          {x + 1, y}, -- Right
          {x, y - 1}, -- Up
          {x, y + 1}, -- Down
        }
        
        for _, neighborPos in ipairs(allNeighbors) do
          local nx, ny = neighborPos[1], neighborPos[2]
          -- Skip the path tile - that's the only opening
          if nx ~= pos.pathTile[1] or ny ~= pos.pathTile[2] then
            local neighborTile = self:getTile(nx, ny)
            if neighborTile then
              -- Block traversable adjacent tiles (GROUND, REST) except the path
              -- IMPORTANT: Don't convert ENEMY tiles to trees - preserve chokepoint enemies
              -- If an enemy is already guarding this area, keep it
              if neighborTile.type == MapManager.TileType.GROUND or
                 neighborTile.type == MapManager.TileType.REST then
                neighborTile.type = MapManager.TileType.TREE
                neighborTile.decorationVariant = self:random(1, #self.sprites.tree)
                neighborTile.decoration = nil
                neighborTile.spriteVariant = nil
              end
              -- If it's already an ENEMY, leave it alone - it might be a chokepoint enemy
            end
          end
        end
        
        -- Place treasure
        tile.type = MapManager.TileType.TREASURE
        tile.protected = false
        tile.pathTile = { x = pos.pathTile[1], y = pos.pathTile[2] }
        
        -- Check if this treasure should be protected by an enemy
        if self:randomFloat() < protectionChance then
          -- Place enemy on the single path tile (blocking the only way to treasure)
          local pathX, pathY = pos.pathTile[1], pos.pathTile[2]
          local pathTile = self:getTile(pathX, pathY)
          
          -- If path tile is already an enemy (e.g., from chokepoint placement), mark as protected
          if pathTile and pathTile.type == MapManager.TileType.ENEMY then
            tile.protected = true
          elseif pathTile and pathTile.type == MapManager.TileType.GROUND then
            -- Enforce global enemy spacing
            local minEnemySpacing = (genConfig and genConfig.minEnemySpacing) or 3
            local hasNearbyEnemy = self:hasEnemyWithin(pathX, pathY, minEnemySpacing)
            if not hasNearbyEnemy then
              -- Place protecting enemy on the single path
              pathTile.type = MapManager.TileType.ENEMY
              tile.protected = true
            end
          end
        end
        
        table.insert(placedTreasures, {
          x = x,
          y = y,
          pathX = pos.pathTile[1],
          pathY = pos.pathTile[2],
          protected = tile.protected,
        })
      end
    end
  end
  
  -- Finalize treasure chokepoints and ensure guarding paths remain intact
  for _, treasureInfo in ipairs(placedTreasures) do
    local tx, ty = treasureInfo.x, treasureInfo.y
    local px, py = treasureInfo.pathX, treasureInfo.pathY

    local treasureTile = self:getTile(tx, ty)
    if treasureTile and px and py then
      -- Ensure the guarding path is reachable from player start
      self:ensurePathToPosition(px, py)

      -- Re-apply chokepoint blocking (in case path carving reopened other sides)
      -- IMPORTANT: Preserve existing ENEMY tiles - they might be chokepoint enemies
      local neighbors = {
        {tx - 1, ty},
        {tx + 1, ty},
        {tx, ty - 1},
        {tx, ty + 1},
      }

      for _, neighborPos in ipairs(neighbors) do
        local nx, ny = neighborPos[1], neighborPos[2]
        if not (nx == px and ny == py) then
          local neighborTile = self:getTile(nx, ny)
          if neighborTile then
            -- Block GROUND and REST, but preserve ENEMY tiles (chokepoint enemies)
            if neighborTile.type == MapManager.TileType.GROUND or
               neighborTile.type == MapManager.TileType.REST then
              neighborTile.type = MapManager.TileType.TREE
              neighborTile.decorationVariant = self:random(1, #self.sprites.tree)
              neighborTile.decoration = nil
              neighborTile.spriteVariant = nil
            end
            -- If it's already an ENEMY, leave it alone
          end
        end
      end

      -- Mark the stored path tile for future reference
      treasureTile.pathTile = { x = px, y = py }

      -- Reinstate protecting enemy if applicable
      if treasureInfo.protected then
        local pathTile = self:getTile(px, py)
        if pathTile then
          pathTile.type = MapManager.TileType.ENEMY
          pathTile.decorationVariant = nil
          pathTile.decoration = nil
          pathTile.spriteVariant = nil
        end
      else
        -- Ensure the path tile remains traversable if unprotected
        local pathTile = self:getTile(px, py)
        if pathTile and pathTile.type ~= MapManager.TileType.ENEMY then
          pathTile.type = MapManager.TileType.GROUND
        end
      end
    end
  end
end

-- Check if a treasure is protected by an adjacent enemy
function MapManager:isTreasureProtected(x, y)
  local tile = self:getTile(x, y)
  if not tile or tile.type ~= MapManager.TileType.TREASURE then
    return false
  end
  
  -- Check for adjacent enemies
  local neighbors = {
    {x - 1, y}, -- Left
    {x + 1, y}, -- Right
    {x, y - 1}, -- Up
    {x, y + 1}, -- Down
  }
  
  for _, pos in ipairs(neighbors) do
    local nx, ny = pos[1], pos[2]
    local neighborTile = self:getTile(nx, ny)
    if neighborTile and neighborTile.type == MapManager.TileType.ENEMY then
      return true, nx, ny -- Return true and enemy position
    end
  end
  
  return false
end

-- Place events on the map (more common than treasures, simpler placement)
function MapManager:placeEvents()
  local config = require("config")
  local genConfig = config.map.generation
  
  -- Collect all valid event positions (ground tiles, far from start)
  local candidatePositions = {}
  for y = 1, self.gridHeight do
    for x = 1, self.gridWidth do
      local tile = self:getTile(x, y)
      if tile and tile.type == MapManager.TileType.GROUND then
        -- Check distance from start position
        local dist = math.abs(x - self.playerGridX) + math.abs(y - self.playerGridY)
        if dist >= (genConfig.minEventDistance or 5) then
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
  
  -- Place events with minimum spacing
  local minEvents = genConfig.minEvents or 6
  local maxEvents = genConfig.maxEvents or 15
  local eventCount = math.min(
    math.floor(#candidatePositions * (genConfig.eventDensity or 0.08)),
    maxEvents
  )
  -- Ensure we meet minimum if possible
  eventCount = math.max(eventCount, math.min(minEvents, #candidatePositions))
  
  local placedEvents = {}
  local minEventSpacing = genConfig.minEventSpacing or 5
  
  -- Cache all special tile positions once for efficiency
  if not self._eventPlacementCache then
    self._eventPlacementCache = {
      treasures = {},
      restSites = {},
      enemies = {},
    }
    
    for ty = 1, self.gridHeight do
      for tx = 1, self.gridWidth do
        local checkTile = self:getTile(tx, ty)
        if checkTile then
          if checkTile.type == MapManager.TileType.TREASURE then
            table.insert(self._eventPlacementCache.treasures, {tx, ty})
          elseif checkTile.type == MapManager.TileType.REST then
            table.insert(self._eventPlacementCache.restSites, {tx, ty})
          elseif checkTile.type == MapManager.TileType.ENEMY then
            table.insert(self._eventPlacementCache.enemies, {tx, ty})
          end
        end
      end
    end
  end
  
  for i = 1, #candidatePositions do
    if #placedEvents >= eventCount then
      break
    end
    
    local x, y = candidatePositions[i][1], candidatePositions[i][2]
    local tile = self:getTile(x, y)
    
    if tile and tile.type == MapManager.TileType.GROUND then
      -- Check minimum spacing from other events, treasures, rest sites, and enemies
      local tooClose = false
      if minEventSpacing > 0 then
        -- Check spacing from already placed events
        for _, eventPos in ipairs(placedEvents) do
          local ex, ey = eventPos[1], eventPos[2]
          local dist = math.abs(x - ex) + math.abs(y - ey)
          if dist < minEventSpacing then
            tooClose = true
            break
          end
        end
        
        -- Check spacing from treasures
        if not tooClose then
          for _, treasurePos in ipairs(self._eventPlacementCache.treasures) do
            local tx, ty = treasurePos[1], treasurePos[2]
            local dist = math.abs(x - tx) + math.abs(y - ty)
            if dist < minEventSpacing then
              tooClose = true
              break
            end
          end
        end
        
        -- Check spacing from rest sites (use slightly smaller spacing to allow more flexibility)
        if not tooClose then
          local restSpacing = math.max(2, minEventSpacing - 1)
          for _, restPos in ipairs(self._eventPlacementCache.restSites) do
            local rx, ry = restPos[1], restPos[2]
            local dist = math.abs(x - rx) + math.abs(y - ry)
            if dist < restSpacing then
              tooClose = true
              break
            end
          end
        end
        
        -- Check spacing from enemies (use slightly smaller spacing)
        if not tooClose then
          local enemySpacing = math.max(2, minEventSpacing - 1)
          for _, enemyPos in ipairs(self._eventPlacementCache.enemies) do
            local ex, ey = enemyPos[1], enemyPos[2]
            local dist = math.abs(x - ex) + math.abs(y - ey)
            if dist < enemySpacing then
              tooClose = true
              break
            end
          end
        end
      end
      
      if not tooClose then
        -- Place event
        tile.type = MapManager.TileType.EVENT
        table.insert(placedEvents, {x, y})
      end
    end
  end
  
  -- Ensure all placed events are accessible
  for _, eventPos in ipairs(placedEvents) do
    local ex, ey = eventPos[1], eventPos[2]
    if not self:isReachableFromStart(ex, ey) then
      -- Carve a path to make this event accessible
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
    -- Check if target is a protected treasure - if so, redirect to the protecting enemy
    local targetTile = self:getTile(gridX, gridY)
    if targetTile and targetTile.type == MapManager.TileType.TREASURE then
      local isProtected, enemyX, enemyY = self:isTreasureProtected(gridX, gridY)
      if isProtected and enemyX and enemyY then
        -- Check if the protecting enemy is adjacent to player (valid move target)
        -- If enemy is between player and treasure, redirect to enemy
        -- Otherwise, allow movement to treasure and handle battle when reaching it
        local dxToEnemy = math.abs(enemyX - self.playerGridX)
        local dyToEnemy = math.abs(enemyY - self.playerGridY)
        local canMoveToEnemy = (dxToEnemy == 1 and dyToEnemy == 0) or (dxToEnemy == 0 and dyToEnemy == 1)
        
        if canMoveToEnemy then
          -- Store the treasure position for later collection
          self._pendingTreasureX = gridX
          self._pendingTreasureY = gridY
          -- Redirect movement to the protecting enemy tile
          gridX, gridY = enemyX, enemyY
        else
          -- Enemy is not adjacent to player, allow movement to treasure
          -- Battle will be triggered when player reaches treasure tile
          self._pendingTreasureX = gridX
          self._pendingTreasureY = gridY
        end
      end
    end
    
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
    
    local tile = self:getTile(self.playerGridX, self.playerGridY)
    
    -- Check if we're on an enemy tile
    if tile and tile.type == MapManager.TileType.ENEMY then
      -- Choose an encounter before signaling battle
      local encounterId = EncounterManager.pickRandomEncounterId()
      if encounterId then
        EncounterManager.setEncounterById(encounterId)
      else
        EncounterManager.clearEncounter()
      end
      -- Check if this enemy was protecting a treasure
      if self._pendingTreasureX and self._pendingTreasureY then
        return true, "protected_treasure", self._pendingTreasureX, self._pendingTreasureY
      end
      return true, "enemy" -- Signal battle
    end
    
    -- Check if we're on a treasure tile
    if tile and tile.type == MapManager.TileType.TREASURE then
      -- Collect treasure immediately if player reached it
      -- If enemy was blocking the path, battle would have been triggered earlier
      tile.type = MapManager.TileType.GROUND
      return false, "treasure_collected"
    end
    
    -- Check if we're on an event tile
    if tile and tile.type == MapManager.TileType.EVENT then
      -- Collect event immediately (simpler than treasures - no protection)
      tile.type = MapManager.TileType.GROUND
      return false, "event_collected"
    end
    
    -- Clear pending treasure if movement completed without battle
    self._pendingTreasureX = nil
    self._pendingTreasureY = nil
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
