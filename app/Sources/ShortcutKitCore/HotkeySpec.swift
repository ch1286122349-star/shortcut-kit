import Foundation

public enum HotkeyValidationError: Error, Equatable, Sendable {
    case emptyKey
    case invalidModifier(String)
    case modifierRequired
}

public struct HotkeySpec: Codable, Equatable, Hashable, Sendable {
    public let modifiers: [String]
    public let key: String

    private static let modifierOrder = ["cmd", "ctrl", "alt", "shift", "fn"]
    private static let modifierAliases = [
        "cmd": "cmd", "command": "cmd", "⌘": "cmd",
        "ctrl": "ctrl", "control": "ctrl", "⌃": "ctrl",
        "alt": "alt", "option": "alt", "opt": "alt", "⌥": "alt",
        "shift": "shift", "⇧": "shift",
        "fn": "fn", "function": "fn",
    ]

    public init(modifiers: [String], key: String) throws {
        var normalizedModifiers = Set<String>()
        for value in modifiers {
            let alias = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard let normalized = Self.modifierAliases[alias] else {
                throw HotkeyValidationError.invalidModifier(value)
            }
            normalizedModifiers.insert(normalized)
        }

        let normalizedKey = Self.normalizeKey(key)
        guard !normalizedKey.isEmpty else { throw HotkeyValidationError.emptyKey }
        if normalizedModifiers.isEmpty, Self.requiresModifier(normalizedKey) {
            throw HotkeyValidationError.modifierRequired
        }

        self.modifiers = Self.modifierOrder.filter(normalizedModifiers.contains)
        self.key = normalizedKey
    }

    public var displayText: String {
        let modifierSymbols = modifiers.compactMap { modifier in
            ["cmd": "⌘", "ctrl": "⌃", "alt": "⌥", "shift": "⇧", "fn": "fn"][modifier]
        }
        let displayKey: String
        switch key {
        case "space": displayKey = "Space"
        case "return": displayKey = "Return"
        case "escape": displayKey = "Esc"
        case "delete": displayKey = "Delete"
        default: displayKey = key.uppercased()
        }
        return (modifierSymbols + [displayKey]).joined(separator: " ")
    }

    public var canonicalString: String {
        (modifiers + [key]).joined(separator: "+")
    }

    private enum CodingKeys: String, CodingKey { case modifiers, key }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let modifiers = try values.decode([String].self, forKey: .modifiers)
        let key = try values.decode(String.self, forKey: .key)
        do {
            try self.init(modifiers: modifiers, key: key)
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .key,
                in: values,
                debugDescription: "Invalid hotkey: \(error)"
            )
        }
    }

    private static func normalizeKey(_ key: String) -> String {
        let value = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch value {
        case " ", "spacebar": return "space"
        case "enter": return "return"
        case "esc": return "escape"
        case "backspace": return "delete"
        default: return value
        }
    }

    private static func requiresModifier(_ key: String) -> Bool {
        if key.range(of: #"^f([1-9]|1[0-9]|2[0-4])$"#, options: .regularExpression) != nil {
            return false
        }
        return key.count == 1 && key.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0)
        }
    }
}

public enum HotkeyConflict: Equatable, Sendable {
    case shortcutKit(actionID: String)
    case hammerspoon(description: String)
    case system(description: String)
}

public enum HotkeyConflictValidator {
    public static func duplicate(
        proposed: HotkeySpec,
        actionID: String,
        activeBindings: [String: HotkeySpec]
    ) -> HotkeyConflict? {
        activeBindings
            .filter { $0.key != actionID && $0.value == proposed }
            .map(\.key)
            .sorted()
            .first
            .map { .shortcutKit(actionID: $0) }
    }
}
