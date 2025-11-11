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

-- Get random event (for future use)
function M.getRandom()
  local keys = {}
  for k, _ in pairs(EVENTS) do
    table.insert(keys, k)
  end
  if #keys > 0 then
    return EVENTS[keys[love.math.random(#keys)]]
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

