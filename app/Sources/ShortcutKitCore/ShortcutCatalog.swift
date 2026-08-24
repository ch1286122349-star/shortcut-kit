import Foundation

public enum ShortcutCatalogError: Error, Equatable {
    case duplicateID(String)
    case duplicateActionID(String)
    case duplicateDefaultHotkey(String, String)
    case emptyActions(String)
    case emptyCatalog
}

public enum ShortcutCatalog {
    public static func load(data: Data) throws -> [ShortcutDefinition] {
        let definitions = try JSONDecoder().decode([ShortcutDefinition].self, from: data)
        guard !definitions.isEmpty else { throw ShortcutCatalogError.emptyCatalog }

        var seen = Set<String>()
        var seenActions = Set<String>()
        var defaultBindings: [HotkeySpec: String] = [:]
        for definition in definitions {
            guard seen.insert(definition.id).inserted else {
                throw ShortcutCatalogError.duplicateID(definition.id)
            }
            guard !definition.actions.isEmpty else {
                throw ShortcutCatalogError.emptyActions(definition.id)
            }
            for action in definition.actions {
                guard seenActions.insert(action.id).inserted else {
                    throw ShortcutCatalogError.duplicateActionID(action.id)
                }
                guard let hotkey = action.defaultHotkey else { continue }
                if let existing = defaultBindings[hotkey] {
                    throw ShortcutCatalogError.duplicateDefaultHotkey(existing, action.id)
                }
                defaultBindings[hotkey] = action.id
            }
        }
        return definitions
    }
}
