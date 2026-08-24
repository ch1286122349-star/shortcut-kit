local Module = {
  id = "btt_bridge",
  BUNDLE_ID = "com.hegenberg.BetterTouchTool",
  VARIABLE = "btt_screenshot_release_armed",
}
Module.__index = Module

function Module.isAvailable(hsContext)
  return hsContext.application.get(Module.BUNDLE_ID) ~= nil
end

function Module.new() return setmetatable({ armed = false }, Module) end

function Module:detect(context)
  if not Module.isAvailable(context.hs) then
    return false, "BetterTouchTool is not running; bridge is optional"
  end
  local ok = context.hs.osascript.applescript(
    'tell application "BetterTouchTool" to get_number_variable "' .. Module.VARIABLE .. '"'
  )
  return ok == true, "BetterTouchTool variable API is unavailable; bridge is optional"
end

function Module:setValue(value)
  local script = string.format(
    'tell application "BetterTouchTool" to set_number_variable "%s" to %d',
    Module.VARIABLE,
    value
  )
  return self.hs.osascript.applescript(script)
end

function Module:disarm()
  self.armed = false
  if self.timer then self.timer:stop(); self.timer = nil end
  self:setValue(0)
end

function Module:arm()
  self.armed = true
  self:setValue(1)
  if self.timer then self.timer:stop() end
  self.timer = self.hs.timer.doAfter(30, function() self:disarm() end)
end

function Module:start(context)
  self.hs = context.hs
  local types = self.hs.eventtap.event.types
  self.keyTap = self.hs.eventtap.new({ types.keyDown }, function(event)
    local flags = event:getFlags()
    local keyCode = event:getKeyCode()
    if (keyCode == self.hs.keycodes.map["4"] or keyCode == self.hs.keycodes.map.s)
      and flags.cmd and not flags.alt and not flags.ctrl and not flags.shift and not flags.fn then
      self:arm()
    elseif keyCode == self.hs.keycodes.map.escape then
      self:disarm()
    end
    return false
  end)
  self.mouseTap = self.hs.eventtap.new({ types.leftMouseUp }, function()
    if self.armed then self.hs.timer.doAfter(0, function() self:disarm() end) end
    return false
  end)
  self:disarm()
  self.keyTap:start(); self.mouseTap:start()
end

function Module:stop()
  if self.keyTap then self.keyTap:stop() end
  if self.mouseTap then self.mouseTap:stop() end
  if self.hs then self:disarm() end
  self.keyTap, self.mouseTap = nil, nil
end

function Module:status() return { enabled = self.keyTap ~= nil, armed = self.armed } end
return Module
