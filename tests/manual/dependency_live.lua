local root = assert(SHORTCUT_KIT_TEST_ROOT, "SHORTCUT_KIT_TEST_ROOT is required")
package.path = root .. "/ShortcutKit.spoon/?.lua;"
  .. root .. "/ShortcutKit.spoon/?/init.lua;"
  .. package.path

local ShortcutKit = dofile(root .. "/ShortcutKit.spoon/init.lua")
local context = { hs = hs, config = ShortcutKit.defaults }
local lines = {}

for _, module in ipairs(ShortcutKit.modules) do
  if module.id == "local_ocr" then
    module.binaryPath = root .. "/ShortcutKit.spoon/bin/local-ocr"
  end
  local ok, detected, reason = pcall(function()
    local found, why = module:detect(context)
    return found, why
  end)
  local state = ok and (detected and "available" or "skipped") or "error"
  local detail = ok and (detected and (module.bundleID or "") or (reason or "")) or tostring(detected)
  table.insert(lines, string.format("%s=%s%s", module.id, state, detail ~= "" and (":" .. detail) or ""))
end

print(table.concat(lines, "\n"))
return table.concat(lines, ";")
