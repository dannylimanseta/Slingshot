local config = require("config")
local theme = require("theme")
local battle_profiles = require("data.battle_profiles")

-- Shared sprites for blocks (same as Block.lua)
local SPRITES = { attack = nil, armor = nil, crit = nil, soul = nil }
do
  local imgs = (config.assets and config.assets.images) or {}
  if imgs.block_attack then
    local ok, img = pcall(love.graphics.newImage, imgs.block_attack)
    if ok then SPRITES.attack = img end
  end
  if imgs.block_defend then
    local ok, img = pcall(love.graphics.newImage, imgs.block_defend)
    if ok then SPRITES.armor = img end
  end
  if imgs.block_crit then
    local ok, img = pcall(love.graphics.newImage, imgs.block_crit)
    if ok then SPRITES.crit = img end
  end
  if imgs.block_soul then
    local ok, img = pcall(love.graphics.newImage, imgs.block_soul)
    if ok then SPRITES.soul = img end
  end
end

local FormationEditorScene = {}
FormationEditorScene.__index = FormationEditorScene

function FormationEditorScene.new()
  return setmetatable({
    -- Formation data: array of {x, y, kind, hp} where x,y are normalized (0-1)
    blocks = {},
    currentBlockType = "damage", -- "damage", "armor", "crit", "soul"
    currentBattleType = battle_profiles.Types.DEFAULT,
    -- Playfield bounds
    playfieldX = 0,
    playfieldY = 0,
    playfieldW = 0,
    playfieldH = 0,
    actualPlayfieldW = 0, -- Actual breakout area width (matches game exactly, without spacing factor)
    -- Mouse tracking
    mouseX = 0,
    mouseY = 0,
    hoveredBlockIndex = nil,
    selectedBlockIndex = nil, -- Currently selected block
    deleteMode = false, -- When true, clicking blocks deletes them instead of selecting
    -- Status
    statusMessage = "",
    statusMessageTimer = 0,
    -- Previous scene reference (to return to)
    previousScene = nil,
  }, FormationEditorScene)
end

function FormationEditorScene:load()
  -- Calculate playfield bounds exactly matching BlockManager:loadPredefinedFormation
  -- BlockManager receives the center canvas width directly from GameplayScene
  -- Use LayoutManager to get exact same dimensions as SplitScene uses
  local LayoutManager = require("managers.LayoutManager")
  local layoutManager = LayoutManager.new()
  
  -- Use love.graphics.getDimensions() to match SplitScene exactly
  local w, h = love.graphics.getDimensions()
  local margin = config.playfield.margin
  
  -- Get center rect using LayoutManager (matches SplitScene exactly)
  local centerRect = layoutManager:getCenterRect(w, h)
  local centerW = centerRect.w -- This is math.floor(w * centerWidthFactor)
  local centerX = centerRect.x -- This is math.floor((w - centerW) * 0.5)
  
  -- Match BlockManager exactly: it receives centerW as width and h as height
  -- BlockManager calculates: playfieldX = margin, playfieldY = margin
  -- playfieldW = width - 2 * margin, playfieldH = height * maxHeightFactor - margin
  -- Where width = centerW and height = h (full screen height)
  local maxHeightFactor = (config.playfield and config.playfield.maxHeightFactor) or 0.65
  self.playfieldX = centerX + margin -- Offset by centerX to position on screen
  self.playfieldY = margin
  self.playfieldW = centerW - 2 * margin -- Use center canvas width, not full screen width
  self.actualPlayfieldW = self.playfieldW -- Store actual breakout area width (matches game exactly)
  self.playfieldH = h * maxHeightFactor - margin -- Use same height and maxHeightFactor as BlockManager
  
  -- Load existing formation for current battle type
  self:loadFormation()
  
  self.statusMessage = "Formation Editor - Click to place/select, Right-click/Delete to remove, 1-4 to change type, S to save, L to load, G to toggle grid, ESC to exit"
  self.statusMessageTimer = 5.0 -- Show for 5 seconds
end

