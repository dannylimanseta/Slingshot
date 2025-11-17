local srcRequirePaths = ";src/?.lua;src/?/init.lua;src/?/?.lua"

-- Expand Lua's package path to include `src/` for modules
package.path = package.path .. srcRequirePaths

-- Also update LÖVE's internal require path so packaged builds resolve modules
if love and love.filesystem and love.filesystem.getRequirePath then
  local current = love.filesystem.getRequirePath()
  if not current:find("src/%?%.lua", 1, true) then
    love.filesystem.setRequirePath(current .. ";" .. srcRequirePaths:sub(2))
  end
end

local config = require("config")
local SceneManager = require("core.SceneManager")
local SceneTransitionHandler = require("core.SceneTransitionHandler")
local InputManager = require("managers.InputManager")

local sceneManager
local transitionHandler
local screenCanvas
local virtualW, virtualH
local scaleFactor = 1
local offsetX, offsetY = 0, 0

-- Cursor management
local normalCursor = nil
local battleCursor = nil
local normalCursorImage = nil
local battleCursorImage = nil
local currentCursorImage = nil
local cursorScale = 1.0
local targetCursorScale = 1.0
local mousePressed = false
local cursorTweenSpeed = 20 -- how quickly cursor scale changes

-- Function to set cursor based on scene type
local function setCursorForScene(scene)
  if not scene then return end
  
  -- Check if scene is SplitScene (battle scene)
  local isBattleScene = false
  local sceneType = type(scene)
  if sceneType == "table" then
    -- Check if it's a SplitScene by checking for characteristic properties
    -- SplitScene has 'left' (GameplayScene) and 'right' (BattleScene) properties
    if scene.left or scene.right then
      isBattleScene = true
    end
  end
  
  -- Set InputManager context based on scene
  if isBattleScene then
    InputManager.setContext("battle")
  else
    -- Heuristic: MapScene has a MapManager; otherwise fall back to UI context
    if scene.mapManager then
      InputManager.setContext("map")
    else
      InputManager.setContext("ui")
    end
  end
  
  -- Set appropriate cursor image (for custom drawing)
  if isBattleScene then
    currentCursorImage = battleCursorImage
    -- Also set system cursor (will be hidden but good fallback)
    if battleCursor then
      love.mouse.setCursor(battleCursor)
    end
  else
    currentCursorImage = normalCursorImage
    -- Also set system cursor (will be hidden but good fallback)
    if normalCursor then
      love.mouse.setCursor(normalCursor)
    end
  end
  
  -- Hide system cursor so we can draw our own
  love.mouse.setVisible(false)
end

local function updateScreenScale()
  local winW, winH = love.graphics.getDimensions()
  local sx = winW / virtualW
  local sy = winH / virtualH
  scaleFactor = math.min(sx, sy)
  offsetX = math.floor((winW - virtualW * scaleFactor) * 0.5)
  offsetY = math.floor((winH - virtualH * scaleFactor) * 0.5)
end

