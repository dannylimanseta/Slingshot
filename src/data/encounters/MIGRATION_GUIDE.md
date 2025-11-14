# Encounter System Migration Guide

## Overview

The encounter system has been refactored from a single large file (`encounters.lua`) into a modular directory structure. This makes it much easier to add, modify, and maintain encounters as the game grows.

## Directory Structure

```
src/data/encounters/
├── _manifest.lua          # Lists all encounter files to load
├── base/                  # Basic encounters (difficulty 1)
│   ├── solo.lua          # Solo enemy encounters
│   └── double.lua        # Two enemy encounters
├── elite/                 # Elite encounters
│   ├── crawler_boar.lua
│   ├── crawler_fawn.lua
│   └── stagmaw_fawn.lua
└── difficulty_2/          # Higher difficulty encounters
    ├── solo_boar.lua
    ├── double_boar.lua
    └── boar_fawn.lua
```

## Adding New Encounters

### Step 1: Create the Encounter File

Create a new `.lua` file in the appropriate directory. The file should return an array of encounter tables:

```lua
-- src/data/encounters/base/my_new_encounter.lua
return {
  {
    id = "ENCOUNTER_MY_NEW_ENCOUNTER",
    difficulty = 1,
    centerWidthFactor = 0.43,
    enemies = {
      "fawn",
      "crawler"
    },
    blockFormation = {
      predefined = {
        -- Your block formation here
        { hp = 1, kind = "damage", x = 0.5, y = 0.5 }
      },
      type = "predefined"
    }
  }
}
```

### Step 2: Add to Manifest

Edit `_manifest.lua` and add your new file:

```lua
return {
  -- ... existing entries ...
  { "base", "my_new_encounter" },  -- Add this line
}
```

That's it! The system will automatically load your new encounter.

## File Organization Guidelines

- **base/**: Standard encounters, difficulty 1, non-elite
- **elite/**: Elite encounters (marked with `elite = true`)
- **difficulty_2/**: Higher difficulty encounters

You can create additional subdirectories as needed (e.g., `difficulty_3/`, `boss/`, etc.) and add them to the manifest.

## Benefits

1. **Scalability**: Each encounter is in its own file, making it easy to find and edit
2. **Organization**: Group related encounters together
3. **Maintainability**: Changes to one encounter don't affect others
4. **Version Control**: Smaller files = cleaner git diffs
5. **Hot Reloading**: The `reload()` function allows hot-reloading during development

## Backward Compatibility

The API remains the same:
- `encounters.get(id)` - Get encounter by ID
- `encounters.list()` - Get all encounters
- `encounters.reload()` - Reload all encounters (for development)

No changes needed to existing code that uses encounters!

