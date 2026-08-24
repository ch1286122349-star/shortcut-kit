local helper = dofile(assert(SHORTCUT_KIT_TEST_ROOT) .. "/tests/lua/test_helper.lua")
local AppConfig = helper.requireProject("lib.app_config")
local Runner = helper.requireProject("lib.module_runner")

local fakeJSON = {
  decode = function(raw)
    if raw == "valid" then
      return {
        schemaVersion = 1,
        modules = { local_ocr = false, future_module = true },
        hotkeys = {
          window_screenshot = { modifiers = { "Shift", "command" }, key = "R" },
          future_action = { modifiers = { "ctrl" }, key = "9" },
        },
      }
    end
    if raw == "bad-hotkey" then
      return { schemaVersion = 1, modules = {}, hotkeys = { broken = { modifiers = {}, key = "a" } } }
    end
    if raw == "wrong-schema" then return { schemaVersion = 2, modules = {} } end
    error("invalid JSON")
  end,
}

local config = assert(AppConfig.decode("valid", fakeJSON))
helper.assertEqual(config.modules.local_ocr, false, "module setting maps to runtime config")
helper.assertEqual(config.modules.future_module, true, "unknown module setting is preserved")
helper.assertEqual(config.hotkeys.window_screenshot[1][1], "cmd", "modifier aliases are canonicalized")
helper.assertEqual(config.hotkeys.window_screenshot[1][2], "shift", "modifiers use stable order")
helper.assertEqual(config.hotkeys.window_screenshot[2], "r", "key is canonicalized")
helper.assertEqual(config.hotkeys.future_action[2], "9", "unknown action override is preserved")

local badHotkey, badHotkeyError = AppConfig.decode("bad-hotkey", fakeJSON)
helper.assertEqual(badHotkey, nil, "invalid hotkey fails closed")
helper.assertEqual(badHotkeyError, "invalid hotkeys", "hotkey error is sanitized")

local invalid, invalidError = AppConfig.decode("wrong-schema", fakeJSON)
helper.assertEqual(invalid, nil, "unknown schema fails closed")
helper.assertEqual(invalidError, "unsupported schemaVersion", "schema error is explicit")

local malformed, malformedError = AppConfig.decode("bad-json", fakeJSON)
helper.assertEqual(malformed, nil, "malformed JSON fails closed")
helper.assertEqual(malformedError, "invalid JSON", "parse error is sanitized")

local runner = Runner.new({ logger = helper.fakeLogger() })
local disabledStarted = false
local report = runner:start({ {
  id = "disabled",
  detect = function() return true end,
  start = function() disabledStarted = true end,
} }, { modules = { disabled = false } }, {})
helper.assertEqual(disabledStarted, false, "disabled module does not start")
helper.assertEqual(report.modules.disabled.state, "disabled", "disabled state is explicit")

print("app_config_spec: PASS")
