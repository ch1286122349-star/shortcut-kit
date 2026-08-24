import Foundation
import XCTest
@testable import ShortcutKitCore

@MainActor
final class AppControllerTests: XCTestCase {
    func testSuccessfulTogglePersistsAndPublishesRuntimeReport() async throws {
        let store = FakeConfigStore(config: .init(modules: ["local_ocr": true]))
        let report = RuntimeReport(
            ok: true,
            version: "0.2.0",
            modules: ["local_ocr": .init(state: "disabled")]
        )
        let bridge = FakeHammerspoonBridge(results: [.success(report)])
        let controller = AppController(configStore: store, bridge: bridge)

        await controller.setModule(id: "local_ocr", enabled: false)

        XCTAssertEqual(try store.load().modules["local_ocr"], false)
        XCTAssertEqual(controller.runtimeReport, report)
        XCTAssertNil(controller.error)
    }

    func testFailedReloadRestoresPreviousConfigAndRuntime() async throws {
        let originalReport = RuntimeReport(
            ok: true,
            version: "0.2.0",
            modules: ["local_ocr": .init(state: "enabled")]
        )
        let store = FakeConfigStore(config: .init(modules: ["local_ocr": true]))
        let bridge = FakeHammerspoonBridge(results: [
            .failure(HammerspoonBridgeError.statusTimeout),
            .success(originalReport),
        ])
        let controller = AppController(configStore: store, bridge: bridge)

        await controller.setModule(id: "local_ocr", enabled: false)

        XCTAssertEqual(try store.load().modules["local_ocr"], true)
        XCTAssertEqual(controller.runtimeReport, originalReport)
        XCTAssertEqual(controller.error, .reloadRolledBack)
        XCTAssertEqual(store.restoreCallCount, 0)
    }

    func testMasterTogglePreservesUnknownModuleWhileSettingCatalogIDs() async throws {
        let store = FakeConfigStore(config: .init(modules: ["future_module": true]))
        let report = RuntimeReport(
            ok: true,
            version: "0.2.0",
            modules: [
                "local_ocr": .init(state: "disabled"),
                "window_screenshot": .init(state: "disabled"),
            ]
        )
        let bridge = FakeHammerspoonBridge(results: [.success(report)])
        let controller = AppController(configStore: store, bridge: bridge)

        await controller.setAll(ids: ["local_ocr", "window_screenshot"], enabled: false)

        let saved = try store.load()
        XCTAssertEqual(saved.modules["future_module"], true)
        XCTAssertEqual(saved.modules["local_ocr"], false)
        XCTAssertEqual(saved.modules["window_screenshot"], false)
    }

    func testCustomHotkeyPersistsAndRequiresRuntimeActionReadback() async throws {
        let old = try HotkeySpec(modifiers: ["cmd"], key: "r")
        let replacement = try HotkeySpec(modifiers: ["ctrl", "shift"], key: "5")
        let store = FakeConfigStore(config: .init())
        let report = RuntimeReport(
            ok: true,
            version: "0.2.0",
            modules: [:],
            actions: ["window_screenshot": replacement.canonicalString]
        )
        let bridge = FakeHammerspoonBridge(results: [.success(report)])
        let controller = AppController(
            configStore: store,
            bridge: bridge,
            defaultHotkeys: ["window_screenshot": old]
        )

        await controller.setHotkey(actionID: "window_screenshot", spec: replacement)

        XCTAssertEqual(try store.load().hotkeys["window_screenshot"], replacement)
        XCTAssertNil(controller.error)
    }

    func testDuplicateShortcutKitHotkeyIsBlockedBeforeSave() async throws {
        let screenshot = try HotkeySpec(modifiers: ["cmd"], key: "r")
        let ocr = try HotkeySpec(modifiers: ["cmd"], key: "s")
        let store = FakeConfigStore(config: .init())
        let controller = AppController(
            configStore: store,
            bridge: FakeHammerspoonBridge(results: []),
            defaultHotkeys: ["window_screenshot": screenshot, "local_ocr": ocr]
        )

        await controller.setHotkey(actionID: "window_screenshot", spec: ocr)

        XCTAssertTrue(try store.load().hotkeys.isEmpty)
        XCTAssertEqual(controller.error, .hotkeyConflict(.shortcutKit(actionID: "local_ocr")))
    }

    func testResetAllHotkeysPreservesUnknownFutureOverride() async throws {
        let screenshot = try HotkeySpec(modifiers: ["ctrl"], key: "7")
        let ocr = try HotkeySpec(modifiers: ["ctrl"], key: "8")
        let future = try HotkeySpec(modifiers: ["ctrl"], key: "9")
        let defaults = [
            "window_screenshot": try HotkeySpec(modifiers: ["cmd"], key: "r"),
            "local_ocr": try HotkeySpec(modifiers: ["cmd"], key: "s"),
        ]
        let defaultActions = defaults.mapValues(\.canonicalString)
        let store = FakeConfigStore(config: .init(hotkeys: [
            "window_screenshot": screenshot,
            "local_ocr": ocr,
            "future_action": future,
        ]))
        let report = RuntimeReport(ok: true, version: "0.2.0", modules: [:], actions: defaultActions)
        let controller = AppController(
            configStore: store,
            bridge: FakeHammerspoonBridge(results: [.success(report)]),
            defaultHotkeys: defaults
        )

        await controller.resetAllHotkeys()

        let saved = try store.load()
        XCTAssertNil(saved.hotkeys["window_screenshot"])
        XCTAssertNil(saved.hotkeys["local_ocr"])
        XCTAssertEqual(saved.hotkeys["future_action"], future)
    }
}

private final class FakeConfigStore: ConfigStoring, @unchecked Sendable {
    private var config: AppConfiguration
    private var previous: AppConfiguration?
    private(set) var restoreCallCount = 0

    init(config: AppConfiguration) { self.config = config }

    func load() throws -> AppConfiguration { config }
    func save(_ config: AppConfiguration) throws {
        previous = self.config
        self.config = config
    }
    func restorePrevious() throws {
        restoreCallCount += 1
        guard let previous else { throw ConfigStoreError.previousConfigurationUnavailable }
        config = previous
    }
}

private actor FakeHammerspoonBridge: HammerspoonBridging {
    private var results: [Result<RuntimeReport, Error>]

    init(results: [Result<RuntimeReport, Error>]) { self.results = results }

    func status() async throws -> RuntimeReport {
        try next().get()
    }

    func reloadAndWait(expected: [String: Bool], timeout: TimeInterval) async throws -> RuntimeReport {
        try next().get()
    }

    private func next() -> Result<RuntimeReport, Error> {
        results.removeFirst()
    }
}
