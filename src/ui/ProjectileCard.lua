local theme = require("theme")
local config = require("config")
local ProjectileManager = require("managers.ProjectileManager")

local ProjectileCard = {}
ProjectileCard.__index = ProjectileCard

-- Rarity colors (RGBA)
local RARITY_COLORS = {
  COMMON = { 0.75, 0.75, 0.75, 1 },    -- Light grey
  UNCOMMON = { 45/255, 159/255, 81/255, 1 }, -- #2D9F51 Green
  RARE = { 0.3, 0.6, 1, 1 },           -- Blue
  EPIC = { 0.8, 0.3, 1, 1 },           -- Purple
  LEGENDARY = { 1, 0.65, 0.2, 1 },     -- Gold/Orange
}

function ProjectileCard.new()
  -- Create fonts with specified sizes
  local fontPath = (config.assets and config.assets.fonts and config.assets.fonts.ui) or nil
  local rarityFont = nil
  local nameFont = nil
  local statFont = nil
  
  if fontPath then
    -- Rarity: 12px
    local ok1, f1 = pcall(love.graphics.newFont, fontPath, 12)
    if ok1 then rarityFont = f1 end
    -- Name/Level: 18px (larger)
    local ok2, f2 = pcall(love.graphics.newFont, fontPath, 18)
    if ok2 then
      nameFont = f2
    end
    -- Stats: 14px
    local ok3, f3 = pcall(love.graphics.newFont, fontPath, 14)
    if ok3 then
      statFont = f3
    end
  end
  
  if not rarityFont then
    rarityFont = love.graphics.newFont(12)
  end
  if not nameFont then
    nameFont = love.graphics.newFont(18)
  end
  if not statFont then
    statFont = love.graphics.newFont(14)
  end
  
  return setmetatable({
    iconImage = nil, -- Cached icon image
    rarityFont = rarityFont, -- 12px font for rarity
    nameFont = nameFont, -- 14px font for name and level
    statFont = statFont, -- 14px font for stats
  }, ProjectileCard)
end

-- Load and cache icon image
function ProjectileCard:loadIcon(iconPath)
  if not iconPath then return nil end
  local ok, img = pcall(love.graphics.newImage, iconPath)
  if ok then
    self.iconImage = img
    return img
  end
  return nil
end

