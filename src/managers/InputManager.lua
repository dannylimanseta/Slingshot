local config = require("config")

-- Centralized, action-based input manager
-- Unifies keyboard, mouse, and gamepad into device-agnostic actions with contexts
local InputManager = {
  -- Active context: "map" | "battle" | "ui"
  context = "ui",
  -- Last active device for prompt glyphs: "kbm" | "pad" | "touch"
  lastDevice = "kbm",

  -- Default bindings per context
  -- Each action maps to an array of bindings:
  -- {type="key", key="space"}, {type="mouse", button=1}, {type="pad", button="a"}, {type="pad_axis", x="rightx", y="righty"}
  binds = {
    map = {
      -- Digital actions
      end_day = { {type="key", key="space"}, {type="pad", button="y"} },
      ui_confirm = { {type="key", key="return"}, {type="pad", button="a"} },
      ui_back = { {type="key", key="escape"}, {type="pad", button="b"} },
      -- UI navigation
      nav_up = { {type="key", key="up"}, {type="key", key="w"}, {type="pad", button="dpup"} },
      nav_down = { {type="key", key="down"}, {type="key", key="s"}, {type="pad", button="dpdown"} },
      nav_left = { {type="key", key="left"}, {type="key", key="a"}, {type="pad", button="dpleft"} },
      nav_right = { {type="key", key="right"}, {type="key", key="d"}, {type="pad", button="dpright"} },
      -- Analog axes
      move = { {type="keys_axis", x_pos="d", x_neg="a", y_pos="s", y_neg="w"}, {type="pad_axis", x="leftx", y="lefty"} },
      pointer = { {type="mouse_pointer"} }, -- mouse controls pointer by default
    },
    battle = {
      -- Digital actions
      shoot = { {type="mouse", button=1}, {type="pad", button="a"} },
      end_turn = { {type="key", key="return"}, {type="pad", button="y"} },
      next_target = { {type="key", key="tab"}, {type="pad", button="rightshoulder"} },
      ui_confirm = { {type="key", key="return"}, {type="pad", button="a"} },
      ui_back = { {type="key", key="escape"}, {type="pad", button="b"} },
      -- Analog axes
      aim = { {type="pad_axis", x="rightx", y="righty"} },
      pointer = { {type="mouse_pointer"} },
    },
    ui = {
      ui_confirm = { {type="key", key="return"}, {type="pad", button="a"}, {type="mouse", button=1} },
      ui_back = { {type="key", key="escape"}, {type="pad", button="b"} },
      nav_up = { {type="key", key="up"}, {type="pad", button="dpup"} },
      nav_down = { {type="key", key="down"}, {type="pad", button="dpdown"} },
      nav_left = { {type="key", key="left"}, {type="pad", button="dpleft"} },
      nav_right = { {type="key", key="right"}, {type="pad", button="dpright"} },
      pointer = { {type="mouse_pointer"} },
    },
  },

  -- Internal state
  _keysDown = {},            -- key -> bool
  _mouseDown = {},           -- button -> bool
  _padButtonsDown = {},      -- button -> bool (single pad focus)
  _padAxes = { leftx=0, lefty=0, rightx=0, righty=0 }, -- axis -> value
  _digitalDown = {},         -- action -> bool (composed)
  _pressedThisFrame = {},    -- action -> bool
  _releasedThisFrame = {},   -- action -> bool
  _analogState = {},         -- action -> {x, y} or value
  _pointer = { x = (config.video and config.video.virtualWidth or 1280) * 0.5,
               y = (config.video and config.video.virtualHeight or 720) * 0.5 },

  -- Settings
  settings = {
    deadzone = {
      left = 0.15,
      right = 0.15,
    },
    sensitivity = {
      aim = 900,      -- px/s when converting right stick to pointer movement
      move = 1.0,     -- scale for move axis
      pointerMouse = 1.0,
    },
  },
}

-- Utility: clamp
local function clamp(v, mn, mx)
  if v < mn then return mn end
  if v > mx then return mx end
  return v
end

