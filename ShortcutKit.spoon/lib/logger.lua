local Logger = {}
Logger.__index = Logger

function Logger.new(options)
  options = options or {}
  return setmetatable({ path = options.path, entries = {} }, Logger)
end

function Logger:write(level, message)
  local safeMessage = tostring(message):gsub("/Users/[^/%s]+", "$HOME")
  table.insert(self.entries, { level = level, message = safeMessage })
  if self.path then
    local file = io.open(self.path, "a")
    if file then
      file:write(os.date("!%Y-%m-%dT%H:%M:%SZ"), " ", level, " ", safeMessage, "\n")
      file:close()
    end
  end
end

function Logger:info(message) self:write("INFO", message) end
function Logger:error(message) self:write("ERROR", message) end

return Logger
