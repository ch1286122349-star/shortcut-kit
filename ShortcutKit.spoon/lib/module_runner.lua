local Runner = {}
Runner.__index = Runner

local function safeError(errorValue)
  local text = tostring(errorValue or "")
  local shortcut = text:match("hotkey conflict:%s*([%w%+%-_]+)")
  if shortcut then return "hotkey conflict: " .. shortcut end
  local invalidKey = text:match("Invalid key:%s*([^%s]+)")
  if invalidKey then return "invalid hotkey: " .. invalidKey end
  return "module failed to start"
end

function Runner.new(options)
  options = options or {}
  return setmetatable({ logger = options.logger }, Runner)
end

function Runner:start(modules, config, context)
  local report = { modules = {}, ok = true }
  local enabledModules = (config and config.modules) or {}
  context.config = config

  for _, module in ipairs(modules or {}) do
    local enabled = enabledModules[module.id] ~= false
    local detected, reason
    if enabled then
      detected, reason = module:detect(context)
    else
      detected, reason = false, "disabled"
    end

    if not enabled then
      report.modules[module.id] = { state = "disabled", reason = "disabled" }
    elseif not detected then
      report.modules[module.id] = { state = "skipped", reason = reason or "dependency unavailable" }
    else
      local ok, err = xpcall(function()
        module:start(context, config)
      end, debug.traceback)
      if ok then
        report.modules[module.id] = { state = "enabled" }
      else
        report.modules[module.id] = { state = "error", reason = safeError(err) }
        report.ok = false
        if self.logger and self.logger.error then
          self.logger:error(module.id .. " failed to start")
        end
      end
    end
  end

  return report
end

return Runner
