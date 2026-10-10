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
local function node(role, value, children, pressable)
  local e = {role=role,value=value,children=children or {}}
  function e:attributeValue(key)
    return ({AXRole=self.role,AXValue=self.value,AXChildren=self.children,AXTitle=self.title,AXDescription=self.description,AXARIACurrent=self.current})[key]
  end
  function e:attributeNames() return {"AXARIACurrent"} end
  function e:actionNames() return pressable and {"AXPress"} or {} end
  function e:performAction(action) assert(action=="AXPress"); keys[#keys+1]="press:"..self.value;return self end
  return e
end
local root=node("AXWindow")
hsFake.axuielement={applicationElement=function() return {
 setAttributeValue=function() end,
 attributeValue=function(_,key) if key=="AXFocusedWindow" then return root end end
} end}
local nativeCandidate=node("AXButton",nil,nil,true)
nativeCandidate.title="Chrome";nativeCandidate.description="Chrome 电脑操控"
root.children={node("AXGroup",nil,{nativeCandidate})}
local m=Module.new(); m:start({hs=hsFake},{})
assert(m:findChromeCandidate({})==nativeCandidate,"匹配真实 Codex 候选结构")
nativeCandidate.title="Chrome Chrome 电脑操控";nativeCandidate.description=""
assert(m:findChromeCandidate({})==nativeCandidate,"候选名称包含图标替代文字时仍能识别")
m:run(); assert(#keys==0,"等待实体修饰键松开，不立即输入")
flags={}; timers[#timers].callback()
assert(keys[1]=="space" and keys[2]=="@chrome","松开后先输入 trigger")
root.children={node("AXList",nil,{node("AXButton","浏览器",nil,true)})}
for _=1,8 do timers[#timers].callback() end
assert(keys[#keys]=="@chrome","冷启动超过旧等待时间也不能盲按 Tab")
local chrome=node("AXButton","Chrome",nil,true);chrome.current="true"
root.children[1].children[2]=chrome
for _=1,2 do timers[#timers].callback() end
assert(keys[#keys]=="tab","Chrome 在第二项时精确选中")
local stale=timers[#timers]; m:run();local before=#keys; stale.callback()
assert(#keys==before,"重复触发必须取消旧选择")
local current=timers[#timers]; window=99; current.callback()
assert(#keys==before,"窗口切换后不选择候选")
window=12; m:run();flags={cmd=true};timers[#timers].callback()
assert(m.lastResult=="selection-cancelled-modifier")
flags={};root.children={node("AXLink","Chrome",nil,true)}
m:run();for _=1,150 do timers[#timers].callback() end
assert(m.lastResult=="chrome-candidate-timeout","聊天链接不能当候选，无候选时安全停止")
root.children={node("AXList",nil,{chrome,node("AXButton","Chrome",nil,true)})}
assert(m:findChromeCandidate({})==nil,"多个同名候选不能猜测")
root.children={node("AXList",nil,{node("AXButton",nil,{node("AXStaticText","Chrome")},true)})}
assert(m:findChromeCandidate({})~=nil,"支持按钮子节点名称")
m:run();local stopped=timers[#timers];m:stop();before=#keys;stopped.callback()
assert(#keys==before,"停用模块取消延迟动作")
m:start({hs=hsFake},{});root.children={node("AXList",nil,{chrome})};m:run();for _=1,2 do timers[#timers].callback() end
assert(m.lastResult=="chrome-tab-sent","重启模块后继续使用准确选择")
bundle="com.google.Chrome";before=#keys;m:run();assert(#keys==before,"其他 App 不触发")
print("chrome_mention_spec: PASS")
