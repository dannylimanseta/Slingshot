local config = require("config")
local Block = require("entities.Block")

local BlockManager = {}
BlockManager.__index = BlockManager

function BlockManager.new()
  return setmetatable({ 
    blocks = {},
    soulBlockSpawned = false, -- Track if soul block has been spawned this battle
    firstClusterCenter = nil, -- Store center of first large cluster for soul block placement
  }, BlockManager)
end

local function aabbOverlap(ax, ay, aw, ah, bx, by, bw, bh)
  return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
end

-- Create a simple spatial hash to speed up overlap checks
local function createSpatialHash(cellSize)
  local grid = {}
  local function cellIndex(v)
    if v == nil or v ~= v then return 0 end
    return math.floor(v / math.max(1, cellSize))
  end
  local function key(ix, iy) return tostring(ix) .. "," .. tostring(iy) end

  local function addToGrid(block)
    local x, y, w, h
    if type(block.getPlacementAABB) == "function" then
      x, y, w, h = block:getPlacementAABB()
    end
    if type(x) ~= "number" or type(y) ~= "number" or type(w) ~= "number" or type(h) ~= "number" then
      if type(block.getAABB) == "function" then
        x, y, w, h = block:getAABB()
      end
    end
    if type(x) ~= "number" or type(y) ~= "number" or type(w) ~= "number" or type(h) ~= "number" then
      return
    end
    local ix0, iy0 = cellIndex(x), cellIndex(y)
    local ix1, iy1 = cellIndex(x + w), cellIndex(y + h)
    for ix = ix0, ix1 do
      for iy = iy0, iy1 do
        local k = key(ix, iy)
        grid[k] = grid[k] or {}
        table.insert(grid[k], block)
      end
    end
  end

  local function forNearby(x, y, w, h, fn)
    local ix0, iy0 = cellIndex(x), cellIndex(y)
    local ix1, iy1 = cellIndex(x + w), cellIndex(y + h)
    for ix = ix0, ix1 do
      for iy = iy0, iy1 do
        local k = key(ix, iy)
        local list = grid[k]
        if list then
          for i = 1, #list do
            if fn(list[i]) == false then return false end
          end
        end
      end
    end
    return true
  end

  return grid, addToGrid, forNearby
end

local function expandedOverlap(ax, ay, aw, ah, bx, by, bw, bh, gap)
  -- Expand existing rect by gap to create spacing
  return aabbOverlap(ax, ay, aw, ah, bx - gap, by - gap, bw + 2 * gap, bh + 2 * gap)
end

-- Generate cluster layout offsets for a given cluster size
-- Returns: {rows, cols, offsets} where offsets is array of {x, y} relative to top-left of cluster
local function generateClusterLayout(size)
  local rows, cols
  if size == 9 then
    rows, cols = 3, 3
  elseif size == 12 then
    -- Randomly choose 3x4 or 4x3
    if love.math.random() < 0.5 then
      rows, cols = 3, 4
    else
      rows, cols = 4, 3
    end
  else
    -- Default to square-ish layout for unknown sizes
    rows = math.ceil(math.sqrt(size))
    cols = math.ceil(size / rows)
  end
  
  local offsets = {}
  local index = 0
  for row = 0, rows - 1 do
    for col = 0, cols - 1 do
      if index < size then
        table.insert(offsets, {col = col, row = row})
        index = index + 1
      end
    end
  end
  
  return rows, cols, offsets
end

