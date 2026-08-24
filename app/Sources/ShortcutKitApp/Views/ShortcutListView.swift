import SwiftUI

struct ShortcutListView: View {
    @ObservedObject var model: AppViewModel

    private var groups: [String] {
        model.rows.map(\.group).reduce(into: []) { result, group in
            if !result.contains(group) { result.append(group) }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Toggle("全部启用", isOn: Binding(
                    get: { model.allRequestedEnabled },
                    set: { enabled in Task { await model.setAll(enabled: enabled) } }
                )).toggleStyle(.switch)
                Spacer()
                Button("全部恢复默认按键") { Task { await model.resetAllHotkeys() } }
                Button { Task { await model.refresh() } } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
            }
            .disabled(model.isBusy)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(groups, id: \.self) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group).font(.headline).foregroundStyle(.secondary)
                            ForEach(model.rows.filter { $0.group == group }) { row in
                                ShortcutRowView(model: model, row: row)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
