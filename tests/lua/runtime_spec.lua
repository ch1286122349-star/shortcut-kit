local helper = dofile(assert(SHORTCUT_KIT_TEST_ROOT) .. "/tests/lua/test_helper.lua")
local Runner = helper.requireProject("lib.module_runner")
local Registry = helper.requireProject("lib.hotkey_registry")
local Config = helper.requireProject("config")

local started = {}
local good = {
  id = "good",
  detect = function() return true end,
  start = function() started.good = true end,
}
local missing = {
  id = "missing",
  detect = function() return false, "app missing" end,
  start = function() error("missing module must not start") end,
}

local runner = Runner.new({ logger = helper.fakeLogger() })
local result = runner:start({ good, missing }, {
  modules = { good = true, missing = true },
}, {})

helper.assertEqual(started.good, true, "detected module starts")
helper.assertEqual(result.modules.good.state, "enabled", "good module state")
helper.assertEqual(result.modules.missing.state, "skipped", "missing module state")
helper.assertEqual(result.modules.missing.reason, "app missing", "missing reason")

local registry = Registry.new({ ["cmd+r"] = "existing" })
local claimed, conflict = registry:claim(
  "window_screenshot",
  "capture",
  { "cmd" },
  "r"
)
helper.assertEqual(claimed, false, "conflicting hotkey is not claimed")
helper.assertEqual(conflict.owner, "existing", "conflict owner")

local sameModule = Registry.new()
helper.assertEqual(sameModule:claim("chatgpt_classic", "chatgpt_toggle", { "cmd" }, "g"), true, "first action claims key")
local duplicateActionClaim = sameModule:claim("chatgpt_classic", "chatgpt_model_auto", { "cmd" }, "g")
helper.assertEqual(duplicateActionClaim, false, "different actions in one module cannot share a key")
helper.assertEqual(sameModule:actions().chatgpt_toggle, "cmd+g", "action bindings are reportable")
local sameModuleConflict = sameModule:conflict({ "cmd" }, "g", "window_screenshot")
helper.assertEqual(sameModuleConflict.actionID, "chatgpt_toggle", "conflict names the active action")
helper.assertEqual(sameModule:conflict({ "cmd" }, "g", "chatgpt_toggle"), nil, "edited action excludes itself")

local merged = Config.load({
  modules = { generic = true, optional = true },
  nested = { value = 1 },
}, {
  modules = { optional = false },
  nested = { value = 2 },
})
helper.assertEqual(merged.modules.generic, true, "default preserved")
helper.assertEqual(merged.modules.optional, false, "user override applied")
helper.assertEqual(merged.nested.value, 2, "nested override applied")

print("runtime_spec: PASS")