function FormationEditorScene:update(dt)
  -- Update status message timer
  if self.statusMessageTimer > 0 then
    self.statusMessageTimer = self.statusMessageTimer - dt
  end
  
  -- Update hovered block index
  self.hoveredBlockIndex = nil
  local scaleMul = config.blocks.spriteScale or 1
  local blockSize = config.blocks.baseSize * scaleMul
  local halfSize = blockSize * 0.5
  
  -- Apply horizontal spacing factor to match BlockManager
  local horizontalSpacingFactor = (config.playfield and config.playfield.horizontalSpacingFactor) or 1.0
  local effectivePlayfieldW = self.playfieldW * horizontalSpacingFactor
  local playfieldXOffset = self.playfieldW * (1 - horizontalSpacingFactor) * 0.5
  
  for i, block in ipairs(self.blocks) do
    local bx = self.playfieldX + playfieldXOffset + block.x * effectivePlayfieldW
    local by = self.playfieldY + block.y * self.playfieldH
    local dx = math.abs(self.mouseX - bx)
    local dy = math.abs(self.mouseY - by)
    if dx <= halfSize and dy <= halfSize then
      self.hoveredBlockIndex = i
      break
    end
  end
end

function FormationEditorScene:draw()
  local width, height = love.graphics.getDimensions()
  
  -- Background
  love.graphics.setColor(0.05, 0.05, 0.08, 1)
  love.graphics.rectangle("fill", 0, 0, width, height)
  
  -- Draw playfield bounds (show actual breakout area width, matching game exactly)
  love.graphics.setColor(0.2, 0.2, 0.3, 1)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", self.playfieldX, self.playfieldY, self.actualPlayfieldW, self.playfieldH)
  
  -- Draw grid if enabled
  if config.blocks.gridSnap.showGrid then
    self:drawGrid()
  end
  
  -- Draw blocks
  local scaleMul = config.blocks.spriteScale or 1
  local blockSize = config.blocks.baseSize * scaleMul
  
  -- Apply horizontal spacing factor to match BlockManager
  local horizontalSpacingFactor = (config.playfield and config.playfield.horizontalSpacingFactor) or 1.0
  local effectivePlayfieldW = self.playfieldW * horizontalSpacingFactor
  local playfieldXOffset = self.playfieldW * (1 - horizontalSpacingFactor) * 0.5
  
  for i, block in ipairs(self.blocks) do
    local bx = self.playfieldX + playfieldXOffset + block.x * effectivePlayfieldW
    local by = self.playfieldY + block.y * self.playfieldH
    
    -- Highlight selected block (stronger than hover)
    local isSelected = (i == self.selectedBlockIndex)
    local isHovered = (i == self.hoveredBlockIndex and not isSelected)
    
    if isSelected then
      love.graphics.setColor(0.2, 0.6, 1, 0.5) -- Blue selection highlight
      love.graphics.rectangle("fill", bx - blockSize * 0.5 - 6, by - blockSize * 0.5 - 6, blockSize + 12, blockSize + 12)
      love.graphics.setColor(0.4, 0.8, 1, 1) -- Blue selection outline
      love.graphics.setLineWidth(3)
      love.graphics.rectangle("line", bx - blockSize * 0.5 - 6, by - blockSize * 0.5 - 6, blockSize + 12, blockSize + 12)
    elseif isHovered then
      love.graphics.setColor(1, 1, 1, 0.3)
      love.graphics.rectangle("fill", bx - blockSize * 0.5 - 4, by - blockSize * 0.5 - 4, blockSize + 8, blockSize + 8)
    end
    
    -- Draw block sprite
    self:drawBlock(bx, by, block.kind, blockSize)
  end
  
  -- Draw cursor preview (if within playfield)
  if self:isMouseInPlayfield() then
    local normX = self:screenToNormalizedX(self.mouseX)
    local normY = self:screenToNormalizedY(self.mouseY)
    
    -- Apply grid snapping to preview
    if config.blocks.gridSnap.enabled then
      normX, normY = self:snapToGrid(normX, normY)
    end
    
    local previewX = self.playfieldX + playfieldXOffset + normX * effectivePlayfieldW
    local previewY = self.playfieldY + normY * self.playfieldH
    
    -- Check if preview block would exceed actual playfield bounds
    local halfSize = blockSize * 0.5
    local blockLeft = previewX - halfSize
    local blockRight = previewX + halfSize
    local actualPlayfieldLeft = self.playfieldX
    local actualPlayfieldRight = self.playfieldX + self.actualPlayfieldW
    local canPlace = blockLeft >= actualPlayfieldLeft and blockRight <= actualPlayfieldRight
    
    -- Draw preview with color indicating if placement is allowed
    if canPlace then
      love.graphics.setColor(1, 1, 1, 0.5)
    else
      love.graphics.setColor(1, 0.3, 0.3, 0.5) -- Red tint if cannot place
    end
    self:drawBlock(previewX, previewY, self.currentBlockType, blockSize)
  end
  
  -- Draw UI
  self:drawUI()
  
  love.graphics.setColor(1, 1, 1, 1)
