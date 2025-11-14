-- Difficulty 2: Solo Bloodhound
-- Formation Shape: Dog Face with Smile (menacing grin!)
return {
  {
    id = "ENCOUNTER_SOLO_BLOODHOUND",
    difficulty = 2,
    centerWidthFactor = 0.43,
    enemies = {
      "bloodhound",
    },
    blockFormation = {
      predefined = {
        -- DOG FACE FORMATION (spread out to avoid occlusion)
        
        -- Ears (top left and right)
        { hp = 1, kind = "damage", x = 0.31, y = 0.19 },
        { hp = 1, kind = "damage", x = 0.69, y = 0.19 },
        
        -- Top of head
        { hp = 1, kind = "crit", x = 0.374, y = 0.262 },
        { hp = 1, kind = "damage", x = 0.436, y = 0.262 },
        { hp = 1, kind = "damage", x = 0.5, y = 0.24 },
        { hp = 1, kind = "damage", x = 0.564, y = 0.262 },
        { hp = 1, kind = "crit", x = 0.626, y = 0.262 },
        
        -- Eyes (left and right)
        { hp = 1, kind = "multiplier", x = 0.374, y = 0.334 },
        { hp = 1, kind = "multiplier", x = 0.626, y = 0.334 },
        
        -- Nose area
        { hp = 1, kind = "damage", x = 0.5, y = 0.406 },
        
        -- Cheeks/sides
        { hp = 1, kind = "armor", x = 0.279, y = 0.406 },
        { hp = 1, kind = "armor", x = 0.721, y = 0.406 },
        
        -- SMILE - curved upward grin (wider spacing)
        -- Left side of smile
        { hp = 1, kind = "damage", x = 0.279, y = 0.477 },
        { hp = 1, kind = "damage", x = 0.342, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.405, y = 0.592 },
        -- Center bottom of smile (teeth)
        { hp = 1, kind = "crit", x = 0.468, y = 0.621 },
        { hp = 1, kind = "crit", x = 0.532, y = 0.621 },
        -- Right side of smile
        { hp = 1, kind = "damage", x = 0.595, y = 0.592 },
        { hp = 1, kind = "damage", x = 0.658, y = 0.549 },
        { hp = 1, kind = "damage", x = 0.721, y = 0.477 },
        
        -- Fangs/teeth detail (upper teeth)
        { hp = 1, kind = "potion", x = 0.374, y = 0.549 },
        { hp = 1, kind = "potion", x = 0.626, y = 0.549 },
      },
      type = "predefined",
    },
  },
}


