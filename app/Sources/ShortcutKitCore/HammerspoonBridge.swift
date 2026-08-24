import Foundation

public enum HammerspoonBridgeError: Error, Equatable {
    case commandFailed
    case invalidStatus
    case statusTimeout
}

public protocol HammerspoonBridging: Sendable {
    func status() async throws -> RuntimeReport
    func reloadAndWait(expected: [String: Bool], timeout: TimeInterval) async throws -> RuntimeReport
    func reloadAndWait(
        expectedModules: [String: Bool],
        expectedHotkeys: [String: HotkeySpec],
        timeout: TimeInterval
    ) async throws -> RuntimeReport
    func checkConflict(spec: HotkeySpec, excludingActionID: String) async throws -> HotkeyConflict?
    func setRecordingMode(_ active: Bool) async throws
}

public extension HammerspoonBridging {
    func reloadAndWait(
        expectedModules: [String: Bool],
        expectedHotkeys: [String: HotkeySpec],
        timeout: TimeInterval
    ) async throws -> RuntimeReport {
        let report = try await reloadAndWait(expected: expectedModules, timeout: timeout)
        guard expectedHotkeys.allSatisfy({ report.actions[$0.key] == $0.value.canonicalString }) else {
            throw HammerspoonBridgeError.statusTimeout
        }
        return report
    }

    func checkConflict(spec: HotkeySpec, excludingActionID: String) async throws -> HotkeyConflict? {
        nil
    }

    func setRecordingMode(_ active: Bool) async throws {}
}

public struct HammerspoonBridge: HammerspoonBridging, Sendable {
    private let runner: any ProcessRunning
    public let executableURL: URL
    public let pollIntervalNanoseconds: UInt64
    public let maximumPollAttempts: Int

    public init(
        runner: any ProcessRunning = ProcessRunner(),
        executableURL: URL = URL(fileURLWithPath: "/opt/homebrew/bin/hs"),
        pollIntervalNanoseconds: UInt64 = 250_000_000,
        maximumPollAttempts: Int = 20
    ) {
        self.runner = runner
        self.executableURL = executableURL
        self.pollIntervalNanoseconds = pollIntervalNanoseconds
        self.maximumPollAttempts = maximumPollAttempts
    }

    public func status() async throws -> RuntimeReport {
        let result = try await runner.run(
            executable: resolvedExecutableURL(),
            arguments: ["-c", Self.statusCommand],
            timeout: 3
        )
        guard result.exitCode == 0 else { throw HammerspoonBridgeError.commandFailed }
        return try decodeReport(result.stdout)
    }

    public func checkConflict(
        spec: HotkeySpec,
        excludingActionID: String
    ) async throws -> HotkeyConflict? {
        let request = ConflictRequest(
            modifiers: spec.modifiers,
            key: spec.key,
            excludingActionID: excludingActionID
        )
        let encoded = try JSONEncoder().encode(request).base64EncodedString()
        let command = """
        local request=hs.json.decode(hs.base64.decode("\(encoded)")); return hs.json.encode(spoon.ShortcutKit:checkHotkeyConflict(request.modifiers,request.key,request.excludingActionID))
        """
        let result = try await runner.run(
            executable: resolvedExecutableURL(),
            arguments: ["-c", command],
            timeout: 3
        )
        guard result.exitCode == 0 else { throw HammerspoonBridgeError.commandFailed }
        guard let data = lastJSONData(result.stdout),
              let response = try? JSONDecoder().decode(ConflictResponse.self, from: data) else {
            throw HammerspoonBridgeError.invalidStatus
        }
        switch response.kind {
        case "none": return nil
        case "shortcutKit":
            guard let actionID = response.actionID else { throw HammerspoonBridgeError.invalidStatus }
            return .shortcutKit(actionID: actionID)
        case "hammerspoon": return .hammerspoon(description: response.description ?? "Hammerspoon")
        case "system": return .system(description: response.description ?? "macOS system shortcut")
        default: throw HammerspoonBridgeError.invalidStatus
        }
    }

