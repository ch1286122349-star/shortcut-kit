local spoonPath = hs and hs.spoons and hs.spoons.scriptPath and hs.spoons.scriptPath() or "./ShortcutKit.spoon/"
package.path = spoonPath .. "?.lua;" .. spoonPath .. "?/init.lua;" .. package.path

local Config = require("config")
local Runner = require("lib.module_runner")
local Logger = require("lib.logger")
local Registry = require("lib.hotkey_registry")
local AppConfig = require("lib.app_config")

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
    chrome_recent_tabs = { { "cmd" }, "3" },
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
    whatsapp_command_w = { { "cmd" }, "w" },
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

function ShortcutKit:startFromAppConfig(path)
  self.appConfigPath = path or AppConfig.defaultPath()
  local config, configError = AppConfig.read(self.appConfigPath, hs)
  self.appConfigError = configError
  return self:start(config or {})
end

function ShortcutKit:stop()
  for _, module in ipairs(self.modules) do
    if module.stop then pcall(function() module:stop() end) end
  end
  return self
end

function ShortcutKit:setRecordingMode(active)
  active = active == true
  if active and not self.recordingMode then
    self:stop()
    self.recordingMode = true
  elseif not active and self.recordingMode then
    self.recordingMode = false
    self:startFromAppConfig(self.appConfigPath)
  end
  return true
end

function ShortcutKit:status()
  return self.report or { modules = {}, ok = false }
end

function ShortcutKit:appStatus()
  local status = self:status()
  local safe = {
    ok = status.ok == true and self.appConfigError == nil,
    version = self.version,
    modules = {},
    actions = self.registry and self.registry:actions() or {},
  }
  if self.appConfigError then safe.configError = self.appConfigError end
  for id, moduleStatus in pairs(status.modules or {}) do
    safe.modules[id] = {
      state = moduleStatus.state,
      reason = moduleStatus.reason,
    }
  end
  return safe
end

function ShortcutKit:checkHotkeyConflict(modifiers, key, excludingAction)
  local conflict = self.registry and self.registry:conflict(modifiers, key, excludingAction) or nil
  if conflict then
    conflict.systemCheckAvailable = type(hs.hotkey.systemAssigned) == "function"
    return conflict
  end
  if type(hs.hotkey.systemAssigned) ~= "function" then
    return { kind = "none", systemCheckAvailable = false }
  end
  local ok, assignment = pcall(hs.hotkey.systemAssigned, modifiers, key)
  if not ok then return { kind = "none", systemCheckAvailable = false } end
  if type(assignment) == "table" and assignment.enabled ~= false then
    return {
      kind = "system",
      description = "macOS system shortcut",
      shortcut = Registry.canonical(modifiers, key),
      systemCheckAvailable = true,
    }
  end
  return { kind = "none", systemCheckAvailable = true }
end

return ShortcutKit
