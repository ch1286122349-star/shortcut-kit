local Detection = require("lib.app_detection")
local Module = { id = "chatgpt_classic", BUNDLE_ID = "com.openai.chat" }
Module.__index = Module

local MODEL_SLUGS = {
  auto = "gpt-5-6",
  instant = "gpt-5-6-instant",
  thinking = "gpt-5-6-thinking",
  pro = "gpt-5-6-pro",
}

function Module.modelSlug(mode) return MODEL_SLUGS[mode] end

function Module.decodeConversation(raw, json)
  local ok, conversation = pcall(json.decode, raw)
  if not ok or type(conversation) ~= "table" then return nil, "missing conversation" end
  return conversation
end

function Module.new() return setmetatable({}, Module) end

function Module:detect(context)
  local candidates = context.config and context.config.apps and context.config.apps.chatgpt
    or { Module.BUNDLE_ID }
  local _, bundleID = Detection.find(context.hs.application, candidates)
  self.bundleID = bundleID
  return bundleID ~= nil, "ChatGPT Classic is not installed"
end

function Module:visibleWindows()
  local app = self.hs.application.get(self.bundleID or Module.BUNDLE_ID)
  local result = {}
  for _, window in ipairs(app and app:allWindows() or {}) do
    if window:isVisible() and not window:isMinimized() then table.insert(result, window) end
  end
  return result
end

function Module:mainWindow(visibleOnly)
  local windows = visibleOnly and self:visibleWindows()
    or ((self.hs.application.get(self.bundleID or Module.BUNDLE_ID)
      or { allWindows = function() return {} end }):allWindows())
  for _, window in ipairs(windows) do if window:isStandard() then return window end end
  return nil
end

function Module:closeLaunchers()
  local closed = false
  for _, window in ipairs(self:visibleWindows()) do
    if not window:isStandard() then
      window:focus()
      self.hs.timer.doAfter(0.05, function() self.hs.eventtap.keyStroke({}, "escape", 0) end)
      closed = true
    end
  end
  return closed
end

function Module:toggleMain()
  local app = self.hs.application.get(self.bundleID or Module.BUNDLE_ID)
  local main = self:mainWindow(true)
  if app and main and app:isFrontmost() then app:hide(); return end
  self:closeLaunchers()
  if app then
    app:unhide(); app:activate(true)
    main = main or self:mainWindow(false)
    if main then
      if main:isMinimized() then main:unminimize() end
      main:focus()
    else
      self.hs.osascript.applescript('tell application id "' .. (self.bundleID or Module.BUNDLE_ID) .. '" to reopen')
    end
    return
  end
  self.hs.application.launchOrFocusByBundleID(self.bundleID or Module.BUNDLE_ID)
end

function Module:switchModel(mode)
  local slug = Module.modelSlug(mode)
  if not slug then return false, "unknown mode" end
  local raw = self.hs.execute("/usr/bin/defaults read com.openai.chat lastSelectedConversation", true)
  local conversation, errorMessage = Module.decodeConversation(raw, self.hs.json)
  if not conversation then
    self.hs.alert.show("ChatGPT Classic 模型切换失败：没有当前会话")
    return false, errorMessage
  end
  conversation.modelSlug = slug
  conversation.lastUpdated = os.time() - 978307200
  local encoded = self.hs.json.encode(conversation)
  local bundleID = self.bundleID or Module.BUNDLE_ID
  local app = self.hs.application.get(bundleID)
  if app then app:kill() end

  local attempts = 0
  local function writeAfterQuit()
    attempts = attempts + 1
    if self.hs.application.get(bundleID) and attempts < 30 then
      self.hs.timer.doAfter(0.1, writeAfterQuit)
      return
    end
    self.modelTask = self.hs.task.new("/usr/bin/defaults", function(exitCode)
      self.modelTask = nil
      if exitCode ~= 0 then self.hs.alert.show("ChatGPT Classic 模型切换失败"); return end
      self.hs.execute("/usr/bin/open -a '/Applications/ChatGPT Classic.app'", true)
      self.hs.alert.show("ChatGPT Classic：" .. mode)
    end, { "write", bundleID, "lastSelectedConversation", "-string", encoded })
    if not self.modelTask or not self.modelTask:start() then
      self.modelTask = nil
      self.hs.alert.show("ChatGPT Classic 模型切换失败")
    end
  end
  writeAfterQuit()
  return true, slug
end

function Module:start(context, config)
  self.hs = context.hs
  self.hotkeys = {}
  local hotkeys = config.hotkeys or {}
  local specs = {
    { "toggle_backtick", hotkeys.chatgpt_toggle or { { "cmd" }, "`" }, function() self:toggleMain() end },
    { "toggle_section", hotkeys.chatgpt_toggle_section or { { "cmd" }, "§" }, function() self:toggleMain() end },
  }
  for index, mode in ipairs({ "auto", "instant", "thinking", "pro" }) do
    table.insert(specs, {
      "model_" .. mode,
      hotkeys["chatgpt_model_" .. mode] or { { "ctrl", "alt" }, tostring(index) },
      function()
        local app = self.hs.application.frontmostApplication()
        if not app or app:bundleID() ~= (self.bundleID or Module.BUNDLE_ID) then
          self.hs.alert.show("请先切到 ChatGPT Classic")
          return
        end
        self:switchModel(mode)
      end,
    })
  end
  for _, item in ipairs(specs) do
    if context.registry then
      local ok, conflict = context.registry:claim(self.id, item[1], item[2][1], item[2][2])
      if not ok then error("hotkey conflict: " .. conflict.shortcut) end
    end
    table.insert(self.hotkeys, self.hs.hotkey.bind(item[2][1], item[2][2], item[3]))
  end
  self.watcher = self.hs.application.watcher.new(function(_, eventType, app)
    if eventType == self.hs.application.watcher.deactivated
      and app and app:bundleID() == (self.bundleID or Module.BUNDLE_ID) then
      self.hs.timer.doAfter(0.08, function()
        self:closeLaunchers()
        local current = self.hs.application.get(self.bundleID or Module.BUNDLE_ID)
        if current and self:mainWindow(false) then current:hide() end
      end)
    end
  end)
  self.watcher:start()
end

function Module:stop()
  for _, hotkey in ipairs(self.hotkeys or {}) do if hotkey.delete then hotkey:delete() end end
  if self.watcher then self.watcher:stop() end
  if self.modelTask then self.modelTask:terminate() end
  self.hotkeys, self.watcher, self.modelTask = nil, nil, nil
end

function Module:status() return { enabled = self.hotkeys ~= nil } end
return Module
