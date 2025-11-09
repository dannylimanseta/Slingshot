-- Expand Lua's package path to include `src/` for modules
package.path = package.path .. ";src/?.lua;src/?/init.lua;src/?/?.lua"

local config = require("config")
local SceneManager = require("core.SceneManager")
local MapScene = require("scenes.MapScene")
local SplitScene = require("scenes.SplitScene")
local FormationEditorScene = require("scenes.FormationEditorScene")
local RewardsScene = require("scenes.RewardsScene")
local OrbRewardScene = require("scenes.OrbRewardScene")
local EncounterSelectScene = require("scenes.EncounterSelectScene")

local sceneManager
local screenCanvas
local virtualW, virtualH
local scaleFactor = 1
local offsetX, offsetY = 0, 0
local previousScene = nil -- Store previous scene when switching to formation editor
local mapScene = nil -- Store map scene to return to after battle

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
  -- Start with map exploration scene
  mapScene = MapScene.new()
  sceneManager:set(mapScene)
  setCursorForScene(mapScene)
end

function love.update(deltaTime)
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
    
    -- Handle battle transition signal from MapScene
    if result == "enter_battle" then
      -- Store map scene as previous scene
      previousScene = mapScene
      -- Switch to battle (SplitScene)
      local battleScene = SplitScene.new()
      sceneManager:set(battleScene)
      setCursorForScene(battleScene)
    elseif type(result) == "table" and result.type == "return_to_map" then
      -- Post-battle flow
      if result.victory then
        -- Mark victory on map for any follow-up logic
        if not mapScene then
          mapScene = MapScene.new()
        end
        mapScene._battleVictory = true
        -- Show rewards scene before returning to map (pass gold reward if available)
        local rewardsScene = RewardsScene.new({ goldReward = result.goldReward or 0 })
        sceneManager:set(rewardsScene)
        setCursorForScene(rewardsScene)
      else
        -- Defeat: go straight back to map
        if mapScene then
          sceneManager:set(mapScene)
          setCursorForScene(mapScene)
          previousScene = nil
        else
          mapScene = MapScene.new()
          sceneManager:set(mapScene)
          setCursorForScene(mapScene)
        end
      end
    elseif result == "return_to_map" then
      -- Backward compatibility: handle string return
      if mapScene then
        sceneManager:set(mapScene)
        setCursorForScene(mapScene)
        previousScene = nil
      else
        mapScene = MapScene.new()
        sceneManager:set(mapScene)
        setCursorForScene(mapScene)
      end
    elseif type(result) == "table" and result.type == "open_orb_reward" then
      -- If RewardsScene indicates pending actions remain, remember it to return after orb pick
      if result.returnToRewards then
        previousScene = sceneManager.currentScene
        if previousScene then previousScene._removeOrbButtonOnReturn = true end
      end
      local orbScene = OrbRewardScene.new({ returnToPreviousOnExit = result.returnToRewards, shaderTime = result.shaderTime })
      sceneManager:set(orbScene, true)
      setCursorForScene(orbScene)
    elseif result == "open_orb_reward" then
      local orbScene = OrbRewardScene.new()
      sceneManager:set(orbScene, true)
      setCursorForScene(orbScene)
    elseif result == "return_to_previous" then
      if previousScene then
        sceneManager:set(previousScene)
        setCursorForScene(previousScene)
        previousScene = nil
      end
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
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(currentCursorImage, mx, my, 0, cursorScale, cursorScale, hotX, hotY)
  end
  
  love.graphics.setColor(1, 1, 1, 1)
end

function love.resize(width, height)
  updateScreenScale()
  if sceneManager then sceneManager:resize(width, height) end
end

function love.keypressed(key, scancode, isRepeat)
  if sceneManager then 
    local result = sceneManager:keypressed(key, scancode, isRepeat)
    
    -- Handle scene switching signals
    if result == "open_formation_editor" then
      -- Store current scene as previous scene
      previousScene = sceneManager.currentScene
      -- Create and switch to formation editor
      local editorScene = FormationEditorScene.new()
      editorScene:setPreviousScene(previousScene)
      sceneManager:set(editorScene)
      setCursorForScene(editorScene)
    elseif result == "restart" then
      -- Return to previous scene (could be MapScene or SplitScene) or restart game
      if previousScene then
        -- Check if returning to map scene or battle scene
        if previousScene == mapScene then
          -- Returning to map from battle
          sceneManager:set(previousScene)
          setCursorForScene(previousScene)
          previousScene = nil
        else
          -- Returning to battle scene (from formation editor)
          if previousScene.reloadBlocks then
            previousScene:reloadBlocks()
          end
          sceneManager:set(previousScene)
          setCursorForScene(previousScene)
          previousScene = nil
        end
      else
        -- No previous scene, restart with map
        mapScene = MapScene.new()
        sceneManager:set(mapScene)
        setCursorForScene(mapScene)
      end
    elseif result == "return_to_map" then
      -- Return to map scene from battle
      if mapScene then
        sceneManager:set(mapScene)
        setCursorForScene(mapScene)
        previousScene = nil
      else
        -- Create new map scene if none exists
        mapScene = MapScene.new()
        sceneManager:set(mapScene)
        setCursorForScene(mapScene)
      end
    elseif result == "open_encounter_select" then
      -- Open encounter selection menu
      local selectScene = EncounterSelectScene.new()
      selectScene:setPreviousScene(sceneManager.currentScene)
      previousScene = sceneManager.currentScene
      sceneManager:set(selectScene)
      setCursorForScene(selectScene)
    elseif result == "start_battle" then
      -- Start battle with selected encounter
      previousScene = mapScene
      local battleScene = SplitScene.new()
      sceneManager:set(battleScene)
      setCursorForScene(battleScene)
    elseif result == "cancel" then
      -- Return to previous scene (map)
      if previousScene then
        sceneManager:set(previousScene)
        setCursorForScene(previousScene)
        previousScene = nil
      elseif mapScene then
        sceneManager:set(mapScene)
        setCursorForScene(mapScene)
      end
    end
  end
end

function love.keyreleased(key, scancode)
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
  if sceneManager then
    local result = sceneManager:mousepressed(vx, vy, button, isTouch, presses)
    -- Handle scene switching signals from mouse clicks
    if result == "start_battle" then
      -- Start battle with selected encounter
      previousScene = mapScene
      local battleScene = SplitScene.new()
      sceneManager:set(battleScene)
      setCursorForScene(battleScene)
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
  if sceneManager then sceneManager:mousereleased(vx, vy, button, isTouch, presses) end
end

function love.mousemoved(x, y, dx, dy, isTouch)
  -- Convert screen coordinates to virtual coordinates (reverse of draw scaling)
  local vx = (x - offsetX) / scaleFactor
  local vy = (y - offsetY) / scaleFactor
  local vdx = dx / scaleFactor
  local vdy = dy / scaleFactor
  if sceneManager then sceneManager:mousemoved(vx, vy, vdx, vdy, isTouch) end
end

function love.wheelmoved(dx, dy)
  if sceneManager then sceneManager:wheelmoved(dx, dy) end
end


