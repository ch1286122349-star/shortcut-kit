local helper = dofile(assert(SHORTCUT_KIT_TEST_ROOT) .. "/tests/lua/test_helper.lua")
local OCR = helper.requireProject("modules.local_ocr")
local Modules = helper.requireProject("modules")

local tasks = {}
local clipboard
local removed = {}
local existing = { ["/fake/local-ocr"] = true }
local hotkeyRelease

helper.assertEqual(
  OCR.defaultBinaryPath("/tmp/ShortcutKit.spoon/modules/local_ocr.lua"),
  "/tmp/ShortcutKit.spoon/bin/local-ocr",
  "OCR binary path resolves from the module file"
)

local fakeHS = {
  fs = { attributes = function(path) return existing[path] and {} or nil end },
  host = { uuid = function() return "test-uuid" end },
  pasteboard = { setContents = function(value) clipboard = value; return true end },
  hotkey = { bind = function(_, _, _, released) hotkeyRelease = released; return { delete = function() end } end },
  task = { new = function(path, callback, args)
    local task = { path = path, callback = callback, args = args }
    function task:start() self.started = true; return true end
    table.insert(tasks, task)
    return task
  end },
}

local ocr = OCR.new({
  binaryPath = "/fake/local-ocr",
  remove = function(path) removed[path] = true end,
})
ocr:start({ hs = fakeHS, registry = { claim = function() return true end } }, { hotkeys = {} })
hotkeyRelease()
helper.assertEqual(ocr:status().running, true, "OCR enters running state")
helper.assertEqual(tasks[1].path, "/usr/sbin/screencapture", "OCR starts interactive screenshot")

local imagePath = "/tmp/shortcut-kit-ocr-test-uuid.png"
existing[imagePath] = true
tasks[1].callback(0, "", "")
helper.assertEqual(tasks[2].path, "/fake/local-ocr", "OCR starts recognition binary")
tasks[2].callback(0, " Hola 你好 \n", "")

helper.assertEqual(ocr:status().running, false, "OCR leaves running state")
helper.assertEqual(clipboard, "Hola 你好", "recognized text is trimmed into clipboard")
helper.assertEqual(removed[imagePath], true, "temporary image is removed")

local registered = false
for _, module in ipairs(Modules) do
  if module.id == "local_ocr" then registered = true end
end
helper.assertEqual(registered, true, "OCR module is registered")

print("local_ocr_spec: PASS")
