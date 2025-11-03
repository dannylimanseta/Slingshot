-- Centralized Block Type Registry
-- This file defines all available block types and their properties
-- Adding a new block type here will automatically make it available everywhere

local block_types = {}

-- Block type definitions
-- Each entry contains:
--   key: string identifier (used in code)
--   displayName: string shown in UI
--   spritePath: relative path to sprite image
--   hotkey: number key (1-9) for editor selection
--   description: optional tooltip/help text
block_types.types = {
  {
    key = "damage",
    displayName = "Damage",
    spritePath = "block_attack",
    hotkey = 1,
    description = "Basic damage block (+1 damage)"
  },
  {
    key = "armor",
    displayName = "Armor",
    spritePath = "block_defend",
    hotkey = 2,
    description = "Armor block (grants armor)"
  },
  {
    key = "crit",
    displayName = "Crit",
    spritePath = "block_crit",
    hotkey = 3,
    description = "Critical hit block (2x damage multiplier)"
  },
  {
    key = "soul",
    displayName = "4x Crit",
    spritePath = "block_crit_2",
    hotkey = 4,
    description = "Soul block (4x damage multiplier)"
  },
  {
    key = "aoe",
    displayName = "AOE",
    spritePath = "block_aoe",
    hotkey = 5,
    description = "Area of Effect block (+3 damage, attacks all enemies)"
  },
  {
    key = "potion",
    displayName = "Potion",
    spritePath = "block_potion",
    hotkey = 6,
    description = "Potion block (heals player for 8 HP)"
  },
}

-- Get block type by key
function block_types.getByKey(key)
  for _, blockType in ipairs(block_types.types) do
    if blockType.key == key then
      return blockType
    end
  end
  return nil
end

-- Get block type by hotkey
function block_types.getByHotkey(hotkey)
  for _, blockType in ipairs(block_types.types) do
    if blockType.hotkey == hotkey then
      return blockType
    end
  end
  return nil
end

-- Get all block type keys
function block_types.getAllKeys()
  local keys = {}
  for _, blockType in ipairs(block_types.types) do
    table.insert(keys, blockType.key)
  end
  return keys
end

-- Get all block types sorted by hotkey
function block_types.getAllSorted()
  local sorted = {}
  for _, blockType in ipairs(block_types.types) do
    table.insert(sorted, blockType)
  end
  table.sort(sorted, function(a, b)
    return (a.hotkey or 99) < (b.hotkey or 99)
  end)
  return sorted
end

-- Get default block type (first one, usually "damage")
function block_types.getDefault()
  return block_types.types[1] and block_types.types[1].key or "damage"
end

-- Validate that a block type key exists
function block_types.isValid(key)
  return block_types.getByKey(key) ~= nil
end

return block_types

