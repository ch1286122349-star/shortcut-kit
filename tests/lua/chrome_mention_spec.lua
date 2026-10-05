local helper = dofile(assert(SHORTCUT_KIT_TEST_ROOT) .. "/tests/lua/test_helper.lua")
local Module = helper.requireProject("modules.chrome_mention")
local timers, keys, flags = {}, {}, {cmd=true,shift=true}
local bundle, window = "com.openai.codex", 12
local hsFake = {
 application={frontmostApplication=function() return {bundleID=function() return bundle end} end},
 window={focusedWindow=function() return {id=function() return window end} end},
 eventtap={event={newKeyEvent=function(_,key,down) return {post=function() keys[#keys+1]=key..(down and ":down" or ":up") end} end},checkKeyboardModifiers=function() return flags end,
 keyStrokes=function(s) keys[#keys+1]=s end,
 keyStroke=function(_,s) keys[#keys+1]=s end},
 timer={usleep=function() end,doAfter=function(delay,cb) local t={delay=delay,callback=cb,stop=function(self) self.stopped=true end}; timers[#timers+1]=t; return t end},
 hotkey={bind=function() return {delete=function() end} end}
}
local m=Module.new(); m:start({hs=hsFake},{})
m:run(); assert(#keys==0,"等待实体修饰键松开，不立即输入")
flags={}; timers[#timers].callback()
assert(keys[1]=="space" and keys[2]=="@chrome","松开后先输入 trigger")
assert(timers[#timers].delay>=0.7,"候选更新的等待在 Tab 前")
local stale=timers[#timers]; m:run(); stale.callback()
assert(keys[#keys]~="tab","重复触发必须取消旧 Tab")
local current=timers[#timers]; window=99; current.callback()
assert(keys[#keys]~="tab","窗口切换后不选择候选")
window=12; m:run(); timers[#timers].callback()
assert(keys[#keys]=="tab","稳定窗口完成候选选择")
m:run(); local stopped=timers[#timers]; m:stop(); stopped.callback()
assert(keys[#keys]~="tab","停用模块取消延迟按键")
bundle="com.google.Chrome"; m:run(); assert(keys[#keys]~="tab","其他 App 不触发")
print("chrome_mention_spec: PASS")