end

function FormationEditorScene:drawBlock(x, y, kind, size)
  local sprite
  if kind == "armor" then
    sprite = SPRITES.armor
  elseif kind == "crit" then
    sprite = SPRITES.crit or SPRITES.attack
  elseif kind == "soul" then
    sprite = SPRITES.soul or SPRITES.attack
  else
    sprite = SPRITES.attack
  end
  
  if sprite then
    local iw, ih = sprite:getWidth(), sprite:getHeight()
    -- Match Block:draw() exactly: s = self.size / max(iw, ih), then s = s * spriteScale
    local baseSize = config.blocks.baseSize
    local s = baseSize / math.max(1, math.max(iw, ih))
    local mul = (config.blocks and config.blocks.spriteScale) or 1
    s = s * mul
    local dx = x - iw * s * 0.5
    local dy = y - ih * s * 0.5
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sprite, dx, dy, 0, s, s)
  else
    -- Fallback to colored rectangle
    local halfSize = size * 0.5
    if kind == "armor" then
      love.graphics.setColor(theme.colors.blockArmor[1] or 0.35, theme.colors.blockArmor[2] or 0.75, theme.colors.blockArmor[3] or 0.95, 1)
    else
      love.graphics.setColor(theme.colors.block[1] or 0.95, theme.colors.block[2] or 0.6, theme.colors.block[3] or 0.25, 1)
    end
    love.graphics.rectangle("fill", x - halfSize, y - halfSize, size, size, 4, 4)
    love.graphics.setColor(theme.colors.blockOutline[1] or 0, theme.colors.blockOutline[2] or 0, theme.colors.blockOutline[3] or 0, 0.2)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x - halfSize, y - halfSize, size, size, 4, 4)
  end
end

function FormationEditorScene:drawUI()
  local width = config.video.virtualWidth
  local font = theme.fonts.base
  
  -- Current block type indicator
  local typeNames = {
    damage = "Damage",
    armor = "Armor",
    crit = "Crit",
    soul = "Soul"
  }
  local typeName = typeNames[self.currentBlockType] or "Unknown"
  local typeText = "Block Type: " .. typeName .. " (Press 1-4 to change)"
  theme.drawTextWithOutline(typeText, 20, 20, 1, 1, 1, 1, 2)
  
  -- Block count
  local countText = "Blocks: " .. #self.blocks
  theme.drawTextWithOutline(countText, 20, 50, 1, 1, 1, 1, 2)
  
  -- Battle type
  local battleText = "Battle Type: " .. self.currentBattleType
  theme.drawTextWithOutline(battleText, 20, 80, 1, 1, 1, 1, 2)
  
  -- Status message
  if self.statusMessageTimer > 0 then
    local height = config.video.virtualHeight
    local alpha = math.min(1, self.statusMessageTimer / 0.5) -- Fade out in last 0.5 seconds
    theme.drawTextWithOutline(self.statusMessage, width * 0.5, height - 40, 1, 1, 1, alpha, 2)
  end
  
  -- Instructions
  local instructions = {
    "1-4: Change block type",
    "S: Save formation",
    "L: Load formation",
    "G: Toggle grid",
    "0: Toggle delete mode",
    "ESC: Exit editor"
  }
  for i, inst in ipairs(instructions) do
    theme.drawTextWithOutline(inst, width - 250, 20 + (i - 1) * 30, 0.8, 0.8, 0.8, 0.7, 2)
  end
  
  -- Show selection info or delete mode status
  if self.deleteMode then
    theme.drawTextWithOutline("DELETE MODE: Click blocks to delete", 20, 110, 1, 0.3, 0.3, 1, 2)
  elseif self.selectedBlockIndex then
    local block = self.blocks[self.selectedBlockIndex]
    local infoText = string.format("Selected: %s block (Delete to remove)", block.kind)
    theme.drawTextWithOutline(infoText, 20, 110, 0.4, 0.8, 1, 1, 2)
  end
