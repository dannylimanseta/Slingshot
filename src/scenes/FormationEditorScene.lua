local config = require("config")
local theme = require("theme")
local battle_profiles = require("data.battle_profiles")
local block_types = require("data.block_types")
local TopBar = require("ui.TopBar")
local EncounterManager = require("core.EncounterManager")

-- Shared sprites for blocks (dynamically loaded from block_types registry)
local SPRITES = {}
do
  local imgs = (config.assets and config.assets.images) or {}
  -- Load sprites for all registered block types
  for _, blockType in ipairs(block_types.types) do
    local spriteKey = blockType.spritePath
    if spriteKey and imgs[spriteKey] then
      local ok, img = pcall(love.graphics.newImage, imgs[spriteKey])
      if ok then
        SPRITES[blockType.key] = img
      end
    end
  end
end

-- Ensure table exists before any method definitions inserted above
local FormationEditorScene = {}

-- Save current blocks into a specific encounter's blockFormation as predefined
function FormationEditorScene:saveFormationEncounter(encounterId)
  if not encounterId then
    self:showStatus("Error: No encounter context available")
    return
  end

  local function round3(value)
    return tonumber(string.format("%.3f", value or 0))
  end

  local newBlocks = {}
  for _, block in ipairs(self.blocks) do
    table.insert(newBlocks, {
      x = round3(block.x),
      y = round3(block.y),
      kind = block.kind or "damage",
      hp = block.hp or 1,
    })
  end

  -- Load current encounters data
  local encountersModule = require("data.encounters")
  local encounterList = encountersModule.list()
  local targetEncounter
  for _, enc in ipairs(encounterList) do
    if enc.id == encounterId then
      targetEncounter = enc
      break
    end
  end

  if not targetEncounter then
    self:showStatus("Error: Encounter " .. tostring(encounterId) .. " not found")
    return
  end

  -- Update encounter block formation in memory
  targetEncounter.blockFormation = targetEncounter.blockFormation or {}
  targetEncounter.blockFormation.type = "predefined"
  targetEncounter.blockFormation.predefined = newBlocks

  local KEY_ORDER = {
    "id",
    "label",
    "difficulty",
    "tags",
    "centerWidthFactor",
    "enemySpacing",
    "enemies",
    "formationId",
    "blockFormation",
  }
  local KEY_PRIORITY = {}
  for index, key in ipairs(KEY_ORDER) do
    KEY_PRIORITY[key] = index
  end

  local function isArray(tbl)
    local count = 0
    local maxIndex = 0
    for k in pairs(tbl) do
      if type(k) ~= "number" then return false end
      if k > maxIndex then maxIndex = k end
      count = count + 1
    end
    return maxIndex == count
  end

  local function serializeValue(value, indentLevel)
    indentLevel = indentLevel or 0
    local indent = string.rep("  ", indentLevel)
    if type(value) == "table" then
      if next(value) == nil then
        return "{}"
      end
      local nextIndent = string.rep("  ", indentLevel + 1)
      if isArray(value) then
        local parts = {"{"}
        local length = #value
        for index, item in ipairs(value) do
          local serialized = serializeValue(item, indentLevel + 1)
          serialized = serialized:gsub("\n", "\n" .. nextIndent)
          local line = nextIndent .. serialized
          if index < length then
            line = line .. ","
          end
          table.insert(parts, line)
        end
        table.insert(parts, indent .. "}")
        return table.concat(parts, "\n")
      else
        local keys = {}
        for k in pairs(value) do table.insert(keys, k) end
        table.sort(keys, function(a, b)
          local pa = KEY_PRIORITY[a] or (#KEY_ORDER + 1)
          local pb = KEY_PRIORITY[b] or (#KEY_ORDER + 1)
          if pa ~= pb then return pa < pb end
          return tostring(a) < tostring(b)
        end)
        local parts = {"{"}
        for idx, key in ipairs(keys) do
          local keyRep
          if type(key) == "string" and key:match("^%a[%w_]*$") then
            keyRep = key .. " = "
          else
            keyRep = "[" .. serializeValue(key, 0) .. "] = "
          end
          local serialized = serializeValue(value[key], indentLevel + 1)
          serialized = serialized:gsub("\n", "\n" .. nextIndent)
          local line = nextIndent .. keyRep .. serialized
          if idx < #keys then
            line = line .. ","
          end
          table.insert(parts, line)
        end
        table.insert(parts, indent .. "}")
        return table.concat(parts, "\n")
      end
    elseif type(value) == "string" then
      return string.format("%q", value)
    elseif type(value) == "number" or type(value) == "boolean" then
      return tostring(value)
    elseif value == nil then
      return "nil"
    else
      error("Unsupported value type: " .. type(value))
    end
  end

  local serializedEncounters = serializeValue(encounterList, 0)

  local lines = {
    'local enemies = require("data.enemies")',
    'local formations = require("data.formations")',
    '',
    'local M = {}',
    '',
    '-- Declarative encounter definitions',
    '-- Each encounter resolves to a battle profile via EncounterManager',
    'local ENCOUNTERS = ' .. serializedEncounters,
    '',
    '-- Index by id for quick lookup',
    'local INDEX = {}',
    'for _, enc in ipairs(ENCOUNTERS) do',
    '\tINDEX[enc.id] = enc',
    'end',
    '',
    'function M.get(id)',
    '\treturn INDEX[id]',
    'end',
    '',
    'function M.list()',
    '\treturn ENCOUNTERS',
    'end',
    '',
    'return M',
    '',
  }

  local content = table.concat(lines, "\n")
  local filePath = "src/data/encounters.lua"
  local out = io.open(filePath, "w")
  if not out then
    self:showStatus("Error: Could not write encounters.lua")
    return
  end
  out:write(content)
  out:close()

  self:showStatus("Formation saved to encounter: " .. tostring(encounterId))
  if EncounterManager and EncounterManager.reloadDatasets then
    EncounterManager.reloadDatasets()
    if EncounterManager.setEncounterById then
      EncounterManager.setEncounterById(encounterId)
    end
  end
  if self.previousScene and self.previousScene.reloadBlocks then
    self.previousScene:reloadBlocks()
  end
end

-- Icons used for overlay labels (match Block.lua)
local ICON_ATTACK = nil
local ICON_ARMOR = nil
local ICON_HEAL = nil
do
  local imgs = (config.assets and config.assets.images) or {}
  -- Load attack icon
  if imgs.icon_attack then
    local ok, img = pcall(love.graphics.newImage, imgs.icon_attack)
    if ok then
      pcall(function() img:setFilter('linear', 'linear') end)
      ICON_ATTACK = img
    end
  end
  -- Load armor icon
  if imgs.icon_armor then
    local ok, img = pcall(love.graphics.newImage, imgs.icon_armor)
    if ok then
      pcall(function() img:setFilter('linear', 'linear') end)
      ICON_ARMOR = img
    end
  end
  -- Load heal icon
  if imgs.icon_heal then
    local ok, img = pcall(love.graphics.newImage, imgs.icon_heal)
    if ok then
      pcall(function() img:setFilter('linear', 'linear') end)
      ICON_HEAL = img
    end
  end
end

FormationEditorScene = FormationEditorScene or {}
FormationEditorScene.__index = FormationEditorScene

function FormationEditorScene.new()
  return setmetatable({
    -- Formation data: array of {x, y, kind, hp} where x,y are normalized (0-1)
    blocks = {},
    currentBlockType = block_types.getDefault(), -- Default to first registered block type
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
    selectedBlockIndex = nil, -- Currently selected block (for backward compatibility)
    selectedBlockIndices = {}, -- Array of selected block indices (for multi-select)
    deleteMode = false, -- When true, clicking blocks deletes them instead of selecting
    gridSnapEnabled = true, -- Toggle for grid snapping (can be disabled for free placement)
    -- Selection box state
    isSelecting = false, -- Whether we're currently dragging a selection box
    selectionBoxStartX = 0,
    selectionBoxStartY = 0,
    selectionBoxEndX = 0,
    selectionBoxEndY = 0,
    mouseDownX = 0, -- Track mouse position when button was pressed
    mouseDownY = 0,
    hasMovedForSelection = false, -- Track if mouse moved enough to start selection box
    -- Group drag state
    isDraggingSelection = false, -- Whether we're dragging selected blocks
    dragStartX = 0,
    dragStartY = 0,
    dragOriginalPositions = {}, -- Store original positions when drag starts {[index] = {x, y}}
    -- Status
    statusMessage = "",
    statusMessageTimer = 0,
    -- Previous scene reference (to return to)
    previousScene = nil,
    topBar = TopBar.new(),
    -- Current encounter context (if opened from battle)
    currentEncounterId = nil,
  }, FormationEditorScene)
end

function FormationEditorScene:load()
  -- Calculate playfield bounds exactly matching BlockManager:loadPredefinedFormation
  -- BlockManager receives the center canvas width directly from GameplayScene
  -- Use LayoutManager to get exact same dimensions as SplitScene uses
  local LayoutManager = require("managers.LayoutManager")
  local layoutManager = LayoutManager.new()
  
  -- Always use virtual resolution from config (matches canvas size)
  local w = (config.video and config.video.virtualWidth) or 1280
  local h = (config.video and config.video.virtualHeight) or 720
  local margin = config.playfield.margin
  
  -- Get center rect using LayoutManager (matches SplitScene exactly)
  local centerRect = layoutManager:getCenterRect(w, h)
  local centerW = centerRect.w -- This is math.floor(w * centerWidthFactor)
  local centerX = centerRect.x -- This is math.floor((w - centerW) * 0.5)
  
  -- Match BlockManager exactly: it receives centerW as width and h as height
  -- BlockManager calculates: playfieldX = margin, playfieldY = margin + topBarHeight
  -- playfieldW = width - 2 * margin, playfieldH = height * maxHeightFactor - margin
  -- Where width = centerW and height = h (full screen height)
  -- In SplitScene, GameplayScene is drawn at centerX - 100 (shifted 100px left)
  -- So we need to match that offset for proper alignment
  local topBarHeight = (config.playfield and config.playfield.topBarHeight) or 60
  local maxHeightFactor = (config.playfield and config.playfield.maxHeightFactor) or 0.65
  local gameCenterX = centerX - 100 -- Match SplitScene's centerX shift
  self.playfieldX = gameCenterX + margin -- Offset by gameCenterX to match game positioning
  self.playfieldY = margin + topBarHeight -- Match game's playfieldY exactly
  self.playfieldW = centerW - 2 * margin -- Use center canvas width, not full screen width
  self.actualPlayfieldW = self.playfieldW -- Store actual breakout area width (matches game exactly)
  -- Increase editor grid height by 30% for more placement space
  local editorHeightMultiplier = 1.3
  self.playfieldH = (h * maxHeightFactor - margin) * editorHeightMultiplier
  
  -- Capture current encounter context if available
  if EncounterManager and EncounterManager.getCurrentEncounterId then
    self.currentEncounterId = EncounterManager.getCurrentEncounterId()
  end

  -- Load existing formation for current battle type
  self:loadFormation()
  
  -- Initialize grid snap enabled from config
  self.gridSnapEnabled = config.blocks.gridSnap.enabled or true
  
  -- Build dynamic help message with available block types
  local blockTypeKeys = {}
  for _, bt in ipairs(block_types.getAllSorted()) do
    if bt.hotkey then
      table.insert(blockTypeKeys, bt.hotkey .. "=" .. bt.displayName)
    end
  end
  local blockTypesStr = table.concat(blockTypeKeys, ", ")
  self.statusMessage = "Formation Editor - Click to place/select, Right-click/Delete to remove, " .. blockTypesStr .. " to change type, S to save, L to load, G to toggle grid snap, H to toggle grid visibility, ESC to exit"
  self.statusMessageTimer = 5.0 -- Show for 5 seconds
end

function FormationEditorScene:update(dt)
  -- Update status message timer
  if self.statusMessageTimer > 0 then
    self.statusMessageTimer = self.statusMessageTimer - dt
  end
  
  -- Update dragging if active
  if self.isDraggingSelection then
    -- Calculate normalized mouse delta
    local currentNormX = self:screenToNormalizedX(self.mouseX)
    local currentNormY = self:screenToNormalizedY(self.mouseY)
    local startNormX = self:screenToNormalizedX(self.dragStartX)
    local startNormY = self:screenToNormalizedY(self.dragStartY)
    
    local deltaNormX = currentNormX - startNormX
    local deltaNormY = currentNormY - startNormY
    
    -- Apply grid snapping if enabled
    if self.gridSnapEnabled then
      local snappedCurrentX, snappedCurrentY = self:snapToGrid(currentNormX, currentNormY)
      local snappedStartX, snappedStartY = self:snapToGrid(startNormX, startNormY)
      deltaNormX = snappedCurrentX - snappedStartX
      deltaNormY = snappedCurrentY - snappedStartY
    end
    
    -- Update positions of all selected blocks relative to their original positions
    for _, idx in ipairs(self.selectedBlockIndices) do
      if self.blocks[idx] and self.dragOriginalPositions[idx] then
        local origX = self.dragOriginalPositions[idx].x
        local origY = self.dragOriginalPositions[idx].y
        self.blocks[idx].x = origX + deltaNormX
        self.blocks[idx].y = origY + deltaNormY
      end
    end
  end
  
  -- Update hovered block index (only if not dragging)
  if not self.isDraggingSelection then
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
  
  -- Update selection box end position
  if self.isSelecting then
    self.selectionBoxEndX = self.mouseX
    self.selectionBoxEndY = self.mouseY
  end
end

function FormationEditorScene:draw()
  -- Always use virtual resolution from config (matches canvas size)
  local width = (config.video and config.video.virtualWidth) or 1280
  local height = (config.video and config.video.virtualHeight) or 720
  
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
    
    -- Check if block is in multi-select
    local isMultiSelected = false
    for _, idx in ipairs(self.selectedBlockIndices) do
      if idx == i then
        isMultiSelected = true
        break
      end
    end
    
    -- Highlight selected block (stronger than hover)
    local isSelected = (i == self.selectedBlockIndex) or isMultiSelected
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
    
    -- Draw block sprite with overlays
    self:drawBlock(bx, by, block.kind, blockSize, block.hp)
  end
  
  -- Draw selection box (dotted line)
  if self.isSelecting then
    self:drawSelectionBox()
  end
  
  -- Draw cursor preview (if within playfield)
  if self:isMouseInPlayfield() then
    local normX = self:screenToNormalizedX(self.mouseX)
    local normY = self:screenToNormalizedY(self.mouseY)
    
    -- Apply grid snapping to preview
    if self.gridSnapEnabled then
      normX, normY = self:snapToGrid(normX, normY)
    end
    
    local previewX = self.playfieldX + playfieldXOffset + normX * effectivePlayfieldW
    local previewY = self.playfieldY + normY * self.playfieldH
    
    -- Check if preview block would exceed actual playfield bounds
    -- Extend top boundary to accommodate extra grid row
    local cellSize = config.blocks.gridSnap.cellSize
    local halfSize = blockSize * 0.5
    local blockLeft = previewX - halfSize
    local blockRight = previewX + halfSize
    local blockTop = previewY - halfSize
    local blockBottom = previewY + halfSize
    local actualPlayfieldLeft = self.playfieldX
    local actualPlayfieldRight = self.playfieldX + self.actualPlayfieldW
    local actualPlayfieldTop = self.playfieldY - cellSize * 0.5 -- Extend upward by half cellSize
    local actualPlayfieldBottom = self.playfieldY + self.playfieldH
    local canPlace = blockLeft >= actualPlayfieldLeft and blockRight <= actualPlayfieldRight and
                     blockTop >= actualPlayfieldTop and blockBottom <= actualPlayfieldBottom
    
    -- Draw preview with color indicating if placement is allowed
    if canPlace then
      love.graphics.setColor(1, 1, 1, 0.5)
    else
      love.graphics.setColor(1, 0.3, 0.3, 0.5) -- Red tint if cannot place
    end
    self:drawBlock(previewX, previewY, self.currentBlockType, blockSize, 1)
  end
  
  -- Draw UI
  self:drawUI()
  
  love.graphics.setColor(1, 1, 1, 1)
  
  -- Top bar is hidden in editor
end

function FormationEditorScene:drawBlock(x, y, kind, size, hp)
  -- Get sprite from registry, fallback to damage block sprite
  local sprite = SPRITES[kind] or SPRITES["damage"]
  
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
      -- Use default block color for any block type without sprite
      love.graphics.setColor(theme.colors.block[1] or 0.95, theme.colors.block[2] or 0.6, theme.colors.block[3] or 0.25, 1)
    end
    love.graphics.rectangle("fill", x - halfSize, y - halfSize, size, size, 4, 4)
    love.graphics.setColor(theme.colors.blockOutline[1] or 0, theme.colors.blockOutline[2] or 0, theme.colors.blockOutline[3] or 0, 0.2)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x - halfSize, y - halfSize, size, size, 4, 4)
  end

  -- Draw value text and icon overlay (match Block.lua visuals)
  local valueText = nil
  local iconToUse = nil
  if kind == "damage" or kind == "attack" then
    valueText = "+1"
    iconToUse = ICON_ATTACK
  elseif kind == "crit" then
    valueText = "x2"
    iconToUse = ICON_ATTACK
  elseif kind == "multiplier" then
    local dmgMult = (config.score and config.score.powerCritMultiplier) or 4
    valueText = "x" .. tostring(dmgMult)
    iconToUse = ICON_ATTACK
  elseif kind == "armor" then
    -- Flat armor value
    valueText = "+3"
    iconToUse = ICON_ARMOR
  elseif kind == "potion" then
    valueText = "+8"
    iconToUse = ICON_HEAL
  end

  if iconToUse then
    local baseFont = theme.fonts.base or love.graphics.getFont()
    love.graphics.setFont(baseFont)
    local baseTextHeight = baseFont:getHeight()
    local textScale = 0.7
    local textHeight = baseTextHeight * textScale
    local iconSize = textHeight * 0.9
    local iconW, iconH = iconToUse:getDimensions()
    local iconScale = iconSize / math.max(iconW, iconH)
    local iconXOffset = (kind == "armor") and 2 or ((kind == "potion") and 2 or 0)
    local iconX = math.floor(x - iconSize * 0.5 + iconXOffset + 0.5)
    local iconYOffset = (kind == "armor") and -7 or -6
    local iconY = math.floor(y - iconSize * 0.5 + iconYOffset + 0.5)
    love.graphics.push("all")
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.draw(iconToUse, iconX, iconY, 0, iconScale, iconScale, 0, 0)
    love.graphics.pop()
  end
end

function FormationEditorScene:drawUI()
  local width = config.video.virtualWidth
  local font = theme.fonts.base
  
  -- Block count
  local countText = "Blocks: " .. #self.blocks
  theme.drawTextWithOutline(countText, 20, 20, 1, 1, 1, 1, 2)
  
  -- Battle type
  local battleText = "Battle Type: " .. self.currentBattleType
  theme.drawTextWithOutline(battleText, 20, 50, 1, 1, 1, 1, 2)
  
  -- Status message
  if self.statusMessageTimer > 0 then
    local height = config.video.virtualHeight
    local alpha = math.min(1, self.statusMessageTimer / 0.5) -- Fade out in last 0.5 seconds
    theme.drawTextWithOutline(self.statusMessage, width * 0.5, height - 40, 1, 1, 1, alpha, 2)
  end
  
  -- Instructions (dynamically generated from block types)
  local instructions = {}
  -- Add block type switching instructions
  for _, blockType in ipairs(block_types.getAllSorted()) do
    if blockType.hotkey then
      table.insert(instructions, blockType.hotkey .. ": " .. blockType.displayName)
    end
  end
  -- Add other instructions
  table.insert(instructions, "S: Save formation")
  table.insert(instructions, "L: Load formation")
  table.insert(instructions, "G: Toggle grid snap")
  table.insert(instructions, "H: Toggle grid visibility")
  table.insert(instructions, "0: Toggle delete mode")
  table.insert(instructions, "ESC: Exit editor")
  for i, inst in ipairs(instructions) do
    theme.drawTextWithOutline(inst, width - 250, 20 + (i - 1) * 30, 0.8, 0.8, 0.8, 0.7, 2)
  end
  
  -- Show selection info, delete mode status, or grid snap status
  if self.deleteMode then
    theme.drawTextWithOutline("DELETE MODE: Click blocks to delete", 20, 80, 1, 0.3, 0.3, 1, 2)
  elseif #self.selectedBlockIndices > 0 then
    if #self.selectedBlockIndices == 1 then
      local block = self.blocks[self.selectedBlockIndices[1]]
      local infoText = string.format("Selected: %s block (Click & drag to move, Delete to remove)", block.kind)
      theme.drawTextWithOutline(infoText, 20, 80, 0.4, 0.8, 1, 1, 2)
    else
      local infoText = string.format("Selected: %d blocks (Click & drag to move, Delete to remove)", #self.selectedBlockIndices)
      theme.drawTextWithOutline(infoText, 20, 80, 0.4, 0.8, 1, 1, 2)
    end
  elseif self.selectedBlockIndex then
    -- Backward compatibility
    local block = self.blocks[self.selectedBlockIndex]
    local infoText = string.format("Selected: %s block (Delete to remove)", block.kind)
    theme.drawTextWithOutline(infoText, 20, 80, 0.4, 0.8, 1, 1, 2)
  else
    -- Show grid snap status when nothing is selected
    local snapStatus = self.gridSnapEnabled and "Grid snap: ON (G to toggle) | Click & drag to select multiple blocks" or "Grid snap: OFF - Free placement (G to toggle) | Click & drag to select multiple blocks"
    theme.drawTextWithOutline(snapStatus, 20, 80, 0.6, 0.6, 0.6, 0.8, 2)
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
          -- Update multi-select indices
          for i = #self.selectedBlockIndices, 1, -1 do
            local idx = self.selectedBlockIndices[i]
            if idx == removedIndex then
              table.remove(self.selectedBlockIndices, i)
            elseif idx > removedIndex then
              self.selectedBlockIndices[i] = idx - 1
            end
          end
          self:showStatus("Block deleted")
        else
          -- Check if clicking on a selected block (start dragging)
          if self:isBlockInSelection(self.hoveredBlockIndex) then
            -- Start dragging selected blocks - store original positions
            self.isDraggingSelection = true
            self.dragStartX = x
            self.dragStartY = y
            self.dragOriginalPositions = {}
            for _, idx in ipairs(self.selectedBlockIndices) do
              if self.blocks[idx] then
                self.dragOriginalPositions[idx] = {
                  x = self.blocks[idx].x,
                  y = self.blocks[idx].y
                }
              end
            end
            self:showStatus("Dragging " .. #self.selectedBlockIndices .. " block(s)")
          else
            -- Select single block (clear multi-select)
            self.selectedBlockIndex = self.hoveredBlockIndex
            self.selectedBlockIndices = {self.hoveredBlockIndex}
            self:showStatus("Block selected")
          end
        end
      else
        -- Click on empty space: prepare for either placement or selection box
        self.mouseDownX = x
        self.mouseDownY = y
        self.hasMovedForSelection = false
        -- Clear previous selection
        self.selectedBlockIndex = nil
        self.selectedBlockIndices = {}
      end
    else
      -- Click outside playfield: clear selection
      self.selectedBlockIndex = nil
      self.selectedBlockIndices = {}
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
      -- Update multi-select indices
      for i = #self.selectedBlockIndices, 1, -1 do
        local idx = self.selectedBlockIndices[i]
        if idx == removedIndex then
          table.remove(self.selectedBlockIndices, i)
        elseif idx > removedIndex then
          self.selectedBlockIndices[i] = idx - 1
        end
      end
      self:showStatus("Block removed")
    end
  end
end

function FormationEditorScene:mousemoved(x, y, dx, dy)
  self.mouseX = x
  self.mouseY = y
  
  -- Check if mouse moved enough to start selection box (when clicking empty space)
  -- Only if we're not already selecting/dragging and mouse was pressed on empty space
  if not self.isSelecting and not self.isDraggingSelection and 
     self.mouseDownX ~= 0 and self.mouseDownY ~= 0 and
     not self.hoveredBlockIndex then
    local dragThreshold = 5 -- pixels
    local distMoved = math.sqrt((x - self.mouseDownX)^2 + (y - self.mouseDownY)^2)
    if distMoved > dragThreshold and not self.hasMovedForSelection then
      -- Start selection box
      self.isSelecting = true
      self.hasMovedForSelection = true
      self.selectionBoxStartX = self.mouseDownX
      self.selectionBoxStartY = self.mouseDownY
      self.selectionBoxEndX = x
      self.selectionBoxEndY = y
    end
  end
end

function FormationEditorScene:mousereleased(x, y, button)
  self.mouseX = x
  self.mouseY = y
  
  if button == 1 then -- Left mouse button release
    if self.isSelecting then
      -- Finalize selection box
      self.isSelecting = false
      local selectedIndices = self:getBlocksInSelectionBox()
      if #selectedIndices > 0 then
        self.selectedBlockIndices = selectedIndices
        self.selectedBlockIndex = selectedIndices[1] -- Set single selection for backward compatibility
        self:showStatus(#selectedIndices .. " block(s) selected")
      else
        -- No blocks selected, clear selection
        self.selectedBlockIndex = nil
        self.selectedBlockIndices = {}
      end
      self.hasMovedForSelection = false
    elseif self.isDraggingSelection then
      -- Finalize drag
      self.isDraggingSelection = false
      self.dragOriginalPositions = {}
      self:showStatus("Blocks moved")
    elseif not self.hasMovedForSelection and self:isMouseInPlayfield() and not self.hoveredBlockIndex then
      -- Quick click on empty space: place a block
      local normX = self:screenToNormalizedX(x)
      local normY = self:screenToNormalizedY(y)
      
      -- Apply grid snapping if enabled
      if self.gridSnapEnabled then
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
      -- Extend top boundary to accommodate extra grid row
      local cellSize = config.blocks.gridSnap.cellSize
      local actualPlayfieldLeft = self.playfieldX
      local actualPlayfieldRight = self.playfieldX + self.actualPlayfieldW
      local actualPlayfieldTop = self.playfieldY - cellSize * 0.5 - 50 -- Extend upward by half cellSize + 50px
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
        self.selectedBlockIndices = {}
      else
        self:showStatus("Cannot place block: exceeds playfield bounds")
      end
    end
    -- Reset mouse down tracking
    self.mouseDownX = 0
    self.mouseDownY = 0
    self.hasMovedForSelection = false
  end
end

function FormationEditorScene:keypressed(key, scancode, isRepeat)
  if key == "escape" then
    -- Auto-save to active encounter (if any), then exit
    if self.currentEncounterId then
      self:saveFormationEncounter(self.currentEncounterId)
    end
    -- Exit editor and restart the game
    -- Signal to main.lua to restart with previous scene
    return "restart"
  end
  
  -- Check if key matches any block type hotkey
  local keyNum = tonumber(key)
  if keyNum then
    local blockType = block_types.getByHotkey(keyNum)
    if blockType then
      self.currentBlockType = blockType.key
      self:showStatus("Block type: " .. blockType.displayName .. (blockType.description and (" - " .. blockType.description) or ""))
      return -- Don't continue processing
    end
  end
  
  if key == "s" then
    self:saveFormation()
  elseif key == "l" then
    self:loadFormation()
  elseif key == "delete" or key == "backspace" then
    -- Delete selected blocks (multi-select) or single selected/hovered block
    if #self.selectedBlockIndices > 0 then
      -- Delete all selected blocks (in reverse order to maintain indices)
      local sortedIndices = {}
      for _, idx in ipairs(self.selectedBlockIndices) do
        table.insert(sortedIndices, idx)
      end
      table.sort(sortedIndices, function(a, b) return a > b end) -- Sort descending
      
      for _, idx in ipairs(sortedIndices) do
        table.remove(self.blocks, idx)
      end
      
      self:showStatus(#sortedIndices .. " block(s) removed")
      self.selectedBlockIndex = nil
      self.selectedBlockIndices = {}
    else
      -- Fallback to single block deletion
      local blockToDelete = self.selectedBlockIndex or self.hoveredBlockIndex
      if blockToDelete then
        table.remove(self.blocks, blockToDelete)
        -- Clear selection
        self.selectedBlockIndex = nil
        self.selectedBlockIndices = {}
        self:showStatus("Block removed")
      end
    end
  elseif key == "g" then
    -- Toggle grid snapping (enables/disables snapping to grid)
    self.gridSnapEnabled = not self.gridSnapEnabled
    self:showStatus(self.gridSnapEnabled and "Grid snap ON" or "Grid snap OFF (free placement)")
  elseif key == "h" then
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
  
  -- Calculate grid with padding (matching drawGrid)
  -- Add one extra row at the top: reduce top padding by cellSize to accommodate extra row
  local cellSize = config.blocks.gridSnap.cellSize
  local gridPadding = (config.blocks.gridSnap.padding) or 30
  local sidePadding = (config.blocks.gridSnap.sidePadding) or 40
  local availableWidth = effectivePlayfieldW - 2 * gridPadding - 2 * sidePadding
  local availableHeight = self.playfieldH - 2 * gridPadding + cellSize -- Add cellSize for extra row
  local numCellsX = math.floor(availableWidth / cellSize)
  local numCellsY = math.floor(availableHeight / cellSize)
  local gridWidth = numCellsX * cellSize
  local gridHeight = numCellsY * cellSize
  -- Center grid within the padded area (account for sidePadding when centering)
  -- Shift grid up by half cellSize to add row at top, plus 50px additional shift
  local gridOffsetX = sidePadding + gridPadding + (availableWidth - gridWidth) * 0.5
  local gridOffsetY = gridPadding - cellSize * 0.5 - 50 + (availableHeight - gridHeight) * 0.5
  local gridStartX = effectivePlayfieldX + gridOffsetX
  local gridStartY = self.playfieldY + gridOffsetY
  
  -- Snap to center of grid cells (not intersections)
  -- Calculate which cell the point is in, then snap to center of that cell
  local cellX = math.floor((screenX - gridStartX) / cellSize)
  local cellY = math.floor((screenY - gridStartY) / cellSize)
  
  -- Clamp to valid cell indices
  cellX = math.max(0, math.min(numCellsX - 1, cellX))
  cellY = math.max(0, math.min(numCellsY - 1, cellY))
  
  -- Snap to center of the cell (cell center = cellIndex * cellSize + cellSize/2)
  local snappedX = cellX * cellSize + cellSize * 0.5
  local snappedY = cellY * cellSize + cellSize * 0.5
  
  -- Convert snapped position to absolute screen coordinates (snappedX is relative to gridStartX)
  local absoluteX = gridStartX + snappedX
  local absoluteY = gridStartY + snappedY
  
  -- Convert back to relative position (relative to effectivePlayfieldX for normalization)
  snappedX = absoluteX - effectivePlayfieldX
  snappedY = absoluteY - self.playfieldY
  
  -- Convert back to normalized coordinates (using effective playfield width)
  local snappedNormX = snappedX / effectivePlayfieldW
  local snappedNormY = snappedY / self.playfieldH
  
  return snappedNormX, snappedNormY
end

function FormationEditorScene:drawSelectionBox()
  -- Draw dotted line selection box
  local x1 = math.min(self.selectionBoxStartX, self.selectionBoxEndX)
  local y1 = math.min(self.selectionBoxStartY, self.selectionBoxEndY)
  local x2 = math.max(self.selectionBoxStartX, self.selectionBoxEndX)
  local y2 = math.max(self.selectionBoxStartY, self.selectionBoxEndY)
  local w = x2 - x1
  local h = y2 - y1
  
  love.graphics.setColor(0.4, 0.8, 1, 0.8) -- Light blue
  love.graphics.setLineWidth(2)
  
  -- Draw dotted rectangle using line segments
  local dashLength = 8
  local gapLength = 4
  local totalLength = dashLength + gapLength
  
  -- Top edge
  for x = x1, x2, totalLength do
    local endX = math.min(x + dashLength, x2)
    if endX > x then
      love.graphics.line(x, y1, endX, y1)
    end
  end
  
  -- Bottom edge
  for x = x1, x2, totalLength do
    local endX = math.min(x + dashLength, x2)
    if endX > x then
      love.graphics.line(x, y2, endX, y2)
    end
  end
  
  -- Left edge
  for y = y1, y2, totalLength do
    local endY = math.min(y + dashLength, y2)
    if endY > y then
      love.graphics.line(x1, y, x1, endY)
    end
  end
  
  -- Right edge
  for y = y1, y2, totalLength do
    local endY = math.min(y + dashLength, y2)
    if endY > y then
      love.graphics.line(x2, y, x2, endY)
    end
  end
  
  love.graphics.setColor(1, 1, 1, 1)
end

function FormationEditorScene:getBlocksInSelectionBox()
  -- Get all blocks that are within the selection box
  local x1 = math.min(self.selectionBoxStartX, self.selectionBoxEndX)
  local y1 = math.min(self.selectionBoxStartY, self.selectionBoxEndY)
  local x2 = math.max(self.selectionBoxStartX, self.selectionBoxEndX)
  local y2 = math.max(self.selectionBoxStartY, self.selectionBoxEndY)
  
  local scaleMul = config.blocks.spriteScale or 1
  local blockSize = config.blocks.baseSize * scaleMul
  local halfSize = blockSize * 0.5
  
  local horizontalSpacingFactor = (config.playfield and config.playfield.horizontalSpacingFactor) or 1.0
  local effectivePlayfieldW = self.playfieldW * horizontalSpacingFactor
  local playfieldXOffset = self.playfieldW * (1 - horizontalSpacingFactor) * 0.5
  
  local selectedIndices = {}
  for i, block in ipairs(self.blocks) do
    local bx = self.playfieldX + playfieldXOffset + block.x * effectivePlayfieldW
    local by = self.playfieldY + block.y * self.playfieldH
    
    -- Check if block center is within selection box
    if bx >= x1 and bx <= x2 and by >= y1 and by <= y2 then
      table.insert(selectedIndices, i)
    end
  end
  
  return selectedIndices
end

function FormationEditorScene:isBlockInSelection(blockIndex)
  -- Check if a block index is in the selected blocks array
  for _, idx in ipairs(self.selectedBlockIndices) do
    if idx == blockIndex then
      return true
    end
  end
  return false
end

function FormationEditorScene:drawGrid()
  -- Draw grid centered horizontally to match block placement
  -- Blocks are placed within effective playfield bounds (with horizontal spacing factor)
  local horizontalSpacingFactor = (config.playfield and config.playfield.horizontalSpacingFactor) or 1.0
  local effectivePlayfieldW = self.playfieldW * horizontalSpacingFactor
  local playfieldXOffset = self.playfieldW * (1 - horizontalSpacingFactor) * 0.5
  local effectivePlayfieldX = self.playfieldX + playfieldXOffset
  
  local cellSize = config.blocks.gridSnap.cellSize
  local gridPadding = (config.blocks.gridSnap.padding) or 30
  local sidePadding = (config.blocks.gridSnap.sidePadding) or 40
  love.graphics.setColor(0.3, 0.3, 0.4, 0.3)
  love.graphics.setLineWidth(1)
  
  -- Calculate grid with padding (matching snapToGrid)
  -- Add one extra row at the top: reduce top padding by cellSize to accommodate extra row
  local availableWidth = effectivePlayfieldW - 2 * gridPadding - 2 * sidePadding
  local availableHeight = self.playfieldH - 2 * gridPadding + cellSize -- Add cellSize for extra row
  local numCellsX = math.floor(availableWidth / cellSize)
  local numCellsY = math.floor(availableHeight / cellSize)
  local gridWidth = numCellsX * cellSize
  local gridHeight = numCellsY * cellSize
  -- Center grid within the padded area (account for sidePadding when centering)
  -- Shift grid up by half cellSize to add row at top, plus 50px additional shift
  local gridOffsetX = sidePadding + gridPadding + (availableWidth - gridWidth) * 0.5
  local gridOffsetY = gridPadding - cellSize * 0.5 - 50 + (availableHeight - gridHeight) * 0.5
  local gridStartX = effectivePlayfieldX + gridOffsetX
  local gridStartY = self.playfieldY + gridOffsetY
  local gridEndX = gridStartX + gridWidth
  local gridEndY = gridStartY + gridHeight
  
  -- Draw vertical lines (within padded grid bounds)
  local x = gridStartX
  while x <= gridEndX do
    love.graphics.line(x, gridStartY, x, gridEndY)
    x = x + cellSize
  end
  
  -- Draw horizontal lines (within padded grid bounds)
  local y = gridStartY
  while y <= gridEndY do
    love.graphics.line(gridStartX, y, gridEndX, y)
    y = y + cellSize
  end
end

function FormationEditorScene:loadFormation()
  -- Prefer loading from active encounter if available
  if self.currentEncounterId then
    local encounters = require("data.encounters")
    local enc = encounters.get(self.currentEncounterId)
    self.selectedBlockIndex = nil
    if enc and enc.blockFormation and enc.blockFormation.type == "predefined" and enc.blockFormation.predefined then
      self.blocks = {}
      for _, block in ipairs(enc.blockFormation.predefined) do
        table.insert(self.blocks, {
          x = block.x or 0.5,
          y = block.y or 0.5,
          kind = block.kind or "damage",
          hp = block.hp or 1,
        })
      end
      self:showStatus("Formation loaded from encounter " .. tostring(self.currentEncounterId))
      return
    else
      self.blocks = {}
      self:showStatus("No predefined formation on encounter; starting empty")
      return
    end
  end
  local profile = battle_profiles.getProfile(self.currentBattleType)
  -- Clear selection when loading
  self.selectedBlockIndex = nil
  
  if profile and profile.blockFormation and profile.blockFormation.type == "predefined" and profile.blockFormation.predefined then
    self.blocks = {}
    -- Deep copy the predefined blocks
    for _, block in ipairs(profile.blockFormation.predefined) do
      local normX = block.x or 0.5
      local normY = block.y or 0.5
      
      -- Preserve exact saved coordinates (don't snap loaded blocks)
      -- Grid snapping only applies to new placements, not loading existing formations
      
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
  -- If editing within an encounter, save into encounters.lua instead
  if self.currentEncounterId then
    return self:saveFormationEncounter(self.currentEncounterId)
  end
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

