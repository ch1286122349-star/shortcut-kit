local History = {}
History.__index = History

local function remove(values, target)
  for index = #values, 1, -1 do
    if values[index] == target then table.remove(values, index) end
  end
end

function History.new() return setmetatable({ byWindow = {} }, History) end

function History:record(windowID, tabID)
  if windowID == nil or tabID == nil then return end
  local key = tostring(windowID)
  local values = self.byWindow[key] or {}
  remove(values, tabID)
  table.insert(values, 1, tabID)
  self.byWindow[key] = values
end

function History:remove(windowID, tabID)
  local values = self.byWindow[tostring(windowID)]
  if values then remove(values, tabID) end
end

function History:candidates(windowID, currentTabID)
  local result = {}
  for _, tabID in ipairs(self.byWindow[tostring(windowID)] or {}) do
    if tabID ~= currentTabID then table.insert(result, tabID) end
  end
  return result
end

return History