function love.load()
  math.randomseed(os.time())

  virtualW = (config.video and config.video.virtualWidth) or 1280
  virtualH = (config.video and config.video.virtualHeight) or 720

  -- Supersampling setup: render at higher resolution for smooth downscaling
  local supersamplingEnabled = config.video and config.video.supersampling and config.video.supersampling.enabled
  local supersamplingFactor = supersamplingEnabled and (config.video.supersampling.factor or 1) or 1

  -- Calculate supersampled canvas size
  local canvasW = virtualW * supersamplingFactor
  local canvasH = virtualH * supersamplingFactor

  screenCanvas = love.graphics.newCanvas(canvasW, canvasH)
  -- Use linear filtering for smooth downscaling from supersampled resolution
  screenCanvas:setFilter('linear', 'linear')
  love.graphics.setDefaultFilter('linear', 'linear', 1)

  -- Store supersampling factor for rendering calculations
  _G.supersamplingFactor = supersamplingFactor

  updateScreenScale()

  -- Load custom cursors
  local normalCursorPath = "assets/images/cursor.png"
  local battleCursorPath = "assets/images/cursor_battle.png"
  
  -- Load normal cursor image (for custom drawing)
  local ok, normalImage = pcall(love.graphics.newImage, normalCursorPath)
  if ok and normalImage then
    normalCursorImage = normalImage
    local hotX = normalImage:getWidth() * 0.5
    local hotY = normalImage:getHeight() * 0.5
    local cursorOk, cursor = pcall(love.mouse.newCursor, normalCursorPath, hotX, hotY)
    if cursorOk and cursor then
      normalCursor = cursor
    end
  end
  
  -- Load battle cursor image (for custom drawing)
  local battleOk, battleImage = pcall(love.graphics.newImage, battleCursorPath)
  if battleOk and battleImage then
    battleCursorImage = battleImage
    local hotX = battleImage:getWidth() * 0.5
    local hotY = battleImage:getHeight() * 0.5
    local cursorOk, cursor = pcall(love.mouse.newCursor, battleCursorPath, hotX, hotY)
    if cursorOk and cursor then
      battleCursor = cursor
    end
  end
  
  -- Set initial cursor
  currentCursorImage = normalCursorImage
  love.mouse.setVisible(false) -- Hide system cursor

  sceneManager = SceneManager.new()
  -- Initialize transition handler with scene manager and cursor setter
  transitionHandler = SceneTransitionHandler.new(sceneManager, setCursorForScene)
  -- Start with map exploration scene
  transitionHandler:initializeMapScene()
end

function love.update(deltaTime)
  -- Update input manager first (for edge detection)
  if InputManager and InputManager.update then
    InputManager.update(deltaTime)
  end
  -- Sync mouse pressed state (handles edge cases like mouse pressed on startup)
  local isMouseDown = love.mouse.isDown(1)
  if isMouseDown ~= mousePressed then
    mousePressed = isMouseDown
    targetCursorScale = isMouseDown and 0.9 or 1.0
  end
  
  -- Update cursor scale tween
  if cursorScale ~= targetCursorScale then
    local diff = targetCursorScale - cursorScale
    cursorScale = cursorScale + diff * math.min(1, cursorTweenSpeed * deltaTime)
    -- Snap to target when very close
    if math.abs(diff) < 0.001 then
      cursorScale = targetCursorScale
    end
  end
  
  if sceneManager then 
    local result = sceneManager:update(deltaTime)
    -- Handle all scene transitions through the centralized handler
    if transitionHandler and result then
      transitionHandler:handleTransition(result)
    end
  end
end

function love.draw()
  -- Draw everything to supersampled canvas
  love.graphics.setCanvas(screenCanvas)
  love.graphics.clear(0, 0, 0, 0)

  -- Apply supersampling transformation: scale up rendering to fill the larger canvas
  local supersamplingFactor = _G.supersamplingFactor or 1
  if supersamplingFactor > 1 then
    love.graphics.push()
    love.graphics.scale(supersamplingFactor, supersamplingFactor)
  end

  -- Render at virtual resolution (gets scaled up by supersampling factor)
  if sceneManager then sceneManager:draw() end

  if supersamplingFactor > 1 then
    love.graphics.pop()
  end

  love.graphics.setCanvas()

  -- Present supersampled canvas scaled down and then up to window size
  love.graphics.setColor(1, 1, 1, 1)
  -- Draw at 1/supersamplingFactor scale first (downscale), then apply window scaleFactor
  love.graphics.draw(screenCanvas, offsetX, offsetY, 0,
    scaleFactor / supersamplingFactor, scaleFactor / supersamplingFactor)
  
  -- Draw custom cursor on top
  if currentCursorImage then
    local mx, my = love.mouse.getPosition()
    local imgW = currentCursorImage:getWidth()
    local imgH = currentCursorImage:getHeight()
    local hotX = imgW * 0.5
    local hotY = imgH * 0.5
    
    -- Scale cursor for retina/high-DPI displays
    -- Use smaller base scale, adjusted by the press-down scale
    local baseScale = 1.0
    local finalScale = baseScale * cursorScale
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(currentCursorImage, mx, my, 0, finalScale, finalScale, hotX, hotY)
  end
  
  love.graphics.setColor(1, 1, 1, 1)