end

function FormationEditorScene:mousepressed(x, y, button)
  self.mouseX = x
  self.mouseY = y
  
  if button == 1 then -- Left click
    if self:isMouseInPlayfield() then
      if self.hoveredBlockIndex then
        if self.deleteMode then
          -- Delete mode: delete the block
          local removedIndex = self.hoveredBlockIndex
          table.remove(self.blocks, removedIndex)
          -- Clear selection if selected block was removed
          if self.selectedBlockIndex == removedIndex then
            self.selectedBlockIndex = nil
          elseif self.selectedBlockIndex and self.selectedBlockIndex > removedIndex then
            -- Adjust selection index if a block before it was removed
            self.selectedBlockIndex = self.selectedBlockIndex - 1
          end
          self:showStatus("Block deleted")
        else
          -- Normal mode: select it
          self.selectedBlockIndex = self.hoveredBlockIndex
          self:showStatus("Block selected")
        end
      else
        -- Click on empty space: place new block
        local normX = self:screenToNormalizedX(x)
        local normY = self:screenToNormalizedY(y)
        
        -- Apply grid snapping if enabled
        if config.blocks.gridSnap.enabled then
          normX, normY = self:snapToGrid(normX, normY)
        end
        
        -- Check if block would exceed actual playfield bounds
        local horizontalSpacingFactor = (config.playfield and config.playfield.horizontalSpacingFactor) or 1.0
        local effectivePlayfieldW = self.playfieldW * horizontalSpacingFactor
        local playfieldXOffset = self.playfieldW * (1 - horizontalSpacingFactor) * 0.5
        local blockX = self.playfieldX + playfieldXOffset + normX * effectivePlayfieldW
        local blockY = self.playfieldY + normY * self.playfieldH
        
        -- Calculate block size for bounds checking
        local scaleMul = config.blocks.spriteScale or 1
        local blockSize = config.blocks.baseSize * scaleMul
        local halfSize = blockSize * 0.5
        
        -- Check if block fits within actual playfield bounds (horizontal and vertical)
        local blockLeft = blockX - halfSize
        local blockRight = blockX + halfSize
        local blockTop = blockY - halfSize
        local blockBottom = blockY + halfSize
        local actualPlayfieldLeft = self.playfieldX
        local actualPlayfieldRight = self.playfieldX + self.actualPlayfieldW
        local actualPlayfieldTop = self.playfieldY
        local actualPlayfieldBottom = self.playfieldY + self.playfieldH
        
        if blockLeft >= actualPlayfieldLeft and blockRight <= actualPlayfieldRight and
           blockTop >= actualPlayfieldTop and blockBottom <= actualPlayfieldBottom then
          table.insert(self.blocks, {
            x = normX,
            y = normY,
            kind = self.currentBlockType,
            hp = 1
          })
          self:showStatus("Block placed")
          -- Clear selection after placing
          self.selectedBlockIndex = nil
        else
          self:showStatus("Cannot place block: exceeds playfield bounds")
        end
      end
    else
      -- Click outside playfield: clear selection
      self.selectedBlockIndex = nil
    end
  elseif button == 2 then -- Right click
    if self.hoveredBlockIndex then
      -- Remove block
      local removedIndex = self.hoveredBlockIndex
      table.remove(self.blocks, removedIndex)
      -- Clear selection if selected block was removed
      if self.selectedBlockIndex == removedIndex then
        self.selectedBlockIndex = nil
      elseif self.selectedBlockIndex and self.selectedBlockIndex > removedIndex then
        -- Adjust selection index if a block before it was removed
        self.selectedBlockIndex = self.selectedBlockIndex - 1
      end
      self:showStatus("Block removed")
    end
  end
end

function FormationEditorScene:mousemoved(x, y, dx, dy)
  self.mouseX = x
  self.mouseY = y
