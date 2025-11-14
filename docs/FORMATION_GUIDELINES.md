# Block Formation Design Guidelines

This document provides guidelines for designing block formations in encounter files.

## Coordinate System

- **Normalized Coordinates**: All positions use normalized coordinates (0.0 to 1.0)
  - `x`: Normalized relative to effective playfield width (typically 0.15 to 0.85)
  - `y`: Normalized relative to playfield height (typically 0.19 to 0.84)
- **Y-axis**: Increases downward (0.0 = top, 1.0 = bottom)
- **X-axis**: Increases rightward (0.0 = left, 1.0 = right)

## Block Types

| Type | Key | Description | Common Use |
|------|-----|-------------|------------|
| Damage | `damage` | Basic damage block (+1 damage) | Foundation blocks, general damage |
| Armor | `armor` | Armor block (+3 armor) | Protection layers, defensive positioning |
| Crit | `crit` | Critical hit block (2x damage) | High-value targets, strategic positioning |
| Multiplier | `multiplier` | Applies damage multiplier | Center positioning, combo setups |
| AOE | `aoe` | Area of Effect (+3 damage, hits all enemies) | Center bridge for multi-enemy encounters |
| Potion | `potion` | Heals player (8 HP) | Side wings, top sections, recovery points |

## Formation Structure

### Basic Block Definition
```lua
{ hp = 1, kind = "damage", x = 0.5, y = 0.5 }
```

- `hp`: Block health (typically 1)
- `kind`: Block type (see Block Types above)
- `x`: Normalized X coordinate (0.0 to 1.0)
- `y`: Normalized Y coordinate (0.0 to 1.0)

## Formation Patterns

### Solo Enemy Encounters

**Layout Strategy**: Centered formations, often vertical towers

**Common Patterns**:
- **Foundation Layer** (y ≈ 0.62): Wide base of damage blocks
- **Protection Layer** (y ≈ 0.55): Armor blocks for defense
- **Strategic Layer** (y ≈ 0.48): Mix of damage and crit blocks
- **High-Value Layer** (y ≈ 0.33-0.41): Crit blocks and multipliers
- **Top Section** (y ≈ 0.19-0.26): Potions and final crit blocks

**Example Structure**:
```lua
-- Bottom foundation (wide base)
{ hp = 1, kind = "damage", x = 0.405, y = 0.621 },
{ hp = 1, kind = "damage", x = 0.468, y = 0.621 },
{ hp = 1, kind = "damage", x = 0.532, y = 0.621 },
{ hp = 1, kind = "damage", x = 0.595, y = 0.621 },
-- Second row (armor protection)
{ hp = 1, kind = "armor", x = 0.405, y = 0.549 },
{ hp = 1, kind = "damage", x = 0.468, y = 0.549 },
-- ... continue building upward
```

**Guidelines**:
- Center blocks around x = 0.4 to 0.6
- Build from bottom to top
- Use wider spacing (0.05-0.07 between blocks) to prevent occlusion
- No AOE blocks needed (single enemy)

### Double Enemy Encounters

**Layout Strategy**: Left/right side formations with center bridge

**Common Patterns**:
- **Left Side** (x ≈ 0.15-0.40): Formation for left enemy
- **Right Side** (x ≈ 0.60-0.85): Formation for right enemy
- **Center Bridge** (x ≈ 0.40-0.60, y ≈ 0.48): AOE blocks effective against both enemies
- **Center Top** (x ≈ 0.45-0.55, y ≈ 0.33-0.41): High-value targets (crit, multiplier)

