-- Difficulty 2: Spore Caller + Bloodhound
-- Formation Shape: Double Spiral Vortex
-- Two interlocking spirals with clear, visible swirl pattern
-- Left spiral (counter-clockwise) for Spore Caller, Right spiral (clockwise) for Bloodhound
-- Spacing: 0.05-0.07 horizontal, 0.07-0.09 vertical to prevent occlusion
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
        -- LEFT SPIRAL (Counter-clockwise: Top → Left → Bottom → Right → Center)
        -- Outer ring - 8 points forming clear counter-clockwise rotation
        { hp = 1, kind = "damage", x = 0.279, y = 0.191 },  -- Top (12 o'clock)
        { hp = 1, kind = "armor", x = 0.153, y = 0.334 },   -- Left (9 o'clock)
        { hp = 1, kind = "damage", x = 0.153, y = 0.477 },  -- Left-center
        { hp = 1, kind = "crit", x = 0.216, y = 0.621 },    -- Bottom-left (7 o'clock)
        { hp = 1, kind = "damage", x = 0.342, y = 0.692 },  -- Bottom (6 o'clock)
        { hp = 1, kind = "armor", x = 0.468, y = 0.621 },   -- Bottom-right (5 o'clock)
        { hp = 1, kind = "damage", x = 0.468, y = 0.477 },   -- Right-center (3 o'clock)
        { hp = 1, kind = "crit", x = 0.405, y = 0.334 },    -- Top-right (1 o'clock)
        
        -- Middle ring - 6 points continuing spiral inward
        { hp = 1, kind = "damage", x = 0.342, y = 0.262 },   -- Top (12 o'clock)
        { hp = 1, kind = "armor", x = 0.216, y = 0.406 },    -- Left (9 o'clock)
        { hp = 1, kind = "damage", x = 0.279, y = 0.549 },   -- Bottom-left (7 o'clock)
        { hp = 1, kind = "crit", x = 0.405, y = 0.549 },    -- Bottom (6 o'clock)
        { hp = 1, kind = "damage", x = 0.405, y = 0.406 },   -- Right (3 o'clock)
        { hp = 1, kind = "potion", x = 0.342, y = 0.406 },  -- Inner center-left
        
        -- RIGHT SPIRAL (Clockwise: Top → Right → Bottom → Left → Center)
        -- Outer ring - 8 points forming clear clockwise rotation
        { hp = 1, kind = "damage", x = 0.721, y = 0.191 },  -- Top (12 o'clock)
        { hp = 1, kind = "armor", x = 0.847, y = 0.334 },   -- Right (3 o'clock)
        { hp = 1, kind = "damage", x = 0.847, y = 0.477 },  -- Right-center
        { hp = 1, kind = "crit", x = 0.784, y = 0.621 },    -- Bottom-right (5 o'clock)
        { hp = 1, kind = "damage", x = 0.658, y = 0.692 },  -- Bottom (6 o'clock)
        { hp = 1, kind = "armor", x = 0.532, y = 0.621 },   -- Bottom-left (7 o'clock)
        { hp = 1, kind = "damage", x = 0.532, y = 0.477 },   -- Left-center (9 o'clock)
        { hp = 1, kind = "crit", x = 0.595, y = 0.334 },    -- Top-left (11 o'clock)
        
        -- Middle ring - 6 points continuing spiral inward
        { hp = 1, kind = "damage", x = 0.658, y = 0.262 },   -- Top (12 o'clock)
        { hp = 1, kind = "armor", x = 0.784, y = 0.406 },    -- Right (3 o'clock)
        { hp = 1, kind = "damage", x = 0.721, y = 0.549 },   -- Bottom-right (5 o'clock)
        { hp = 1, kind = "crit", x = 0.595, y = 0.549 },    -- Bottom (6 o'clock)
        { hp = 1, kind = "damage", x = 0.595, y = 0.406 },   -- Left (9 o'clock)
        { hp = 1, kind = "potion", x = 0.658, y = 0.406 },  -- Inner center-right
        
        -- CENTER CONVERGENCE (Where spirals meet - high value targets)
        { hp = 1, kind = "aoe", x = 0.468, y = 0.477 },      -- Left-center AOE
        { hp = 1, kind = "aoe", x = 0.532, y = 0.477 },      -- Right-center AOE
        { hp = 1, kind = "crit", x = 0.5, y = 0.406 },       -- Top center
        { hp = 1, kind = "multiplier", x = 0.5, y = 0.334 }, -- Top center premium
        { hp = 1, kind = "crit", x = 0.5, y = 0.262 },      -- Topmost center
        
        -- SPIRAL ENHANCEMENTS (Additional blocks to reinforce spiral visibility)
        -- Top outer points
        { hp = 1, kind = "potion", x = 0.279, y = 0.262 },  -- Left top
        { hp = 1, kind = "potion", x = 0.721, y = 0.262 },  -- Right top
        -- Side outer points
        { hp = 1, kind = "armor", x = 0.216, y = 0.406 },   -- Left side
        { hp = 1, kind = "armor", x = 0.784, y = 0.406 },   -- Right side
        -- Bottom outer points
        { hp = 1, kind = "damage", x = 0.279, y = 0.692 },   -- Left bottom
        { hp = 1, kind = "damage", x = 0.721, y = 0.692 },  -- Right bottom
      },
      type = "predefined"
    }
  }
}

