local History = require("modules.chrome_history")

local RecentTabs = { id = "chrome_recent_tabs" }

local allModifiers = { "cmd", "ctrl", "alt", "shift", "fn" }

function RecentTabs.matchesHotkey(key, flags, spec)
  spec = spec or { { "cmd" }, "3" }
  flags = flags or {}
  if tostring(key):lower() ~= tostring(spec[2]):lower() then return false end
  local required = {}
  for _, modifier in ipairs(spec[1] or {}) do required[modifier] = true end
  for _, modifier in ipairs(allModifiers) do
    if (flags[modifier] == true) ~= (required[modifier] == true) then return false end
  end
  return true
end
RecentTabs.__index = RecentTabs

RecentTabs.chrome = {}

function RecentTabs.chrome.readCurrent(hsContext)
  local runtimeHS = hsContext or hs
  local ok, result = runtimeHS.osascript.applescript([[
    tell application "Google Chrome"
      if (count of windows) is 0 then return missing value
      return {id of front window, id of active tab of front window}
    end tell
  ]])
  if not ok or type(result) ~= "table" or #result < 2 then return nil end
  return { windowID = result[1], tabID = result[2] }
end

function RecentTabs.chrome.switchTo(windowID, tabID, hsContext)
  local runtimeHS = hsContext or hs
  local numericWindowID, numericTabID = tonumber(windowID), tonumber(tabID)
  if not numericWindowID or not numericTabID then return false end
  local script = string.format([[
    tell application "Google Chrome"
      if (count of windows) is 0 then return false
      set targetWindow to front window
      if ((id of targetWindow) as text) is not "%d" then return false
      repeat with tabIndex from 1 to (count of tabs of targetWindow)
        if ((id of tab tabIndex of targetWindow) as text) is "%d" then
          set active tab index of targetWindow to tabIndex
          return true
        end if
      end repeat
      return false
    end tell
  ]], numericWindowID, numericTabID)
  local ok, result = runtimeHS.osascript.applescript(script)
  return ok and result == true
end

function RecentTabs.new(options)
  assert(type(options) == "table", "options are required")
  return setmetatable({
    history = options.history or History.new(),
    readCurrent = assert(options.readCurrent),
    switchTo = assert(options.switchTo),
    setHotkeyEnabled = options.setHotkeyEnabled or function() end,
    hotkeyEnabled = false,
  }, RecentTabs)
end

function RecentTabs:recordCurrent()
  local current = self.readCurrent()
  if not current or current.windowID == nil or current.tabID == nil then return nil end
  self.history:record(current.windowID, current.tabID)
  return current
end

function RecentTabs:toggle()
  local current = self:recordCurrent()
  if not current then return false end
  for _, tabID in ipairs(self.history:candidates(current.windowID, current.tabID)) do
    if self.switchTo(current.windowID, tabID) then
      self.history:record(current.windowID, tabID)
      return true, tabID, current.windowID
    end
    self.history:remove(current.windowID, tabID)
  end
  return false
end

function RecentTabs:setChromeActive(active)
  self.hotkeyEnabled = active == true
  self.setHotkeyEnabled(self.hotkeyEnabled)
end

function RecentTabs.module()
  local module = { id = "chrome_recent_tabs" }

  function module:detect(context)
    local app = context.hs.application
    return app.get("com.google.Chrome") ~= nil
      or (app.pathForBundleID and app.pathForBundleID("com.google.Chrome") ~= nil),
      "Google Chrome is not installed"
  end

  function module:start(context, config)
    self.hs = context.hs
    local hs = self.hs
    local spec = ((config.hotkeys or {}).chrome_recent_tabs) or { { "cmd" }, "3" }
    if context.registry then
      local claimed, conflict = context.registry:claim(self.id, "chrome_recent_tabs", spec[1], spec[2])
      if not claimed then error("hotkey conflict: " .. conflict.shortcut) end
    end
    local function chromeFrontmost()
      local app = hs.application.frontmostApplication()
      return app and app:bundleID() == "com.google.Chrome"
    end

    local types = hs.eventtap.event.types
    self.commandTap = hs.eventtap.new({ types.keyDown, types.keyUp }, function(event)
      local flags = event:getFlags()
      if event:getKeyCode() ~= hs.keycodes.map[spec[2]]
        or not RecentTabs.matchesHotkey(spec[2], flags, spec)
        or not chromeFrontmost() then return false end
      if event:getType() == types.keyDown
        and event:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat) ~= 1 then
        self.runtime:toggle()
      end
      return true
    end)
    self.runtime = RecentTabs.new({
      readCurrent = function() return RecentTabs.chrome.readCurrent(hs) end,
      switchTo = function(windowID, tabID) return RecentTabs.chrome.switchTo(windowID, tabID, hs) end,
      setHotkeyEnabled = function(enabled)
        if enabled then self.commandTap:start() else self.commandTap:stop() end
      end,
    })
    self.appWatcher = hs.application.watcher.new(function(_, eventType, app)
      if eventType == hs.application.watcher.activated then
        self.runtime:setChromeActive(app and app:bundleID() == "com.google.Chrome")
        if app and app:bundleID() == "com.google.Chrome" then self.runtime:recordCurrent() end
      end
    end)
    self.inputTap = hs.eventtap.new({ types.leftMouseUp, types.keyUp }, function()
      if chromeFrontmost() then hs.timer.doAfter(0.12, function() self.runtime:recordCurrent() end) end
      return false
    end)
    self.appWatcher:start()
    self.inputTap:start()
    self.runtime:setChromeActive(chromeFrontmost())
    if chromeFrontmost() then self.runtime:recordCurrent() end
  end

  function module:stop()
    if self.commandTap then self.commandTap:stop() end
    if self.appWatcher then self.appWatcher:stop() end
    if self.inputTap then self.inputTap:stop() end
    self.commandTap, self.appWatcher, self.inputTap, self.runtime = nil, nil, nil, nil
  end

  function module:status()
    return { enabled = self.commandTap ~= nil, chromeActive = self.runtime and self.runtime.hotkeyEnabled or false }
  end
  return module
end

return RecentTabs
