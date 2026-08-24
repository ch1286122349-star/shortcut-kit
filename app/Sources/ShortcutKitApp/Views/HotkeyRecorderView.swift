import AppKit
import ShortcutKitCore
import SwiftUI

struct HotkeyRecorderView: View {
    let displayText: String
    let onRecordingChange: (Bool) async -> Void
    let onRecord: (HotkeySpec) -> Void
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
                    stopRecording()
                    onRecord(spec)
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
        let wasRecording = isRecording
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
        if wasRecording { Task { await onRecordingChange(false) } }
    }

    private static func spec(from event: NSEvent) throws -> HotkeySpec {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: [String] = []
        if flags.contains(.command) { modifiers.append("cmd") }
        if flags.contains(.control) { modifiers.append("ctrl") }
        if flags.contains(.option) { modifiers.append("alt") }
        if flags.contains(.shift) { modifiers.append("shift") }
        if flags.contains(.function) { modifiers.append("fn") }
        return try HotkeySpec(modifiers: modifiers, key: keyName(for: event))
    }

    private static func keyName(for event: NSEvent) -> String {
        let special: [UInt16: String] = [
            36: "return", 48: "tab", 49: "space", 51: "delete", 53: "escape",
            123: "left", 124: "right", 125: "down", 126: "up",
            122: "f1", 120: "f2", 99: "f3", 118: "f4", 96: "f5", 97: "f6",
            98: "f7", 100: "f8", 101: "f9", 109: "f10", 103: "f11", 111: "f12",
        ]
        return special[event.keyCode] ?? event.charactersIgnoringModifiers?.lowercased() ?? ""
    }
}
