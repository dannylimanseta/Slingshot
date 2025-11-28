-- SplitSceneInput.lua
-- Handles all input routing for SplitScene (mouse, keyboard, controller)

local config = require("config")
local InputManager = require("managers.InputManager")

local SplitSceneInput = {}

--- Helper function to check if point is within bounds
---@param x number Point X
---@param y number Point Y
---@param b table Bounds {x, y, w, h}
---@return boolean
local function pointInBounds(x, y, b)
  return x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h
end

--- Get screen dimensions and layout info
---@param scene table SplitScene instance
---@return number w, number h, table centerRect, number centerX, table centerBounds
local function getLayoutInfo(scene)
  local w = (config.video and config.video.virtualWidth) or love.graphics.getWidth()
  local h = (config.video and config.video.virtualHeight) or love.graphics.getHeight()
  local centerRect = scene.layoutManager:getCenterRect(w, h)
  local centerX = centerRect.x - 100 -- Shift breakout canvas 100px to the left
  local centerBounds = { x = centerX, y = 0, w = centerRect.w, h = h }
  return w, h, centerRect, centerX, centerBounds
end

--- Handle mouse press events
---@param scene table SplitScene instance
---@param x number Mouse X
---@param y number Mouse Y
---@param button number Mouse button
---@return any result Optional result signal
function SplitSceneInput.mousepressed(scene, x, y, button)
  -- Store mouse position for OrbsUI
  scene._mouseX = x
  scene._mouseY = y
  
  -- Check if orbs UI is open - handle close button click
  if scene._orbsUIOpen and scene.orbsUI then
    if scene.orbsUI:mousepressed(x, y, button) then
      -- Close button was clicked
      scene._orbsUIOpen = false
      scene.orbsUI:setVisible(false)
      return
    end
    -- Don't process other clicks when UI is open
    return
  end
  
  -- Check if clicking on inventory icon in top bar
  if scene.topBar and not scene.topBar.disableInventoryIcon and scene.topBar.inventoryIconBounds then
    local bounds = scene.topBar.inventoryIconBounds
    if x >= bounds.x and x <= bounds.x + bounds.w and y >= bounds.y and y <= bounds.y + bounds.h then
      return "open_inventory"
    end
  end
  
  -- Check if clicking on orbs icon in top bar
  if scene.topBar and scene.topBar.orbsIconBounds then
    local bounds = scene.topBar.orbsIconBounds
    if x >= bounds.x and x <= bounds.x + bounds.w and y >= bounds.y and y <= bounds.y + bounds.h then
      scene._orbsUIOpen = true
      if scene.orbsUI then
        scene.orbsUI:setVisible(true)
      end
      return
    end
  end
  
  local w, h, centerRect, centerX, centerBounds = getLayoutInfo(scene)
  
  if pointInBounds(x, y, centerBounds) and scene.left and scene.left.mousepressed then
    scene.left:mousepressed(x - centerBounds.x, y - centerBounds.y, button, centerBounds)
  elseif scene.right and scene.right.mousepressed then
    -- Forward clicks outside center to battle scene with full-screen bounds
    scene.right:mousepressed(x, y, button, { x = 0, y = 0, w = w, h = h, center = centerRect.center })
  end
end

--- Handle mouse release events
---@param scene table SplitScene instance
---@param x number Mouse X
---@param y number Mouse Y
---@param button number Mouse button
function SplitSceneInput.mousereleased(scene, x, y, button)
  -- Check if orbs UI is open - handle drag and drop
  if scene._orbsUIOpen and scene.orbsUI then
    if scene.orbsUI:mousereleased(x, y, button) then
      -- If orbs were reordered, reload shooter projectiles
      if scene.left and scene.left.shooter and scene.left.shooter.loadProjectiles then
        scene.left.shooter:loadProjectiles()
      end
      return
    end
  end
  
  local w, h, centerRect, centerX, centerBounds = getLayoutInfo(scene)
  
  if pointInBounds(x, y, centerBounds) and scene.left and scene.left.mousereleased then
    scene.left:mousereleased(x - centerBounds.x, y - centerBounds.y, button, centerBounds)
  elseif scene.right and scene.right.mousereleased then
    scene.right:mousereleased(x, y, button, { x = 0, y = 0, w = w, h = h, center = centerRect.center })
  end