**Example Structure**:
```lua
-- Left side formation (for left enemy)
{ hp = 1, kind = "damage", x = 0.279, y = 0.621 },
{ hp = 1, kind = "damage", x = 0.342, y = 0.621 },
{ hp = 1, kind = "armor", x = 0.279, y = 0.549 },
-- ... continue left side

-- Right side formation (for right enemy)
{ hp = 1, kind = "damage", x = 0.658, y = 0.621 },
{ hp = 1, kind = "damage", x = 0.721, y = 0.621 },
{ hp = 1, kind = "armor", x = 0.721, y = 0.549 },
-- ... continue right side

-- Center bridge (AOE blocks)
{ hp = 1, kind = "aoe", x = 0.468, y = 0.477 },
{ hp = 1, kind = "aoe", x = 0.532, y = 0.477 },
```

**Guidelines**:
- Keep left and right formations balanced
- Place AOE blocks in center bridge (y ≈ 0.48) for multi-target effectiveness
- Use `centerWidthFactor = 0.43` to define center area
- Mirror formations when possible for visual symmetry

### Multi-Enemy Encounters (3+ enemies)

**Layout Strategy**: Separate formations per enemy side with center bridge

**Common Patterns**:
- **Left Side** (x ≈ 0.15-0.35): Formation for leftmost enemy
- **Center-Left** (x ≈ 0.35-0.50): Formation for center enemy (if applicable)
- **Center-Right** (x ≈ 0.50-0.65): Formation for center enemy (if applicable)
- **Right Side** (x ≈ 0.65-0.85): Formation for rightmost enemy
- **Center Bridge** (x ≈ 0.40-0.60): AOE blocks spanning multiple enemies

**Guidelines**:
- Spread formations wider to accommodate multiple enemies
- Increase AOE block count in center bridge
- Consider enemy-specific formations (e.g., shockwave-resistant spread for crawler)

### Elite Encounters

**Layout Strategy**: Larger, more complex formations with strategic positioning

**Common Patterns**:
- More blocks overall (50-80 blocks)
- Deeper formations (extending to y ≈ 0.84)
- Strategic block placement based on enemy abilities
- Higher density of high-value blocks (crit, multiplier)

**Guidelines**:
- Use enemy-specific strategies (e.g., spread formations for shockwave-resistant enemies)
- Increase block variety and strategic positioning
- Consider enemy positioning when placing blocks

## Block Placement Guidelines

### Y-Coordinate Ranges

| Section | Y Range | Typical Use |
|---------|---------|-------------|
| Top | 0.19 - 0.26 | Potions, high-value crit blocks |
| Upper Middle | 0.33 - 0.41 | Crit blocks, multipliers, strategic targets |
| Middle | 0.48 - 0.55 | AOE blocks (center bridge), main formation layers |
| Lower Middle | 0.62 - 0.69 | Foundation blocks, armor layers |
| Bottom | 0.76 - 0.84 | Extended formations (elite encounters) |

### X-Coordinate Ranges

| Section | X Range | Typical Use |
|---------|---------|-------------|
| Far Left | 0.15 - 0.22 | Left side formations, side wings |
| Left | 0.28 - 0.40 | Left enemy formations |
| Center-Left | 0.40 - 0.50 | Center bridge (left side), center formations |
| Center-Right | 0.50 - 0.60 | Center bridge (right side), center formations |
| Right | 0.60 - 0.72 | Right enemy formations |
| Far Right | 0.78 - 0.85 | Right side formations, side wings |

### Spacing Guidelines

- **Horizontal Spacing**: 0.05 to 0.07 between block centers (prevents occlusion)
- **Vertical Spacing**: 0.07 to 0.09 between rows (allows visual clarity)
- **Grid Alignment**: Consider aligning to grid (multiples of ~0.043 for x, ~0.07 for y)

## Block Type Distribution

### Solo Encounters
- **Damage**: 40-50% (foundation)
- **Armor**: 20-30% (protection layers)
- **Crit**: 15-20% (strategic targets)
- **Multiplier**: 5-10% (center positioning)
- **Potion**: 5-10% (side wings, top)
- **AOE**: 0% (not needed for single enemy)

