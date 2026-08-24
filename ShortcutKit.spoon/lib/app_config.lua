local AppConfig = {}

local modifierOrder = { "cmd", "ctrl", "alt", "shift", "fn" }
local modifierAliases = {
  cmd = "cmd", command = "cmd",
  ctrl = "ctrl", control = "ctrl",
  alt = "alt", option = "alt", opt = "alt",
  shift = "shift", fn = "fn", ["function"] = "fn",
}

local function decodeHotkey(value)
  if type(value) ~= "table" or type(value.modifiers) ~= "table" or type(value.key) ~= "string" then
    return nil
  end
  local seen = {}
  for _, modifier in ipairs(value.modifiers) do
    if type(modifier) ~= "string" then return nil end
    local normalized = modifierAliases[modifier:lower()]
    if not normalized then return nil end
    seen[normalized] = true
  end
  local key = value.key:match("^%s*(.-)%s*$"):lower()
  if key == "" then return nil end
  if not next(seen) and key:match("^[%w]$") then return nil end
  local modifiers = {}
  for _, modifier in ipairs(modifierOrder) do
    if seen[modifier] then table.insert(modifiers, modifier) end
  end
  return { modifiers, key }
end

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
  local hotkeys = {}
  if decoded.hotkeys ~= nil and type(decoded.hotkeys) ~= "table" then
    return nil, "invalid hotkeys"
  end
  for id, value in pairs(decoded.hotkeys or {}) do
    if type(id) ~= "string" then return nil, "invalid hotkeys" end
    local hotkey = decodeHotkey(value)
    if not hotkey then return nil, "invalid hotkeys" end
    hotkeys[id] = hotkey
  end
  return { modules = decoded.modules, hotkeys = hotkeys }
end

function AppConfig.read(path, hsContext)
  local configPath = path or AppConfig.defaultPath()
  if not configPath then return { modules = {}, hotkeys = {} }, nil end
  local file = io.open(configPath, "r")
  if not file then return { modules = {}, hotkeys = {} }, nil end
  local raw = file:read("*a")
  file:close()
  return AppConfig.decode(raw, hsContext.json)
end

return AppConfig
