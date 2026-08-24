require("hs.ipc")
hs.loadSpoon("ShortcutKit")
spoon.ShortcutKit:start()
shortcutKitStatus = function() return spoon.ShortcutKit:status() end
