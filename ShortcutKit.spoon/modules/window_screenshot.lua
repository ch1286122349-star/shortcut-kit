local Module = { id = "window_screenshot" }
Module.__index = Module

local function contains(frame, point)
  return point.x >= frame.x and point.x <= frame.x + frame.w
    and point.y >= frame.y and point.y <= frame.y + frame.h
end

function Module.findWindow(windows, point)
  for _, window in ipairs(windows or {}) do
    local frame = window:frame()
    if window:isVisible() and not window:isMinimized() and frame and contains(frame, point) then
      return window
    end
  end
  return nil
end

function Module.new()
  return setmetatable({ running = false, hotkey = nil, task = nil }, Module)
end

function Module:detect() return true end

function Module:capture()
  if self.running then return false, "capture already running" end
  local target = Module.findWindow(self.hs.window.orderedWindows(), self.hs.mouse.absolutePosition())
  if not target or not target:id() then return false, "no capturable window under mouse" end

  self.running = true
  self.task = self.hs.task.new("/usr/sbin/screencapture", function(exitCode, _, stderr)
    self.task = nil
    self.running = false
    self.lastResult = exitCode == 0 and "success" or ("failed: " .. tostring(stderr))
  end, { "-c", "-l", tostring(target:id()) })

  if not self.task or not self.task:start() then
    self.task = nil
    self.running = false
    return false, "screencapture task did not start"
  end
  return true
end

function Module:start(context, config)
  self.hs = assert(context.hs, "Hammerspoon context is required")
  local spec = ((config.hotkeys or {}).window_screenshot) or { { "cmd" }, "r" }
  if context.registry then
    local claimed, conflict = context.registry:claim(self.id, "window_screenshot", spec[1], spec[2])
    if not claimed then error("hotkey conflict: " .. conflict.shortcut) end
  end
  self.hotkey = self.hs.hotkey.bind(spec[1], spec[2], nil, function() self:capture() end)
end

function Module:stop()
  if self.hotkey and self.hotkey.delete then self.hotkey:delete() end
  if self.task and self.task.terminate then self.task:terminate() end
  self.hotkey, self.task, self.running = nil, nil, false
end

function Module:status()
  return { running = self.running, result = self.lastResult }
end

return Module
