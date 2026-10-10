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

-- 只选择候选列表里的准确名称，不依赖加载速度或默认高亮项。
function Module:findChromeCandidate(app)
  if not self.hs.axuielement then return nil end
  local ax = self.hs.axuielement.applicationElement(app)
  ax:setAttributeValue("AXManualAccessibility", true)
  local root = ax:attributeValue("AXFocusedWindow")
  local count, matches = 0, {}
  local function exact(value)
    return type(value) == "string" and value:match("^%s*@?[Cc][Hh][Rr][Oo][Mm][Ee]%s*$") ~= nil
  end
  local function scan(element, depth, inList)
    count = count + 1
    if count > 900 or depth > 40 then return end
    local role = element:attributeValue("AXRole")
    local candidateList = inList or role == "AXList" or role == "AXMenu"
    local children = element:attributeValue("AXChildren") or {}
    local named = exact(element:attributeValue("AXTitle"))
      or exact(element:attributeValue("AXDescription"))
      or exact(element:attributeValue("AXValue"))
    for _, child in ipairs(children) do
      if child:attributeValue("AXRole") == "AXStaticText" then
        named = named or exact(child:attributeValue("AXValue"))
          or exact(child:attributeValue("AXTitle"))
      end
    end
    -- 当前 Codex 候选用 AXButton，容器未必暴露为 AXList。
    -- 实体按键采集：标题 Chrome，描述 Chrome 电脑操控。
    local description = element:attributeValue("AXDescription") or ""
    local browserCandidate = exact(element:attributeValue("AXTitle"))
      and (description:match("^Chrome%s+电脑操控%s*$")
        or description:match("^Chrome%s+Computer [Uu]se%s*$"))
    if (candidateList or browserCandidate) and named and (role == "AXButton" or role == "AXMenuItem" or role == "AXRow") then
      for _, action in ipairs(element:actionNames() or {}) do
        if action == "AXPress" then matches[#matches + 1] = element; break end
      end
    end
    for _, child in ipairs(children) do scan(child, depth + 1, candidateList) end
  end
  if root then scan(root, 0, false) end
  -- 有歧义时不猜，不对聊天正文里的 Chrome 链接操作。
  if #matches == 1 then return matches[1] end
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
    local polls = 0
    local function selectExactCandidate()
      local currentFlags = self.hs.eventtap.checkKeyboardModifiers()
      if currentFlags.cmd or currentFlags.shift or currentFlags.alt or currentFlags.ctrl then
        self.lastResult = "selection-cancelled-modifier"
        return
      end
      polls = polls + 1
      local ok, candidate = pcall(self.findChromeCandidate, self, app)
      if ok and candidate then
        local pressed, result = pcall(function() return candidate:performAction("AXPress") end)
        self.lastResult = pressed and result and "chrome-pressed" or "chrome-press-failed"
        return
      end
      if polls >= 40 then
        self.lastResult = ok and "chrome-candidate-timeout" or "candidate-read-failed"
        return
      end
      schedule(0.15, selectExactCandidate)
    end
    schedule(0.15, selectExactCandidate)
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
