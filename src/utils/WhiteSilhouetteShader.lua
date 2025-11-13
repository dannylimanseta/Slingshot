-- White silhouette shader for hit flashes (solid white fill using sprite alpha)

local WhiteSilhouetteShader = {}

local SHADER = love.graphics.newShader([[ 
extern float u_alpha; // Flash intensity 0..1

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec4 texel = Texel(tex, uv);
  float a = texel.a * color.a * u_alpha;
  return vec4(1.0, 1.0, 1.0, a);
}
]])

function WhiteSilhouetteShader.getShader()
  return SHADER
end

return WhiteSilhouetteShader








