import AppKit
import SwiftUI

struct DependenciesView: View {
    @ObservedObject var model: AppViewModel
    @State private var launchAtLogin = LaunchAtLoginService().isEnabled

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                dependency("Hammerspoon", available: model.runtimeReport != nil, detail: "快捷键运行引擎")
                dependency("辅助功能权限", available: model.runtimeReport?.ok == true, detail: "控制应用和监听快捷键")
                dependency("屏幕录制权限", available: model.runtimeReport?.ok == true, detail: "窗口截图和本地 OCR")
                Toggle("登录 Mac 后自动启动 ShortcutKit", isOn: Binding(
                    get: { launchAtLogin },
                    set: { value in
                        do { try LaunchAtLoginService().setEnabled(value); launchAtLogin = value }
                        catch { launchAtLogin = LaunchAtLoginService().isEnabled }
                    }
                ))
                ForEach(["Google Chrome", "Codex", "网易邮箱大师", "ChatGPT Classic", "WhatsApp Edge PWA", "BetterTouchTool"], id: \.self) { name in
                    dependency(name, available: dependencyAvailable(name), detail: "只影响对应快捷键")
                }
                Divider()
                HStack {
                    VStack(alignment: .leading) {
                        Text("安装或修复快捷键运行组件").font(.headline)
                        Text("会安装 Hammerspoon 和本 App 携带的 ShortcutKit，不需要管理员权限。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("安装或修复") { Task { await model.installOrRepair() } }
                        .buttonStyle(.borderedProminent)
                }
                if let message = model.installationMessage {
                    Text(message).foregroundStyle(.green)
                }
                Divider()
                HStack {
                    Button("打开辅助功能设置") { openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") }
                    Button("打开屏幕录制设置") { openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") }
                    Spacer()
                    Button("刷新") { Task { await model.refresh() } }
                }
            }
            .padding(8)
        }
    }

    private func dependency(_ name: String, available: Bool, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: available ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(available ? .green : .orange)
            VStack(alignment: .leading) {
                Text(name).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(available ? "可用" : "需要检查").foregroundStyle(available ? .green : .orange)
        }
        .padding(12).background(.background, in: RoundedRectangle(cornerRadius: 10))
    }

    private func dependencyAvailable(_ name: String) -> Bool {
        let rows = model.rows.filter { $0.dependency == name }
        return !rows.isEmpty && rows.allSatisfy { $0.badge != .dependencyUnavailable }
    }

    private func openSettings(_ value: String) {
        if let url = URL(string: value) { NSWorkspace.shared.open(url) }
    }
}
