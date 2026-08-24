local spoonPath = hs and hs.spoons and hs.spoons.scriptPath and hs.spoons.scriptPath() or "./ShortcutKit.spoon/"
package.path = spoonPath .. "?.lua;" .. spoonPath .. "?/init.lua;" .. package.path

local Config = require("config")
local Runner = require("lib.module_runner")
local Logger = require("lib.logger")
local Registry = require("lib.hotkey_registry")

local ShortcutKit = {
  name = "ShortcutKit",
  version = "0.1.0",
  author = "ShortcutKit contributors",
  homepage = "https://github.com/ch1286122349-star/shortcut-kit",
  license = "MIT",
  modules = require("modules"),
  report = nil,
}

ShortcutKit.defaults = {
  modules = {
    window_screenshot = true,
    command_space = true,
    right_option = true,
    left_mouse_modifier = true,
    local_ocr = true,
    chrome_recent_tabs = true,
    chrome_mention = true,
    codex_toggle = true,
    mailmaster_toggle = true,
    chatgpt_classic = true,
    whatsapp_command_w = true,
    btt_bridge = true,
  },
  hotkeys = {
    window_screenshot = { { "cmd" }, "r" },
    command_space = { { "cmd" }, "space" },
    local_ocr = { { "cmd" }, "s" },
    chrome_mention_2 = { { "cmd", "shift" }, "2" },
    chrome_mention_3 = { { "cmd", "shift" }, "3" },
    codex_toggle = { { "cmd" }, "2" },
    mailmaster_toggle = { { "cmd" }, "5" },
    mailmaster_pad5 = { { "cmd" }, "pad5" },
    chatgpt_toggle = { { "cmd" }, "`" },
    chatgpt_toggle_section = { { "cmd" }, "§" },
    chatgpt_model_auto = { { "ctrl", "alt" }, "1" },
    chatgpt_model_instant = { { "ctrl", "alt" }, "2" },
    chatgpt_model_thinking = { { "ctrl", "alt" }, "3" },
    chatgpt_model_pro = { { "ctrl", "alt" }, "4" },
  },
  apps = {
    codex = { "com.openai.codex" },
    mailmaster = { "com.netease.macmail" },
    chatgpt = { "com.openai.chat" },
    whatsapp = { "com.microsoft.edgemac.app.hnpfjngllnobngcgfapefoaidbinmjnm" },
  },
}

function ShortcutKit:start(userConfig)
  self.config = Config.load(self.defaults, userConfig or {})
  self.logger = Logger.new({ path = self.config.logPath })
  self.registry = Registry.new(self.config.existingHotkeys or {})
  self.runner = Runner.new({ logger = self.logger })
  self.report = self.runner:start(self.modules, self.config, {
    hs = hs,
    logger = self.logger,
    registry = self.registry,
  })
  return self
end

function ShortcutKit:stop()
  for _, module in ipairs(self.modules) do
    if module.stop then pcall(function() module:stop() end) end
  end
  return self
end

function ShortcutKit:status()
  return self.report or { modules = {}, ok = false }
end

return ShortcutKit
