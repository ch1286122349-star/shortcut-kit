import XCTest
@testable import ShortcutKitCore

final class ShortcutCatalogTests: XCTestCase {
    func testCatalogDecodesEveryRuntimeModuleExactlyOnce() throws {
        let data = try Data(contentsOf: Self.catalogURL)
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
          {"id":"same","title":"A","actions":[{"id":"a","title":"A"}],"summary":"A","scope":"全局","group":"全局"},
          {"id":"same","title":"B","actions":[{"id":"b","title":"B"}],"summary":"B","scope":"全局","group":"全局"}
        ]
        """
        XCTAssertThrowsError(try ShortcutCatalog.load(data: Data(duplicate.utf8)))
    }

    func testCatalogRejectsDuplicateActionIDsAndDefaultBindings() throws {
        let duplicateAction = """
        [{"id":"one","title":"One","actions":[{"id":"same","title":"A"},{"id":"same","title":"B"}],"summary":"A","scope":"全局","group":"全局"}]
        """
        XCTAssertThrowsError(try ShortcutCatalog.load(data: Data(duplicateAction.utf8)))

        let duplicateBinding = """
        [{"id":"one","title":"One","actions":[
          {"id":"a","title":"A","defaultHotkey":{"modifiers":["cmd"],"key":"r"}},
          {"id":"b","title":"B","defaultHotkey":{"modifiers":["command"],"key":"R"}}
        ],"summary":"A","scope":"全局","group":"全局"}]
        """
        XCTAssertThrowsError(try ShortcutCatalog.load(data: Data(duplicateBinding.utf8)))
    }

    func testEveryEditableActionHasAUniqueValidDefault() throws {
        let definitions = try ShortcutCatalog.load(data: Data(contentsOf: Self.catalogURL))
        let actions = definitions.flatMap(\.actions)
        let editable = actions.filter(\.isEditable)

        XCTAssertFalse(editable.isEmpty)
        XCTAssertEqual(Set(actions.map(\.id)).count, actions.count)
        XCTAssertEqual(Set(editable.compactMap(\.defaultHotkey)).count, editable.count)
        XCTAssertEqual(
            definitions.first(where: { $0.id == "window_screenshot" })?.actions.first?.defaultHotkey,
            try HotkeySpec(modifiers: ["cmd"], key: "r")
        )
    }

    private static let catalogURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/ShortcutKitApp/Resources/shortcut-catalog.json")
}