-- Utility: apply radial deadzone
local function applyDeadzone(x, y, dz)
  local mag = math.sqrt(x * x + y * y)
  if mag < dz then return 0, 0 end
  -- re-scale to [0,1] after deadzone cut
  local scale = (mag - dz) / (1 - dz)
  if mag > 0 then
    local nx = (x / mag) * scale
    local ny = (y / mag) * scale
    return nx, ny
  end
  return 0, 0
end

-- Context management
function InputManager.setContext(name)
  if name ~= InputManager.context then
    InputManager.context = name
    -- Clear edge states on context switch to avoid phantom presses
    InputManager._digitalDown = {}
    InputManager._pressedThisFrame = {}
    InputManager._releasedThisFrame = {}
  end
end

function InputManager.getContext()
  return InputManager.context
end

function InputManager.getLastDevice()
  return InputManager.lastDevice
end

-- Public queries
function InputManager.pressed(action)
  return InputManager._pressedThisFrame[action] == true
end

function InputManager.released(action)
  return InputManager._releasedThisFrame[action] == true
end

function InputManager.isDown(action)
  return InputManager._digitalDown[action] == true
end

function InputManager.axis(action)
  local v = InputManager._analogState[action]
  if v == nil then return 0, 0 end
  local x = v.x or 0
  local y = v.y or 0
  return x, y
end

function InputManager.getPointer()
  return InputManager._pointer.x, InputManager._pointer.y
end

-- Minimal glyph helper (stubbed for now)
function InputManager.getGlyph(action)
  -- Return a short label based on primary binding and last device
  local ctxBinds = InputManager.binds[InputManager.context] or {}
  local bindings = ctxBinds[action]
  if not bindings or #bindings == 0 then return "" end
  local device = InputManager.lastDevice
  if device == "pad" then
    for _, b in ipairs(bindings) do
      if b.type == "pad" then
        local map = { a="A", b="B", x="X", y="Y", leftshoulder="LB", rightshoulder="RB", start="Start", back="Back" }
        return map[b.button] or b.button or ""
      end
    end
  else
    for _, b in ipairs(bindings) do
      if b.type == "key" then
        local map = { ["return"]="Enter", ["escape"]="Esc", ["space"]="Space", ["tab"]="Tab" }
        return map[b.key] or b.key
      elseif b.type == "mouse" then
        return (b.button == 1 and "LMB") or (b.button == 2 and "RMB") or "MB"..tostring(b.button or "?")
      end
    end
  end
  return ""
end

-- Internal: set digital edges
local function setActionDown(action, down)
  local wasDown = InputManager._digitalDown[action] == true
  if down and not wasDown then
    InputManager._pressedThisFrame[action] = true
    InputManager._digitalDown[action] = true
  elseif (not down) and wasDown then
    InputManager._releasedThisFrame[action] = true
    InputManager._digitalDown[action] = false
  end
end

-- Internal: evaluate current composed state for all actions
local function evaluateActions()
  local ctxBinds = InputManager.binds[InputManager.context] or {}
  -- Clear analog each frame, then rebuild
  InputManager._analogState = {}

  for action, bindings in pairs(ctxBinds) do
    local anyDown = false
    local ax, ay = 0, 0
    for _, b in ipairs(bindings) do
      if b.type == "key" then
        if InputManager._keysDown[b.key] then
          anyDown = true
        end
      elseif b.type == "mouse" then
        if InputManager._mouseDown[b.button or 1] then
          anyDown = true
        end
      elseif b.type == "pad" then
        if InputManager._padButtonsDown[b.button] then
          anyDown = true
        end
      elseif b.type == "pad_axis" then
        local x = InputManager._padAxes[b.x or "leftx"] or 0
        local y = InputManager._padAxes[b.y or "lefty"] or 0
        local dz = (b.x == "rightx" or b.y == "righty") and InputManager.settings.deadzone.right or InputManager.settings.deadzone.left
        local fx, fy = applyDeadzone(x, y, dz or 0)
        ax = ax + fx
        ay = ay + fy
      elseif b.type == "keys_axis" then
        local x = 0
        local y = 0
        if b.x_pos and InputManager._keysDown[b.x_pos] then x = x + 1 end
        if b.x_neg and InputManager._keysDown[b.x_neg] then x = x - 1 end
        if b.y_pos and InputManager._keysDown[b.y_pos] then y = y + 1 end
        if b.y_neg and InputManager._keysDown[b.y_neg] then y = y - 1 end
        -- Normalize to -1..1 if both pressed
        local mag = math.sqrt(x*x + y*y)
        if mag > 1 then x = x / mag; y = y / mag end
        ax = ax + x
        ay = ay + y
      elseif b.type == "mouse_pointer" then
        -- Pointer handled separately; keep binding as capability marker
      end
    end

    -- Set digital state if bindings include digital inputs
    -- Digital is true if any digital binding active
    setActionDown(action, anyDown)

    -- Write analog vector if any axis sources contributed
    if ax ~= 0 or ay ~= 0 then
      InputManager._analogState[action] = { x = clamp(ax, -1, 1), y = clamp(ay, -1, 1) }
    end
  end
