local Module = { id = "chrome_mention" }
Module.__index = Module

function Module.new() return setmetatable({}, Module) end

function Module:detect(context)
  local app = context.hs.application
  return app.get("com.openai.codex") ~= nil
    or (app.pathForBundleID and app.pathForBundleID("com.openai.codex") ~= nil),
    "Codex is not installed"
end

function Module:run()
  local down = self.hs.eventtap.event.newKeyEvent({}, "space", true)
  local up = self.hs.eventtap.event.newKeyEvent({}, "space", false)
  down:post()
  self.hs.timer.usleep(30000)
  up:post()
  self.hs.eventtap.keyStrokes("@chrome")
  self.hs.timer.doAfter(0.2, function()
    self.hs.eventtap.keyStroke({}, "tab", 0)
  end)
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
  for _, hotkey in ipairs(self.hotkeys or {}) do if hotkey.delete then hotkey:delete() end end
  self.hotkeys = nil
end

function Module:status() return { enabled = self.hotkeys ~= nil } end
return Module