end

function love.resize(width, height)
  updateScreenScale()
  if sceneManager then sceneManager:resize(width, height) end
end

function love.keypressed(key, scancode, isRepeat)
  if InputManager and InputManager.onKeyPressed then
    InputManager.onKeyPressed(key, scancode, isRepeat)
  end
  if sceneManager then 
    local result = sceneManager:keypressed(key, scancode, isRepeat)
    -- Handle all scene transitions through the centralized handler
    if transitionHandler and result then
      transitionHandler:handleTransition(result)
    end
  end
end

function love.keyreleased(key, scancode)
  if InputManager and InputManager.onKeyReleased then
    InputManager.onKeyReleased(key, scancode)
  end
  if sceneManager then sceneManager:keyreleased(key, scancode) end
end

function love.mousepressed(x, y, button, isTouch, presses)
  -- Track mouse press for cursor scaling
  if button == 1 then -- Left mouse button
    mousePressed = true
    targetCursorScale = 0.9 -- 10% smaller
  end
  
  -- Convert screen coordinates to virtual coordinates (reverse of draw scaling)
  local vx = (x - offsetX) / scaleFactor
  local vy = (y - offsetY) / scaleFactor
  if InputManager and InputManager.onMousePressed then
    InputManager.onMousePressed(vx, vy, button, isTouch, presses)
  end
  if sceneManager then
    local result = sceneManager:mousepressed(vx, vy, button, isTouch, presses)
    -- Handle all scene transitions through the centralized handler
    if transitionHandler and result then
      transitionHandler:handleTransition(result)
    end
  end
end

function love.mousereleased(x, y, button, isTouch, presses)
  -- Track mouse release for cursor scaling
  if button == 1 then -- Left mouse button
    mousePressed = false
    targetCursorScale = 1.0 -- Return to normal size
  end
  
  -- Convert screen coordinates to virtual coordinates (reverse of draw scaling)
  local vx = (x - offsetX) / scaleFactor
  local vy = (y - offsetY) / scaleFactor
  if InputManager and InputManager.onMouseReleased then
    InputManager.onMouseReleased(vx, vy, button, isTouch, presses)
  end
  if sceneManager then
    local result = sceneManager:mousereleased(vx, vy, button, isTouch, presses)
    if transitionHandler and result then
      transitionHandler:handleTransition(result)
    end
  end
end

function love.mousemoved(x, y, dx, dy, isTouch)
  -- Convert screen coordinates to virtual coordinates (reverse of draw scaling)
  local vx = (x - offsetX) / scaleFactor
  local vy = (y - offsetY) / scaleFactor
  local vdx = dx / scaleFactor
  local vdy = dy / scaleFactor
  if InputManager and InputManager.onMouseMoved then
    InputManager.onMouseMoved(vx, vy, vdx, vdy, isTouch)
  end
  if sceneManager then sceneManager:mousemoved(vx, vy, vdx, vdy, isTouch) end
end

function love.wheelmoved(dx, dy)
  if InputManager and InputManager.onWheelMoved then
    InputManager.onWheelMoved(dx, dy)
  end
  if sceneManager then sceneManager:wheelmoved(dx, dy) end
end

-- Gamepad support: forward to InputManager (scenes do not consume these directly yet)
function love.gamepadpressed(joystick, button)
  if InputManager and InputManager.onGamepadPressed then
    InputManager.onGamepadPressed(joystick, button)
  end
end

function love.gamepadreleased(joystick, button)
  if InputManager and InputManager.onGamepadReleased then
    InputManager.onGamepadReleased(joystick, button)
  end
end

function love.gamepadaxis(joystick, axis, value)
  if InputManager and InputManager.onGamepadAxis then
    InputManager.onGamepadAxis(joystick, axis, value)
  end
end


