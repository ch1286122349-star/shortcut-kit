local Detection = require("lib.app_detection")
local Module = { id = "codex_toggle", BUNDLE_ID = "com.openai.codex" }
Module.__index = Module

function Module.actionFor(frontmostBundleID, targetBundleID)
  if frontmostBundleID == (targetBundleID or Module.BUNDLE_ID) then return "restore_and_hide" end
  return "remember_and_focus"
end

function Module.new() return setmetatable({}, Module) end

function Module:detect(context)
  local candidates = context.config and context.config.apps and context.config.apps.codex
    or { Module.BUNDLE_ID }
  local _, bundleID = Detection.find(context.hs.application, candidates)
  self.bundleID = bundleID
  return bundleID ~= nil, "Codex is not installed"
end

function Module:remember()
  local app = self.hs.application.frontmostApplication()
  if not app or app:bundleID() == (self.bundleID or Module.BUNDLE_ID) then return end
  local window = app:focusedWindow()
  self.previous = {
    pid = app:pid(),
    bundleID = app:bundleID(),
    windowID = window and window:id() or nil,
  }
end

function Module:restore()
  local previous = self.previous or {}
  local window = previous.windowID and self.hs.window.get(previous.windowID) or nil
  if window then
    local app = window:application()
    if app and app:bundleID() ~= (self.bundleID or Module.BUNDLE_ID) then
      app:unhide(); app:activate(true)
      if window:isMinimized() then window:unminimize() end
      window:focus()
      return true
    end
  end
  local app = previous.pid and self.hs.application.applicationForPID(previous.pid) or nil
  if not app and previous.bundleID then app = self.hs.application.get(previous.bundleID) end
  if app and app:bundleID() ~= (self.bundleID or Module.BUNDLE_ID) then
    app:unhide(); app:activate(true)
    return true
  end
  local codex = self.hs.application.get(self.bundleID or Module.BUNDLE_ID)
  for _, candidate in ipairs(self.hs.window.orderedWindows()) do
    local candidateApp = candidate:application()
    if candidate:isVisible() and not candidate:isMinimized()
      and candidateApp and (not codex or candidateApp:pid() ~= codex:pid()) then
      candidateApp:activate(true); candidate:focus()
      return true
    end
  end
  return false
end

function Module:toggle()
  local bundleID = self.bundleID or Module.BUNDLE_ID
  local codex = self.hs.application.get(bundleID)
  local frontmost = self.hs.application.frontmostApplication()
  if Module.actionFor(frontmost and frontmost:bundleID(), bundleID) == "restore_and_hide" then
    self:restore()
    if codex then codex:hide() end
    return
  end
  self:remember()
  self.hs.application.launchOrFocusByBundleID(bundleID)
end

function Module:start(context, config)
  self.hs = context.hs
  local spec = (config.hotkeys or {}).codex_toggle or { { "cmd" }, "2" }
  if context.registry then
    local ok, conflict = context.registry:claim(self.id, "toggle", spec[1], spec[2])
    if not ok then error("hotkey conflict: " .. conflict.shortcut) end
  end
  self.hotkey = self.hs.hotkey.bind(spec[1], spec[2], function() self:toggle() end)
end

function Module:stop()
  if self.hotkey and self.hotkey.delete then self.hotkey:delete() end
  self.hotkey, self.previous = nil, nil
end

function Module:status() return { enabled = self.hotkey ~= nil } end
return Module
