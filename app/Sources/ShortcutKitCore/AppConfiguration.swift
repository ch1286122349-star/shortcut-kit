import Foundation

public struct AppConfiguration: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var modules: [String: Bool]

    public init(schemaVersion: Int = currentSchemaVersion, modules: [String: Bool] = [:]) {
        self.schemaVersion = schemaVersion
        self.modules = modules
    }

    public mutating func setModule(_ id: String, enabled: Bool) {
        modules[id] = enabled
    }

    public func setting(_ id: String, default defaultValue: Bool = true) -> Bool {
        modules[id] ?? defaultValue
    }
}