-- Calculate card height based on content
-- @param projectile table - Projectile data
-- @return number - Calculated card height
function ProjectileCard:calculateHeight(projectile)
  local padding = 12
  local spacing = 4
  
  -- Top padding
  local height = padding
  
  -- Rarity text height
  height = height + self.rarityFont:getHeight()
  
  -- Spacing after rarity
  height = height + spacing
  
  -- Name text height
  height = height + self.nameFont:getHeight()
  
  -- Spacing after name
  height = height + spacing
  
  -- Stats area (include baseDamage line if present)
  local stats = projectile.stats or {}
  local statLineHeight = self.statFont:getHeight() + 2
  local bonus = (projectile.baseDamage and 1 or 0)
  local statCount = math.min(#stats + bonus, 10) -- Limit to 10 lines max for safety
  if statCount > 0 then
    height = height + (statCount * statLineHeight)
  end
  
  -- Bottom padding
  height = height + padding
  
  -- Ensure minimum height fits icon (24px * 1.3 = 31.2px + padding)
  local minHeight = 24 * 1.3 + padding * 2
  return math.max(height, minHeight)
end

-- Draw the projectile card at the specified position
-- @param x number - Left edge position
-- @param y number - Top edge position
-- @param projectileId string - ID of projectile to display (e.g., "qi_orb")
-- @param alpha number - Optional alpha value for fade effect (0.0 to 1.0, defaults to 1.0)
function ProjectileCard:draw(x, y, projectileId, alpha)
  if not projectileId then return end
  alpha = alpha or 1.0
  
  -- Ensure predictable render state (so alpha blending behaves correctly)
  love.graphics.push("all")
  love.graphics.setBlendMode("alpha")
  
  local projectile = ProjectileManager.getProjectile(projectileId)
  if not projectile then return end
  
  -- Card dimensions
  local cardW = 280
  local cardH = self:calculateHeight(projectile) -- Dynamic height
  local padding = 12
  local iconSize = 24 * 1.3 -- Increased by 30% (was 24)
  local iconPadding = 12
  local cornerRadius = 8
  
  -- Card background (black) - lower alpha for more see-through
  love.graphics.setColor(0, 0, 0, 0.3 * alpha)
  love.graphics.rectangle("fill", x, y, cardW, cardH, cornerRadius, cornerRadius)
  
  -- Border/highlight - use rarity color for UNCOMMON, otherwise white with 10% alpha
  local rarity = projectile.rarity or "COMMON"
  local rarityColor = RARITY_COLORS[rarity] or RARITY_COLORS.COMMON
  if rarity == "UNCOMMON" then
    -- Use rarity color for uncommon border
    love.graphics.setColor(rarityColor[1], rarityColor[2], rarityColor[3], 0.3 * alpha)
  else
    -- Default white border with 10% alpha
    love.graphics.setColor(1, 1, 1, 0.1 * alpha)
  end
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, cardW, cardH, cornerRadius, cornerRadius)
  
  -- Icon on the left
  local iconX = x + iconPadding
  local iconY = y + (cardH - iconSize) * 0.5
  
  if projectile.icon then
    local iconImg = self:loadIcon(projectile.icon)
    if iconImg then
      love.graphics.setColor(1, 1, 1, alpha)
      local iw, ih = iconImg:getWidth(), iconImg:getHeight()
      local scale = iconSize / math.max(iw, ih)
      love.graphics.draw(iconImg, iconX + iconSize * 0.5, iconY + iconSize * 0.5, 0, scale, scale, iw * 0.5, ih * 0.5)
    else
      -- Fallback: draw circle - apply alpha
      love.graphics.setColor(0.9, 0.85, 0.7, alpha) -- Light beige/yellowish
      love.graphics.circle("fill", iconX + iconSize * 0.5, iconY + iconSize * 0.5, iconSize * 0.4)
    end
  end
  
  -- Text content area (right of icon)
  local textStartX = iconX + iconSize + padding
  local textY = y + padding
  local textW = cardW - textStartX - padding
  
  -- Rarity text - use rarity color, uppercase, 50% size font - apply alpha
  local rarity = projectile.rarity or "COMMON"
  local rarityColor = RARITY_COLORS[rarity] or RARITY_COLORS.COMMON
  love.graphics.setFont(self.rarityFont)
  -- Use rarity color for text, fallback to light grey for COMMON
  if rarity == "COMMON" then
    love.graphics.setColor(0.6, 0.6, 0.6, 0.9 * alpha) -- Light grey for COMMON
  else
    love.graphics.setColor(rarityColor[1], rarityColor[2], rarityColor[3], 0.9 * alpha)
  end
  local rarityText = string.upper(rarity)
  local rarityFontH = self.rarityFont:getHeight()
  love.graphics.print(rarityText, textStartX, textY)
  
  -- Projectile name (bold white, 50% size font) - apply alpha
  local nameY = textY + rarityFontH + 4
  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.setFont(self.nameFont)
  local nameText = projectile.name or "Unknown"
  local nameFontH = self.nameFont:getHeight()
  theme.drawTextWithOutline(nameText, textStartX, nameY, 1, 1, 1, alpha, 1)
  
  -- Level indicator (top right, aligned with name, 50% size font) - apply alpha
  local levelText = "LV " .. tostring(projectile.level or 1)
  local levelTextW = self.nameFont:getWidth(levelText)
  local levelX = x + cardW - padding - levelTextW
  love.graphics.setColor(1, 1, 1, alpha)
  theme.drawTextWithOutline(levelText, levelX, nameY, 1, 1, 1, alpha, 1)
  
  -- Stats (below name, dynamic based on content) - apply alpha
  local stats = projectile.stats or {}
  local statsStartY = nameY + nameFontH + 4
  love.graphics.setColor(1, 1, 1, 0.9 * alpha)
  love.graphics.setFont(self.statFont)
  local statLineHeight = self.statFont:getHeight() + 2
  
  local lineIndex = 0
  -- Base damage line first (if available)
  if projectile.baseDamage then
    lineIndex = lineIndex + 1
    local dmgText = tostring(projectile.baseDamage) .. " Damage"
    theme.drawTextWithOutline(dmgText, textStartX, statsStartY + (lineIndex - 1) * statLineHeight, 1, 1, 1, 0.9 * alpha, 1)
  end
  -- Draw remaining stats
  for _, statText in ipairs(stats) do
    lineIndex = lineIndex + 1
    theme.drawTextWithOutline(statText, textStartX, statsStartY + (lineIndex - 1) * statLineHeight, 1, 1, 1, 0.9 * alpha, 1)
  end
  
  -- Reset graphics state
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.pop()
end

return ProjectileCard

