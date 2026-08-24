import SwiftUI

struct ShortcutRowView: View {
    @ObservedObject var model: AppViewModel
    let row: ShortcutRowState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(row.title).font(.headline)
                        BadgeView(badge: row.badge)
                    }
                    Text(row.summary).foregroundStyle(.secondary)
                    Text([row.scope, row.dependency].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.tertiary)
                    if let reason = row.reason, row.badge != .enabled, row.badge != .disabled {
                        Text(reason).font(.caption).foregroundStyle(.orange)
                    }
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { row.requestedEnabled },
                    set: { value in Task { await model.setModule(id: row.id, enabled: value) } }
                ))
                .labelsHidden().toggleStyle(.switch)
                .accessibilityLabel("\(row.title)，\(row.requestedEnabled ? "已开启" : "已关闭")")
            }
            VStack(spacing: 7) {
                ForEach(row.actions) { action in
                    HStack(spacing: 10) {
                        Text(action.title).font(.caption).frame(width: 110, alignment: .leading)
                        if action.isEditable {
                            HotkeyRecorderView(
                                displayText: action.displayText,
                                onRecordingChange: { active in await model.setRecordingMode(active) }
                            ) { spec in
                                await model.setHotkey(actionID: action.id, spec: spec)
                            }
                            if action.isOverridden {
                                Button("恢复默认") { Task { await model.resetHotkey(actionID: action.id) } }
                                    .buttonStyle(.link)
                            }
                        } else {
                            Text(action.displayText)
                                .font(.system(.body, design: .rounded).weight(.medium))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator.opacity(0.7)))
        .disabled(model.isBusy)
    }
}

private struct BadgeView: View {
    let badge: ShortcutBadge
    private var color: Color {
        switch badge {
        case .enabled: .green
        case .disabled: .secondary
        case .dependencyUnavailable, .permissionUnavailable: .orange
        case .conflict, .runtimeError: .red
        case .unknown: .blue
        }
    }
    var body: some View {
        Text(badge.title).font(.caption2.weight(.semibold)).foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 3).background(color.opacity(0.12), in: Capsule())
    }
}
