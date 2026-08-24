import Foundation

public struct ShortcutActionDefinition: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let defaultHotkey: HotkeySpec?

    public init(id: String, title: String, defaultHotkey: HotkeySpec? = nil) {
        self.id = id
        self.title = title
        self.defaultHotkey = defaultHotkey
    }

    public var isEditable: Bool { defaultHotkey != nil }
    public var defaultDisplayText: String { defaultHotkey?.displayText ?? title }
}

public struct ShortcutDefinition: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let actions: [ShortcutActionDefinition]
    public let summary: String
    public let scope: String
    public let group: String
    public let dependency: String?

    public init(
        id: String,
        title: String,
        actions: [ShortcutActionDefinition],
        summary: String,
        scope: String,
        group: String,
        dependency: String? = nil
    ) {
        self.id = id
        self.title = title
        self.actions = actions
        self.summary = summary
        self.scope = scope
        self.group = group
        self.dependency = dependency
    }

    public var keys: [String] { actions.map(\.defaultDisplayText) }
}
