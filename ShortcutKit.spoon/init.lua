local spoonPath = hs and hs.spoons and hs.spoons.scriptPath and hs.spoons.scriptPath() or "./ShortcutKit.spoon/"
package.path = spoonPath .. "?.lua;" .. spoonPath .. "?/init.lua;" .. package.path

local Config = require("config")
local Runner = require("lib.module_runner")
local Logger = require("lib.logger")

local ShortcutKit = {
  name = "ShortcutKit",
  version = "0.1.0",
  author = "ShortcutKit contributors",
  homepage = "https://github.com/shortcut-kit/shortcut-kit",
  license = "MIT",
  modules = {},
  report = nil,
}

ShortcutKit.defaults = { modules = {} }

function ShortcutKit:start(userConfig)
  self.config = Config.load(self.defaults, userConfig or {})
  self.logger = Logger.new({ path = self.config.logPath })
  self.runner = Runner.new({ logger = self.logger })
  self.report = self.runner:start(self.modules, self.config, { hs = hs, logger = self.logger })
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
