-- Playfield utility functions
-- Shared calculations for grid bounds and playfield layout

local config = require("config")

local M = {}

-- Calculate grid bounds (matching editor exactly)
-- Returns: gridStartX, gridEndX
function M.calculateGridBounds(width, height)
  local margin = config.playfield.margin
  local playfieldW = width - 2 * margin
  local horizontalSpacingFactor = (config.playfield and config.playfield.horizontalSpacingFactor) or 1.0
  local effectivePlayfieldW = playfieldW * horizontalSpacingFactor
  local playfieldXOffset = playfieldW * (1 - horizontalSpacingFactor) * 0.5
  
  local gridPadding = (config.blocks.gridSnap.padding) or 30
  local sidePadding = (config.blocks.gridSnap.sidePadding) or 40
  local gridAvailableWidth = effectivePlayfieldW - 2 * gridPadding - 2 * sidePadding
  local cellSize = (config.blocks.gridSnap.cellSize) or 38
  local numCellsX = math.floor(gridAvailableWidth / cellSize)
  local gridWidth = numCellsX * cellSize
  local gridOffsetX = sidePadding + gridPadding + (gridAvailableWidth - gridWidth) * 0.5
  
  -- Grid starts at margin + playfieldXOffset + gridOffsetX
  local gridStartX = margin + playfieldXOffset + gridOffsetX
  local gridEndX = gridStartX + gridWidth
  
  return gridStartX, gridEndX
end

return M

