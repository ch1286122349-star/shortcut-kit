local Helper = {}

local root = assert(SHORTCUT_KIT_TEST_ROOT, "SHORTCUT_KIT_TEST_ROOT is required")
package.path = table.concat({
  root .. "/?.lua",
  root .. "/?/init.lua",
  root .. "/ShortcutKit.spoon/?.lua",
  root .. "/ShortcutKit.spoon/?/init.lua",
  package.path,
}, ";")

function Helper.requireProject(name)
  package.loaded[name] = nil
  return require(name)
end

function Helper.fakeLogger()
  return {
    entries = {},
    info = function(self, message)
      table.insert(self.entries, { level = "info", message = message })
    end,
    error = function(self, message)
      table.insert(self.entries, { level = "error", message = message })
    end,
  }
end

function Helper.assertEqual(actual, expected, label)
  assert(actual == expected, string.format(
    "%s: expected %s, got %s",
    label or "value",
    tostring(expected),
    tostring(actual)
  ))
end

return Helper
