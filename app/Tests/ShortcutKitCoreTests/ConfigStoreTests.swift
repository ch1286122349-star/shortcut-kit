import Foundation
import XCTest
@testable import ShortcutKitCore

final class ConfigStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShortcutKitConfigStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testSaveCreatesRecoverablePreviousConfiguration() throws {
        let store = ConfigStore(directory: directory)
        try store.save(.init(schemaVersion: 1, modules: ["local_ocr": true]))
        try store.save(.init(schemaVersion: 1, modules: ["local_ocr": false]))

        try store.restorePrevious()

        XCTAssertEqual(try store.load().modules["local_ocr"], true)
    }

    func testUpdatingKnownModulePreservesUnknownModule() throws {
        let store = ConfigStore(directory: directory)
        try store.save(.init(schemaVersion: 1, modules: [
            "future_module": true,
            "local_ocr": true,
        ]))

        var config = try store.load()
        config.setModule("local_ocr", enabled: false)
        try store.save(config)

        let reloaded = try store.load()
        XCTAssertEqual(reloaded.modules["future_module"], true)
        XCTAssertEqual(reloaded.modules["local_ocr"], false)
    }

    func testMissingConfigurationReturnsDefaults() throws {
        let store = ConfigStore(directory: directory)
        XCTAssertEqual(try store.load(), AppConfiguration())
    }
}
