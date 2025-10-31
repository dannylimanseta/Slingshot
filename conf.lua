function love.conf(t)
  t.identity = "Slingshot"
  t.appendidentity = false

  -- Window
  t.window.title = "Slingshot"
  t.window.width = 1280
  t.window.height = 720
  t.window.resizable = true
  t.window.highdpi = true

  -- Modules (leave defaults enabled; adjust later as needed)
  t.modules.joystick = false
  t.modules.physics = true
end