    public func setRecordingMode(_ active: Bool) async throws {
        let command = "return spoon.ShortcutKit:setRecordingMode(\(active ? "true" : "false"))"
        let result = try await runner.run(
            executable: resolvedExecutableURL(),
            arguments: ["-c", command],
            timeout: 3
        )
        guard result.exitCode == 0 else { throw HammerspoonBridgeError.commandFailed }
    }

    public func reloadAndWait(
        expected: [String: Bool],
        timeout: TimeInterval = 5
    ) async throws -> RuntimeReport {
        try await reloadAndWait(expectedModules: expected, expectedHotkeys: [:], timeout: timeout)
    }

    public func reloadAndWait(
        expectedModules: [String: Bool],
        expectedHotkeys: [String: HotkeySpec],
        timeout: TimeInterval = 5
    ) async throws -> RuntimeReport {
        _ = try? await runner.run(
            executable: resolvedExecutableURL(),
            arguments: ["-c", "hs.reload()"],
            timeout: min(timeout, 3)
        )

        let attemptsFromTimeout = pollIntervalNanoseconds == 0
            ? maximumPollAttempts
            : max(1, Int((timeout * 1_000_000_000) / Double(pollIntervalNanoseconds)))
        let attempts = min(maximumPollAttempts, attemptsFromTimeout)
        for _ in 0..<attempts {
            if pollIntervalNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
            }
            guard let report = try? await status() else { continue }
            if report.ok
                && Self.matches(report: report, expected: expectedModules)
                && expectedHotkeys.allSatisfy({ report.actions[$0.key] == $0.value.canonicalString }) {
                return report
            }
        }
        throw HammerspoonBridgeError.statusTimeout
    }

    private func decodeReport(_ output: String) throws -> RuntimeReport {
        guard let data = lastJSONData(output) else {
            throw HammerspoonBridgeError.invalidStatus
        }
        do {
            return try JSONDecoder().decode(RuntimeReport.self, from: data)
        } catch {
            throw HammerspoonBridgeError.invalidStatus
        }
    }

    private func lastJSONData(_ output: String) -> Data? {
        let line = output
            .split(whereSeparator: \Character.isNewline)
            .map(String.init)
            .last(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("{") })
        return line?.data(using: .utf8)
    }

    private static func matches(report: RuntimeReport, expected: [String: Bool]) -> Bool {
        expected.allSatisfy { id, requestedEnabled in
            guard let state = report.modules[id]?.state else { return false }
            if requestedEnabled { return state == "enabled" || state == "skipped" }
            return state == "disabled"
        }
    }

    private static let statusCommand = """
    return hs.json.encode(shortcutKitAppStatus and shortcutKitAppStatus() or {ok=false,version=\"unknown\",modules={},configError=\"missing\"})
    """

    private func resolvedExecutableURL(fileManager: FileManager = .default) -> URL {
        if fileManager.isExecutableFile(atPath: executableURL.path) { return executableURL }
        let home = fileManager.homeDirectoryForCurrentUser.path
        let candidates = [
            "/opt/homebrew/bin/hs",
            "/usr/local/bin/hs",
            "/Applications/Hammerspoon.app/Contents/Frameworks/hs",
            "\(home)/Applications/Hammerspoon.app/Contents/Frameworks/hs",
        ]
        return candidates.map(URL.init(fileURLWithPath:))
            .first(where: { fileManager.isExecutableFile(atPath: $0.path) })
            ?? executableURL
    }
}

private struct ConflictRequest: Encodable {
    let modifiers: [String]
    let key: String
    let excludingActionID: String
}

private struct ConflictResponse: Decodable {
    let kind: String
    let actionID: String?
    let description: String?
    let systemCheckAvailable: Bool
}
