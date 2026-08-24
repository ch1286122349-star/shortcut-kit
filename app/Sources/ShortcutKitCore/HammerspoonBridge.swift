import Foundation

public enum HammerspoonBridgeError: Error, Equatable {
    case commandFailed
    case invalidStatus
    case statusTimeout
}

public struct HammerspoonBridge: Sendable {
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
            executable: executableURL,
            arguments: ["-c", Self.statusCommand],
            timeout: 3
        )
        guard result.exitCode == 0 else { throw HammerspoonBridgeError.commandFailed }
        return try decodeReport(result.stdout)
    }

    public func reloadAndWait(
        expected: [String: Bool],
        timeout: TimeInterval = 5
    ) async throws -> RuntimeReport {
        _ = try? await runner.run(
            executable: executableURL,
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
            if report.ok && Self.matches(report: report, expected: expected) {
                return report
            }
        }
        throw HammerspoonBridgeError.statusTimeout
    }

    private func decodeReport(_ output: String) throws -> RuntimeReport {
        let line = output
            .split(whereSeparator: \Character.isNewline)
            .map(String.init)
            .last(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("{") })
        guard let line, let data = line.data(using: .utf8) else {
            throw HammerspoonBridgeError.invalidStatus
        }
        do {
            return try JSONDecoder().decode(RuntimeReport.self, from: data)
        } catch {
            throw HammerspoonBridgeError.invalidStatus
        }
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
}
