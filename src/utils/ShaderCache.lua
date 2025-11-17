local ShaderCache = {}

local cache = {}

local function buildKey(id, opts)
  if not opts or not next(opts) then
    return id
  end

  local fragments = { id }
  local keys = {}
  for k in pairs(opts) do
    table.insert(keys, k)
  end
  table.sort(keys)

  for _, k in ipairs(keys) do
    local v = opts[k]
    table.insert(fragments, tostring(k))
    table.insert(fragments, tostring(v))
  end

  return table.concat(fragments, ":")
end

local function compileShader(source)
  if type(source) == "function" then
    return source()
  end
  return love.graphics.newShader(source)
end

function ShaderCache.get(id, source, opts)
  assert(type(id) == "string" and id ~= "", "ShaderCache.get requires non-empty id")
  assert(source, "ShaderCache.get requires shader source or builder")

  local key = buildKey(id, opts)
  local entry = cache[key]
  if entry and entry.shader and not entry.recompileRequested then
    return entry.shader
  end

  local ok, shaderOrErr = pcall(compileShader, source)
  if not ok then
    return nil, shaderOrErr
  end

  cache[key] = {
    shader = shaderOrErr,
    source = source,
    opts = opts,
  }
  return shaderOrErr
end

function ShaderCache.release(id, opts)
  local key = buildKey(id, opts)
  local entry = cache[key]
  if not entry then
    return
  end

  if entry.shader and entry.shader.release then
    pcall(entry.shader.release, entry.shader)
  end
  cache[key] = nil
end

function ShaderCache.markDirty(id, opts)
  local key = buildKey(id, opts)
  local entry = cache[key]
  if entry then
    entry.recompileRequested = true
  end
end

function ShaderCache.clear()
  for key, entry in pairs(cache) do
    if entry.shader and entry.shader.release then
      pcall(entry.shader.release, entry.shader)
    end
    cache[key] = nil
  end
end

return ShaderCache


