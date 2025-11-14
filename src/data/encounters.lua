local enemies = require("data.enemies")
local formations = require("data.formations")

local M = {}

-- Load encounters from directory structure using manifest
local function loadEncountersFromManifest()
  local ENCOUNTERS = {}
  
  -- Load manifest
  local manifest = require("data.encounters._manifest")
  
  -- Load each file listed in manifest
  for _, entry in ipairs(manifest) do
    local subdir, filename = entry[1], entry[2]
    local modulePath = string.format("data.encounters.%s.%s", subdir, filename)
    
    local ok, module = pcall(require, modulePath)
    if ok and module then
      -- Module can return a single encounter or array of encounters
      if type(module) == "table" then
        -- Check if it's an array (has numeric indices) or single encounter (has id)
        if module[1] then
          -- Array of encounters
          for _, enc in ipairs(module) do
            table.insert(ENCOUNTERS, enc)
          end
        elseif module.id then
          -- Single encounter
          table.insert(ENCOUNTERS, module)
        end
      end
    else
      -- File doesn't exist yet, that's okay (for development)
      print(string.format("Warning: Could not load encounter file: %s", modulePath))
    end
  end
  
  return ENCOUNTERS
end

-- Load all encounters
local ENCOUNTERS = loadEncountersFromManifest()

-- Index by id for quick lookup
local INDEX = {}
for _, enc in ipairs(ENCOUNTERS) do
  if enc.id then
    INDEX[enc.id] = enc
  end
end

function M.get(id)
  return INDEX[id]
end

function M.list()
  return ENCOUNTERS
end

-- Reload function for hot-reloading during development
function M.reload()
  -- Clear package cache for all encounter modules
  for k, _ in pairs(package.loaded) do
    if string.find(k, "^data%.encounters%.") then
      package.loaded[k] = nil
    end
  end
  
  -- Reload this module
  package.loaded["data.encounters"] = nil
  local newModule = require("data.encounters")
  for k, v in pairs(newModule) do
    M[k] = v
  end
  
  -- Rebuild index
  ENCOUNTERS = loadEncountersFromManifest()
  INDEX = {}
  for _, enc in ipairs(ENCOUNTERS) do
    if enc.id then
      INDEX[enc.id] = enc
    end
  end
end

return M
