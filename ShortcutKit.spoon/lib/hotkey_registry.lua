local Registry = {}
Registry.__index = Registry

local modifierOrder = { cmd = 1, ctrl = 2, alt = 3, shift = 4, fn = 5 }

local function canonical(modifiers, key)
  local normalized = {}
  for _, modifier in ipairs(modifiers or {}) do
    local value = modifier:lower()
    value = value == "command" and "cmd" or value
    value = value == "control" and "ctrl" or value
    value = value == "option" and "alt" or value
    table.insert(normalized, value)
  end
  table.sort(normalized, function(a, b)
    return (modifierOrder[a] or 99) < (modifierOrder[b] or 99)
  end)
  table.insert(normalized, tostring(key):lower())
  return table.concat(normalized, "+")
end

function Registry.new(existing)
  return setmetatable({ existing = existing or {}, claims = {} }, Registry)
end

function Registry:claim(moduleId, actionId, modifiers, key)
  local shortcut = canonical(modifiers, key)
  local owner = self.existing[shortcut]
  if owner and owner ~= moduleId then
    return false, { shortcut = shortcut, owner = owner, module = moduleId, action = actionId }
  end
  local claimed = self.claims[shortcut]
  if claimed and (claimed.module ~= moduleId or claimed.action ~= actionId) then
    return false, { shortcut = shortcut, owner = claimed.module, module = moduleId, action = actionId }
  end
  self.claims[shortcut] = { module = moduleId, action = actionId }
  return true
end

Registry.canonical = canonical

function Registry:actions()
  local actions = {}
  for shortcut, claim in pairs(self.claims) do actions[claim.action] = shortcut end
  return actions
end

function Registry:conflict(modifiers, key, excludingAction)
  local shortcut = canonical(modifiers, key)
  local owner = self.existing[shortcut]
  if owner then return { kind = "hammerspoon", description = tostring(owner), shortcut = shortcut } end
  local claimed = self.claims[shortcut]
  if claimed and claimed.action ~= excludingAction then
    return {
      kind = "shortcutKit",
      actionID = claimed.action,
      description = claimed.module,
      shortcut = shortcut,
    }
  end
  return nil
end

return Registry