end

function FormationEditorScene:keypressed(key, scancode, isRepeat)
  if key == "escape" then
    -- Exit editor and restart the game
    -- Signal to main.lua to restart with a new game
    return "restart"
  elseif key == "1" then
    self.currentBlockType = "damage"
    self:showStatus("Block type: Damage")
  elseif key == "2" then
    self.currentBlockType = "armor"
    self:showStatus("Block type: Armor")
  elseif key == "3" then
    self.currentBlockType = "crit"
    self:showStatus("Block type: Crit")
  elseif key == "4" then
    self.currentBlockType = "soul"
    self:showStatus("Block type: Soul")
  elseif key == "s" then
    self:saveFormation()
  elseif key == "l" then
    self:loadFormation()
  elseif key == "delete" or key == "backspace" then
    -- Delete selected block, or hovered block if no selection
    local blockToDelete = self.selectedBlockIndex or self.hoveredBlockIndex
    if blockToDelete then
      table.remove(self.blocks, blockToDelete)
      -- Clear selection
      self.selectedBlockIndex = nil
      self:showStatus("Block removed")
    end
  elseif key == "g" then
    -- Toggle grid visibility
    config.blocks.gridSnap.showGrid = not config.blocks.gridSnap.showGrid
    self:showStatus(config.blocks.gridSnap.showGrid and "Grid shown" or "Grid hidden")
  elseif key == "0" then
    -- Toggle delete mode
    self.deleteMode = not self.deleteMode
    self.selectedBlockIndex = nil -- Clear selection when toggling delete mode
    self:showStatus(self.deleteMode and "Delete mode ON (click blocks to delete)" or "Delete mode OFF")
  end
end

function FormationEditorScene:isMouseInPlayfield()
  -- Check if mouse is within actual breakout area bounds (matching game exactly)
  return self.mouseX >= self.playfieldX and self.mouseX <= self.playfieldX + self.actualPlayfieldW and
         self.mouseY >= self.playfieldY and self.mouseY <= self.playfieldY + self.playfieldH
end

function FormationEditorScene:screenToNormalizedX(screenX)
  -- Account for horizontal spacing factor when converting screen to normalized coordinates
  local horizontalSpacingFactor = (config.playfield and config.playfield.horizontalSpacingFactor) or 1.0
  local effectivePlayfieldW = self.playfieldW * horizontalSpacingFactor
  local playfieldXOffset = self.playfieldW * (1 - horizontalSpacingFactor) * 0.5
  local relativeX = screenX - (self.playfieldX + playfieldXOffset)
  return math.max(0, math.min(1, relativeX / effectivePlayfieldW))
end

function FormationEditorScene:screenToNormalizedY(screenY)
  local relativeY = screenY - self.playfieldY
  return math.max(0, math.min(1, relativeY / self.playfieldH))
end

function FormationEditorScene:showStatus(message)
  self.statusMessage = message
  self.statusMessageTimer = 2.0
end

function FormationEditorScene:snapToGrid(normX, normY)
  -- Account for horizontal spacing factor
  local horizontalSpacingFactor = (config.playfield and config.playfield.horizontalSpacingFactor) or 1.0
  local effectivePlayfieldW = self.playfieldW * horizontalSpacingFactor
  local playfieldXOffset = self.playfieldW * (1 - horizontalSpacingFactor) * 0.5
  local effectivePlayfieldX = self.playfieldX + playfieldXOffset
  
  -- Convert normalized coordinates to screen pixels (using effective playfield)
  local screenX = effectivePlayfieldX + normX * effectivePlayfieldW
  local screenY = self.playfieldY + normY * self.playfieldH
  
  -- Calculate centered grid position (matching drawGrid)
  local cellSize = config.blocks.gridSnap.cellSize
  local numCells = math.floor(effectivePlayfieldW / cellSize)
  local gridWidth = numCells * cellSize
  local gridOffset = (effectivePlayfieldW - gridWidth) * 0.5
  local gridStartX = effectivePlayfieldX + gridOffset
  
  -- Snap to centered grid (no clamping - placement will be prevented if out of bounds)
  local snappedX = math.floor((screenX - gridStartX) / cellSize + 0.5) * cellSize
  local snappedY = math.floor((screenY - self.playfieldY) / cellSize + 0.5) * cellSize
  
  -- Convert snapped position to absolute screen coordinates (snappedX is relative to gridStartX)
  local absoluteX = gridStartX + snappedX
  local absoluteY = self.playfieldY + snappedY
  
  -- Convert back to relative position (relative to effectivePlayfieldX for normalization)
  snappedX = absoluteX - effectivePlayfieldX
  snappedY = absoluteY - self.playfieldY
  
  -- Convert back to normalized coordinates (using effective playfield width)
  local snappedNormX = snappedX / effectivePlayfieldW
  local snappedNormY = snappedY / self.playfieldH
  
  return snappedNormX, snappedNormY