-- Try to place a cluster of blocks
-- Returns: {blocks = array, centerX = number, centerY = number} if successful, nil if failed
local function tryPlaceCluster(world, width, height, clusterSize, forNearby, addToGrid, margin, visSize, pad, maxFrac, animateSpawn, getSpawnDelay)
  animateSpawn = animateSpawn or false
  getSpawnDelay = getSpawnDelay or function() return 0 end
  local rows, cols, offsets = generateClusterLayout(clusterSize)
  local clusterAttempts = (config.blocks.clustering and config.blocks.clustering.clusterAttempts) or 12
  
  for attempt = 1, clusterAttempts do
    -- Calculate cluster bounds
    local clusterWidth = cols * visSize + (cols - 1) * pad
    local clusterHeight = rows * visSize + (rows - 1) * pad
    local halfW = clusterWidth * 0.5
    local halfH = clusterHeight * 0.5
    
    -- Pick cluster center (top-left corner of cluster)
    local clusterX = love.math.random(margin, math.max(margin, width - margin - clusterWidth))
    local maxY = math.max(margin, height * maxFrac - clusterHeight)
    local clusterY = love.math.random(margin, maxY)
    
    -- Check if entire cluster fits without overlap
    local canPlace = true
    for _, offset in ipairs(offsets) do
      local blockX = clusterX + offset.col * (visSize + pad)
      local blockY = clusterY + offset.row * (visSize + pad)
      local blockHalfVis = visSize * 0.5
      local blockCx = blockX + blockHalfVis
      local blockCy = blockY + blockHalfVis
      
      -- Check overlap with existing blocks
      forNearby(blockX - pad, blockY - pad, visSize + 2 * pad, visSize + 2 * pad, function(b)
        if not b then return true end
        local bx, by, bw, bh
        if type(b.getPlacementAABB) == "function" then
          bx, by, bw, bh = b:getPlacementAABB()
        end
        if type(bx) ~= "number" or type(by) ~= "number" or type(bw) ~= "number" or type(bh) ~= "number" then
          if type(b.getAABB) == "function" then
            bx, by, bw, bh = b:getAABB()
          end
        end
        if type(bx) ~= "number" or type(by) ~= "number" or type(bw) ~= "number" or type(bh) ~= "number" then
          return true
        end
        if expandedOverlap(blockX, blockY, visSize, visSize, bx, by, bw, bh, pad) then
          canPlace = false
          return false
        end
        return true
      end)
      
      if not canPlace then break end
    end
    
    -- If cluster fits, place all blocks
    if canPlace then
      local clusterBlocks = {}
      for _, offset in ipairs(offsets) do
        local blockX = clusterX + offset.col * (visSize + pad)
        local blockY = clusterY + offset.row * (visSize + pad)
        local blockHalfVis = visSize * 0.5
        local blockCx = blockX + blockHalfVis
        local blockCy = blockY + blockHalfVis
        
        -- Determine block kind (preserve ratios)
        local hp = 1
        local kind
        do
          local r = love.math.random()
          local critR = math.max(0, math.min(1, (config.blocks and config.blocks.critSpawnRatio) or 0))
          local armorR = math.max(0, math.min(1, (config.blocks and config.blocks.armorSpawnRatio) or 0))
          if r < critR then
            kind = "crit"
          elseif r < critR + armorR then
            kind = "armor"
          else
            kind = "damage"
          end
        end
        
        local spawnDelay = getSpawnDelay()
        local block = Block.new(world, blockCx, blockCy, hp, kind, { animateSpawn = animateSpawn, spawnDelay = spawnDelay })
        table.insert(clusterBlocks, block)
        addToGrid(block)
      end
      -- Calculate cluster center (geometric center of the cluster grid)
      local clusterCenterX = clusterX + clusterWidth * 0.5
      local clusterCenterY = clusterY + clusterHeight * 0.5
      return {blocks = clusterBlocks, centerX = clusterCenterX, centerY = clusterCenterY}
    end
  end
  
  return nil -- Failed to place cluster
end

-- Place a single block (fallback when clustering fails or disabled)
local function placeSingleBlock(world, width, height, forNearby, addToGrid, margin, visSize, pad, attemptsPerBlock, maxFrac, animateSpawn, getSpawnDelay)
  animateSpawn = animateSpawn or false
  getSpawnDelay = getSpawnDelay or function() return 0 end
  for attempt = 1, attemptsPerBlock do
    local hp = 1
    local kind
    do
      local r = love.math.random()
      local critR = math.max(0, math.min(1, (config.blocks and config.blocks.critSpawnRatio) or 0))
      local armorR = math.max(0, math.min(1, (config.blocks and config.blocks.armorSpawnRatio) or 0))
      if r < critR then
        kind = "crit"
      elseif r < critR + armorR then
        kind = "armor"
      else
        kind = "damage"
      end
    end

    local halfVis = visSize * 0.5
    local cx = love.math.random(margin + halfVis, math.max(margin + halfVis, width - margin - halfVis))
    local maxY = math.max(margin + halfVis, height * maxFrac - halfVis)
    local cy = love.math.random(margin + halfVis, maxY)
    local x = cx - halfVis
    local y = cy - halfVis

    local overlap = false
    forNearby(x - pad, y - pad, visSize + 2 * pad, visSize + 2 * pad, function(b)
      if not b then return true end
      local bx, by, bw, bh
      if type(b.getPlacementAABB) == "function" then
        bx, by, bw, bh = b:getPlacementAABB()
      end
      if type(bx) ~= "number" or type(by) ~= "number" or type(bw) ~= "number" or type(bh) ~= "number" then
        if type(b.getAABB) == "function" then
          bx, by, bw, bh = b:getAABB()
        end
      end
      if type(bx) ~= "number" or type(by) ~= "number" or type(bw) ~= "number" or type(bh) ~= "number" then
        return true
      end
      if expandedOverlap(x, y, visSize, visSize, bx, by, bw, bh, pad) then
        overlap = true
        return false
      end
      return true
    end)

    if not overlap then
      local spawnDelay = getSpawnDelay()
      local block = Block.new(world, cx, cy, hp, kind, { animateSpawn = animateSpawn, spawnDelay = spawnDelay })
      addToGrid(block)
      return block
    end
  end
  return nil
