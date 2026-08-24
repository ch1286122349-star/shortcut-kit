import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var model: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ShortcutKit").font(.title2.bold())
                    Text("你的快捷键，可开关、可修改、可恢复默认").foregroundStyle(.secondary)
                }
                Spacer()
                if model.isBusy { ProgressView().controlSize(.small) }
            }
            .padding(20)
            if let message = model.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(message)
                    Spacer()
                    Button("关闭") { model.errorMessage = nil }.buttonStyle(.plain)
                }
                .foregroundStyle(.orange).padding(.horizontal, 20).padding(.bottom, 10)
            }
            Divider()
            TabView {
                ShortcutListView(model: model).tabItem { Label("快捷键", systemImage: "keyboard") }
                DependenciesView(model: model).tabItem { Label("权限与依赖", systemImage: "checkmark.shield") }
                DiagnosticsView(model: model).tabItem { Label("诊断", systemImage: "stethoscope") }
            }
            .padding(12)
        }
    }
}
