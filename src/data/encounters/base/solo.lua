-- Base solo enemy encounters
return {
  {
    id = "ENCOUNTER_SOLO_FAWN",
    difficulty = 1,
    centerWidthFactor = 0.43,
    enemies = {
      "fawn"
    },
    blockFormation = {
      predefined = {
        -- Bottom row (foundation) - damage blocks
        { hp = 1, kind = "damage", x = 0.405, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.468, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.532, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.595, y = 0.621 },
        -- Second row - mix of damage and armor
        { hp = 1, kind = "armor", x = 0.405, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.468, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.532, y = 0.549 },
        { hp = 1, kind = "armor", x = 0.595, y = 0.549 },
        -- Third row - center focus with crit
        { hp = 1, kind = "damage", x = 0.436, y = 0.477 },
        { hp = 1, kind = "crit", x = 0.5, y = 0.477 },
        { hp = 1, kind = "damage", x = 0.564, y = 0.477 },
        -- Fourth row - armor protection layer
        { hp = 1, kind = "armor", x = 0.468, y = 0.406 },
        { hp = 1, kind = "armor", x = 0.532, y = 0.406 },
        -- Top section - strategic positioning
        { hp = 1, kind = "crit", x = 0.5, y = 0.334 },
        { hp = 1, kind = "damage", x = 0.436, y = 0.262 },
        { hp = 1, kind = "damage", x = 0.564, y = 0.262 },
        -- Side wings for variety
        { hp = 1, kind = "potion", x = 0.342, y = 0.477 },
        { hp = 1, kind = "potion", x = 0.658, y = 0.477 }
      },
      type = "predefined"
    }
  },
  {
    id = "ENCOUNTER_SOLO_FUNGLOOM",
    difficulty = 1,
    centerWidthFactor = 0.43,
    enemies = {
      "fungloom"
    },
    blockFormation = {
      predefined = {
        -- Vertical tower formation - well-spaced to avoid occlusion
        -- Bottom foundation (wide base, good spacing)
        { hp = 1, kind = "damage", x = 0.405, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.5, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.595, y = 0.621 },
        -- Second row - armor protection (staggered for better visibility)
        { hp = 1, kind = "armor", x = 0.436, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.5, y = 0.549 },
        { hp = 1, kind = "armor", x = 0.564, y = 0.549 },
        -- Third row - crit focus (wider spacing to prevent occlusion)
        { hp = 1, kind = "damage", x = 0.405, y = 0.477 },
        { hp = 1, kind = "crit", x = 0.5, y = 0.477 },
        { hp = 1, kind = "damage", x = 0.595, y = 0.477 },
        -- Fourth row - multiplier introduction (protected, wider spacing)
        { hp = 1, kind = "armor", x = 0.436, y = 0.406 },
        { hp = 1, kind = "multiplier", x = 0.5, y = 0.406 },
        { hp = 1, kind = "armor", x = 0.564, y = 0.406 },
        -- Fifth row - high value targets (spread out)
        { hp = 1, kind = "crit", x = 0.405, y = 0.334 },
        { hp = 1, kind = "damage", x = 0.5, y = 0.334 },
        { hp = 1, kind = "crit", x = 0.595, y = 0.334 },
        -- Top section - potions and final crit (well spaced)
        { hp = 1, kind = "potion", x = 0.405, y = 0.262 },
        { hp = 1, kind = "crit", x = 0.5, y = 0.262 },
        { hp = 1, kind = "potion", x = 0.595, y = 0.262 },
        -- Side wings - additional damage blocks (no AOE for single enemy)
        { hp = 1, kind = "damage", x = 0.342, y = 0.477 },
        { hp = 1, kind = "damage", x = 0.658, y = 0.477 },
        { hp = 1, kind = "armor", x = 0.279, y = 0.406 },
        { hp = 1, kind = "armor", x = 0.721, y = 0.406 }
      },
      type = "predefined"
    }
  }
}

