-- Grid-based fade transition shader
-- Adapted from Shadertoy-style GLSL to LÖVE shader format

local TransitionShader = {}

-- Grid fade transition shader
-- fadeType: 0 = vertical, 1 = horizontal, 2 = center
local TRANSITION_SHADER = love.graphics.newShader([[
extern float u_fadeTimer;
extern float u_fadeType; // 0 = vertical, 1 = horizontal, 2 = center
extern float u_gridWidth;
extern float u_gridHeight;
extern Image u_previousScene;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    // Use UV coordinates (normalized 0-1) instead of screen coordinates
    // This ensures the shader works correctly regardless of canvas/screen size
    vec2 uv_coord = uv;
    
    float fadeTimer = u_fadeTimer;
    
    // Scale the uvs to integers to scale directly with the equation
    vec2 posI = vec2(uv_coord.x * u_gridWidth * 2.0, uv_coord.y * u_gridHeight * 2.0);
    // Modulo the position to clamp it to repeat the pattern
    vec2 pos = mod(posI, 2.0) - vec2(1.0, 1.0);
    float size;
    
    posI = vec2(floor(posI.x / 2.0) / u_gridWidth, floor(posI.y / 2.0) / u_gridHeight);
    
    // Calculate size based on fade type
    // Size should be large when fadeTimer < position (showing previous scene)
    // Size should be small when fadeTimer > position (showing current scene)
    float diff;
    if (u_fadeType < 0.5) {
        // Vertical fade (bottom-to-top)
        diff = fadeTimer - (1.0 - posI.y);
    } else if (u_fadeType < 1.5) {
        // Horizontal fade
        diff = fadeTimer - posI.x;
    } else {
        // Center fade
        diff = fadeTimer - (abs(posI.x - 0.5) + abs(posI.y - 0.5));
    }
    
    // Only show previous scene when fadeTimer hasn't reached this position yet
    // When diff is negative, fadeTimer is before position, so size should be large
    // When diff is positive, fadeTimer has passed position, so size should be small
    if (diff < 0.0) {
        size = abs(pow(diff, 3.0));
    } else {
        size = 0.0; // Small size - show current scene
    }
    
    // Sample both scenes
    vec4 currentCol = Texel(tex, uv);
    vec4 prevCol = Texel(u_previousScene, uv);
    
    // Absolute value method for expressing the area of a rotatable square
    // If inside the diamond/square pattern, show previous scene, otherwise show current scene
    // This creates a wipe effect where the pattern reveals the new scene
    if (abs(pos.x) + abs(pos.y) < size) {
        return prevCol;
    } else {
        return currentCol;
    }
}
]])

function TransitionShader.getShader()
  return TRANSITION_SHADER
end

return TransitionShader

