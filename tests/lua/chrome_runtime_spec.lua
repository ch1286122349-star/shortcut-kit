local helper = dofile(assert(SHORTCUT_KIT_TEST_ROOT) .. "/tests/lua/test_helper.lua")
local RecentTabs = helper.requireProject("modules.chrome_recent_tabs")
local Mention = helper.requireProject("modules.chrome_mention")

helper.assertEqual(type(RecentTabs.chrome), "table", "Chrome integration boundary is exposed")
helper.assertEqual(type(RecentTabs.chrome.readCurrent), "function", "Chrome current-tab reader is exposed")
helper.assertEqual(type(RecentTabs.chrome.switchTo), "function", "Chrome tab switcher is exposed")

local current = { windowID = 10, tabID = 101 }
local validTabs = { [101] = true, [102] = true }
local switched = {}
local enabledStates = {}
local runtime = RecentTabs.new({
  readCurrent = function() return { windowID = current.windowID, tabID = current.tabID } end,
  switchTo = function(windowID, tabID)
    table.insert(switched, { windowID = windowID, tabID = tabID })
    if not validTabs[tabID] then return false end
    current = { windowID = windowID, tabID = tabID }
    return true
  end,
  setHotkeyEnabled = function(enabled) table.insert(enabledStates, enabled) end,
})

helper.assertEqual(runtime:toggle(), false, "first toggle does not guess")
current = { windowID = 10, tabID = 102 }
runtime:recordCurrent()
local switchedToA, targetA = runtime:toggle()
helper.assertEqual(switchedToA, true, "second live tab toggles")
helper.assertEqual(targetA, 101, "toggle returns previous tab")
local switchedToB, targetB = runtime:toggle()
helper.assertEqual(switchedToB, true, "toggle can return")
helper.assertEqual(targetB, 102, "toggle returns newer tab")
runtime:setChromeActive(true)
runtime:setChromeActive(false)
helper.assertEqual(enabledStates[1], true, "Chrome activation enables hotkey")
helper.assertEqual(enabledStates[2], false, "Chrome deactivation disables hotkey")

local actions = {}
local fakeHS = {
  eventtap = {
    event = { newKeyEvent = function(_, key, down)
      return { post = function() table.insert(actions, key .. (down and ":down" or ":up")) end }
    end },
    keyStrokes = function(text) table.insert(actions, "text:" .. text) end,
    keyStroke = function(_, key) table.insert(actions, "key:" .. key) end,
  },
  timer = {
    usleep = function() end,
    doAfter = function(_, callback) callback(); return { stop = function() end } end,
  },
}
local mention = Mention.new()
mention.hs = fakeHS
mention:run()
helper.assertEqual(actions[1], "space:down", "mention begins with space")
helper.assertEqual(actions[3], "text:@chrome", "mention types trigger before Tab")
helper.assertEqual(actions[4], "key:tab", "mention confirms with Tab")

print("chrome_runtime_spec: PASS")
