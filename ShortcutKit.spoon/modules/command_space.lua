local Module = { id = "command_space" }
Module.__index = Module

function Module.new() return setmetatable({}, Module) end
function Module:detect() return true end

function Module:start(context, config)
  self.hs = context.hs
  local spec = ((config.hotkeys or {}).command_space) or { { "cmd" }, "space" }
  if context.registry then
    local ok, conflict = context.registry:claim(self.id, "command_space", spec[1], spec[2])
    if not ok then error("hotkey conflict: " .. conflict.shortcut) end
  end
  self.hotkey = self.hs.hotkey.bind(spec[1], spec[2], function()
    local down = self.hs.eventtap.event.newKeyEvent({ "cmd" }, "o", true)
    local up = self.hs.eventtap.event.newKeyEvent({ "cmd" }, "o", false)
    down:post()
    self.hs.timer.usleep(30000)
    up:post()
  end)
end

function Module:stop()
  if self.hotkey and self.hotkey.delete then self.hotkey:delete() end
  self.hotkey = nil
end

function Module:status() return { enabled = self.hotkey ~= nil } end
return Module
