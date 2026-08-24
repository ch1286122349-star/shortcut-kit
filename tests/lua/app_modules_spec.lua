local helper = dofile(assert(SHORTCUT_KIT_TEST_ROOT) .. "/tests/lua/test_helper.lua")
local Codex = helper.requireProject("modules.codex_toggle")
local MailMaster = helper.requireProject("modules.mailmaster_toggle")
local ChatGPT = helper.requireProject("modules.chatgpt_classic")
local WhatsApp = helper.requireProject("modules.whatsapp_command_w")
local BTT = helper.requireProject("modules.btt_bridge")

helper.assertEqual(Codex.actionFor("com.openai.codex"), "restore_and_hide", "Codex toggles back")
helper.assertEqual(Codex.actionFor("com.apple.finder"), "remember_and_focus", "Codex remembers origin")
local customCodex = Codex.new()
local customDetected = customCodex:detect({
  config = { apps = { codex = { "com.example.codex" } } },
  hs = { application = {
    get = function(id) return id == "com.example.codex" and {} or nil end,
    pathForBundleID = function() return nil end,
  } },
})
helper.assertEqual(customDetected, true, "Codex bundle candidates are configurable")

local windows = {
  { subrole = function() return "AXStandardWindow" end, frame = function() return { w = 500, h = 400 } end },
  { subrole = function() return "AXStandardWindow" end, frame = function() return { w = 900, h = 700 } end },
}
helper.assertEqual(MailMaster.largestStandardWindow(windows), windows[2], "MailMaster repairs to largest window")

local conversation, errorMessage = ChatGPT.decodeConversation("not json", {
  decode = function() error("invalid JSON") end,
})
helper.assertEqual(conversation, nil, "invalid ChatGPT preference is rejected")
helper.assertEqual(errorMessage, "missing conversation", "invalid preference has a safe error")
helper.assertEqual(ChatGPT.modelSlug("thinking"), "gpt-5-6-thinking", "ChatGPT model mapping is preserved")
helper.assertEqual(ChatGPT.modelSlug("unknown"), nil, "unknown ChatGPT model is rejected")

local exactWhatsApp = "com.microsoft.edgemac.app.hnpfjngllnobngcgfapefoaidbinmjnm"
helper.assertEqual(
  WhatsApp.shouldIntercept("w", { cmd = true }, exactWhatsApp),
  true,
  "exact WhatsApp PWA Command+W is intercepted"
)
helper.assertEqual(
  WhatsApp.shouldIntercept("w", { cmd = true }, "com.apple.finder"),
  false,
  "other apps keep native Command+W"
)
helper.assertEqual(
  WhatsApp.shouldIntercept("w", { cmd = true, shift = true }, exactWhatsApp),
  false,
  "modified WhatsApp Command+W is not intercepted"
)

helper.assertEqual(BTT.isAvailable({ application = { get = function() return nil end } }), false, "missing BTT disables bridge")
helper.assertEqual(BTT.isAvailable({ application = { get = function(id) return id == BTT.BUNDLE_ID and {} or nil end } }), true, "running BTT enables bridge")
local btt = BTT.new()
local bttDetected = btt:detect({ hs = {
  application = { get = function() return {} end },
  osascript = { applescript = function() return false end },
} })
helper.assertEqual(bttDetected, false, "unreadable BTT variable API disables bridge")

print("app_modules_spec: PASS")
