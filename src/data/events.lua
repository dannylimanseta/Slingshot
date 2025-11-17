local M = {}

-- Event definitions
-- Each event has:
--   id: unique identifier
--   title: event title displayed in UI
--   image: path to event image (relative to assets/images/events/)
--   text: main event description text
--   choices: array of choice objects, each with:
--     text: choice text (can include colored text like "Lose 8 HP." in red, "Gain 50 Gold." in green)
--     effects: table with effect keys (hp, gold, etc.)
local EVENTS = {
  whispering_idol = {
    id = "whispering_idol",
    title = "The Whispering Idol",
    image = "event_placeholder.png",
    text = "You find a half-buried idol carved from white calcified stone, its face locked in a familiar, hollow grin. As you draw near, a faint whisper echoes inside your skull.\n\n'Feed me... and I will reward you.'\n\nA warm pulse emanates from the idol, and you feel your lifeforce tugged gently forward, as if an unseen hand is reaching for your veins.",
    choices = {
      {
        text = "Touch the Idol. Lose 8 HP. Gain 50 Gold.",
        effects = { hp = -8, gold = 50 }
      },
      {
        text = "Step away. Nothing happens.",
        effects = {}
      }
    }
  },
  echoing_anvil = {
    id = "echoing_anvil",
    title = "Echoing Anvil",
    image = "event_placeholder.png",
    text = "You enter a hollow in the forest where the fog is unusually still. In the center sits a stone anvil made of the same white, calcified material as the masks. Two mask-faces are fused into its sides, grinning wide.\n\nAs you approach, the anvil hums. Your orbs rattle in their slots, reacting to the ethereal anvil.\n\n\"Strike us,\" the faces whisper, \"and we will make your tools sharper… we only ask for a little of you.\"",
    choices = {
      {
        text = "Place your orbs on the anvil. Upgrade 2 random orbs by 1 level. Lose 10% Max HP.",
        effects = { upgradeRandomOrbs = 2, hpPercent = -10 }
      },
      {
        text = "Leave it alone. Nothing happens.",
        effects = {}
      }
    }
  },
  wandering_trader = {
    id = "wandering_trader",
    title = "The Wandering Trader",
    image = "event_placeholder.png",
    text = "A figure emerges from the fog, draped in tattered robes that seem to shift and shimmer. Their face is hidden beneath a hood, but you catch glimpses of calcified stone where skin should be. They carry a heavy satchel that clinks with the sound of metal and something else, something that hums with power.\n\n\"Gold for power,\" they whisper, their voice like wind through cracks. \"One hundred pieces, and I will grant you a boon that will serve you well. What say you?\"",
    choices = {
      {
        text = "Pay 100 Gold. Gain a Relic.",
        effects = { gold = -100, relic = true }
      },
      {
        text = "Decline. Nothing happens.",
        effects = {}
      }
    }
  },
  ancient_spring = {
    id = "ancient_spring",
    title = "The Ancient Spring",
    image = "event_placeholder.png",
    text = "You stumble upon a clearing where the fog parts to reveal a small spring. The water glimmers with an otherworldly light, and strange runes circle its edge, carved in the same calcified stone as the masks you've seen.\n\nAs you approach, the water seems to call to you. You feel a choice forming: strengthen your body, or sharpen your tools. The spring's power can only grant one blessing.",
    choices = {
      {
        text = "Drink from the spring. Gain 6 Max HP.",
        effects = { maxHp = 6 }
      },
      {
        text = "Dip your orbs in the water. Upgrade a random Orb.",
        effects = { upgradeRandomOrbs = 1 }
      }
    }
  },
  transmutation_circle = {
    id = "transmutation_circle",
    title = "The Transmutation Circle",
    image = "event_placeholder.png",
    text = "A circle of white calcified stone is embedded in the ground, its surface covered in intricate runes that pulse with a faint, shifting light. As you step closer, your orbs begin to resonate, their forms wavering like heat haze.\n\nThe circle whispers promises of change, of transformation. It offers to reshape one of your tools into something new, something different. But transformation is unpredictable, and you cannot choose what emerges from the circle's glow.",
    choices = {
      {
        text = "Place an orb in the circle. Transform a random Orb into another Orb.",
        effects = { transformRandomOrb = true }
      },
      {
        text = "Step away. Nothing happens.",
        effects = {}
      }
    }
  },
  weakened_foes = {
    id = "weakened_foes",
    title = "Weakened Foes",
    image = "event_placeholder.png",
    text = "You come across a clearing where the fog seems thinner, and the air carries a strange, metallic tang. Scattered across the ground are fragments of calcified stone, cracked and brittle. Some still bear the faint outlines of faces, their expressions frozen in what might be pain or exhaustion.\n\nAs you examine the fragments, you feel a strange resonance. The next enemies you face will be weakened, their life force already drained. They will fall quickly, but you wonder what price was paid for this advantage.",
    choices = {
      {
        text = "Absorb the weakened essence. Next encounter enemies spawn with 1 HP.",
        effects = { nextEncounterEnemies1HP = true }
      },
      {
        text = "Leave the fragments alone. Nothing happens.",
        effects = {}
      }
    }
  },
  wheel_of_masks = {
    id = "wheel_of_masks",
    title = "Wheel of Masks",
    image = "event_placeholder.png",
    text = "You uncover a sunken amphitheater of calcified stone. In its center spins a wheel studded with the same smiling masks that stalk your dreams. Each wedge hums with a different promise. The faces insist you spin it once.\n\nClick the carved wheel on the left to spin it and accept whatever fate the masks decree.",
    wheelSegments = {
      {
        id = "gold_40",
        label = "40 Gold",
        description = "Gain 40 shimmering gold pieces.",
        icon = "assets/images/icon_gold.png",
        color = { 1.0, 0.78, 0.24, 1.0 },
        effects = { gold = 40 },
      },
      {
        id = "random_relic",
        label = "Relic",
        description = "Gain a random relic from the wandering masks.",
        icon = "assets/images/relics/power_core.png",
        color = { 0.72, 0.58, 1.0, 1.0 },
        effects = { relic = true },
      },
      {
        id = "full_heal",
        label = "Full Heal",
        description = "Restore all missing health.",
        icon = "assets/images/icon_heal.png",
        color = { 0.48, 0.86, 0.78, 1.0 },
        effects = { healFull = true },
      },
      {
        id = "lose_orb",
        label = "Lose an Orb",
        description = "A random equipped orb vanishes into the wheel.",
        icon = "assets/images/icon_orbs.png",
        color = { 0.94, 0.44, 0.61, 1.0 },
        effects = { removeRandomOrb = true },
      },
      {
        id = "blood_tax",
        label = "Blood Tax",
        description = "Lose 10% of your max HP.",
        icon = "assets/images/icon_health.png",
        color = { 0.91, 0.34, 0.26, 1.0 },
        effects = { hpPercent = -10 },
      },
    },
  },
  -- Add more events here as needed
  -- Example template:
  -- [event_id] = {
  --   id = "event_id",
  --   title = "Event Title",
  --   image = "event_image.png",
  --   text = "Event description text...",
  --   choices = {
  --     { text = "Choice 1", effects = { hp = -5, gold = 20 } },
  --     { text = "Choice 2", effects = {} }
  --   }
  -- }
}

