local Detection = require("lib.app_detection")
local Module = { id = "mailmaster_toggle", BUNDLE_ID = "com.netease.macmail" }
Module.__index = Module

function Module.largestStandardWindow(windows)
  local best, bestArea = nil, 0
  for _, window in ipairs(windows or {}) do
    if window:subrole() == "AXStandardWindow" then
      local frame = window:frame()
      local area = frame.w * frame.h
      if area > bestArea then best, bestArea = window, area end
    end
  end
  return best
end

function Module.new() return setmetatable({}, Module) end

function Module:detect(context)
  local candidates = context.config and context.config.apps and context.config.apps.mailmaster
    or { Module.BUNDLE_ID }
  local _, bundleID = Detection.find(context.hs.application, candidates)
  self.bundleID = bundleID
  return bundleID ~= nil, "MailMaster is not installed"
end

function Module:repair()
  local app = self.hs.application.get(self.bundleID or Module.BUNDLE_ID)
  local focused = app and app:focusedWindow()
  if focused and focused:isVisible() and not focused:isMinimized() then
    local frame = focused:frame()
    if frame.w >= 320 and frame.h >= 240 then return false end
  end
  local window = app and Module.largestStandardWindow(app:allWindows()) or nil
  if not window then
    self.hs.execute("/usr/bin/open -a '/Applications/MailMaster.app'", true)
    return true
  end
  app:unhide()
  if window:isMinimized() then window:unminimize() end
  window:focus()
  return true
end

function Module:toggle()
  local bundleID = self.bundleID or Module.BUNDLE_ID
  local app = self.hs.application.get(bundleID)
  if app and app:isFrontmost() then app:hide(); return end
  self.hs.application.launchOrFocusByBundleID(bundleID)
  self.hs.timer.doAfter(0.08, function() self:repair() end)
end

function Module:start(context, config)
  self.hs = context.hs
  self.hotkeys = {}
  for _, item in ipairs({
    { "mailmaster_toggle", (config.hotkeys or {}).mailmaster_toggle or { { "cmd" }, "5" } },
    { "mailmaster_pad5", (config.hotkeys or {}).mailmaster_pad5 or { { "cmd" }, "pad5" } },
  }) do
    if context.registry then
      local ok, conflict = context.registry:claim(self.id, item[1], item[2][1], item[2][2])
      if not ok then error("hotkey conflict: " .. conflict.shortcut) end
    end
    table.insert(self.hotkeys, self.hs.hotkey.bind(item[2][1], item[2][2], function() self:toggle() end))
  end
  self.watcher = self.hs.application.watcher.new(function(_, eventType, app)
    if eventType == self.hs.application.watcher.activated and app and app:bundleID() == (self.bundleID or Module.BUNDLE_ID) then
      self.hs.timer.doAfter(0.08, function() self:repair() end)
    end
  end)
  self.watcher:start()
end

function Module:stop()
  for _, hotkey in ipairs(self.hotkeys or {}) do if hotkey.delete then hotkey:delete() end end
  if self.watcher then self.watcher:stop() end
  self.hotkeys, self.watcher = nil, nil
end

function Module:status() return { enabled = self.hotkeys ~= nil } end
return Module
