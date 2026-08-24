import Foundation

public enum ConfigStoreError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
    case previousConfigurationUnavailable
}

public protocol ConfigStoring: Sendable {
    func load() throws -> AppConfiguration
    func save(_ config: AppConfiguration) throws
    func restorePrevious() throws
}

public struct ConfigStore: ConfigStoring, Sendable {
    public let directory: URL
    public let configURL: URL
    public let previousURL: URL

    public init(directory: URL) {
        self.directory = directory
        self.configURL = directory.appendingPathComponent("config.json", isDirectory: false)
        self.previousURL = directory.appendingPathComponent("config.previous.json", isDirectory: false)
    }

    public static func defaultStore(fileManager: FileManager = .default) -> ConfigStore {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return ConfigStore(directory: base.appendingPathComponent("ShortcutKit", isDirectory: true))
    }

    public func load() throws -> AppConfiguration {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return AppConfiguration()
        }
        let config = try JSONDecoder().decode(AppConfiguration.self, from: Data(contentsOf: configURL))
        guard config.schemaVersion == AppConfiguration.currentSchemaVersion else {
            throw ConfigStoreError.unsupportedSchemaVersion(config.schemaVersion)
        }
        return config
    }

    public func save(_ config: AppConfiguration) throws {
        guard config.schemaVersion == AppConfiguration.currentSchemaVersion else {
            throw ConfigStoreError.unsupportedSchemaVersion(config.schemaVersion)
        }
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: configURL.path) {
            let previousTemporary = directory.appendingPathComponent(".previous-\(UUID().uuidString).tmp")
            try fileManager.copyItem(at: configURL, to: previousTemporary)
            try replace(previousURL, with: previousTemporary, fileManager: fileManager)
        }

        let data = try JSONEncoder.shortcutKit.encode(config)
        let temporary = directory.appendingPathComponent(".config-\(UUID().uuidString).tmp")
        try data.write(to: temporary, options: .withoutOverwriting)
        try replace(configURL, with: temporary, fileManager: fileManager)
    }

    public func restorePrevious() throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: previousURL.path) else {
            throw ConfigStoreError.previousConfigurationUnavailable
        }
        let temporary = directory.appendingPathComponent(".restore-\(UUID().uuidString).tmp")
        try fileManager.copyItem(at: previousURL, to: temporary)
        try replace(configURL, with: temporary, fileManager: fileManager)
    }

    private func replace(_ destination: URL, with temporary: URL, fileManager: FileManager) throws {
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
    }
}

private extension JSONEncoder {
    static var shortcutKit: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
