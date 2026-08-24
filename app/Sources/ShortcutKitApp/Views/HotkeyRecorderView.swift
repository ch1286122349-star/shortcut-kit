import AppKit
import ShortcutKitCore
import SwiftUI

struct HotkeyRecorderView: View {
    let displayText: String
    let onRecordingChange: (Bool) async -> Void
    let onRecord: (HotkeySpec) async -> Void
    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var validationMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Button(isRecording ? "请按新组合…" : displayText) { beginRecording() }
                .buttonStyle(.bordered).tint(isRecording ? .accentColor : nil)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .accessibilityLabel("当前快捷键 \(displayText)，点击后录入新组合")
            if let validationMessage {
                Text(validationMessage).font(.caption2).foregroundStyle(.red)
            }
        }
        .onDisappear { stopRecording() }
    }

    private func beginRecording() {
        stopRecording()
        validationMessage = nil
        Task { @MainActor in
            await onRecordingChange(true)
            isRecording = true
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 { stopRecording(); return nil }
                do {
                    let spec = try Self.spec(from: event)
                    let wasRecording = endRecording()
                    Task {
                        if wasRecording { await onRecordingChange(false) }
                        await onRecord(spec)
                    }
                } catch HotkeyValidationError.modifierRequired {
                    validationMessage = "字母和数字至少要配一个修饰键"
                } catch {
                    validationMessage = "这个按键组合暂不支持"
                }
                return nil
            }
        }
    }

    private func stopRecording() {
        let wasRecording = endRecording()
        if wasRecording { Task { await onRecordingChange(false) } }
    }

    @discardableResult
    private func endRecording() -> Bool {
        let wasRecording = isRecording
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
        return wasRecording
    }

    private static func spec(from event: NSEvent) throws -> HotkeySpec {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: [String] = []
        if flags.contains(.command) { modifiers.append("cmd") }
        if flags.contains(.control) { modifiers.append("ctrl") }
        if flags.contains(.option) { modifiers.append("alt") }
        if flags.contains(.shift) { modifiers.append("shift") }
        if flags.contains(.function) { modifiers.append("fn") }
        return try HotkeySpec(
            modifiers: modifiers,
            key: keyName(keyCode: event.keyCode, charactersIgnoringModifiers: event.charactersIgnoringModifiers)
        )
    }

    static func keyName(keyCode: UInt16, charactersIgnoringModifiers: String?) -> String {
        let keyCodes: [UInt16: String] = [
            0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
            8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
            16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 37: "l",
            38: "j", 39: "'", 40: "k", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "n", 46: "m", 47: ".", 50: "`",
            36: "return", 48: "tab", 49: "space", 51: "delete", 53: "escape",
            123: "left", 124: "right", 125: "down", 126: "up",
            122: "f1", 120: "f2", 99: "f3", 118: "f4", 96: "f5", 97: "f6",
            98: "f7", 100: "f8", 101: "f9", 109: "f10", 103: "f11", 111: "f12",
        ]
        return keyCodes[keyCode] ?? charactersIgnoringModifiers?.lowercased() ?? ""
    }
}
