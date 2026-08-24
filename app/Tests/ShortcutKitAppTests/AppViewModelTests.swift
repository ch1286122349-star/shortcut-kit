import XCTest
@testable import ShortcutKitApp
@testable import ShortcutKitCore

@MainActor
final class AppViewModelTests: XCTestCase {
    func testRecorderUsesPhysicalDigitWhenShiftedCharacterIsPercent() {
        XCTAssertEqual(
            HotkeyRecorderView.keyName(keyCode: 23, charactersIgnoringModifiers: "%"),
            "5"
        )
    }

    func testRowsSeparateRequestedPreferenceFromRuntimeFailure() async throws {
        let action = ShortcutActionDefinition(
            id: "codex_toggle",
            title: "显示或隐藏",
            defaultHotkey: try HotkeySpec(modifiers: ["cmd"], key: "2")
        )
        let definition = ShortcutDefinition(
            id: "codex_toggle",
            title: "Codex 切换",
            actions: [action],
            summary: "显示或隐藏 Codex",
            scope: "全局",
            group: "应用",
            dependency: "Codex"
        )
        let report = RuntimeReport(
            ok: true,
            version: "0.2.0",
            modules: ["codex_toggle": .init(state: "skipped", reason: "Codex is not installed")]
        )
        let store = ViewModelConfigStore(config: .init(modules: ["codex_toggle": true]))
        let bridge = ViewModelBridge(report: report)
        let controller = AppController(
            configStore: store,
            bridge: bridge,
            defaultHotkeys: ["codex_toggle": try XCTUnwrap(action.defaultHotkey)]
        )
        let model = AppViewModel(controller: controller, catalog: [definition])

        await model.refresh()

        let row = try XCTUnwrap(model.rows.first)
        XCTAssertTrue(row.requestedEnabled)
        XCTAssertEqual(row.badge, .dependencyUnavailable)
        XCTAssertEqual(row.actions.first?.displayText, "⌘ 2")
    }

    func testCustomHotkeyDisplayUsesOverrideAndMarksResetAvailable() async throws {
        let defaultSpec = try HotkeySpec(modifiers: ["cmd"], key: "r")
        let customSpec = try HotkeySpec(modifiers: ["ctrl", "shift"], key: "5")
        let definition = ShortcutDefinition(
            id: "window_screenshot",
            title: "窗口截图",
            actions: [.init(id: "window_screenshot", title: "截取窗口", defaultHotkey: defaultSpec)],
            summary: "截图",
            scope: "全局",
            group: "全局"
        )
        let report = RuntimeReport(
            ok: true,
            version: "0.2.0",
            modules: ["window_screenshot": .init(state: "enabled")],
            actions: ["window_screenshot": customSpec.canonicalString]
        )
        let controller = AppController(
            configStore: ViewModelConfigStore(config: .init(hotkeys: ["window_screenshot": customSpec])),
            bridge: ViewModelBridge(report: report),
            defaultHotkeys: ["window_screenshot": defaultSpec]
        )
        let model = AppViewModel(controller: controller, catalog: [definition])

        await model.refresh()

        let action = try XCTUnwrap(model.rows.first?.actions.first)
        XCTAssertEqual(action.displayText, "⌃ ⇧ 5")
        XCTAssertTrue(action.isOverridden)
    }
}

private final class ViewModelConfigStore: ConfigStoring, @unchecked Sendable {
    private var config: AppConfiguration
    private var previous: AppConfiguration?
    init(config: AppConfiguration) { self.config = config }
    func load() throws -> AppConfiguration { config }
    func save(_ config: AppConfiguration) throws { previous = self.config; self.config = config }
    func restorePrevious() throws {
        guard let previous else { throw ConfigStoreError.previousConfigurationUnavailable }
        config = previous
    }
}

private actor ViewModelBridge: HammerspoonBridging {
    let report: RuntimeReport
    init(report: RuntimeReport) { self.report = report }
    func status() async throws -> RuntimeReport { report }
    func reloadAndWait(expected: [String: Bool], timeout: TimeInterval) async throws -> RuntimeReport { report }
}
