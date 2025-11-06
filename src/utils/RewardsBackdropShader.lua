local RewardsBackdropShader = {}

-- FBM-based animated backdrop shader (adapted from Shadertoy to LÖVE)
-- Original by Morgan McGuire (noise), integrated with rotating fbm and palette
local SHADER = love.graphics.newShader([[ 
extern float u_time;
extern vec2 u_resolution;

float random(vec2 st){
  return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

mat2 rotate(float a){
  float c = cos(a);
  float s = sin(a);
  return mat2(c, s, -s, c);
}

float noise(vec2 _st){
  vec2 i = floor(_st);
  vec2 f = fract(_st);

  float a = random(i);
  float b = random(i + vec2(1.0, 0.0));
  float c = random(i + vec2(0.0, 1.0));
  float d = random(i + vec2(1.0, 1.0));

  vec2 u = f * f * (3.0 - 2.0 * f);

  return mix(a, b, u.x) +
         (c - a) * u.y * (1.0 - u.x) +
         (d - b) * u.x * u.y;
}

float fbm(vec2 n){
  float total = 0.0;
  float amplitude = 0.7;
  mat2 rot = rotate(0.5);
  for(int i = 0; i < 6; ++i){
    total += amplitude * noise(n);
    n = rot * n * 2.0 + 300.0;
    amplitude *= 0.45;
  }
  return total;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc){
  // Use screen coords sc as fragCoord and normalize by resolution
  vec2 st = sc / u_resolution * 3.0;

  vec2 q = vec2(0.0);
  q.x = fbm(st + 0.01 * u_time);
  q.y = fbm(st + vec2(1.0, 0.0));

  vec2 r = vec2(0.0);
  r.x = fbm(st + 1.0 * q + 0.15 * u_time);
  r.y = fbm(st + 1.0 * q + 0.10 * u_time);

  float f = fbm(st + r);

  vec3 col = mix(vec3(0.3, 0.5, 0.6),
                 vec3(0.3, 0.3, 0.4),
                 clamp((f * f) * 2.0, 0.0, 0.5));

  col = mix(col,
            vec3(0.3589, 0.369, 0.3875),
            clamp(abs(r.x) * 10.0, 0.0, 0.80));

  float g = (f*f*f + 0.9*f*f + 0.5*f);
  // Keep semi-transparency like the original (.5)
  return vec4(col * g, 0.5) * color;
}
]])

function RewardsBackdropShader.getShader()
  return SHADER
end

return RewardsBackdropShader