end

function BlockManager:randomize(world, width, height)
  self.blocks = {}
  self.firstClusterCenter = nil  -- Reset cluster center tracking
  local margin = config.playfield.margin
  local attemptsPerBlock = config.blocks.attemptsPerBlock
  local pad = (config.blocks and config.blocks.minGap) or 0
  local scaleMul = math.max(1, (config.blocks and config.blocks.spriteScale) or 1)

  local cellSize = config.blocks.baseSize * scaleMul + pad
  local grid, addToGrid, forNearby = createSpatialHash(cellSize)

  local size = config.blocks.baseSize
  local visSize = size * scaleMul
  local maxFrac = 0.6
  
  local clusteringEnabled = (config.blocks.clustering and config.blocks.clustering.enabled) or false
  local clusterSizes = (config.blocks.clustering and config.blocks.clustering.clusterSizes) or {9, 12}
  local minRemainingForCluster = (config.blocks.clustering and config.blocks.clustering.minRemainingForCluster) or 9

  local remaining = config.blocks.count
  local staggerDelay = (config.blocks.spawnAnim and config.blocks.spawnAnim.staggerDelay) or 0.03
  local blockIndex = 0
  
  -- Helper to get next spawn delay for staggering
  local function getNextSpawnDelay()
    local delay = blockIndex * staggerDelay
    blockIndex = blockIndex + 1
    return delay
  end

  -- Try to place clusters if enabled
  if clusteringEnabled then
    while remaining >= minRemainingForCluster do
      -- Choose a cluster size that fits within remaining blocks
      local validSizes = {}
      for _, cs in ipairs(clusterSizes) do
        if cs <= remaining then
          table.insert(validSizes, cs)
        end
      end
      
      if #validSizes == 0 then break end
      
      local clusterSize = validSizes[love.math.random(#validSizes)]
      local clusterResult = tryPlaceCluster(world, width, height, clusterSize, forNearby, addToGrid, margin, visSize, pad, maxFrac, true, getNextSpawnDelay)
      
      if clusterResult and clusterResult.blocks then
        for _, block in ipairs(clusterResult.blocks) do
          table.insert(self.blocks, block)
        end
        -- Store center of first large cluster for soul block placement
        if not self.firstClusterCenter and clusterResult.centerX and clusterResult.centerY then
          self.firstClusterCenter = {x = clusterResult.centerX, y = clusterResult.centerY}
        end
        remaining = remaining - clusterSize
      else
        -- Cluster placement failed, fall back to individual blocks
        break
      end
    end
  end

  -- Place remaining blocks individually
  for _ = 1, remaining do
    local block = placeSingleBlock(world, width, height, forNearby, addToGrid, margin, visSize, pad, attemptsPerBlock, maxFrac, true, getNextSpawnDelay)
    if block then
      table.insert(self.blocks, block)
    end
  end
  
  -- Spawn soul block in innermost spot of largest cluster (only once per battle)
  if not self.soulBlockSpawned then
    local soulBlock = self:spawnSoulBlock(world)
    if soulBlock then
      self.soulBlockSpawned = true
    end
  end
end

-- Spawn a number of new blocks without overlapping existing ones; returns the new blocks list
function BlockManager:addRandomBlocks(world, width, height, count)
  if not count or count <= 0 then return {} end
  local margin = config.playfield.margin
  local attemptsPerBlock = config.blocks.attemptsPerBlock
  local pad = (config.blocks and config.blocks.minGap) or 0
  local scaleMul = math.max(1, (config.blocks and config.blocks.spriteScale) or 1)

  local cellSize = config.blocks.baseSize * scaleMul + pad
  local grid, addToGrid, forNearby = createSpatialHash(cellSize)

  -- Seed spatial hash with currently alive blocks
  for _, b in ipairs(self.blocks) do
    if b and b.alive then addToGrid(b) end
  end

  local size = config.blocks.baseSize
  local visSize = size * scaleMul
  local maxFrac = 0.6
  
  local clusteringEnabled = (config.blocks.clustering and config.blocks.clustering.enabled) or false
  local clusterSizes = (config.blocks.clustering and config.blocks.clustering.clusterSizes) or {9, 12}
  local minRemainingForCluster = (config.blocks.clustering and config.blocks.clustering.minRemainingForCluster) or 9

  local newBlocks = {}
  local remaining = count

  -- Try to place clusters if enabled
  if clusteringEnabled then
    while remaining >= minRemainingForCluster do
      -- Choose a cluster size that fits within remaining blocks
      local validSizes = {}
      for _, cs in ipairs(clusterSizes) do
        if cs <= remaining then
          table.insert(validSizes, cs)
        end
      end
      
      if #validSizes == 0 then break end
      
      local clusterSize = validSizes[love.math.random(#validSizes)]
      local clusterBlocks = tryPlaceCluster(world, width, height, clusterSize, forNearby, addToGrid, margin, visSize, pad, maxFrac, true)
      
      if clusterBlocks then
        for _, block in ipairs(clusterBlocks) do
          table.insert(self.blocks, block)
          table.insert(newBlocks, block)
        end
        remaining = remaining - clusterSize
      else
        -- Cluster placement failed, fall back to individual blocks
        break
      end
    end
  end

  -- Place remaining blocks individually
  for _ = 1, remaining do
    local block = placeSingleBlock(world, width, height, forNearby, addToGrid, margin, visSize, pad, attemptsPerBlock, maxFrac, true)
    if block then
      table.insert(self.blocks, block)
      table.insert(newBlocks, block)
    end
  end

  return newBlocks
end

function BlockManager:aliveBlocks()
  local out = {}
  for _, b in ipairs(self.blocks) do
    if b.alive then table.insert(out, b) end
  end
  return out
end

-- Find clusters of blocks (groups of adjacent blocks) using flood fill
-- Returns array of clusters, where each cluster is an array of blocks
local function findClusters(blocks, pad)
  pad = pad or 0
  local visited = {}
  local clusters = {}
  
  -- Helper to check if two blocks are adjacent (overlapping or touching)
  local function areAdjacent(a, b)
    if a == b then return false end
    local ax, ay, aw, ah = a:getPlacementAABB()
    local bx, by, bw, bh = b:getPlacementAABB()
    -- Check if blocks overlap or are within pad distance (accounting for gaps)
    -- Expand each block's bounds by pad to account for spacing between blocks in clusters
    local margin = pad * 1.1  -- Slightly more than pad to ensure blocks spaced by pad are detected
    return aabbOverlap(ax - margin, ay - margin, aw + 2 * margin, ah + 2 * margin, 
                       bx - margin, by - margin, bw + 2 * margin, bh + 2 * margin)
  end
  
  -- Flood fill to find connected components
  for i, block in ipairs(blocks) do
    if not visited[i] and block.alive then
      local cluster = {}
      local queue = {i}
      visited[i] = true
      
      while #queue > 0 do
        local idx = table.remove(queue, 1)
        local current = blocks[idx]
        table.insert(cluster, current)
        
        -- Check all other blocks for adjacency
        for j, other in ipairs(blocks) do
          if not visited[j] and other.alive and areAdjacent(current, other) then
            visited[j] = true
            table.insert(queue, j)
          end
        end
      end
      
      if #cluster > 0 then
        table.insert(clusters, cluster)
      end
    end
  end
  
  return clusters
end

-- Find the innermost block in a cluster (closest to cluster center)
local function findInnermostBlock(cluster)
  if #cluster == 0 then return nil end
  if #cluster == 1 then return cluster[1] end
  
  -- Calculate cluster center
  local sumX, sumY = 0, 0
  for _, block in ipairs(cluster) do
    local cx, cy = block.cx, block.cy
    sumX = sumX + cx
    sumY = sumY + cy
  end
  local centerX = sumX / #cluster
  local centerY = sumY / #cluster
  
  -- Find block closest to center
  local innermost = nil
  local minDist = math.huge
  for _, block in ipairs(cluster) do
    local dx = block.cx - centerX
    local dy = block.cy - centerY
    local dist = dx * dx + dy * dy
    if dist < minDist then
      minDist = dist
      innermost = block
    end
  end
  
  return innermost
end

-- Helper: Check if a position overlaps with existing blocks
local function checkOverlap(cx, cy, existingBlocks, pad, visSize)
  local halfVis = visSize * 0.5
  local sx = cx - halfVis
  local sy = cy - halfVis
  
  for _, block in ipairs(existingBlocks) do
    if block and block.alive then
      local bx, by, bw, bh = block:getPlacementAABB()
      if bx and by and bw and bh then
        if expandedOverlap(sx, sy, visSize, visSize, bx, by, bw, bh, pad) then
          return true, block
        end
      end
    end
  end
  return false, nil
end

-- Spawn a soul block at the center of the largest cluster
-- Returns the soul block if placed, nil otherwise
function BlockManager:spawnSoulBlock(world)
  local alive = self:aliveBlocks()
  if #alive == 0 then return nil end
  
  local pad = (config.blocks and config.blocks.minGap) or 0
  local scaleMul = math.max(1, (config.blocks and config.blocks.spriteScale) or 1)
  local size = config.blocks.baseSize
  local visSize = size * scaleMul
  
  -- Use stored cluster center if available (most reliable, calculated during placement)
  local centerX, centerY = nil, nil
  if self.firstClusterCenter and self.firstClusterCenter.x and self.firstClusterCenter.y then
    centerX = self.firstClusterCenter.x
    centerY = self.firstClusterCenter.y
  else
    -- Fallback: detect clusters and calculate center
    local clusters = findClusters(alive, pad)
    
    if #clusters == 0 then return nil end
    
    -- Find largest cluster
    local largestCluster = nil
    local largestSize = 0
    for _, cluster in ipairs(clusters) do
      if #cluster > largestSize then
        largestSize = #cluster
        largestCluster = cluster
      end
    end
    
    if not largestCluster or #largestCluster == 0 then return nil end
    
    -- Calculate the geometric center of the cluster using AABB bounds
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    
    for _, block in ipairs(largestCluster) do
      if block and block.alive then
        local bx, by, bw, bh = block:getPlacementAABB()
        if bx and by and bw and bh then
          minX = math.min(minX, bx)
          minY = math.min(minY, by)
          maxX = math.max(maxX, bx + bw)
          maxY = math.max(maxY, by + bh)
        end
      end
    end
    
    -- If we couldn't calculate bounds, fall back to averaging block centers
    if minX == math.huge or minY == math.huge then
      local sumX, sumY = 0, 0
      local count = 0
      for _, block in ipairs(largestCluster) do
        if block and block.alive and block.cx and block.cy then
          sumX = sumX + block.cx
          sumY = sumY + block.cy
          count = count + 1
        end
      end
      if count == 0 then return nil end
      centerX = sumX / count
      centerY = sumY / count
    else
      -- Calculate center from AABB bounds
      centerX = (minX + maxX) * 0.5
      centerY = (minY + maxY) * 0.5
    end
  end
  
  if not centerX or not centerY then return nil end
  
  -- Check if center position overlaps with existing blocks
  local overlaps, overlappingBlock = checkOverlap(centerX, centerY, alive, pad, visSize)
  
  if overlaps then
    -- If center overlaps, find the innermost block (closest to center) and replace it
    local closestBlock = nil
    local minDist = math.huge
    
    -- Find block closest to center
    for _, block in ipairs(alive) do
      if block and block.alive and block.cx and block.cy then
        local dx = block.cx - centerX
        local dy = block.cy - centerY
        local dist = dx * dx + dy * dy
        if dist < minDist then
          minDist = dist
          closestBlock = block
        end
      end
    end
    
    if closestBlock then
      -- Replace the closest block with soul block at its position
      local oldIndex = nil
      for i, b in ipairs(self.blocks) do
        if b == closestBlock then
          oldIndex = i
          break
        end
      end
      
      closestBlock:destroy()
      local soulBlock = Block.new(world, closestBlock.cx, closestBlock.cy, 1, "soul", { animateSpawn = true, spawnDelay = 0 })
      
      if oldIndex then
        self.blocks[oldIndex] = soulBlock
      else
        table.insert(self.blocks, soulBlock)
      end
      
      return soulBlock
    end
  end
  
  -- Center position is clear, place soul block there
  local soulBlock = Block.new(world, centerX, centerY, 1, "soul", { animateSpawn = true, spawnDelay = 0 })
  table.insert(self.blocks, soulBlock)
  
  return soulBlock
end

function BlockManager:draw()
  for _, b in ipairs(self.blocks) do b:draw() end
end

function BlockManager:update(dt)
  for _, b in ipairs(self.blocks) do
    if b.update then b:update(dt) end
  end
end

return BlockManager


