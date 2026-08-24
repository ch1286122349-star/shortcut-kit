local root = assert(SHORTCUT_KIT_TEST_ROOT, "SHORTCUT_KIT_TEST_ROOT is required")
package.path = root .. "/ShortcutKit.spoon/?.lua;"
  .. root .. "/ShortcutKit.spoon/?/init.lua;"
  .. package.path

local RecentTabs = require("modules.chrome_recent_tabs")
local current = assert(RecentTabs.chrome.readCurrent(), "Chrome must be running with an open window")
assert(current.windowID and current.tabID, "Chrome did not return a window and tab ID")
assert(
  RecentTabs.chrome.switchTo(current.windowID, current.tabID),
  "Chrome could not switch back to its active tab"
)

print(string.format(
  "chrome_live.lua: PASS (window=%s tab=%s)",
  tostring(current.windowID),
  tostring(current.tabID)
))
