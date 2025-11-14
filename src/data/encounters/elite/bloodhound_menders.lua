-- Elite: Bloodhound + 2 Menders
-- Formation: Left = Bloodhound (aggressive DPS), Right = Two Menders (support/heal)
-- Strategy: Menders will heal the Bloodhound, making the fight harder as it gets more dangerous when wounded
return {
  {
    id = "ENCOUNTER_ELITE_BLOODHOUND_MENDERS",
    difficulty = 2, -- Difficulty 2
    elite = true,
    centerWidthFactor = 0.43,
    enemies = {
      "bloodhound",
      "mender",
      "mender",
    },
    blockFormation = {
      predefined = {
        -- INTEGRATED FORMATION: Menacing face with support columns
        
        -- === LEFT SIDE: Bloodhound's aggressive formation ===
        -- Fangs/aggressive left side
        { hp = 1, kind = "damage", x = 0.153, y = 0.191 },
        { hp = 1, kind = "damage", x = 0.216, y = 0.262 },
        { hp = 1, kind = "crit", x = 0.153, y = 0.334 },
        { hp = 1, kind = "damage", x = 0.216, y = 0.406 },
        { hp = 1, kind = "damage", x = 0.153, y = 0.477 },
        
        -- Left eye and cheek
        { hp = 1, kind = "multiplier", x = 0.279, y = 0.262 },
        { hp = 1, kind = "armor", x = 0.279, y = 0.334 },
        { hp = 1, kind = "damage", x = 0.279, y = 0.406 },
        
        -- === CENTER: Shared aggressive features ===
        -- Forehead/top
        { hp = 1, kind = "crit", x = 0.342, y = 0.191 },
        { hp = 1, kind = "damage", x = 0.405, y = 0.191 },
        { hp = 1, kind = "damage", x = 0.468, y = 0.119 },
        { hp = 1, kind = "damage", x = 0.532, y = 0.119 },
        { hp = 1, kind = "damage", x = 0.595, y = 0.191 },
        { hp = 1, kind = "crit", x = 0.658, y = 0.191 },
        
        -- Center face features
        { hp = 1, kind = "damage", x = 0.342, y = 0.262 },
        { hp = 1, kind = "damage", x = 0.405, y = 0.334 },
        { hp = 1, kind = "damage", x = 0.5, y = 0.334 }, -- Nose
        { hp = 1, kind = "damage", x = 0.595, y = 0.334 },
        { hp = 1, kind = "damage", x = 0.658, y = 0.262 },
        
        -- Grinning mouth (menacing smile)
        { hp = 1, kind = "damage", x = 0.342, y = 0.477 },
        { hp = 1, kind = "crit", x = 0.405, y = 0.549 },
        { hp = 1, kind = "crit", x = 0.468, y = 0.577 },
        { hp = 1, kind = "crit", x = 0.532, y = 0.577 },
        { hp = 1, kind = "crit", x = 0.595, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.658, y = 0.477 },
        
        -- === RIGHT SIDE: Mender support towers ===
        -- Right eye and support structure
        { hp = 1, kind = "multiplier", x = 0.721, y = 0.262 },
        { hp = 1, kind = "armor", x = 0.721, y = 0.334 },
        { hp = 1, kind = "potion", x = 0.721, y = 0.406 },
        
        -- Outer right tower (healing emphasis)
        { hp = 1, kind = "potion", x = 0.784, y = 0.191 },
        { hp = 1, kind = "potion", x = 0.847, y = 0.262 },
        { hp = 1, kind = "armor", x = 0.784, y = 0.334 },
        { hp = 1, kind = "armor", x = 0.847, y = 0.406 },
        { hp = 1, kind = "potion", x = 0.784, y = 0.477 },
      },
      type = "predefined",
    },
  },
}

