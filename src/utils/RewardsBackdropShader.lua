-- Rewards backdrop shader adapted from provided Shadertoy-style GLSL

local RewardsBackdropShader = {}

local SHADER = love.graphics.newShader([[ 
extern float u_time;
extern vec2 u_resolution;
extern float u_desaturate; // 0 = original color, 1 = grayscale
extern float u_noiseAmount; // 0 = no noise, 1 = strong
extern float u_noiseScale;  // noise frequency
extern float u_noiseSpeed;  // animation speed

// Hash and value noise helpers
float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 78.233);
  return fract(p.x * p.y);
}

float valueNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  // sc is pixel position within the render target
  vec2 F = sc;
  vec2 screenUV = sc / u_resolution;
  vec3 A = vec3(u_resolution, u_resolution.y);
  vec3 p;
  float u = 0.0;
  float R = 0.0;
  float o = 0.0;
  float r = 0.0;
  float a = u_time;

  vec4 O = vec4(0.0);

  for (u = 0.0; u < 44.0; u += 1.0) {
    p = R * normalize(vec3(F + F - A.xy, A.y));
    p.z -= 2.0;
    r = length(p);
    p /= (r * 0.1);

    // Rotate p.xz using time-varying matrix
    vec4 c = cos(a * 0.2 + vec4(0.0, 33.0, 11.0, 0.0));
    p.xz *= mat2(c.x, c.y, c.z, c.w);

    // Original uses texture(iChannel3, F/1024.).r * 0.1; omit texture term
    o = min(r - 0.3, 0.0) + 0.1;
    R += o;

    float s = sin(p.x + cos(p.y) * cos(p.z)) * sin(p.z + sin(p.y) * cos(p.x + a));
    float m = smoothstep(0.5, 0.7, s);
    float falloff = mix(m, 1.0, 0.15 / (r * r + 1e-5));
    float shell = smoothstep(5.0, 0.0, r);

    vec4 wave = 1.0 + cos(R * 3.0 + vec4(0.0, 1.0, 2.0, 0.0));
    O += (0.05 / (0.4 + o)) * falloff * shell * wave;
  }

  // Normalize and clamp
  O = clamp(O * 0.5, 0.0, 1.0);
  // Add animated value noise grain
  float n = valueNoise(screenUV * max(u_noiseScale, 0.0001) + vec2(u_time * u_noiseSpeed, 0.0));
  O.rgb = clamp(O.rgb + (n - 0.5) * (u_noiseAmount * 0.4), 0.0, 1.0);
  // Desaturate
  float lum = dot(O.rgb, vec3(0.299, 0.587, 0.114));
  vec3 gray = vec3(lum);
  O.rgb = mix(O.rgb, gray, clamp(u_desaturate, 0.0, 1.0));
  // Ensure alpha
  O.a = 1.0;
  return O * color;
}
]])

function RewardsBackdropShader.getShader()
  return SHADER
end

return RewardsBackdropShader


