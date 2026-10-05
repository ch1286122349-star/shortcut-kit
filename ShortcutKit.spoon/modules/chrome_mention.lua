local Module = { id = "chrome_mention" }
Module.__index = Module

function Module.new() return setmetatable({}, Module) end

function Module:detect(context)
  local app = context.hs.application
  return app.get("com.openai.codex") ~= nil
    or (app.pathForBundleID and app.pathForBundleID("com.openai.codex") ~= nil),
    "Codex is not installed"
end

-- 每次触发只保留一条按键序列，避免旧 Tab 选中新的候选。
function Module:cancel()
  self.generation = (self.generation or 0) + 1
  if self.timer then self.timer:stop(); self.timer = nil end
end

function Module:run()
  self:cancel()
  if not self.hotkeys then return end
  local app = self.hs.application.frontmostApplication()
  local win = self.hs.window.focusedWindow()
  if not app or app:bundleID() ~= "com.openai.codex" or not win then
    self.lastResult = "ignored-other-app"
    return
  end
  local generation, windowID = self.generation, win:id()
  local function stillHere()
    local current = self.hs.application.frontmostApplication()
    local focused = self.hs.window.focusedWindow()
    return self.hotkeys and self.generation == generation
      and current and current:bundleID() == "com.openai.codex"
      and focused and focused:id() == windowID
  end
  local function schedule(delay, callback)
    self.timer = self.hs.timer.doAfter(delay, function()
      if not stillHere() then return end
      self.timer = nil
      callback()
    end)
  end
  local attempts = 0
  local function insertWhenReleased()
    local flags = self.hs.eventtap.checkKeyboardModifiers()
    if flags.cmd or flags.shift or flags.alt or flags.ctrl then
      attempts = attempts + 1
      if attempts >= 100 then self.lastResult = "modifier-timeout"; return end
      schedule(0.03, insertWhenReleased)
      return
    end
    self.hs.eventtap.keyStroke({}, "space", 0)
    self.hs.eventtap.keyStrokes("@chrome")
    self.lastResult = "waiting-for-candidates"
    -- 候选刷新前不能按 Tab；固定等待仅作时序保护，不代表已读回候选。
    schedule(0.8, function()
      local currentFlags = self.hs.eventtap.checkKeyboardModifiers()
      if currentFlags.cmd or currentFlags.shift or currentFlags.alt or currentFlags.ctrl then
        self.lastResult = "selection-cancelled-modifier"
        return
      end
      self.hs.eventtap.keyStroke({}, "tab", 0)
      self.lastResult = "tab-sent"
    end)
  end
  insertWhenReleased()
end

function Module:start(context, config)
  self.hs = context.hs
  local hotkeys = config.hotkeys or {}
  local specs = {
    { action = "chrome_mention_2", spec = hotkeys.chrome_mention_2 or { { "cmd", "shift" }, "2" } },
    { action = "chrome_mention_3", spec = hotkeys.chrome_mention_3 or { { "cmd", "shift" }, "3" } },
  }
  self.hotkeys = {}
  for _, item in ipairs(specs) do
    if context.registry then
      local ok, conflict = context.registry:claim(self.id, item.action, item.spec[1], item.spec[2])
      if not ok then error("hotkey conflict: " .. conflict.shortcut) end
    end
    table.insert(self.hotkeys, self.hs.hotkey.bind(item.spec[1], item.spec[2], function() self:run() end))
  end
end

function Module:stop()
  self:cancel()
  for _, hotkey in ipairs(self.hotkeys or {}) do if hotkey.delete then hotkey:delete() end end
  self.hotkeys = nil
end

function Module:status() return { enabled = self.hotkeys ~= nil, result = self.lastResult } end
return Module