### Double Encounters
- **Damage**: 35-45% (foundation)
- **Armor**: 20-25% (protection layers)
- **Crit**: 15-20% (strategic targets)
- **Multiplier**: 5-10% (center positioning)
- **AOE**: 10-15% (center bridge)
- **Potion**: 5-10% (side wings, top)

### Elite Encounters
- **Damage**: 30-40% (foundation)
- **Armor**: 25-30% (extended protection)
- **Crit**: 20-25% (increased strategic value)
- **Multiplier**: 5-10% (center positioning)
- **AOE**: 10-15% (center bridge)
- **Potion**: 5-10% (side wings, top)

## Common Formation Patterns

### Vertical Tower
- Single column or narrow formation
- Good for solo encounters
- Builds from bottom to top
- Example: Solo Fungloom

### Horizontal Spread
- Wide, shallow formation
- Good for shockwave-resistant enemies
- Spreads blocks across multiple columns
- Example: Crawler formations

### Pyramid/Triangle
- Wide base, narrows toward top
- Classic formation pattern
- Good balance of foundation and strategic targets
- Example: Solo Fawn

### Dual Towers
- Two separate vertical formations
- One per enemy in double encounters
- Connected by center bridge
- Example: Double Fawn

### Center Bridge
- Horizontal row of AOE blocks in center
- Connects left and right formations
- Effective against multiple enemies
- Typically at y ≈ 0.48

## Formation Shape Variety

**IMPORTANT**: Vary formation shapes to keep encounters visually interesting and strategically diverse. Don't always use the same patterns!

### Diamond/Rhombus
- Diamond shape with widest point in middle
- Good for solo encounters
- Creates interesting targeting challenges
- Example pattern:
```lua
-- Top point
{ hp = 1, kind = "crit", x = 0.5, y = 0.334 },
-- Upper middle (wider)
{ hp = 1, kind = "damage", x = 0.468, y = 0.406 },
{ hp = 1, kind = "damage", x = 0.532, y = 0.406 },
-- Middle (widest)
{ hp = 1, kind = "damage", x = 0.436, y = 0.477 },
{ hp = 1, kind = "damage", x = 0.5, y = 0.477 },
{ hp = 1, kind = "damage", x = 0.564, y = 0.477 },
-- Lower middle (narrower)
{ hp = 1, kind = "armor", x = 0.468, y = 0.549 },
{ hp = 1, kind = "armor", x = 0.532, y = 0.549 },
-- Bottom point
{ hp = 1, kind = "damage", x = 0.5, y = 0.621 }
```

### Circle/Ring
- Blocks arranged in circular or ring pattern
- Good for solo encounters, creates unique targeting
- Can be full circle or partial arc
- Example pattern (partial ring):
```lua
-- Top arc
{ hp = 1, kind = "damage", x = 0.436, y = 0.334 },
{ hp = 1, kind = "crit", x = 0.5, y = 0.262 },
{ hp = 1, kind = "damage", x = 0.564, y = 0.334 },
-- Sides
{ hp = 1, kind = "armor", x = 0.405, y = 0.406 },
{ hp = 1, kind = "armor", x = 0.595, y = 0.406 },
-- Bottom arc
{ hp = 1, kind = "damage", x = 0.436, y = 0.549 },
{ hp = 1, kind = "damage", x = 0.564, y = 0.549 }
```

### Wave Pattern
- Blocks arranged in wavy or zigzag pattern
- Creates interesting visual flow
- Good for multi-enemy encounters with flowing movement
- Example pattern:
```lua
-- Wave pattern (zigzag)
{ hp = 1, kind = "damage", x = 0.279, y = 0.477 },
{ hp = 1, kind = "damage", x = 0.342, y = 0.406 },  -- Up
{ hp = 1, kind = "damage", x = 0.405, y = 0.477 },  -- Down
{ hp = 1, kind = "damage", x = 0.468, y = 0.406 },  -- Up
{ hp = 1, kind = "damage", x = 0.532, y = 0.477 },  -- Down
{ hp = 1, kind = "damage", x = 0.595, y = 0.406 },  -- Up
{ hp = 1, kind = "damage", x = 0.658, y = 0.477 }   -- Down
```

