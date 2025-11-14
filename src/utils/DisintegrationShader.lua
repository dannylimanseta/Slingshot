-- Disintegration shader effect for enemy death
-- Adapted from Shadertoy-style GLSL to LÖVE shader format

local DisintegrationShader = {}

-- Gradient Noise functions
local DISINTEGRATION_SHADER = love.graphics.newShader([[
extern float u_time;
extern float u_noiseScale;
extern float u_thickness;
extern vec4 u_lineColor;
extern float u_colorIntensity;
extern float u_progress; // 0.0 = start, 1.0 = fully disintegrated

// Gradient Noise functions
vec2 gradientNoise_dir(vec2 p) {
    // Rotation matrix to rotate the gradient
    p = mod(p, 289.0);
    float x = mod((34.0 * p.x + 1.0) * p.x, 289.0) + p.y;
    x = mod((34.0 * x + 1.0) * x, 289.0);
    x = fract(x / 41.0) * 2.0 - 1.0;
    return normalize(vec2(x - floor(x + 0.5), abs(x) - 0.5));
}

float gradientNoise(vec2 p) {
    vec2 ip = floor(p);
    vec2 fp = fract(p);
    float d00 = dot(gradientNoise_dir(ip), fp);
    float d01 = dot(gradientNoise_dir(ip + vec2(0.0, 1.0)), fp - vec2(0.0, 1.0));
    float d10 = dot(gradientNoise_dir(ip + vec2(1.0, 0.0)), fp - vec2(1.0, 0.0));
    float d11 = dot(gradientNoise_dir(ip + vec2(1.0, 1.0)), fp - vec2(1.0, 1.0));
    fp = fp * fp * fp * (fp * (fp * 6.0 - 15.0) + 10.0);
    return mix(mix(d00, d01, fp.y), mix(d10, d11, fp.y), fp.x);
}

float GradientNoise(vec2 UV, float Scale) {
    return gradientNoise(UV * Scale) + 0.5;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    // Sample the texture
    vec4 col = Texel(tex, uv);
    
    // Generate noise
    float noise = GradientNoise(uv, u_noiseScale);
    noise = clamp(noise, 0.0, 1.0);
    
    // Vertical distortion (bottom disintegrates first)
    vec2 distortedUV = uv;
    distortedUV.y = pow(distortedUV.y, 2.0) * 3.0;
    float heightCalc = noise + distortedUV.y;
    
    // Animated value based on time and progress
    // Progress goes from 0 (start) to 1 (fully disintegrated)
    // Map progress to disintegration value: higher progress = more disintegrated
    // Start low so disintegration begins from bottom, increase to make enemy disappear
    // Faster animation: increased time multiplier (1.0) and progress multiplier (4.0)
    float val = sin(u_time * 1.0) * 0.5 + u_progress * 4.0;
    
    // Inverted: pixels disappear when heightCalc > val (instead of < val)
    // This makes the enemy actually disintegrate and disappear
    float stepFn = 1.0 - step(heightCalc - val, 0.0); // Visible area (inverted)
    float stepFnOff = 1.0 - step(heightCalc - (val + u_thickness), 0.0); // Disintegration edge (inverted)
    float lines = stepFn - stepFnOff; // Edge lines where disintegration is happening
    vec4 lineColor = lines * u_lineColor * u_colorIntensity;
    
    vec4 maskedOffTex = col * stepFn;
    return vec4(maskedOffTex.rgb + lineColor.rgb, stepFn * col.a);
}
]])

function DisintegrationShader.getShader()
  return DISINTEGRATION_SHADER
end

return DisintegrationShader

