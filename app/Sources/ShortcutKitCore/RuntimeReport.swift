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
    public let actions: [String: String]
    public let configError: String?

    public init(
        ok: Bool,
        version: String,
        modules: [String: RuntimeModuleState],
        actions: [String: String] = [:],
        configError: String? = nil
    ) {
        self.ok = ok
        self.version = version
        self.modules = modules
        self.actions = actions
        self.configError = configError
    }

    private enum CodingKeys: String, CodingKey { case ok, version, modules, actions, configError }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        ok = try values.decode(Bool.self, forKey: .ok)
        version = try values.decode(String.self, forKey: .version)
        modules = try values.decode([String: RuntimeModuleState].self, forKey: .modules)
        actions = try values.decodeIfPresent([String: String].self, forKey: .actions) ?? [:]
        configError = try values.decodeIfPresent(String.self, forKey: .configError)
    }
}
