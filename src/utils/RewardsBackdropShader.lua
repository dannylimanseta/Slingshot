local RewardsBackdropShader = {}

local SHADER = love.graphics.newShader([[ 
extern float u_time;
extern vec2 u_resolution;
extern float u_transitionProgress; // kept for compatibility, not used

#define PI 3.14159265359

// Dark grayscale palette
vec3 col1 = vec3(0.35, 0.35, 0.35);
vec3 col2 = vec3(0.22, 0.22, 0.22);
vec3 col3 = vec3(0.45, 0.45, 0.45);

float disk(vec2 r, vec2 center, float radius) {
	return 1.0 - smoothstep(radius - 0.008, radius + 0.008, length(r - center));
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc){
	// Map Shadertoy uniforms
	float iTime = u_time;
	vec2 iResolution = u_resolution;
	vec2 fragCoord = sc;

	// Slow down overall animation speed
	float ts = 0.35;
	float t = iTime * (2.0 * ts);
	vec2 r = (2.0 * fragCoord.xy - iResolution.xy) / iResolution.y;

	r *= 1.0 + 0.05 * sin(r.x * 5.0 + iTime * ts) + 0.05 * sin(r.y * 3.0 + iTime * ts);
	r *= 1.0 + 0.2 * length(r);

	float side = 0.5;
	vec2 r2 = mod(r, side);
	vec2 r3 = r2 - side / 2.0;

	float i = floor(r.x / side) + 2.0;
	float j = floor(r.y / side) + 4.0;
	float ii = r.x / side + 2.0;
	float jj = r.y / side + 4.0;	
	
	// Start darker
	vec3 pix = vec3(0.10);
	
	float rad, disks;
		
	rad = 0.15 + 0.05 * sin(t + ii * jj);
	disks = disk(r3, vec2(0.0, 0.0), rad);
	pix = mix(pix, col2, disks);

	float speed = 0.6;
	float tt = iTime * speed + 0.1 * i + 0.08 * j;
	float stopEveryAngle = PI / 2.0;
	float stopRatio = 0.7;
	float t1 = (floor(tt) + smoothstep(0.0, 1.0 - stopRatio, fract(tt))) * stopEveryAngle;
		
	float x = -0.07 * cos(t1 + i);
	float y = 0.055 * (sin(t1 + j) + cos(t1 + i));
	rad = 0.1 + 0.05 * sin(t + i + j);
	disks = disk(r3, vec2(x, y), rad);
	pix = mix(pix, col1, disks);
	
	rad = 0.2 + 0.05 * sin(t * (1.0 + 0.01 * i));
	disks = disk(r3, vec2(0.0, 0.0), rad);
	pix += 0.2 * col3 * disks * sin(t + i * j + i);

	pix -= smoothstep(0.3, 5.5, length(r));
	// Convert to grayscale and darken
	float lum = dot(pix, vec3(0.299, 0.587, 0.114));
	pix = vec3(lum) * 0.6;
	// Add a subtle cool-blue tint to the grayscale
	pix *= vec3(0.9, 0.95, 1.15);
	// Reference u_transitionProgress to prevent driver stripping the uniform
	if (u_transitionProgress < -1.0) {
		pix *= 1.0;
	}
	return vec4(pix, 1.0) * color;
}
]])

function RewardsBackdropShader.getShader()
  return SHADER
end

return RewardsBackdropShader


