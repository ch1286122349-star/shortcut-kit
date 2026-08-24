local Module = { id = "local_ocr" }
Module.__index = Module

local function trim(value)
  return (value or ""):match("^%s*(.-)%s*$") or ""
end

function Module.new(options)
  options = options or {}
  return setmetatable({
    binaryPath = options.binaryPath,
    remove = options.remove or os.remove,
    running = false,
  }, Module)
end

function Module:detect(context)
  local hs = context.hs
  local path = self.binaryPath or (hs.spoons and hs.spoons.resourcePath("bin/local-ocr"))
  self.binaryPath = path
  return hs.fs.attributes(path) ~= nil, "OCR binary is unavailable"
end

function Module:finish(imagePath)
  if imagePath then self.remove(imagePath) end
  self.screenshotTask, self.recognitionTask, self.running = nil, nil, false
end

function Module:trigger()
  if self.running then return false, "OCR is already running" end
  if not self.hs.fs.attributes(self.binaryPath) then return false, "OCR binary is unavailable" end

  self.running = true
  local imagePath = "/tmp/shortcut-kit-ocr-" .. self.hs.host.uuid() .. ".png"
  self.screenshotTask = self.hs.task.new("/usr/sbin/screencapture", function(exitCode, _, stderr)
    self.screenshotTask = nil
    if exitCode ~= 0 or not self.hs.fs.attributes(imagePath) then
      self.lastError = trim(stderr)
      self:finish(imagePath)
      return
    end

    self.recognitionTask = self.hs.task.new(self.binaryPath, function(ocrExitCode, stdout, ocrStderr)
      self.recognitionTask = nil
      local text = trim(stdout)
      if ocrExitCode == 0 and text ~= "" then
        self.hs.pasteboard.setContents(text)
        self.lastError = nil
      else
        self.lastError = trim(ocrStderr) ~= "" and trim(ocrStderr) or "No text recognized"
      end
      self:finish(imagePath)
    end, { imagePath })

    if not self.recognitionTask or not self.recognitionTask:start() then
      self.lastError = "OCR recognition task did not start"
      self:finish(imagePath)
    end
  end, { "-i", "-x", imagePath })

  if not self.screenshotTask or not self.screenshotTask:start() then
    self.lastError = "Screenshot task did not start"
    self:finish(imagePath)
    return false, self.lastError
  end
  return true
end

function Module:start(context, config)
  self.hs = context.hs
  if not self.binaryPath then
    self.binaryPath = self.hs.spoons.resourcePath("bin/local-ocr")
  end
  local spec = ((config.hotkeys or {}).local_ocr) or { { "cmd" }, "s" }
  if context.registry then
    local ok, conflict = context.registry:claim(self.id, "recognize", spec[1], spec[2])
    if not ok then error("hotkey conflict: " .. conflict.shortcut) end
  end
  self.hotkey = self.hs.hotkey.bind(spec[1], spec[2], nil, function() self:trigger() end)
end

function Module:stop()
  if self.hotkey and self.hotkey.delete then self.hotkey:delete() end
  if self.screenshotTask and self.screenshotTask.terminate then self.screenshotTask:terminate() end
  if self.recognitionTask and self.recognitionTask.terminate then self.recognitionTask:terminate() end
  self.hotkey, self.screenshotTask, self.recognitionTask, self.running = nil, nil, nil, false
end

function Module:status()
  return { running = self.running, error = self.lastError, binary = self.binaryPath }
end

return Module
