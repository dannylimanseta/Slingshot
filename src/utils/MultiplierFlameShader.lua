-- Animated flame shader used to highlight multiplier blocks.
-- Draw by setting the shader, sending `u_time`, `u_resolution`, `u_intensity`,
-- and rendering a rectangle/mesh over the desired area.
-- Example:
--   local shader = MultiplierFlameShader.getShader()
--   shader:send("u_time", love.timer.getTime())
--   shader:send("u_resolution", {width, height})
--   shader:send("u_intensity", 1.0)
--   love.graphics.setShader(shader)
--   love.graphics.rectangle("fill", x, y, width, height)
--   love.graphics.setShader()

local MultiplierFlameShader = {}

local SHADER = love.graphics.newShader([[
extern float u_time;
extern vec2 u_rectOrigin;
extern vec2 u_rectSize;
extern float u_intensity;
extern float u_timeOffset;

float hash2D(vec2 x) {
  return fract(sin(dot(x, vec2(13.454, 7.405))) * 12.3043);
}

float voronoi2D(vec2 uv) {
  vec2 fl = floor(uv);
  vec2 fr = fract(uv);
  float res = 1.0;
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 p = vec2(i, j);
      float h = hash2D(fl + p);
      vec2 vp = p - fr + h;
      float d = dot(vp, vp);
      res += 1.0 / pow(d, 8.0);
    }
  }
  return pow(1.0 / res, 1.0 / 16.0);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
  vec2 uv = vec2(0.0);
  if (u_rectSize.x > 0.0 && u_rectSize.y > 0.0) {
    uv = (screen_coords - u_rectOrigin) / u_rectSize;
  }
  uv = clamp(uv, 0.0, 1.0);
  uv.y = 1.0 - uv.y;

  float iTime = u_time + u_timeOffset;

  float up0 = voronoi2D(uv * vec2(6.0, 4.0) + vec2(0.0, -iTime * 2.0));
  float up1 = 0.5 + voronoi2D(uv * vec2(6.0, 4.0) + vec2(42.0, -iTime * 2.0) + 30.0);
  float finalMask = up0 * up1 + (1.0 - uv.y);

  finalMask += (1.0 - uv.y) * 0.5;
  finalMask *= 0.7 - abs(uv.x - 0.5);

  vec3 dark = mix(vec3(0.0), vec3(1.0, 0.4, 0.0), step(0.8, finalMask));
  vec3 light = mix(dark, vec3(1.0, 0.8, 0.0), step(0.95, finalMask));
  vec3 fireColor = clamp(light * max(u_intensity, 0.0), 0.0, 1.5);

  float alpha = smoothstep(0.35, 1.0, finalMask);
  alpha = clamp(alpha * color.a, 0.0, 1.0);

  return vec4(fireColor * color.rgb, alpha);
}
]])

function MultiplierFlameShader.getShader()
  return SHADER
end

return MultiplierFlameShader


