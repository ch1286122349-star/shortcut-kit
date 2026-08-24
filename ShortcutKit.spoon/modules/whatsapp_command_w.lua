local Detection = require("lib.app_detection")
local Module = {
  id = "whatsapp_command_w",
  BUNDLE_ID = "com.microsoft.edgemac.app.hnpfjngllnobngcgfapefoaidbinmjnm",
}
Module.__index = Module

function Module.shouldIntercept(key, flags, bundleID)
  flags = flags or {}
  return key == "w" and flags.cmd == true and not flags.alt and not flags.ctrl
    and not flags.shift and not flags.fn and bundleID == Module.BUNDLE_ID
end

function Module.new() return setmetatable({}, Module) end

function Module:detect(context)
  local candidates = context.config and context.config.apps and context.config.apps.whatsapp
    or { Module.BUNDLE_ID }
  local _, bundleID = Detection.find(context.hs.application, candidates)
  self.bundleID = bundleID
  return bundleID ~= nil, "WhatsApp Edge PWA is not installed"
end

function Module:start(context)
  self.hs = context.hs
  local types = self.hs.eventtap.event.types
  self.tap = self.hs.eventtap.new({ types.keyDown }, function(event)
    local app = self.hs.application.frontmostApplication()
    local key = event:getKeyCode() == self.hs.keycodes.map.w and "w" or nil
    if key == "w" and event:getFlags().cmd and not event:getFlags().alt
      and not event:getFlags().ctrl and not event:getFlags().shift and not event:getFlags().fn
      and app and app:bundleID() == (self.bundleID or Module.BUNDLE_ID) then
      app:hide()
      return true
    end
    return false
  end)
  self.tap:start()
end

function Module:stop() if self.tap then self.tap:stop(); self.tap = nil end end
function Module:status() return { enabled = self.tap ~= nil, scope = "whatsapp_pwa_only" } end
return Module
