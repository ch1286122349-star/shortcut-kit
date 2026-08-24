local Detection = require("lib.app_detection")
local Module = {
  id = "whatsapp_command_w",
  BUNDLE_ID = "com.microsoft.edgemac.app.hnpfjngllnobngcgfapefoaidbinmjnm",
}
Module.__index = Module

local allModifiers = { "cmd", "ctrl", "alt", "shift", "fn" }

function Module.shouldIntercept(key, flags, bundleID, spec)
  spec = spec or { { "cmd" }, "w" }
  flags = flags or {}
  if tostring(key):lower() ~= tostring(spec[2]):lower() or bundleID ~= Module.BUNDLE_ID then return false end
  local required = {}
  for _, modifier in ipairs(spec[1] or {}) do required[modifier] = true end
  for _, modifier in ipairs(allModifiers) do
    if (flags[modifier] == true) ~= (required[modifier] == true) then return false end
  end
  return true
end

function Module.new() return setmetatable({}, Module) end

function Module:detect(context)
  local candidates = context.config and context.config.apps and context.config.apps.whatsapp
    or { Module.BUNDLE_ID }
  local _, bundleID = Detection.find(context.hs.application, candidates)
  self.bundleID = bundleID
  return bundleID ~= nil, "WhatsApp Edge PWA is not installed"
end

function Module:start(context, config)
  self.hs = context.hs
  self.spec = ((config.hotkeys or {}).whatsapp_command_w) or { { "cmd" }, "w" }
  if context.registry then
    local claimed, conflict = context.registry:claim(self.id, "whatsapp_command_w", self.spec[1], self.spec[2])
    if not claimed then error("hotkey conflict: " .. conflict.shortcut) end
  end
  local types = self.hs.eventtap.event.types
  self.tap = self.hs.eventtap.new({ types.keyDown }, function(event)
    local app = self.hs.application.frontmostApplication()
    local keyMatches = event:getKeyCode() == self.hs.keycodes.map[self.spec[2]]
    if keyMatches and app and Module.shouldIntercept(
      self.spec[2], event:getFlags(), app:bundleID(), self.spec
    ) then
      app:hide()
      return true
    end
    return false
  end)
  self.tap:start()
end

function Module:stop() if self.tap then self.tap:stop(); self.tap = nil end; self.spec = nil end
function Module:status() return { enabled = self.tap ~= nil, scope = "whatsapp_pwa_only" } end
return Module