### Spiral
- Blocks arranged in spiral pattern
- Creates unique visual interest
- Good for elite encounters
- Example pattern:
```lua
-- Spiral from outside in
{ hp = 1, kind = "damage", x = 0.405, y = 0.334 },  -- Top-left
{ hp = 1, kind = "damage", x = 0.595, y = 0.334 },  -- Top-right
{ hp = 1, kind = "damage", x = 0.595, y = 0.549 },  -- Bottom-right
{ hp = 1, kind = "damage", x = 0.405, y = 0.549 },  -- Bottom-left
{ hp = 1, kind = "crit", x = 0.5, y = 0.477 }        -- Center
```

### Staircase/Steps
- Blocks arranged in stepped pattern
- Creates diagonal visual flow
- Good for both solo and multi-enemy encounters
- Example pattern:
```lua
-- Left staircase
{ hp = 1, kind = "damage", x = 0.279, y = 0.621 },
{ hp = 1, kind = "damage", x = 0.342, y = 0.549 },
{ hp = 1, kind = "damage", x = 0.405, y = 0.477 },
{ hp = 1, kind = "damage", x = 0.468, y = 0.406 },
-- Right staircase (mirrored)
{ hp = 1, kind = "damage", x = 0.721, y = 0.621 },
{ hp = 1, kind = "damage", x = 0.658, y = 0.549 },
{ hp = 1, kind = "damage", x = 0.595, y = 0.477 },
{ hp = 1, kind = "damage", x = 0.532, y = 0.406 }
```

### Cross/Plus
- Blocks arranged in cross or plus shape
- Good for solo encounters
- Creates interesting center focus
- Example pattern:
```lua
-- Vertical line
{ hp = 1, kind = "damage", x = 0.5, y = 0.334 },
{ hp = 1, kind = "crit", x = 0.5, y = 0.406 },
{ hp = 1, kind = "damage", x = 0.5, y = 0.477 },
{ hp = 1, kind = "damage", x = 0.5, y = 0.549 },
{ hp = 1, kind = "damage", x = 0.5, y = 0.621 },
-- Horizontal line
{ hp = 1, kind = "armor", x = 0.405, y = 0.477 },
{ hp = 1, kind = "armor", x = 0.468, y = 0.477 },
{ hp = 1, kind = "armor", x = 0.532, y = 0.477 },
{ hp = 1, kind = "armor", x = 0.595, y = 0.477 }
```

### Hexagon
- Blocks arranged in hexagonal pattern
- Good for solo encounters
- Creates balanced, interesting shape
- Example pattern:
```lua
-- Top
{ hp = 1, kind = "crit", x = 0.5, y = 0.334 },
-- Upper sides
{ hp = 1, kind = "damage", x = 0.436, y = 0.406 },
{ hp = 1, kind = "damage", x = 0.564, y = 0.406 },
-- Middle sides
{ hp = 1, kind = "armor", x = 0.405, y = 0.477 },
{ hp = 1, kind = "armor", x = 0.595, y = 0.477 },
-- Lower sides
{ hp = 1, kind = "damage", x = 0.436, y = 0.549 },
{ hp = 1, kind = "damage", x = 0.564, y = 0.549 },
-- Bottom
{ hp = 1, kind = "damage", x = 0.5, y = 0.621 }
```

### Arrow/Chevron
- Blocks arranged pointing in a direction
- Creates directional visual flow
- Good for encounters with movement themes
- Example pattern (pointing up):
```lua
-- Bottom row (wide)
{ hp = 1, kind = "damage", x = 0.405, y = 0.621 },
{ hp = 1, kind = "damage", x = 0.468, y = 0.621 },
{ hp = 1, kind = "damage", x = 0.532, y = 0.621 },
{ hp = 1, kind = "damage", x = 0.595, y = 0.621 },
-- Middle row (narrower)
{ hp = 1, kind = "armor", x = 0.468, y = 0.549 },
{ hp = 1, kind = "armor", x = 0.532, y = 0.549 },
-- Top point
{ hp = 1, kind = "crit", x = 0.5, y = 0.477 }
```

