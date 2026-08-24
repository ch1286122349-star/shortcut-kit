import Foundation
import XCTest
@testable import ShortcutKitCore

final class InstallationServiceTests: XCTestCase {
    func testInstallUsesBundledScriptAndExplicitArguments() async throws {
        let runner = RecordingProcessRunner()
        let resources = URL(fileURLWithPath: "/Applications/ShortcutKit.app/Contents/Resources")
        let hammerspoonRoot = URL(fileURLWithPath: "/tmp/hammerspoon-fixture")
        let service = InstallationService(
            runner: runner,
            resourceRoot: resources,
            hammerspoonRoot: hammerspoonRoot
        )

        _ = try await service.install(skipHammerspoon: true)

        let invocations = await runner.invocations
        let invocation = try XCTUnwrap(invocations.first)
        XCTAssertEqual(invocation.executable.path, resources.appendingPathComponent("scripts/install.sh").path)
        XCTAssertEqual(invocation.arguments, [
            "--root", hammerspoonRoot.path, "--apply", "--skip-hammerspoon",
        ])
    }

    func testResourceOutsideBundleIsRejected() async throws {
        let service = InstallationService(
            runner: RecordingProcessRunner(),
            resourceRoot: URL(fileURLWithPath: "/Applications/ShortcutKit.app/Contents/Resources"),
            hammerspoonRoot: URL(fileURLWithPath: "/tmp/hammerspoon-fixture"),
            installScript: URL(fileURLWithPath: "/tmp/untrusted-install.sh")
        )

        do {
            _ = try await service.install(skipHammerspoon: true)
            XCTFail("Expected invalid resource path")
        } catch {
            XCTAssertEqual(error as? InstallationServiceError, .invalidResourcePath)
        }
    }
}

private actor RecordingProcessRunner: ProcessRunning {
    struct Invocation: Sendable {
        let executable: URL
        let arguments: [String]
    }

    private(set) var invocations: [Invocation] = []

    func run(executable: URL, arguments: [String], timeout: TimeInterval) async throws -> ProcessResult {
        invocations.append(.init(executable: executable, arguments: arguments))
        return ProcessResult(exitCode: 0, stdout: "ok", stderr: "")
    }
}
