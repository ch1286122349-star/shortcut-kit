import Foundation

public struct ProcessResult: Equatable, Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public enum ProcessRunnerError: Error, Equatable {
    case timedOut
    case launchFailed
}

public protocol ProcessRunning: Sendable {
    func run(executable: URL, arguments: [String], timeout: TimeInterval) async throws -> ProcessResult
}
