local helper = dofile(assert(SHORTCUT_KIT_TEST_ROOT) .. "/tests/lua/test_helper.lua")
local History = helper.requireProject("modules.chrome_history")

local function assertSequence(actual, expected, label)
  helper.assertEqual(#actual, #expected, label .. " length")
  for index, value in ipairs(expected) do
    helper.assertEqual(actual[index], value, label .. " item " .. index)
  end
end

local history = History.new()
history:record(10, 101)
history:record(10, 102)
assertSequence(history:candidates(10, 102), { 101 }, "newest first")
history:record(10, 101)
assertSequence(history:candidates(10, 101), { 102 }, "duplicate moves to front")
history:record(20, 201)
assertSequence(history:candidates(10, 101), { 102 }, "window histories are isolated")
history:remove(10, 102)
assertSequence(history:candidates(10, 101), {}, "closed tab is removed")

print("chrome_history_spec: PASS")