end

function FormationEditorScene:drawGrid()
  -- Draw grid centered horizontally to match block placement
  -- Blocks are placed within effective playfield bounds (with horizontal spacing factor)
  local horizontalSpacingFactor = (config.playfield and config.playfield.horizontalSpacingFactor) or 1.0
  local effectivePlayfieldW = self.playfieldW * horizontalSpacingFactor
  local playfieldXOffset = self.playfieldW * (1 - horizontalSpacingFactor) * 0.5
  local effectivePlayfieldX = self.playfieldX + playfieldXOffset
  
  local cellSize = config.blocks.gridSnap.cellSize
  love.graphics.setColor(0.3, 0.3, 0.4, 0.3)
  love.graphics.setLineWidth(1)
  
  -- Center the grid horizontally within the effective playfield
  -- Calculate how many full cells fit in the effective playfield width
  local numCells = math.floor(effectivePlayfieldW / cellSize)
  local gridWidth = numCells * cellSize
  local gridOffset = (effectivePlayfieldW - gridWidth) * 0.5
  local gridStartX = effectivePlayfieldX + gridOffset
  local gridEndX = gridStartX + gridWidth
  
  local y1 = self.playfieldY
  local y2 = self.playfieldY + self.playfieldH
  
  -- Draw vertical lines (centered within effective playfield bounds)
  local x = gridStartX
  while x <= gridEndX do
    love.graphics.line(x, y1, x, y2)
    x = x + cellSize
  end
  
  -- Draw horizontal lines
  local startY = self.playfieldY
  local endY = self.playfieldY + self.playfieldH
  
  local y = startY
  while y <= endY do
    love.graphics.line(gridStartX, y, gridEndX, y)
    y = y + cellSize
  end
end

function FormationEditorScene:loadFormation()
  local profile = battle_profiles.getProfile(self.currentBattleType)
  -- Clear selection when loading
  self.selectedBlockIndex = nil
  
  if profile and profile.blockFormation and profile.blockFormation.type == "predefined" and profile.blockFormation.predefined then
    self.blocks = {}
    -- Deep copy the predefined blocks
    for _, block in ipairs(profile.blockFormation.predefined) do
      local normX = block.x or 0.5
      local normY = block.y or 0.5
      
      -- Optionally snap loaded blocks to grid (comment out if you want exact positions)
      if config.blocks.gridSnap.enabled then
        normX, normY = self:snapToGrid(normX, normY)
      end
      
      table.insert(self.blocks, {
        x = normX,
        y = normY,
        kind = block.kind or "damage",
        hp = block.hp or 1
      })
    end
    self:showStatus("Formation loaded from " .. self.currentBattleType)
  else
    self.blocks = {}
    self:showStatus("No predefined formation found, starting empty")
  end
end

