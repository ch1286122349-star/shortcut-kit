local Runner = {}
Runner.__index = Runner

function Runner.new(options)
  options = options or {}
  return setmetatable({ logger = options.logger }, Runner)
end

function Runner:start(modules, config, context)
  local report = { modules = {}, ok = true }
  local enabledModules = (config and config.modules) or {}

  for _, module in ipairs(modules or {}) do
    local enabled = enabledModules[module.id] ~= false
    local detected, reason
    if enabled then
      detected, reason = module:detect(context)
    else
      detected, reason = false, "disabled"
    end

    if not detected then
      report.modules[module.id] = { state = "skipped", reason = reason or "dependency unavailable" }
    else
      local ok, err = xpcall(function()
        module:start(context, config)
      end, debug.traceback)
      if ok then
        report.modules[module.id] = { state = "enabled" }
      else
        report.modules[module.id] = { state = "error", reason = tostring(err) }
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
