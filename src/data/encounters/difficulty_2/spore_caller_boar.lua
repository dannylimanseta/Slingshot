-- Difficulty 2: Spore Caller + Bloodhound
-- Formation Shape: Left = Spore Caller (vertical tower), Right = Bloodhound (pyramid)
-- Center bridge with AOE blocks for hitting both enemies
return {
  {
    id = "ENCOUNTER_SPORE_CALLER_BLOODHOUND",
    difficulty = 2,
    centerWidthFactor = 0.43,
    enemies = {
      "spore_caller",
      "bloodhound"
    },
    blockFormation = {
      predefined = {
        -- Left side: Vertical tower formation (for Spore Caller)
        -- Bottom foundation
        { hp = 1, kind = "damage", x = 0.279, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.342, y = 0.621 },
        -- Second row
        { hp = 1, kind = "armor", x = 0.279, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.342, y = 0.549 },
        -- Third row
        { hp = 1, kind = "damage", x = 0.279, y = 0.477 },
        { hp = 1, kind = "crit", x = 0.342, y = 0.477 },
        -- Fourth row
        { hp = 1, kind = "armor", x = 0.279, y = 0.406 },
        { hp = 1, kind = "crit", x = 0.342, y = 0.406 },
        -- Fifth row
        { hp = 1, kind = "damage", x = 0.279, y = 0.334 },
        { hp = 1, kind = "multiplier", x = 0.342, y = 0.334 },
        -- Top
        { hp = 1, kind = "crit", x = 0.310, y = 0.262 },
        -- Side support
        { hp = 1, kind = "potion", x = 0.153, y = 0.477 },
        { hp = 1, kind = "potion", x = 0.153, y = 0.334 },
        { hp = 1, kind = "armor", x = 0.216, y = 0.406 },
        
        -- Right side: Pyramid formation (for Bloodhound)
        -- Bottom row (wide base)
        { hp = 1, kind = "damage", x = 0.658, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.721, y = 0.621 },
        { hp = 1, kind = "damage", x = 0.784, y = 0.621 },
        -- Second row
        { hp = 1, kind = "armor", x = 0.658, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.721, y = 0.549 },
        { hp = 1, kind = "armor", x = 0.784, y = 0.549 },
        -- Third row
        { hp = 1, kind = "damage", x = 0.658, y = 0.477 },
        { hp = 1, kind = "crit", x = 0.721, y = 0.477 },
        { hp = 1, kind = "damage", x = 0.784, y = 0.477 },
        -- Fourth row
        { hp = 1, kind = "armor", x = 0.658, y = 0.406 },
        { hp = 1, kind = "multiplier", x = 0.721, y = 0.406 },
        { hp = 1, kind = "armor", x = 0.784, y = 0.406 },
        -- Fifth row
        { hp = 1, kind = "crit", x = 0.658, y = 0.334 },
        { hp = 1, kind = "crit", x = 0.784, y = 0.334 },
        -- Top
        { hp = 1, kind = "crit", x = 0.721, y = 0.262 },
        -- Side support
        { hp = 1, kind = "potion", x = 0.847, y = 0.477 },
        { hp = 1, kind = "potion", x = 0.847, y = 0.334 },
        
        -- Center bridge - AOE blocks (effective against both enemies)
        -- Well-separated from left (ends at x=0.342) and right (starts at x=0.658)
        { hp = 1, kind = "aoe", x = 0.405, y = 0.477 },
        { hp = 1, kind = "aoe", x = 0.468, y = 0.477 },
        { hp = 1, kind = "aoe", x = 0.532, y = 0.477 },
        { hp = 1, kind = "aoe", x = 0.595, y = 0.477 },
        -- Center middle row
        { hp = 1, kind = "crit", x = 0.405, y = 0.406 },
        { hp = 1, kind = "multiplier", x = 0.5, y = 0.406 },
        { hp = 1, kind = "crit", x = 0.595, y = 0.406 },
        -- Center top - high value targets
        { hp = 1, kind = "crit", x = 0.468, y = 0.334 },
        { hp = 1, kind = "armor", x = 0.532, y = 0.334 },
        { hp = 1, kind = "crit", x = 0.5, y = 0.262 },
        -- Center bottom support
        { hp = 1, kind = "damage", x = 0.468, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.532, y = 0.549 }
      },
      type = "predefined"
    }
  }
}

