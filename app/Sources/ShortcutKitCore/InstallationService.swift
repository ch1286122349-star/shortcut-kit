import Foundation

public enum InstallationServiceError: Error, Equatable, Sendable {
    case invalidResourcePath
    case commandFailed(Int32)
}

public struct InstallationPreview: Equatable, Sendable {
    public let resourceRoot: URL
    public let hammerspoonRoot: URL
}

public struct InstallationService: Sendable {
    private let runner: any ProcessRunning
    public let resourceRoot: URL
    public let hammerspoonRoot: URL
    public let installScript: URL

    public init(
        runner: any ProcessRunning = ProcessRunner(),
        resourceRoot: URL,
        hammerspoonRoot: URL,
        installScript: URL? = nil
    ) {
        self.runner = runner
        self.resourceRoot = resourceRoot.standardizedFileURL
        self.hammerspoonRoot = hammerspoonRoot.standardizedFileURL
        self.installScript = (installScript ?? resourceRoot.appendingPathComponent("scripts/install.sh"))
            .standardizedFileURL
    }

    public func preview() -> InstallationPreview {
        InstallationPreview(resourceRoot: resourceRoot, hammerspoonRoot: hammerspoonRoot)
    }

    @discardableResult
    public func install(skipHammerspoon: Bool = false) async throws -> ProcessResult {
        try validateBundled(installScript)
        var arguments = ["--root", hammerspoonRoot.path, "--apply"]
        if skipHammerspoon { arguments.append("--skip-hammerspoon") }
        let result = try await runner.run(executable: installScript, arguments: arguments, timeout: 120)
        guard result.exitCode == 0 else { throw InstallationServiceError.commandFailed(result.exitCode) }
        return result
    }

    @discardableResult
    public func repair(skipHammerspoon: Bool = false) async throws -> ProcessResult {
        try await install(skipHammerspoon: skipHammerspoon)
    }

    private func validateBundled(_ url: URL) throws {
        let rootPath = resourceRoot.path.hasSuffix("/") ? resourceRoot.path : resourceRoot.path + "/"
        guard url.path.hasPrefix(rootPath) else { throw InstallationServiceError.invalidResourcePath }
    }
}
