-- Sheen shader for AOE/cleave blocks
-- Creates an animated bright highlight that sweeps across the surface
-- Usage:
--   local S = SheenShader.getShader()
--   S:send("u_time", love.timer.getTime())
--   S:send("u_timeOffset", 0.0) -- per-instance offset to desynchronize
--   S:send("u_speed", 1.0) -- sweep speed
--   S:send("u_width", 0.3) -- width of sheen highlight (0..1)
--   S:send("u_intensity", 0.6) -- brightness of sheen (0..1)
--   S:send("u_angle", 0.785) -- angle of sweep in radians (default ~45 degrees)
--   love.graphics.setShader(S)
--   love.graphics.draw(sprite, ...)
--   love.graphics.setShader()

local SheenShader = {}

local SHADER = love.graphics.newShader([[
extern float u_time;
extern float u_timeOffset; // per-instance time offset to desynchronize animations
extern float u_speed;       // speed of sheen sweep (default 1.0)
extern float u_width;      // width of sheen highlight (0..1, default 0.3)
extern float u_intensity;  // brightness of sheen (0..1, default 0.6)
extern float u_angle;      // angle of sweep direction in radians (default ~45 degrees)

  // Note: smoothstep is built-in to GLSL

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec4 base = Texel(tex, uv) * color;
  // Early out when fully transparent
  if (base.a <= 0.0) {
    return base;
  }

  // Calculate sweep direction using angle
  float cs = cos(u_angle);
  float sn = sin(u_angle);
  // Project UV onto sweep direction
  float sweepCoord = uv.x * cs + uv.y * sn;
  
  // Animated sweep position (loops continuously)
  float t = u_time + u_timeOffset;
  float sweepPos = mod(sweepCoord + t * u_speed, 1.0);
  
  // Create sheen highlight with soft edges
  // Sheen is brightest at center, fades to edges
  float sheenCenter = 0.5; // Center of the sweep
  float dist = abs(sweepPos - sheenCenter);
  float halfWidth = u_width * 0.5;
  
  // Create smooth falloff from center using built-in smoothstep
  float sheen = 1.0 - smoothstep(0.0, halfWidth, dist);
  
  // Apply intensity and add to base color
  vec3 sheenColor = vec3(1.0, 1.0, 1.0); // White sheen
  vec3 finalRgb = base.rgb + sheenColor * sheen * u_intensity;
  finalRgb = clamp(finalRgb, 0.0, 1.0);
  
  return vec4(finalRgb, base.a);
}
]])

function SheenShader.getShader()
  return SHADER
end

return SheenShader

