local helper = dofile(assert(SHORTCUT_KIT_TEST_ROOT) .. "/tests/lua/test_helper.lua")
local Screenshot = helper.requireProject("modules.window_screenshot")
local RightOption = helper.requireProject("modules.right_option")
local LeftMouse = helper.requireProject("modules.left_mouse_modifier")
local Modules = helper.requireProject("modules")

local function fakeWindow(id, frame, visible, minimized)
  return {
    id = function() return id end,
    frame = function() return frame end,
    isVisible = function() return visible end,
    isMinimized = function() return minimized == true end,
  }
end

local windows = {
  fakeWindow(11, { x = 0, y = 0, w = 100, h = 100 }, true),
  fakeWindow(22, { x = 10, y = 10, w = 50, h = 50 }, true),
}
helper.assertEqual(
  Screenshot.findWindow(windows, { x = 20, y = 20 }):id(),
  11,
  "frontmost containing window wins"
)
helper.assertEqual(
  Screenshot.findWindow({ fakeWindow(33, { x = 0, y = 0, w = 100, h = 100 }, false) }, { x = 20, y = 20 }),
  nil,
  "hidden window is ignored"
)

local releaseCallback
local taskArgs
local screenshotModule = Screenshot.new()
screenshotModule:start({
  registry = { claim = function() return true end },
  hs = {
    hotkey = { bind = function(_, _, _, released) releaseCallback = released; return { delete = function() end } end },
    window = { orderedWindows = function() return windows end },
    mouse = { absolutePosition = function() return { x = 20, y = 20 } end },
    task = { new = function(_, callback, args)
      taskArgs = args
      return { start = function() callback(0, "", ""); return true end }
    end },
  },
}, { hotkeys = {} })
releaseCallback()
helper.assertEqual(taskArgs[1], "-c", "window screenshot copies to clipboard")
helper.assertEqual(taskArgs[2], "-l", "window screenshot targets a window ID")
helper.assertEqual(taskArgs[3], "11", "window screenshot uses frontmost window ID")

helper.assertEqual(
  RightOption.shouldTrigger(0.36, false, false),
  true,
  "long standalone right Option triggers"
)
helper.assertEqual(
  RightOption.shouldTrigger(0.50, true, false),
  false,
  "right Option used as modifier does not trigger"
)

helper.assertEqual(LeftMouse.actionFor("c", "com.apple.TextEdit"), "cmd+c", "left+C copies")
helper.assertEqual(LeftMouse.actionFor("v", "com.apple.TextEdit"), "cmd+v", "left+V pastes")
helper.assertEqual(LeftMouse.actionFor("d", "com.apple.finder"), "cmd+delete", "Finder left+D deletes")
helper.assertEqual(LeftMouse.actionFor("d", "com.apple.TextEdit"), "delete", "other app left+D deletes")
helper.assertEqual(LeftMouse.mouseEventResult(), false, "mouse events pass through")

local moduleIDs = {}
for _, module in ipairs(Modules) do moduleIDs[module.id] = true end
helper.assertEqual(moduleIDs.window_screenshot, true, "screenshot module is registered")
helper.assertEqual(moduleIDs.command_space, true, "command space module is registered")
helper.assertEqual(moduleIDs.right_option, true, "right Option module is registered")
helper.assertEqual(moduleIDs.left_mouse_modifier, true, "left mouse module is registered")

print("generic_modules_spec: PASS")
