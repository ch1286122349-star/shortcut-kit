import Foundation

public final class ProcessRunner: ProcessRunning, @unchecked Sendable {
    public init() {}

    public func run(
        executable: URL,
        arguments: [String],
        timeout: TimeInterval
    ) async throws -> ProcessResult {
        let box = RunningProcessBox()
        return try await withThrowingTaskGroup(of: ProcessResult.self) { group in
            group.addTask {
                try Self.runSynchronously(
                    executable: executable,
                    arguments: arguments,
                    box: box
                )
            }
            group.addTask {
                let nanoseconds = UInt64(max(0, timeout) * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanoseconds)
                box.terminate()
                throw ProcessRunnerError.timedOut
            }

            guard let first = try await group.next() else {
                throw ProcessRunnerError.launchFailed
            }
            group.cancelAll()
            return first
        }
    }

    private static func runSynchronously(
        executable: URL,
        arguments: [String],
        box: RunningProcessBox
    ) throws -> ProcessResult {
        let process = Process()
        let output = Pipe()
        let error = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = error
        box.set(process)
        do {
            try process.run()
        } catch {
            throw ProcessRunnerError.launchFailed
        }
        process.waitUntilExit()
        let stdout = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return ProcessResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }
}

private final class RunningProcessBox: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?

    func set(_ process: Process) {
        lock.lock()
        self.process = process
        lock.unlock()
    }

    func terminate() {
        lock.lock()
        let active = process
        lock.unlock()
        if active?.isRunning == true { active?.terminate() }
    }
}