-- Get event by ID
function M.get(id)
  return EVENTS[id]
end

-- Get random event that hasn't been seen yet
-- Once all events have been seen, resets and starts over
function M.getRandom()
  local PlayerState = require("core.PlayerState")
  local playerState = PlayerState.getInstance()
  
  -- Get all event keys
  local allKeys = {}
  for k, _ in pairs(EVENTS) do
    table.insert(allKeys, k)
  end
  
  if #allKeys == 0 then
    return nil
  end
  
  -- Filter out seen events
  local unseenKeys = {}
  for _, key in ipairs(allKeys) do
    if not playerState:hasSeenEvent(key) then
      table.insert(unseenKeys, key)
    end
  end
  
  -- If all events have been seen, reset and use all events
  local availableKeys = unseenKeys
  if #unseenKeys == 0 then
    playerState:resetSeenEvents()
    availableKeys = allKeys
  end
  
  -- Pick a random event from available ones
  if #availableKeys > 0 then
    local key = availableKeys[love.math.random(#availableKeys)]
    local ev = EVENTS[key]
    -- Mark this event as seen
    playerState:markEventSeen(key)
    return ev
  end
  
  return nil
end

-- List all events
function M.list()
  local out = {}
  for _, v in pairs(EVENTS) do
    table.insert(out, v)
  end
  return out
end

return M

