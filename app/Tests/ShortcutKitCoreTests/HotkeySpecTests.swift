import XCTest
@testable import ShortcutKitCore

final class HotkeySpecTests: XCTestCase {
    func testCanonicalizesAliasesModifierOrderAndKeyCase() throws {
        let spec = try HotkeySpec(modifiers: ["Shift", "command", "option"], key: "R")

        XCTAssertEqual(spec.modifiers, ["cmd", "alt", "shift"])
        XCTAssertEqual(spec.key, "r")
        XCTAssertEqual(spec.displayText, "⌘ ⌥ ⇧ R")
    }

    func testRejectsUnmodifiedLetter() {
        XCTAssertThrowsError(try HotkeySpec(modifiers: [], key: "r")) { error in
            XCTAssertEqual(error as? HotkeyValidationError, .modifierRequired)
        }
    }

    func testAllowsUnmodifiedFunctionKey() throws {
        XCTAssertEqual(try HotkeySpec(modifiers: [], key: "f12").displayText, "F12")
    }

    func testRejectsUnknownModifierAndEmptyKey() {
        XCTAssertThrowsError(try HotkeySpec(modifiers: ["hyper"], key: "r"))
        XCTAssertThrowsError(try HotkeySpec(modifiers: ["cmd"], key: "  "))
    }

    func testDuplicateValidatorIgnoresTheActionBeingEdited() throws {
        let screenshot = try HotkeySpec(modifiers: ["cmd"], key: "r")
        let ocr = try HotkeySpec(modifiers: ["cmd"], key: "s")
        let bindings = ["window_screenshot": screenshot, "local_ocr": ocr]

        XCTAssertEqual(
            HotkeyConflictValidator.duplicate(
                proposed: ocr,
                actionID: "window_screenshot",
                activeBindings: bindings
            ),
            .shortcutKit(actionID: "local_ocr")
        )
        XCTAssertNil(
            HotkeyConflictValidator.duplicate(
                proposed: screenshot,
                actionID: "window_screenshot",
                activeBindings: bindings
            )
        )
    }

    func testHotkeySpecRejectsMalformedJSONDuringDecode() {
        let malformed = #"{"modifiers":[],"key":"a"}"#
        XCTAssertThrowsError(try JSONDecoder().decode(HotkeySpec.self, from: Data(malformed.utf8)))
    }
}
