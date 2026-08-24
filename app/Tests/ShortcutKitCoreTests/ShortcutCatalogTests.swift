import XCTest
@testable import ShortcutKitCore

final class ShortcutCatalogTests: XCTestCase {
    func testCatalogDecodesEveryRuntimeModuleExactlyOnce() throws {
        let data = Data(Self.catalogJSON.utf8)
        let definitions = try ShortcutCatalog.load(data: data)

        XCTAssertEqual(Set(definitions.map(\.id)).count, definitions.count)
        XCTAssertEqual(Set(definitions.map(\.id)), [
            "window_screenshot", "command_space", "right_option",
            "left_mouse_modifier", "local_ocr", "chrome_recent_tabs",
            "chrome_mention", "codex_toggle", "mailmaster_toggle",
            "chatgpt_classic", "whatsapp_command_w", "btt_bridge",
        ])
    }

    func testCatalogRejectsDuplicateIDs() throws {
        let duplicate = """
        [
          {"id":"same","title":"A","keys":["⌘ A"],"summary":"A","scope":"全局","group":"全局"},
          {"id":"same","title":"B","keys":["⌘ B"],"summary":"B","scope":"全局","group":"全局"}
        ]
        """
        XCTAssertThrowsError(try ShortcutCatalog.load(data: Data(duplicate.utf8)))
    }

    private static let catalogJSON = """
    [
      {"id":"window_screenshot","title":"窗口截图","keys":["⌘ R"],"summary":"截取鼠标所在窗口","scope":"全局","group":"全局"},
      {"id":"command_space","title":"打开","keys":["⌘ Space"],"summary":"发送原生 Command+O","scope":"全局","group":"全局"},
      {"id":"right_option","title":"三空格","keys":["长按右 Option"],"summary":"输入三个空格","scope":"全局","group":"全局"},
      {"id":"left_mouse_modifier","title":"鼠标组合","keys":["左键+C/V/D"],"summary":"复制粘贴删除","scope":"全局","group":"全局"},
      {"id":"local_ocr","title":"本地 OCR","keys":["⌘ S"],"summary":"框选识别文字","scope":"全局","group":"全局"},
      {"id":"chrome_recent_tabs","title":"Chrome 最近标签","keys":["⌘ 3"],"summary":"返回最近标签","scope":"Chrome","group":"浏览器","dependency":"Google Chrome"},
      {"id":"chrome_mention","title":"Codex Chrome 提及","keys":["⌘ ⇧ 2","⌘ ⇧ 3"],"summary":"插入 @chrome","scope":"Codex","group":"浏览器","dependency":"Codex"},
      {"id":"codex_toggle","title":"Codex 切换","keys":["⌘ 2"],"summary":"显示隐藏 Codex","scope":"全局","group":"应用","dependency":"Codex"},
      {"id":"mailmaster_toggle","title":"邮箱大师","keys":["⌘ 5","⌘ 小键盘5"],"summary":"显示隐藏邮箱大师","scope":"全局","group":"应用","dependency":"邮箱大师"},
      {"id":"chatgpt_classic","title":"ChatGPT Classic","keys":["⌘ `","⌘ §","⌃ ⌥ 1–4"],"summary":"窗口和模型快捷键","scope":"ChatGPT Classic","group":"应用","dependency":"ChatGPT Classic"},
      {"id":"whatsapp_command_w","title":"WhatsApp 保留窗口","keys":["⌘ W"],"summary":"隐藏并保留 PWA 窗口","scope":"WhatsApp Edge PWA","group":"应用","dependency":"WhatsApp Edge PWA"},
      {"id":"btt_bridge","title":"BTT 截图桥接","keys":["自动"],"summary":"释放截图拖动状态","scope":"可选集成","group":"集成","dependency":"BetterTouchTool"}
    ]
    """
}
