import Foundation

public enum DiagnosticsSanitizer {
    private static let allowedKeys: Set<String> = [
        "appVersion",
        "spoonVersion",
        "runtimeOK",
        "enabledCount",
        "disabledCount",
        "skippedCount",
        "errorCount",
        "lastReloadOutcome",
    ]

    public static func sanitize(_ input: [String: String]) -> [String: String] {
        input.filter { allowedKeys.contains($0.key) }
    }
}