### Shape Variation Tips

1. **Mix Shapes**: Don't use the same shape for every encounter - alternate between tower, diamond, wave, etc.
2. **Enemy Theme**: Match shape to enemy theme (e.g., wave pattern for water-themed enemies)
3. **Difficulty Scaling**: Use simpler shapes (tower, pyramid) for easier encounters, complex shapes (spiral, hexagon) for elite encounters
4. **Multi-Enemy Variation**: Use different shapes for each enemy side (e.g., tower on left, diamond on right)
5. **Visual Interest**: Unusual shapes create memorable encounters
6. **Strategic Depth**: Different shapes create different targeting challenges for players

## Best Practices

1. **Vary Formation Shapes**: Use different shapes (diamond, tower, circle, wave, spiral, etc.) to keep encounters visually interesting and strategically diverse
2. **Start with Foundation**: Always begin with bottom row of damage blocks
3. **Build Upward**: Layer blocks from bottom to top
4. **Balance Formations**: Keep left/right formations balanced in multi-enemy encounters
5. **Use Center Bridge**: Place AOE blocks in center for multi-enemy encounters
6. **Strategic Positioning**: Place high-value blocks (crit, multiplier) in accessible positions
7. **Prevent Occlusion**: Use adequate spacing (0.05-0.07) between blocks
8. **Consider Enemy Abilities**: Design formations that work with or against enemy mechanics
9. **Match Shape to Theme**: Consider matching formation shape to enemy theme (e.g., wave for water enemies)
10. **Test Visually**: Verify formations look balanced and playable
11. **Comment Your Code**: Add comments explaining formation strategy and shape choice
12. **Follow Existing Patterns**: Use similar encounters as reference, but don't copy exactly - vary the shapes!

## Example Encounter Structure

```lua
return {
  {
    id = "ENCOUNTER_EXAMPLE",
    difficulty = 1,
    centerWidthFactor = 0.43,  -- For multi-enemy encounters
    enemies = {
      "fawn",
      "fawn"
    },
    blockFormation = {
      predefined = {
        -- Left side formation (for left enemy)
        -- Bottom foundation
        { hp = 1, kind = "damage", x = 0.279, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.342, y = 0.621 },
        -- Second row
        { hp = 1, kind = "armor", x = 0.279, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.342, y = 0.549 },
        -- ... continue building
        
        -- Right side formation (for right enemy)
        -- Bottom foundation
        { hp = 1, kind = "damage", x = 0.658, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.721, y = 0.621 },
        -- ... continue building
        
        -- Center bridge (AOE blocks)
        { hp = 1, kind = "aoe", x = 0.468, y = 0.477 },
        { hp = 1, kind = "aoe", x = 0.532, y = 0.477 },
        
        -- Center top (high-value targets)
        { hp = 1, kind = "crit", x = 0.5, y = 0.334 }
      },
      type = "predefined"
    }
  }
}
```

## Troubleshooting

**Blocks overlapping visually**: Increase spacing between blocks (aim for 0.05-0.07 difference in coordinates)

**Formation looks unbalanced**: Mirror left/right formations or adjust block counts

**AOE blocks not effective**: Ensure center bridge spans x ≈ 0.40-0.60 and is at appropriate y level (≈ 0.48)

**Formation too dense**: Reduce block count or increase spacing

**Formation too sparse**: Add more blocks or reduce spacing

## Reference Files

- Base encounters: `src/data/encounters/base/`
- Difficulty 2 encounters: `src/data/encounters/difficulty_2/`
- Elite encounters: `src/data/encounters/elite/`
- Block types: `src/data/block_types.lua`