function FormationEditorScene:saveFormation()
  -- Read the battle_profiles.lua file
  -- Try to read from source using io first (for development)
  local filePath = "src/data/battle_profiles.lua"
  local file
  
  -- Try io.open first (works in development, not in packaged games)
  local ioFile = io.open(filePath, "r")
  if ioFile then
    file = ioFile:read("*all")
    ioFile:close()
  else
    -- Fallback to love.filesystem (reads from save directory)
    file = love.filesystem.read(filePath)
  end
  
  if not file then
    self:showStatus("Error: Could not read battle_profiles.lua")
    return
  end
  
  -- Convert blocks to Lua table format
  local blockLines = {}
  for _, block in ipairs(self.blocks) do
    table.insert(blockLines, string.format("      {x = %.3f, y = %.3f, kind = \"%s\", hp = %d},", block.x, block.y, block.kind, block.hp or 1))
  end
  
  -- Build the predefined section (with proper indentation)
  local predefinedContent = ""
  if #blockLines > 0 then
    predefinedContent = table.concat(blockLines, "\n") .. "\n"
  end
  
  -- Find the battle type section
  local battleTypeKey = "[battle_profiles.Types." .. self.currentBattleType .. "]"
  local startPos = file:find(battleTypeKey, 1, true)
  
  if not startPos then
    self:showStatus("Error: Battle type " .. self.currentBattleType .. " not found")
    return
  end
  
  -- Find the opening brace after the key
  local braceStart = file:find("{", startPos, true)
  if not braceStart then
    self:showStatus("Error: Could not parse battle_profiles.lua")
    return
  end
  
  -- Find blockFormation section
  local formationPattern = "blockFormation%s*=%s*%{"
  local formationStart = file:find(formationPattern, braceStart)
  
  local updatedFile
  if formationStart then
    -- Replace existing blockFormation section
    -- Find the predefined part within blockFormation
    -- Use a pattern that ensures "predefined" is a standalone identifier (not inside a string)
    -- Look for "predefined" followed by whitespace and "="
    local predefinedPattern = "predefined%s*="
    local predefinedStart = file:find(predefinedPattern, formationStart)
    
    if predefinedStart then
      -- Find the equals sign after "predefined"
      local equalsPos = file:find("=", predefinedStart, true)
      if not equalsPos then
        self:showStatus("Error: Could not find predefined assignment")
        return
      end
      
      -- Skip whitespace after =
      local afterEquals = equalsPos + 1
      while afterEquals <= #file and file:sub(afterEquals, afterEquals):match("%s") do
        afterEquals = afterEquals + 1
      end
      
      -- Check if it's "predefined = nil" or "predefined = { ... }"
      local nextThree = file:sub(afterEquals, afterEquals + 2)
      local isNil = (nextThree == "nil")
      
      if isNil then
        -- Replace "predefined = nil" with "predefined = { ... }"
        -- Find the comma or closing brace after nil
        local nilEnd = file:find("nil", equalsPos, true)
        if not nilEnd then
          self:showStatus("Error: Could not find nil value")
          return
        end
        nilEnd = nilEnd + 3 -- Position after "nil"
        -- Skip whitespace
        while nilEnd <= #file and file:sub(nilEnd, nilEnd):match("%s") do
          nilEnd = nilEnd + 1
        end
        -- Find the next comma or closing brace (but stay within blockFormation)
        local nextComma = file:find(",", nilEnd, true)
        local nextBrace = file:find("}", nilEnd, true)
        local endPos = nilEnd
        if nextComma and nextBrace then
          endPos = math.min(nextComma, nextBrace)
        elseif nextComma then
          endPos = nextComma
        elseif nextBrace then
          endPos = nextBrace
        else
          endPos = nilEnd
        end
        
        local beforePredefined = file:sub(1, predefinedStart - 1)
        local afterPredefined = file:sub(endPos)
        updatedFile = beforePredefined .. "predefined = {\n" .. predefinedContent .. "    }" .. afterPredefined
      else
        -- Find the opening brace after =
        local braceOpenPos = file:find("{", equalsPos, true)
        if not braceOpenPos then
          self:showStatus("Error: Could not find predefined opening brace")
          return
        end
        
        -- Find the matching closing brace (carefully count braces)
        local i = braceOpenPos + 1
        local braceCount = 1
        while i <= #file and braceCount > 0 do
          local char = file:sub(i, i)
          -- Ignore braces inside strings or comments
          if char == "{" then
            braceCount = braceCount + 1
          elseif char == "}" then
            braceCount = braceCount - 1
          end
          i = i + 1
        end
        
        if braceCount ~= 0 then
          self:showStatus("Error: Could not find matching brace for predefined")
          return
        end
        
        -- Found the end (i points to character after closing brace)
        local beforePredefined = file:sub(1, predefinedStart - 1)
        local afterPredefined = file:sub(i)
        updatedFile = beforePredefined .. "predefined = {\n" .. predefinedContent .. "    }" .. afterPredefined
      end
    else
      -- blockFormation exists but no predefined, add it before closing brace of blockFormation
      local i = formationStart
      local braceCount = 0
      local foundOpen = false
      while i <= #file do
        local char = file:sub(i, i)
        if char == "{" then
          braceCount = braceCount + 1
          foundOpen = true
        elseif char == "}" then
          braceCount = braceCount - 1
          if foundOpen and braceCount == 0 then
            -- Found the end of blockFormation
            local beforeBrace = file:sub(1, i - 1)
            local afterBrace = file:sub(i)
            updatedFile = beforeBrace .. ",\n      predefined = {\n" .. predefinedContent .. "      },\n    }" .. afterBrace
            break
          end
        end
        i = i + 1
      end
      
      if not updatedFile then
        self:showStatus("Error: Could not parse blockFormation section")
        return
      end
    end
  else
    -- No blockFormation section, add it before the closing brace of the battle type
    local i = braceStart
    local braceCount = 0
    while i <= #file do
      local char = file:sub(i, i)
      if char == "{" then
        braceCount = braceCount + 1
      elseif char == "}" then
        braceCount = braceCount - 1
        if braceCount == 0 then
          -- Found the end of battle type section
          local beforeBrace = file:sub(1, i - 1)
          local afterBrace = file:sub(i)
          updatedFile = beforeBrace .. ",\n    blockFormation = {\n      type = \"predefined\",\n      predefined = {\n" .. predefinedContent .. "      },\n    }" .. afterBrace
          break
        end
      end
      i = i + 1
    end
    
    if not updatedFile then
      self:showStatus("Error: Could not parse battle type section")
      return
    end
  end
  
  -- Also ensure type is set to "predefined" within blockFormation
  if formationStart then
    -- Find type field within blockFormation and update it
    local typeStart = updatedFile:find("type%s*=", formationStart)
    if typeStart then
      -- Find the start of the line (for indentation)
      local lineStart = typeStart
      while lineStart > 1 and updatedFile:sub(lineStart - 1, lineStart - 1) ~= "\n" do
        lineStart = lineStart - 1
      end
      
      -- Find the end of the line (newline)
      local lineEnd = updatedFile:find("\n", typeStart)
      if not lineEnd then
        lineEnd = #updatedFile + 1
      end
      
      -- Extract indentation from the original line
      local indent = ""
      for i = lineStart, typeStart - 1 do
        local char = updatedFile:sub(i, i)
        if char == " " or char == "\t" then
          indent = indent .. char
        end
      end
      
      -- Replace the entire line
      local beforeLine = updatedFile:sub(1, lineStart - 1)
      local afterLine = updatedFile:sub(lineEnd)
      updatedFile = beforeLine .. indent .. "type = \"predefined\", -- \"random\" or \"predefined\"\n" .. afterLine
    else
      -- Type field doesn't exist, add it after opening brace of blockFormation
      local braceOpen = updatedFile:find("{", formationStart, true)
      if braceOpen then
        updatedFile = updatedFile:sub(1, braceOpen) .. "\n      type = \"predefined\", -- \"random\" or \"predefined\"\n" .. updatedFile:sub(braceOpen + 1)
      end
    end
  end
  
  -- Write the updated file
  -- Try io.open first (works in development)
  local ioFile = io.open(filePath, "w")
  local success = false
  if ioFile then
    ioFile:write(updatedFile)
    ioFile:close()
    success = true
  else
    -- Fallback to love.filesystem (writes to save directory)
    success = love.filesystem.write(filePath, updatedFile)
    if success then
      self:showStatus("Formation saved to save directory (copy to src/data/battle_profiles.lua)")
    end
  end
  
  if success then
    self:showStatus("Formation saved to " .. self.currentBattleType)
    -- Reload the module to pick up changes
    package.loaded["data.battle_profiles"] = nil
    battle_profiles = require("data.battle_profiles")
  else
    self:showStatus("Error: Could not write to battle_profiles.lua")
  end
end

function FormationEditorScene:setPreviousScene(scene)
  self.previousScene = scene
end

return FormationEditorScene

