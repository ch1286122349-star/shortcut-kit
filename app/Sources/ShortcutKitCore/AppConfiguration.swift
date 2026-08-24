import Foundation

public struct AppConfiguration: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var modules: [String: Bool]
    public var hotkeys: [String: HotkeySpec]

    public init(
        schemaVersion: Int = currentSchemaVersion,
        modules: [String: Bool] = [:],
        hotkeys: [String: HotkeySpec] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.modules = modules
        self.hotkeys = hotkeys
    }

    public mutating func setModule(_ id: String, enabled: Bool) {
        modules[id] = enabled
    }

    public func setting(_ id: String, default defaultValue: Bool = true) -> Bool {
        modules[id] ?? defaultValue
    }

    public mutating func setHotkey(_ actionID: String, to spec: HotkeySpec) {
        hotkeys[actionID] = spec
    }

    public mutating func resetHotkey(_ actionID: String) {
        hotkeys.removeValue(forKey: actionID)
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, modules, hotkeys }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        modules = try values.decodeIfPresent([String: Bool].self, forKey: .modules) ?? [:]
        hotkeys = try values.decodeIfPresent([String: HotkeySpec].self, forKey: .hotkeys) ?? [:]
    }
}
