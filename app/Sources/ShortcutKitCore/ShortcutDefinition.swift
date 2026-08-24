import Foundation

public struct ShortcutDefinition: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let keys: [String]
    public let summary: String
    public let scope: String
    public let group: String
    public let dependency: String?

    public init(
        id: String,
        title: String,
        keys: [String],
        summary: String,
        scope: String,
        group: String,
        dependency: String? = nil
    ) {
        self.id = id
        self.title = title
        self.keys = keys
        self.summary = summary
        self.scope = scope
        self.group = group
        self.dependency = dependency
    }
}
