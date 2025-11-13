-- PhysicsManager: Handles Box2D world, collision callbacks, and wall management
-- Extracted from GameplayScene to improve maintainability

local config = require("config")
local playfield = require("utils.playfield")

local PhysicsManager = {}
PhysicsManager.__index = PhysicsManager

function PhysicsManager.new(bounds)
  local self = setmetatable({
    world = nil,
    wallBody = nil,
    wallFixtures = {},
    gridStartX = 0,
    gridEndX = 0,
    -- Collision callbacks (set by parent scene)
    onBeginContact = nil,
    onPreSolve = nil,
    onPostSolve = nil,
  }, PhysicsManager)
  
  self:initialize(bounds)
  return self
end

function PhysicsManager:initialize(bounds)
  local width = (bounds and bounds.w) or love.graphics.getWidth()
  local height = (bounds and bounds.h) or love.graphics.getHeight()
  
  -- Create physics world
  self.world = love.physics.newWorld(0, 0, true)
  
  -- Set collision callbacks (will forward to parent scene)
  self.world:setCallbacks(
    function(a, b, contact) self:_beginContact(a, b, contact) end,
    function(a, b, contact) self:_preSolve(a, b, contact) end,
    function(a, b, contact) self:_postSolve(a, b, contact) end,
    nil
  )
  
  -- Create walls
  self:createWalls(width, height)
end

function PhysicsManager:createWalls(width, height)
  -- Calculate grid bounds to match editor exactly
  local gridStartX, gridEndX = playfield.calculateGridBounds(width, height)
  self.gridStartX = gridStartX
  self.gridEndX = gridEndX
  
  -- Create wall body (static)
  local topBarHeight = (config.playfield and config.playfield.topBarHeight) or 60
  self.wallBody = love.physics.newBody(self.world, 0, 0, "static")
  
  -- Create wall shapes
  local left = love.physics.newEdgeShape(gridStartX, topBarHeight, gridStartX, height)
  local right = love.physics.newEdgeShape(gridEndX, topBarHeight, gridEndX, height)
  local top = love.physics.newEdgeShape(gridStartX, topBarHeight, gridEndX, topBarHeight)
  local bottomSensor = love.physics.newEdgeShape(gridStartX, height, gridEndX, height)
  
  -- Create fixtures
  local fL = love.physics.newFixture(self.wallBody, left)
  local fR = love.physics.newFixture(self.wallBody, right)
  local fT = love.physics.newFixture(self.wallBody, top)
  local fB = love.physics.newFixture(self.wallBody, bottomSensor)
  
  -- Set fixture data
  fL:setUserData({ type = "wall", side = "left" })
  fR:setUserData({ type = "wall", side = "right" })
  fT:setUserData({ type = "wall" })
  fB:setUserData({ type = "bottom" })
  fB:setSensor(true)
  
  -- Store fixtures
  self.wallFixtures = { left = fL, right = fR, top = fT, bottom = fB }
end

function PhysicsManager:updateWalls(width, height)
  -- Destroy old wall fixtures
  if self.wallFixtures then
    for _, fixture in pairs(self.wallFixtures) do
      if fixture and fixture.destroy then
        pcall(function() fixture:destroy() end)
      end
    end
  end
  
  -- Recreate walls with new dimensions
  self:createWalls(width, height)
end

function PhysicsManager:update(dt)
  if self.world then
    self.world:update(dt)
  end
end

function PhysicsManager:getWorld()
  return self.world
end

function PhysicsManager:getGridBounds()
  return self.gridStartX, self.gridEndX
end

-- Collision callback forwarders (internal)
function PhysicsManager:_beginContact(a, b, contact)
  if self.onBeginContact then
    self.onBeginContact(a, b, contact)
  end
end

function PhysicsManager:_preSolve(a, b, contact)
  if self.onPreSolve then
    self.onPreSolve(a, b, contact)
  end
end

function PhysicsManager:_postSolve(a, b, contact)
  if self.onPostSolve then
    self.onPostSolve(a, b, contact)
  end
end

-- Cleanup
function PhysicsManager:unload()
  -- Destroy wall fixtures
  if self.wallFixtures then
    for _, fixture in pairs(self.wallFixtures) do
      if fixture and fixture.destroy then
        pcall(function() fixture:destroy() end)
      end
    end
    self.wallFixtures = nil
  end
  
  -- Destroy wall body
  if self.wallBody and self.wallBody.destroy then
    pcall(function() self.wallBody:destroy() end)
    self.wallBody = nil
  end
  
  -- Clear world callbacks
  if self.world then
    self.world:setCallbacks(nil, nil, nil, nil)
    self.world = nil
  end
end

return PhysicsManager

