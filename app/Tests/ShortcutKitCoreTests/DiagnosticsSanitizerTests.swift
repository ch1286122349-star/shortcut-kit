import XCTest
@testable import ShortcutKitCore

final class DiagnosticsSanitizerTests: XCTestCase {
    func testSanitizerDropsPathsAndPrivateContent() {
        let input = [
            "appVersion": "0.2.0",
            "runtimeOK": "true",
            "path": "/Users/local/private",
            "clipboard": "secret",
        ]

        XCTAssertEqual(DiagnosticsSanitizer.sanitize(input), [
            "appVersion": "0.2.0",
            "runtimeOK": "true",
        ])
    }
}
