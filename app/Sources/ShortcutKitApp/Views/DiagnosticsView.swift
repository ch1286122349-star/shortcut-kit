import AppKit
import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var model: AppViewModel
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox("运行状态") {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 9) {
                    row("App 版本", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "开发版")
                    row("Spoon 版本", model.runtimeReport?.version ?? "未连接")
                    row("运行正常", model.runtimeReport?.ok == true ? "是" : "否")
                    row("已启用", "\(model.enabledCount)")
                    row("需要处理", "\(model.problemCount)")
                }
                .padding(8)
            }
            Text("复制内容只包含版本和状态计数，不包含用户名、文件路径、窗口标题、剪贴板或截图。")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(copied ? "已复制" : "复制安全诊断") { copyDiagnostics() }
                Button("刷新状态") { Task { await model.refresh() } }
                Spacer()
            }
            Spacer()
        }
        .padding(8)
    }

    @ViewBuilder private func row(_ label: String, _ value: String) -> some View {
        GridRow { Text(label).foregroundStyle(.secondary); Text(value).textSelection(.enabled) }
    }

    private func copyDiagnostics() {
        let dictionary: [String: Any] = [
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "development",
            "spoonVersion": model.runtimeReport?.version ?? "unavailable",
            "runtimeOK": model.runtimeReport?.ok == true,
            "enabledCount": model.enabledCount,
            "errorCount": model.problemCount,
        ]
        let data = try? JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted, .sortedKeys])
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}", forType: .string)
        copied = true
    }
}