end

--- Handle mouse move events
---@param scene table SplitScene instance
---@param x number Mouse X
---@param y number Mouse Y
---@param dx number Delta X
---@param dy number Delta Y
function SplitSceneInput.mousemoved(scene, x, y, dx, dy)
  -- Store mouse position for OrbsUI
  scene._mouseX = x
  scene._mouseY = y
  
  local w, h, centerRect, centerX, centerBounds = getLayoutInfo(scene)
  
  if pointInBounds(x, y, centerBounds) and scene.left and scene.left.mousemoved then
    scene.left:mousemoved(x - centerBounds.x, y - centerBounds.y, dx, dy, centerBounds)
  elseif scene.right and scene.right.mousemoved then
    scene.right:mousemoved(x, y, dx, dy, { x = 0, y = 0, w = w, h = h, center = centerRect.center })
  end
end

--- Handle mouse wheel events
---@param scene table SplitScene instance
---@param x number Wheel X
---@param y number Wheel Y
function SplitSceneInput.wheelmoved(scene, x, y)
  -- Handle scrolling for OrbsUI
  if scene._orbsUIOpen and scene.orbsUI then
    scene.orbsUI:scroll(y)
    return
  end
end

--- Handle keyboard events
---@param scene table SplitScene instance
---@param key string Key pressed
---@param scancode string Scancode
---@param isRepeat boolean Is repeat
---@return any result Optional result signal
function SplitSceneInput.keypressed(scene, key, scancode, isRepeat)
  if key == "p" then
    -- Signal to open formation editor
    return "open_formation_editor"
  elseif key == "escape" then
    -- Return to map (manual exit from battle)
    return "return_to_map"
  end
  
  -- Forward keypress to sub-scenes if needed
  if scene.left and scene.left.keypressed then
    scene.left:keypressed(key, scancode, isRepeat)
  end
  if scene.right and scene.right.keypressed then
    scene.right:keypressed(key, scancode, isRepeat)
  end
end

--- Handle controller/gamepad input via InputManager (called in update)
---@param scene table SplitScene instance
---@param centerRect table Center rectangle from layout manager
---@param h number Screen height
function SplitSceneInput.updateController(scene, centerRect, h)
  -- Map pointer to gameplay (left) local coordinates
  local pointerX, pointerY = InputManager.getPointer()
  local centerX = centerRect.x - 100
  local centerBounds = { x = centerX, y = 0, w = centerRect.w, h = h }
  local inLeft =
    pointerX >= centerBounds.x and pointerX <= centerBounds.x + centerBounds.w and
    pointerY >= centerBounds.y and pointerY <= centerBounds.y + centerBounds.h

  if inLeft and scene.left then
    local lx = pointerX - centerBounds.x
    local ly = pointerY - centerBounds.y
    -- Keep gameplay cursor in sync with controller pointer
    if scene.left.mousemoved then
      scene.left:mousemoved(lx, ly, 0, 0, centerBounds)
    end
    -- Shoot action maps to left mouse press/release
    if InputManager.pressed("shoot") and scene.left.mousepressed then
      scene.left:mousepressed(lx, ly, 1, centerBounds)
    end
    if InputManager.released("shoot") and scene.left.mousereleased then
      scene.left:mousereleased(lx, ly, 1, centerBounds)
    end
  end

  -- Battle target cycling
  if scene.right and InputManager.pressed("next_target") and scene.right._cycleEnemySelection then
    scene.right:_cycleEnemySelection()
  end
end

return SplitSceneInput

