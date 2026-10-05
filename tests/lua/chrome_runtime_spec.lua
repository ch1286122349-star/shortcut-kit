local helper = dofile(assert(SHORTCUT_KIT_TEST_ROOT) .. "/tests/lua/test_helper.lua")
local RecentTabs = helper.requireProject("modules.chrome_recent_tabs")
local Mention = helper.requireProject("modules.chrome_mention")

helper.assertEqual(type(RecentTabs.chrome), "table", "Chrome integration boundary is exposed")
helper.assertEqual(type(RecentTabs.chrome.readCurrent), "function", "Chrome current-tab reader is exposed")
helper.assertEqual(type(RecentTabs.chrome.switchTo), "function", "Chrome tab switcher is exposed")
helper.assertEqual(
  RecentTabs.matchesHotkey("k", { ctrl = true, shift = true }, { { "ctrl", "shift" }, "k" }),
  true,
  "Chrome recent-tabs trigger can be customized"
)
helper.assertEqual(
  RecentTabs.matchesHotkey("3", { cmd = true }, { { "ctrl", "shift" }, "k" }),
  false,
  "old Chrome trigger stops matching after customization"
)

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

-- 提及快捷键的松键、延时和取消行为由 chrome_mention_spec 覆盖。
helper.assertEqual(type(Mention.new), "function", "mention module remains registered")
print("chrome_runtime_spec: PASS")
