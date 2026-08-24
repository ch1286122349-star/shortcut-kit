local helper = dofile(assert(SHORTCUT_KIT_TEST_ROOT) .. "/tests/lua/test_helper.lua")
local AppConfig = helper.requireProject("lib.app_config")
local Runner = helper.requireProject("lib.module_runner")

local fakeJSON = {
  decode = function(raw)
    if raw == "valid" then
      return { schemaVersion = 1, modules = { local_ocr = false, future_module = true } }
    end
    if raw == "wrong-schema" then return { schemaVersion = 2, modules = {} } end
    error("invalid JSON")
  end,
}

local config = assert(AppConfig.decode("valid", fakeJSON))
helper.assertEqual(config.modules.local_ocr, false, "module setting maps to runtime config")
helper.assertEqual(config.modules.future_module, true, "unknown module setting is preserved")

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
