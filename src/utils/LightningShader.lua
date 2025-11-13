-- Lightning shader for lightning orb projectile
-- Creates an electric/lightning effect with animated sparks and glow
-- Usage:
--   local S = LightningShader.getShader()
--   S:send("u_time", love.timer.getTime())
--   S:send("u_intensity", 1.0) -- 0..1
--   love.graphics.setShader(S)
--   love.graphics.draw(sprite, ...)
--   love.graphics.setShader()

local LightningShader = {}

local SHADER = love.graphics.newShader([[
extern float u_time;
extern float u_intensity; // 0..1 (how strong the lightning effect is)

// Fast HSV to RGB
vec3 hsv2rgb(vec3 c) {
  vec3 rgb = clamp( abs(mod(c.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0 );
  rgb = rgb * rgb * (3.0 - 2.0 * rgb);
  return c.z * mix(vec3(1.0), rgb, c.y);
}

// Cheap smooth value noise for lightning sparks
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

// Fractal noise for lightning patterns
float fbm(vec2 p){
  float v = 0.0;
  float a = 0.5;
  for(int i=0;i<3;i++){
    v += a * noise(p);
    p *= 2.0;
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

  // Center UV coordinates
  vec2 centered = uv - 0.5;
  float dist = length(centered);
  
  // Animated lightning sparks
  float t = u_time * 3.0;
  vec2 sparkUV = uv * 8.0 + vec2(t * 0.5, -t * 0.3);
  float sparkNoise = fbm(sparkUV);
  
  // Create lightning bolt pattern (radial from center)
  float angle = atan(centered.y, centered.x);
  float radius = dist * 4.0;
  vec2 boltUV = vec2(radius, angle * 2.0) + vec2(t * 0.8, t * 0.4);
  float boltPattern = fbm(boltUV);
  
  // Combine patterns for lightning effect
  float lightning = sparkNoise * 0.6 + boltPattern * 0.4;
  lightning = smoothstep(0.4, 1.0, lightning);
  
  // Electric blue/cyan color
  vec3 electricColor = vec3(0.3, 0.7, 1.0); // Bright cyan-blue
  vec3 lightningTint = mix(vec3(1.0), electricColor, lightning * u_intensity);
  
  // Add bright white sparks
  float sparkle = smoothstep(0.85, 1.0, sparkNoise);
  lightningTint += sparkle * 0.5 * u_intensity;
  
  // Apply lightning effect to base color
  vec3 finalRgb = base.rgb * lightningTint;
  finalRgb = clamp(finalRgb, 0.0, 1.0);
  
  // Enhance alpha slightly for glow effect
  float alpha = base.a * (1.0 + lightning * 0.2 * u_intensity);
  alpha = clamp(alpha, 0.0, 1.0);
  
  return vec4(finalRgb, alpha);
}
]])

function LightningShader.getShader()
  return SHADER
end

return LightningShader

