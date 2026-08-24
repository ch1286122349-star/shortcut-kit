local SafeTask = {}
SafeTask.__index = SafeTask

function SafeTask.new(factory)
  return setmetatable({ factory = assert(factory, "task factory is required") }, SafeTask)
end

function SafeTask:start(path, args, callback)
  local task = self.factory(path, callback, args)
  if not task or not task:start() then return nil, "task did not start" end
  return task
end

return SafeTask
