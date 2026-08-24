local AppConfig = {}

function AppConfig.defaultPath(environment)
  local env = environment or os.getenv
  local home = env("HOME")
  if not home or home == "" then return nil end
  return home .. "/Library/Application Support/ShortcutKit/config.json"
end

function AppConfig.decode(raw, json)
  if type(raw) ~= "string" or type(json) ~= "table" or type(json.decode) ~= "function" then
    return nil, "invalid JSON"
  end
  local ok, decoded = pcall(json.decode, raw)
  if not ok or type(decoded) ~= "table" then return nil, "invalid JSON" end
  if decoded.schemaVersion ~= 1 then return nil, "unsupported schemaVersion" end
  if type(decoded.modules) ~= "table" then return nil, "invalid modules" end
  for id, enabled in pairs(decoded.modules) do
    if type(id) ~= "string" or type(enabled) ~= "boolean" then
      return nil, "invalid modules"
    end
  end
  return { modules = decoded.modules }
end

function AppConfig.read(path, hsContext)
  local configPath = path or AppConfig.defaultPath()
  if not configPath then return { modules = {} }, nil end
  local file = io.open(configPath, "r")
  if not file then return { modules = {} }, nil end
  local raw = file:read("*a")
  file:close()
  return AppConfig.decode(raw, hsContext.json)
end

return AppConfig
