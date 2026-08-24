local Module = { id = "left_mouse_modifier" }
Module.__index = Module

function Module.actionFor(key, bundleID)
  if key == "c" then return "cmd+c" end
  if key == "v" then return "cmd+v" end
  if key == "d" and bundleID == "com.apple.finder" then return "cmd+delete" end
  if key == "d" then return "delete" end
  return nil
end

function Module.mouseEventResult() return false end
function Module.new() return setmetatable({}, Module) end
function Module:detect() return true end

function Module:start(context)
  self.hs = context.hs
  local types = self.hs.eventtap.event.types
  self.mouseTap = self.hs.eventtap.new({ types.leftMouseDown, types.leftMouseUp }, function(event)
    if event:getType() == types.leftMouseDown then
      self.pressedAt = self.hs.timer.absoluteTime()
    else
      self.pressedAt = nil
    end
    return Module.mouseEventResult()
  end)
  self.keyTap = self.hs.eventtap.new({ types.keyDown }, function(event)
    if not self.pressedAt then return false end
    local seconds = (self.hs.timer.absoluteTime() - self.pressedAt) / 1000000000
    if seconds < 0.05 then return false end
    local flags = event:getFlags()
    if flags.cmd or flags.alt or flags.ctrl or flags.shift or flags.fn then return false end
    if event:getProperty(self.hs.eventtap.event.properties.keyboardEventAutorepeat) == 1 then return true end
    local keyCode = event:getKeyCode()
    local keys = self.hs.keycodes.map
    local key = keyCode == keys.c and "c" or keyCode == keys.v and "v" or keyCode == keys.d and "d" or nil
    local app = self.hs.application.frontmostApplication()
    local action = Module.actionFor(key, app and app:bundleID() or nil)
    if not action then return false end
    if action == "cmd+c" then self.hs.eventtap.keyStroke({ "cmd" }, "c", 0)
    elseif action == "cmd+v" then self.hs.eventtap.keyStroke({ "cmd" }, "v", 0)
    elseif action == "cmd+delete" then self.hs.eventtap.keyStroke({ "cmd" }, "delete", 0)
    else self.hs.eventtap.keyStroke({}, "delete", 0) end
    return true
  end)
  self.mouseTap:start()
  self.keyTap:start()
end

function Module:stop()
  if self.mouseTap then self.mouseTap:stop() end
  if self.keyTap then self.keyTap:stop() end
  self.mouseTap, self.keyTap, self.pressedAt = nil, nil, nil
end

function Module:status()
  return { mouseTap = self.mouseTap ~= nil, keyTap = self.keyTap ~= nil, passthrough = true }
end
return Module
