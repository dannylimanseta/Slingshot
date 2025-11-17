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

-- Word wrap text to fit within maxWidth
local function wrapText(text, font, maxWidth)
  -- Safety check: ensure maxWidth is reasonable
  if not maxWidth or maxWidth <= 0 then
    -- Fallback: return text as single line if maxWidth is invalid
    return { text }
  end
  
  local words = {}
  for word in text:gmatch("%S+") do
    table.insert(words, word)
  end
  
  local lines = {}
  local currentLine = ""
  
  for _, word in ipairs(words) do
    local testLine = currentLine == "" and word or currentLine .. " " .. word
    local width = font:getWidth(testLine)
    
    -- If adding this word would exceed maxWidth and we already have content, start a new line
    if width > maxWidth and currentLine ~= "" then
      table.insert(lines, currentLine)
      currentLine = word
    else
      -- Otherwise, add the word to current line (even if it's wider than maxWidth - better than breaking mid-word)
      currentLine = testLine
    end
  end
  
  if currentLine ~= "" then
    table.insert(lines, currentLine)
  end
  
  return lines
end

-- Build dynamic stat lines based on current level/effective values
local function buildDynamicStats(projectile, effective, maxWidth, font)
  local lines = {}
  local id = projectile.id or ""
  if id == "black_hole" then
    -- Black hole: show description with word wrapping
    if projectile.description then
      -- Use the full available width (don't artificially limit it)
      -- maxWidth should be around 220px based on card layout
      local safeMaxWidth = maxWidth or 220
      -- Only enforce minimum if maxWidth seems invalid, otherwise trust the calculation
      if safeMaxWidth < 100 then
        safeMaxWidth = 220 -- Fallback to expected width
      end
      local wrappedLines = wrapText(projectile.description, font, safeMaxWidth)
      for _, line in ipairs(wrappedLines) do
        table.insert(lines, line)
      end
    end
  elseif id == "multi_strike" then
    table.insert(lines, string.format("Fires %d projectiles", (effective and effective.count) or 3))
    if effective and effective.maxBounces then
      table.insert(lines, string.format("Bounces %d times", effective.maxBounces))
    end
    table.insert(lines, "Narrow cone")
  elseif id == "twin_strike" then
    table.insert(lines, string.format("Fires %d mirrored projectiles", (effective and effective.count) or 2))
    if effective and effective.maxBounces then
      table.insert(lines, string.format("Bounces %d times", effective.maxBounces))
    end
  elseif id == "pierce" then
    table.insert(lines, "Fires 1 projectile")
    if effective and effective.maxPierce then
      table.insert(lines, string.format("Pierces %d blocks", effective.maxPierce))
    end
  else
    -- Default (strike)
    table.insert(lines, "Fires 1 projectile")
    if effective and effective.maxBounces then
      table.insert(lines, string.format("Bounces %d times", effective.maxBounces))
    end
  end
  return lines
end

function ProjectileCard.new()
  -- Create fonts with specified sizes (scaled for crisp rendering)
  -- Increased sizes for better readability: Rarity: 14px (was 12px)
  local rarityFont = theme.newFont(14)
  -- Name/Level: 20px (was 18px)
  local nameFont = theme.newFont(20)
  -- Stats: 16px (was 14px)
  local statFont = theme.newFont(16)
  
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
  local cardW = 288
  local iconSize = 24 * 1.3
  local iconPadding = 12
  
  -- Calculate text area width
  local textStartX = iconPadding + iconSize + padding
  local maxWidth = cardW - textStartX - padding
  
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
  local effective = ProjectileManager.getEffective(projectile)
  local stats = buildDynamicStats(projectile, effective, maxWidth, self.statFont)
  local statLineHeight = self.statFont:getHeight() + 2
  local bonus = (effective and effective.baseDamage and 1 or 0)
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
-- @param projectileId string - ID of projectile to display (e.g., "strike")
-- @param alpha number - Optional alpha value for fade effect (0.0 to 1.0, defaults to 1.0)
function ProjectileCard:draw(x, y, projectileId, alpha)
  if not projectileId then return end
  alpha = alpha or 1.0
  
  -- Ensure predictable render state (so alpha blending behaves correctly)
  love.graphics.push("all")
  love.graphics.setBlendMode("alpha")
  
  local projectile = ProjectileManager.getProjectile(projectileId)
  if not projectile then return end
  local effective = ProjectileManager.getEffective(projectile)
  
  -- Card dimensions
  local cardW = 288 -- Increased by 20% from 240
  local cardH = self:calculateHeight(projectile) -- Dynamic height
  local padding = 12
  local iconSize = 24 * 1.3 -- Increased by 30% (was 24)
  local iconPadding = 12
  local cornerRadius = 8
  
  -- Card background (black) - increased alpha for better readability
  love.graphics.setColor(0, 0, 0, 0.9 * alpha)
  love.graphics.rectangle("fill", x, y, cardW, cardH, cornerRadius, cornerRadius)
  
  -- Border/highlight - use rarity color for border at 30% alpha
  local rarity = projectile.rarity or "COMMON"
  local rarityColor = RARITY_COLORS[rarity] or RARITY_COLORS.COMMON
  love.graphics.setColor(rarityColor[1], rarityColor[2], rarityColor[3], 0.3 * alpha)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, cardW, cardH, cornerRadius, cornerRadius)
  
  -- Icon on the left (anchored to top-left, shifted up)
  local iconX = x + iconPadding
  local iconY = y + padding
  
  if projectile.icon then
    local iconImg = self:loadIcon(projectile.icon)
    if iconImg then
      love.graphics.setColor(1, 1, 1, alpha)
      local iw, ih = iconImg:getWidth(), iconImg:getHeight()
      local scale = iconSize / math.max(iw, ih)
      -- Draw anchored at top-left inside the card
      love.graphics.draw(iconImg, iconX, iconY, 0, scale, scale)
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
  -- Use full available width for text (accounting for icon and padding)
  local textW = cardW - textStartX - padding
  -- For black hole descriptions, ensure we use the full width available
  local stats = buildDynamicStats(projectile, effective, textW, self.statFont)
  local statsStartY = nameY + nameFontH + 4
  love.graphics.setColor(1, 1, 1, 0.9 * alpha)
  love.graphics.setFont(self.statFont)
  local statLineHeight = self.statFont:getHeight() + 2
  
  local lineIndex = 0
  -- Base damage line first (if available)
  if effective and effective.baseDamage then
    lineIndex = lineIndex + 1
    local dmgText = tostring(effective.baseDamage) .. " Damage"
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