end

-- Frame update: recompute composed states and integrate pointer from stick
function InputManager.update(dt)
  -- Reset edge flags at start of frame
  InputManager._pressedThisFrame = {}
  InputManager._releasedThisFrame = {}

  evaluateActions()

  -- If right stick is used for aim in this context, move pointer accordingly
  local aimX, aimY = 0, 0
  do
    local ax, ay = 0, 0
    if InputManager.context == "battle" then
      ax, ay = InputManager.axis("aim")
    else
      -- Some contexts may not have aim; do nothing
    end
    aimX, aimY = ax, ay
  end
  if (aimX ~= 0 or aimY ~= 0) then
    InputManager.lastDevice = "pad"
    local speed = InputManager.settings.sensitivity.aim or 900
    local dx = aimX * speed * dt
    local dy = aimY * speed * dt
    local vw = (config.video and config.video.virtualWidth) or 1280
    local vh = (config.video and config.video.virtualHeight) or 720
    InputManager._pointer.x = clamp(InputManager._pointer.x + dx, 0, vw)
    InputManager._pointer.y = clamp(InputManager._pointer.y + dy, 0, vh)
  end
end

-- Love callbacks (to be forwarded by main.lua)
function InputManager.onKeyPressed(key, scancode, isRepeat)
  InputManager.lastDevice = "kbm"
  InputManager._keysDown[key] = true
end

function InputManager.onKeyReleased(key, scancode)
  InputManager.lastDevice = "kbm"
  InputManager._keysDown[key] = false
end

function InputManager.onMousePressed(x, y, button, isTouch, presses)
  InputManager.lastDevice = isTouch and "touch" or "kbm"
  InputManager._mouseDown[button or 1] = true
  -- Update pointer to press position
  if x and y then
    InputManager._pointer.x = x
    InputManager._pointer.y = y
  end
end

function InputManager.onMouseReleased(x, y, button, isTouch, presses)
  InputManager.lastDevice = isTouch and "touch" or "kbm"
  InputManager._mouseDown[button or 1] = false
  if x and y then
    InputManager._pointer.x = x
    InputManager._pointer.y = y
  end
end

function InputManager.onMouseMoved(x, y, dx, dy, isTouch)
  InputManager.lastDevice = isTouch and "touch" or "kbm"
  if x and y then
    InputManager._pointer.x = x
    InputManager._pointer.y = y
  end
end

function InputManager.onWheelMoved(dx, dy)
  InputManager.lastDevice = "kbm"
end

function InputManager.onGamepadPressed(joystick, button)
  InputManager.lastDevice = "pad"
  InputManager._padButtonsDown[button] = true
end

function InputManager.onGamepadReleased(joystick, button)
  InputManager.lastDevice = "pad"
  InputManager._padButtonsDown[button] = false
end

function InputManager.onGamepadAxis(joystick, axis, value)
  InputManager.lastDevice = "pad"
  InputManager._padAxes[axis] = value
end

return InputManager


