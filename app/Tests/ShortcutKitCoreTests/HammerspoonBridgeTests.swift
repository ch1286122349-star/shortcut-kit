import Foundation
import XCTest
@testable import ShortcutKitCore

final class HammerspoonBridgeTests: XCTestCase {
    func testStatusDecodesJSONReport() async throws {
        let runner = FakeProcessRunner(results: [
            ProcessResult(exitCode: 0, stdout: Self.runtimeJSON, stderr: ""),
        ])
        let bridge = HammerspoonBridge(
            runner: runner,
            executableURL: URL(fileURLWithPath: "/fake/hs"),
            pollIntervalNanoseconds: 0
        )

        let report = try await bridge.status()

        XCTAssertTrue(report.ok)
        XCTAssertEqual(report.modules["local_ocr"]?.state, "enabled")
    }

    func testReloadIgnoresExpectedPortInvalidationAndWaitsForStatus() async throws {
        let runner = FakeProcessRunner(results: [
            ProcessResult(exitCode: 69, stdout: "", stderr: "message port was invalidated"),
            ProcessResult(exitCode: 69, stdout: "", stderr: "can't access Hammerspoon message port"),
            ProcessResult(exitCode: 0, stdout: Self.runtimeJSON, stderr: ""),
        ])
        let bridge = HammerspoonBridge(
            runner: runner,
            executableURL: URL(fileURLWithPath: "/fake/hs"),
            pollIntervalNanoseconds: 0
        )

        let report = try await bridge.reloadAndWait(
            expected: ["local_ocr": true],
            timeout: 1
        )

        XCTAssertTrue(report.ok)
        XCTAssertEqual(report.modules["local_ocr"]?.state, "enabled")
        let callCount = await runner.callCount
        XCTAssertEqual(callCount, 3)
    }

    func testReloadRejectsMismatchedModuleState() async throws {
        let runner = FakeProcessRunner(results: [
            ProcessResult(exitCode: 0, stdout: "", stderr: ""),
            ProcessResult(exitCode: 0, stdout: Self.runtimeJSON, stderr: ""),
        ])
        let bridge = HammerspoonBridge(
            runner: runner,
            executableURL: URL(fileURLWithPath: "/fake/hs"),
            pollIntervalNanoseconds: 0,
            maximumPollAttempts: 1
        )

        do {
            _ = try await bridge.reloadAndWait(expected: ["local_ocr": false], timeout: 1)
            XCTFail("Expected module state mismatch")
        } catch {
            XCTAssertEqual(error as? HammerspoonBridgeError, .statusTimeout)
        }
    }

    func testConflictCheckDecodesShortcutKitAndSystemSources() async throws {
        let shortcutRunner = FakeProcessRunner(results: [
            ProcessResult(
                exitCode: 0,
                stdout: #"{"kind":"shortcutKit","actionID":"local_ocr","description":"local_ocr","systemCheckAvailable":true}"#,
                stderr: ""
            ),
        ])
        let shortcutBridge = HammerspoonBridge(runner: shortcutRunner, executableURL: URL(fileURLWithPath: "/fake/hs"))
        let spec = try HotkeySpec(modifiers: ["cmd"], key: "s")
        let shortcutConflict = try await shortcutBridge.checkConflict(
            spec: spec,
            excludingActionID: "window_screenshot"
        )
        XCTAssertEqual(shortcutConflict, .shortcutKit(actionID: "local_ocr"))

        let systemRunner = FakeProcessRunner(results: [
            ProcessResult(
                exitCode: 0,
                stdout: #"{"kind":"system","description":"macOS system shortcut","systemCheckAvailable":true}"#,
                stderr: ""
            ),
        ])
        let systemBridge = HammerspoonBridge(runner: systemRunner, executableURL: URL(fileURLWithPath: "/fake/hs"))
        let systemConflict = try await systemBridge.checkConflict(
            spec: spec,
            excludingActionID: "window_screenshot"
        )
        XCTAssertEqual(systemConflict, .system(description: "macOS system shortcut"))
    }

    private static let runtimeJSON = """
    {"ok":true,"version":"0.2.0","modules":{"local_ocr":{"state":"enabled"}}}
    """
}

private actor FakeProcessRunner: ProcessRunning {
    private var results: [ProcessResult]
    private(set) var callCount = 0

    init(results: [ProcessResult]) {
        self.results = results
    }

    func run(executable: URL, arguments: [String], timeout: TimeInterval) async throws -> ProcessResult {
        callCount += 1
        guard !results.isEmpty else { throw ProcessRunnerError.timedOut }
        return results.removeFirst()
    }
}
