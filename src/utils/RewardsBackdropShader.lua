local RewardsBackdropShader = {}

-- FBM-based animated backdrop shader (adapted from Shadertoy to LÖVE)
-- Original by Morgan McGuire (noise), integrated with rotating fbm and palette
local SHADER = love.graphics.newShader([[ 
extern float u_time;
extern vec2 u_resolution;
extern float u_transitionProgress; // 0..1 progress for circle growth during transitions

const float PI = 3.14159265358979323846;

vec2 random2(vec2 st){
  st = vec2(dot(st, vec2(127.1, 311.7)), dot(st, vec2(269.5, 183.3)));
  return -1.0 + 2.0 * fract(sin(st) * 43758.5453123);
}

// Gradient Noise by Inigo Quilez - iq/2013
float noise(vec2 st){
  vec2 i = floor(st);
  vec2 f = fract(st);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(dot(random2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
        dot(random2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
    mix(dot(random2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
        dot(random2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x),
    u.y);
}

float circle(vec2 st, float radius){
  vec2 l = st - vec2(0.5);
  return 1.0 - smoothstep(
    radius - (radius * 0.01),
    radius + (radius * 0.01),
    dot(l, l) * 4.0);
}

vec2 rotate2D(vec2 st, float angle){
  st -= 0.5;
  st = mat2(cos(angle), -sin(angle),
            sin(angle),  cos(angle)) * st;
  st += 0.5;
  return st;
}

// Almost Identity by Inigo Quilez - iq
float almostIdentity(float x, float n){
  return sqrt(x * x + n);
}

// Exponential Impulse by Inigo Quilez - iq
float expImpulse(float k, float x){
  float h = k * x;
  return h * exp(1.0 - h);
}

// Cubic Pulse by Inigo Quilez - iq
float cubicPulse(float c, float w, float x){
  x = abs(x - c);
  if (x > w) return 0.0;
  x /= w;
  return 1.0 - x * x * (3.0 - 2.0 * x);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc){
  vec2 fragCoord = sc;
  // Normalize like Shadertoy using Y to preserve aspect
  vec2 resYY = vec2(u_resolution.y, u_resolution.y);
  vec2 st = fragCoord / resYY;
  vec3 outColor = vec3(0.0);

  st.x -= 0.4;
  float t = abs(1.0 - sin(u_time)) * 10.0;

  float circleFreq = 30.0;
  float circleAmpl = 5.0;
  float circleShapeNoise = noise(st * circleFreq) / circleAmpl;

  // Circle growth animation
  float pulse = cubicPulse(0.08, 1.2, sin(u_time / PI));
  float base = pulse / 1.5;
  // Enforce a higher minimum radius and increase overall size
  float minFloor = 0.4;
  float circleRadius = 2.08 * max(base, minFloor); // 1.6 * 1.3 = 2.08 total scale
  // Additional growth driven only by transitions
  float extraScale = 1.0 + clamp(u_transitionProgress, 0.0, 1.0) * 1.5; // up to +150% during transition
  circleRadius *= extraScale;
  float c = circle(st + circleShapeNoise, circleRadius);
  outColor += c;

  vec2 startRotation = rotate2D(st, mod(u_time, 2.0 * PI));
  float circleStars = smoothstep(0.38, 0.39, noise(startRotation * 200.0) * 1.02);
  outColor *= circleStars;

  vec3 portal = outColor;

  t = abs(1.0 - sin(u_time * 0.2)) * 5.0 + 2.0;
  st += noise(st * 5.0) * t;

  float splatterFreq = 2.0;
  float redSplatter = smoothstep(0.15, 0.16, noise(st * splatterFreq + 10.0));
  float greenSplatter = smoothstep(0.11, 0.12, noise(st * splatterFreq * 2.0 + 20.0));
  float blueSplatter = smoothstep(0.13, 0.14, noise(st * splatterFreq * 3.0 + 30.0));

  // Desaturate splatter into a mask, then tint bluish-grey
  float splatterMask = (redSplatter + greenSplatter + blueSplatter) / 3.0;
  vec3 splatter = splatterMask * vec3(0.45, 0.52, 0.62); // bluish grey

  // Tint the portal contribution slightly cooler/bluer
  portal *= vec3(0.35, 0.42, 0.55);
  portal *= splatterMask;

  outColor = mix(portal, splatter, 1.0 - c);

  return vec4(outColor, 1.0) * color;
}
]])

function RewardsBackdropShader.getShader()
  return SHADER
end

return RewardsBackdropShader


