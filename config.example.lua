-- Pass this table to spoon.ShortcutKit:start({...}) from your Hammerspoon init.lua.
return {
  modules = {
    -- Disable an individual feature without affecting the rest.
    chatgpt_classic = false,
  },
  hotkeys = {
    -- Example: move the window screenshot shortcut to Command+Shift+R.
    window_screenshot = { { "cmd", "shift" }, "r" },
  },
  apps = {
    -- Candidate bundle IDs are checked in order.
    codex = { "com.openai.codex" },
    mailmaster = { "com.netease.macmail" },
    chatgpt = { "com.openai.chat" },
    whatsapp = { "com.microsoft.edgemac.app.hnpfjngllnobngcgfapefoaidbinmjnm" },
  },
}
