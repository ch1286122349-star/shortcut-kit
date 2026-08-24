local Config = {}

local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do result[key] = copy(item) end
  return result
end

local function merge(target, overrides)
  for key, value in pairs(overrides or {}) do
    if type(value) == "table" and type(target[key]) == "table" then
      merge(target[key], value)
    else
      target[key] = copy(value)
    end
  end
  return target
end

function Config.load(defaults, user)
  assert(type(defaults) == "table", "defaults must be a table")
  if user ~= nil then assert(type(user) == "table", "user config must be a table") end
  return merge(copy(defaults), user or {})
end

return Config
