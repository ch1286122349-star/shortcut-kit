import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("打开快捷键设置…") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        }
        Divider()
        Button(model.allRequestedEnabled ? "关闭全部快捷键" : "开启全部快捷键") {
            Task { await model.setAll(enabled: !model.allRequestedEnabled) }
        }
        .disabled(model.isBusy)
        Text("已运行 \(model.enabledCount) 项 · 问题 \(model.problemCount) 项")
        Button("刷新状态") { Task { await model.refresh() } }
        Divider()
        Button("退出 ShortcutKit") { NSApp.terminate(nil) }
    }
}
