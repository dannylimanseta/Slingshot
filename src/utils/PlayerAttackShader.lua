-- Player attack shader overlay shown during player attack animations.
-- Adapted from a Shadertoy-style radial noise shader for use with LÖVE.
-- Usage:
--   local shader = PlayerAttackShader.getShader()
--   shader:send("u_time", timeSeconds)
--   shader:send("u_resolution", { width, height })
--   shader:send("u_center", { centerX, centerY })
--   shader:send("u_radius", radius)
--   shader:send("u_edge", edgeThreshold)
--   shader:send("u_intensity", intensity)
--   love.graphics.setShader(shader)
--   love.graphics.rectangle("fill", 0, 0, width, height)
--   love.graphics.setShader()

local PlayerAttackShader = {}

local SHADER = love.graphics.newShader([[
extern float u_time;
extern vec2 u_resolution;
extern vec2 u_center;
extern float u_radius;
extern float u_edge;
extern float u_intensity;

vec3 random3(vec3 c) {
  float j = 4096.0 * sin(dot(c, vec3(17.0, 59.4, 15.0)));
  vec3 r;
  r.z = fract(512.0 * j);
  j *= 0.125;
  r.x = fract(512.0 * j);
  j *= 0.125;
  r.y = fract(512.0 * j);
  return r - 0.5;
}

float simplex3d(vec3 p) {
  vec3 s = floor(p + dot(p, vec3(0.3333333)));
  vec3 x = p - s + dot(s, vec3(0.1666667));
  vec3 e = step(vec3(0.0), x - x.yzx);
  vec3 i1 = e * (1.0 - e.zxy);
  vec3 i2 = 1.0 - e.zxy * (1.0 - e);
  vec3 x1 = x - i1 + 0.1666667;
  vec3 x2 = x - i2 + 2.0 * 0.1666667;
  vec3 x3 = x - 1.0 + 3.0 * 0.1666667;
  vec4 w, d;
  w.x = dot(x, x);
  w.y = dot(x1, x1);
  w.z = dot(x2, x2);
  w.w = dot(x3, x3);
  w = max(0.6 - w, 0.0);
  d.x = dot(random3(s), x);
  d.y = dot(random3(s + i1), x1);
  d.z = dot(random3(s + i2), x2);
  d.w = dot(random3(s + 1.0), x3);
  w *= w;
  w *= w;
  d *= w;
  return dot(d, vec4(52.0));
}

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
  vec2 res = vec2(max(u_resolution.x, 1.0), max(u_resolution.y, 1.0));
  vec2 center = u_center;
  if (center.x <= 0.0 && center.y <= 0.0) {
    center = res * 0.5;
  }

  float radius = (u_radius > 0.0) ? u_radius : 12.0;
  float edge = (u_edge > 0.0) ? u_edge : 0.3;
  float intensity = max(u_intensity, 0.0);

  vec2 uv = (screen_coords - center) / res.y;
  float lenUV = length(uv);
  vec2 dir = (lenUV > 1e-5) ? (uv / lenUV) : vec2(0.0);

  float time = u_time * 2.0;
  float scale = 50.0;
  vec2 base = vec2(0.5 * res.x / res.y, 0.5);
  vec2 p = base + dir * min(lenUV, 0.05);

  vec3 p3 = scale * 0.25 * vec3(p.xy, 0.0) + vec3(0.0, 0.0, time * 0.025);
  float noise = simplex3d(p3 * 32.0) * 0.5 + 0.5;
  float dist = abs(clamp(lenUV / radius, 0.0, 1.0) * noise * 2.0 - 1.0);
  float stepped = smoothstep(edge - 0.5, edge + 0.5, noise * (1.0 - pow(dist, 4.0)));
  float finalMask = smoothstep(edge - 0.05, edge + 0.05, noise * stepped);

  float alpha = clamp(finalMask * intensity, 0.0, 1.0);
  vec3 glow = vec3(1.0) * alpha;

  return vec4(glow * color.rgb, alpha * color.a);
}
]])

function PlayerAttackShader.getShader()
  return SHADER
end

return PlayerAttackShader


