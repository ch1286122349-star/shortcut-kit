import Foundation

public struct RuntimeModuleState: Codable, Equatable, Sendable {
    public let state: String
    public let reason: String?

    public init(state: String, reason: String? = nil) {
        self.state = state
        self.reason = reason
    }
}

public struct RuntimeReport: Codable, Equatable, Sendable {
    public let ok: Bool
    public let version: String
    public let modules: [String: RuntimeModuleState]
    public let configError: String?

    public init(
        ok: Bool,
        version: String,
        modules: [String: RuntimeModuleState],
        configError: String? = nil
    ) {
        self.ok = ok
        self.version = version
        self.modules = modules
        self.configError = configError
    }
}
