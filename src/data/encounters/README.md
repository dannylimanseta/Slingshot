# Encounters Directory Structure

This directory contains encounter definitions organized by category.

## Structure

- `base/` - Basic encounters (solo enemies, simple combinations)
- `elite/` - Elite encounters (marked with `elite = true`)
- `difficulty_2/` - Higher difficulty encounters

## Adding New Encounters

1. Create a new file in the appropriate category directory
2. Export your encounter(s) as a table or array
3. The main `encounters.lua` will automatically load it

## Example

```lua
-- src/data/encounters/base/solo_fawn.lua
return {
  {
    id = "ENCOUNTER_SOLO_FAWN",
    difficulty = 1,
    -- ... rest of encounter definition
  }
}
```

