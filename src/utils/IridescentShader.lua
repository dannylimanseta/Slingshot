-- Iridescent (rainbow) shader for special blocks
-- Lightweight HSV rainbow banding that scrolls over UVs
-- Usage:
--   local S = IridescentShader.getShader()
--   S:send(\"u_time\", love.timer.getTime())
--   S:send(\"u_intensity\", 0.7) -- 0..1
--   S:send(\"u_scale\", 14.0)     -- frequency of color bands
--   S:send(\"u_angle\", 0.6)      -- band direction in radians
--   love.graphics.setShader(S)
--   love.graphics.draw(sprite, ...)
--   love.graphics.setShader()

local IridescentShader = {}

local SHADER = love.graphics.newShader([[
extern float u_time;
extern float u_intensity; // 0..1 (how strong the tinting is)
extern float u_scale;     // banding frequency (lower = fewer bands)
extern float u_angle;     // direction of bands (radians)
extern float u_variation; // 0..1 amount of perpendicular waviness to break stripes
extern float u_noiseScale;   // scale for organic noise warp
extern float u_noiseAmp;     // amplitude for organic noise warp
extern float u_shineStrength; // 0..1 extra highlight strength for shininess
extern float u_patchiness;   // 0..1 blend between stripes (0) and patchy noise (1)
extern float u_timeOffset;   // per-instance time offset to desynchronize animations

// Fast HSV to RGB (Filmic-ish)
vec3 hsv2rgb(vec3 c) {
  vec3 rgb = clamp( abs(mod(c.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0 );
  // smooth curve for nicer bands
  rgb = rgb * rgb * (3.0 - 2.0 * rgb);
  return c.z * mix(vec3(1.0), rgb, c.y);
}

// Overlay blend (component-wise)
vec3 overlayBlend(vec3 base, vec3 blend) {
  vec3 low = 2.0 * base * blend;
  vec3 high = 1.0 - 2.0 * (1.0 - base) * (1.0 - blend);
  vec3 mask = step(0.5, base);
  return mix(low, high, mask);
}

// Cheap smooth value noise (not perfect but good enough for organic wobble)
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p){
  vec2 i = floor(p);
  vec2 f = fract(p);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float fbm(vec2 p){
  float v = 0.0;
  float a = 0.5;
  for(int i=0;i<4;i++){
    v += a * noise(p);
    p *= 2.02;
    a *= 0.5;
  }
  return v;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec4 base = Texel(tex, uv) * color;
  // Early out when fully transparent
  if (base.a <= 0.0) {
    return base;
  }

  // Project UVs onto a rotated axis for directional bands
  float cs = cos(u_angle);
  float sn = sin(u_angle);
  float coord = uv.x * cs - uv.y * sn;        // main axis
  float perp  = uv.x * (-sn) + uv.y * cs;     // perpendicular axis

  // Organic warp from fBm noise
  float t = u_time + u_timeOffset;
  float n = fbm(vec2(coord, perp) * max(0.0001, u_noiseScale) + vec2(t * 0.15, -t * 0.12));
  // Slow moving bands across the surface, with sine wobble and noise warp combined
  float bands = coord * u_scale + t * 0.6;
  bands += u_variation * 0.35 * sin(perp * (u_scale * 0.6) + t * 0.8);
  bands += u_noiseAmp * (n - 0.5) * 2.0; // center around 0
  float hueBands = fract(bands + 0.15 * n);
  // Noise-driven hue for patchy look (animated slightly)
  float hueNoise = fract(n + t * 0.03);
  float hue = mix(hueBands, hueNoise, clamp(u_patchiness, 0.0, 1.0));
  vec3 ir = hsv2rgb(vec3(hue, 0.9, 1.0)); // bright, saturated rainbow

  // Pseudo specular highlights: sharpen band peaks and sprinkle sparkles
  float peak = 1.0 - abs(fract(bands) - 0.5) * 2.0;     // 0..1, max at band center
  peak = smoothstep(0.6, 1.0, peak);
  float sparkle = fbm(uv * (u_noiseScale * 3.0) + vec2(t * 1.2, t * -0.9));
  sparkle = smoothstep(0.88, 1.0, sparkle);
  // Blend highlight driver toward noise so highlights also look patchy
  float patchBoost = mix(1.0, smoothstep(0.35, 0.95, n), clamp(u_patchiness, 0.0, 1.0));
  float shine = pow(peak * patchBoost, 6.0) * (0.6 + 0.4 * sparkle);

  // Modulate the base with the rainbow using overlay for punchy highlights
  vec3 tint = (0.55 + 0.45 * ir);
  vec3 overlayRes = overlayBlend(base.rgb, tint);
  vec3 rainbowed = mix(base.rgb, overlayRes, clamp(u_intensity, 0.0, 1.0));
  vec3 finalRgb = rainbowed + u_shineStrength * shine;
  finalRgb = clamp(finalRgb, 0.0, 1.0);
  return vec4(finalRgb, base.a);
}
]])

function IridescentShader.getShader()
  return SHADER
end

return IridescentShader


