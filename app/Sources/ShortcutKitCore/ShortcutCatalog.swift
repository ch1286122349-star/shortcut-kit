import Foundation

public enum ShortcutCatalogError: Error, Equatable {
    case duplicateID(String)
    case emptyCatalog
}

public enum ShortcutCatalog {
    public static func load(data: Data) throws -> [ShortcutDefinition] {
        let definitions = try JSONDecoder().decode([ShortcutDefinition].self, from: data)
        guard !definitions.isEmpty else { throw ShortcutCatalogError.emptyCatalog }

        var seen = Set<String>()
        for definition in definitions {
            guard seen.insert(definition.id).inserted else {
                throw ShortcutCatalogError.duplicateID(definition.id)
            }
        }
        return definitions
    }
}
