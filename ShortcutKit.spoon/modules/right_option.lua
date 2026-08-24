local Module = { id = "right_option" }
Module.__index = Module

function Module.shouldTrigger(heldSeconds, usedAsModifier, alreadyTriggered)
  return heldSeconds >= 0.35 and not usedAsModifier and not alreadyTriggered
end

function Module.new()
  return setmetatable({ isDown = false, usedAsModifier = false, triggered = false }, Module)
end

function Module:detect() return true end

function Module:sendSpace()
  local down = self.hs.eventtap.event.newKeyEvent({}, "space", true)
  local up = self.hs.eventtap.event.newKeyEvent({}, "space", false)
  down:post()
  self.hs.timer.usleep(30000)
  up:post()
end

function Module:fireTripleSpace()
  for index = 1, 3 do
    self:sendSpace()
    if index < 3 then self.hs.timer.usleep(90000) end
  end
end

function Module:start(context)
  self.hs = context.hs
  local types = self.hs.eventtap.event.types
  self.flagsTap = self.hs.eventtap.new({ types.flagsChanged }, function(event)
    if event:getKeyCode() ~= 61 then return false end
    local pressed = event:getFlags().alt
    if pressed and not self.isDown then
      self.isDown = true
      self.usedAsModifier = false
      self.triggered = false
      self.pressedAt = self.hs.timer.absoluteTime()
    elseif not pressed and self.isDown then
      local seconds = (self.hs.timer.absoluteTime() - self.pressedAt) / 1000000000
      local trigger = Module.shouldTrigger(seconds, self.usedAsModifier, self.triggered)
      self.isDown, self.pressedAt = false, nil
      if trigger then self.hs.timer.doAfter(0.02, function() self:fireTripleSpace() end) end
    end
    return true
  end)
  self.keyTap = self.hs.eventtap.new({ types.keyDown }, function(event)
    if self.isDown and not self.triggered and event:getKeyCode() ~= 61 then
      self.usedAsModifier = true
    end
    return false
  end)
  self.flagsTap:start()
  self.keyTap:start()
end

function Module:stop()
  if self.flagsTap then self.flagsTap:stop() end
  if self.keyTap then self.keyTap:stop() end
  self.flagsTap, self.keyTap = nil, nil
end

function Module:status()
  return { flagsTap = self.flagsTap ~= nil, keyTap = self.keyTap ~= nil }
end
return Module
