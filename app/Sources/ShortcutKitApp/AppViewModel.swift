import AppKit
import Combine
import Foundation
import ShortcutKitCore

enum ShortcutBadge: Equatable {
    case enabled
    case disabled
    case dependencyUnavailable
    case permissionUnavailable
    case conflict
    case runtimeError
    case unknown

    var title: String {
        switch self {
        case .enabled: "已开启"
        case .disabled: "已关闭"
        case .dependencyUnavailable: "依赖不可用"
        case .permissionUnavailable: "权限未开启"
        case .conflict: "快捷键冲突"
        case .runtimeError: "运行错误"
        case .unknown: "等待状态"
        }
    }
}

struct ShortcutActionRowState: Identifiable, Equatable {
    let id: String
    let title: String
    let displayText: String
    let spec: HotkeySpec?
    let isEditable: Bool
    let isOverridden: Bool
}

struct ShortcutRowState: Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String
    let scope: String
    let group: String
    let dependency: String?
    let requestedEnabled: Bool
    let badge: ShortcutBadge
    let reason: String?
    let actions: [ShortcutActionRowState]
}

@MainActor
final class AppViewModel: ObservableObject {
    private let controller: AppController
    let catalog: [ShortcutDefinition]

    @Published private(set) var rows: [ShortcutRowState] = []
    @Published private(set) var runtimeReport: RuntimeReport?
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?
    @Published private(set) var installationMessage: String?

    init(controller: AppController, catalog: [ShortcutDefinition]) {
        self.controller = controller
        self.catalog = catalog
        synchronize()
    }

    var allRequestedEnabled: Bool {
        !rows.isEmpty && rows.allSatisfy(\.requestedEnabled)
    }

    var enabledCount: Int { rows.filter { $0.badge == .enabled }.count }
    var problemCount: Int {
        rows.filter { ![.enabled, .disabled].contains($0.badge) }.count
    }

    func refresh() async {
        isBusy = true
        await controller.refresh()
        synchronize()
    }

    func setModule(id: String, enabled: Bool) async {
        isBusy = true
        await controller.setModule(id: id, enabled: enabled)
        synchronize()
    }

    func setAll(enabled: Bool) async {
        isBusy = true
        await controller.setAll(ids: catalog.map(\.id), enabled: enabled)
        synchronize()
    }

    func setHotkey(actionID: String, spec: HotkeySpec) async {
        isBusy = true
        await controller.setHotkey(actionID: actionID, spec: spec)
        synchronize()
    }

    func resetHotkey(actionID: String) async {
        isBusy = true
        await controller.resetHotkey(actionID: actionID)
        synchronize()
    }

    func resetAllHotkeys() async {
        isBusy = true
        await controller.resetAllHotkeys()
        synchronize()
    }

    func setRecordingMode(_ active: Bool) async {
        await controller.setRecordingMode(active)
        if !active { synchronize() }
    }

    func installOrRepair() async {
        guard let resources = Bundle.main.resourceURL else {
            errorMessage = "找不到 App 安装资源，请重新下载完整安装包。"
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let root = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".hammerspoon", isDirectory: true)
            let service = InstallationService(resourceRoot: resources, hammerspoonRoot: root)
            _ = try await service.repair(skipHammerspoon: false)
            let appCandidates = [
                URL(fileURLWithPath: "/Applications/Hammerspoon.app"),
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Hammerspoon.app"),
            ]
            if let appURL = appCandidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
                _ = try? await NSWorkspace.shared.openApplication(at: appURL, configuration: .init())
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            installationMessage = "安装或修复完成"
            await controller.reloadRuntime()
            synchronize()
        } catch {
            errorMessage = "安装或修复失败，请在诊断页查看恢复方式。"
        }
    }

    private func synchronize() {
        let config = controller.configuration
        runtimeReport = controller.runtimeReport
        isBusy = controller.isBusy
        errorMessage = Self.message(for: controller.error)
        rows = catalog.map { definition in
            let runtime = runtimeReport?.modules[definition.id]
            return ShortcutRowState(
                id: definition.id,
                title: definition.title,
                summary: definition.summary,
                scope: definition.scope,
                group: definition.group,
                dependency: definition.dependency,
                requestedEnabled: config.setting(definition.id),
                badge: Self.badge(for: runtime),
                reason: runtime?.reason,
                actions: definition.actions.map { action in
                    let override = config.hotkeys[action.id]
                    let effective = override ?? action.defaultHotkey
                    return ShortcutActionRowState(
                        id: action.id,
                        title: action.title,
                        displayText: effective?.displayText ?? action.title,
                        spec: effective,
                        isEditable: action.isEditable,
                        isOverridden: override != nil
                    )
                }
            )
        }
    }

    private static func badge(for state: RuntimeModuleState?) -> ShortcutBadge {
        guard let state else { return .unknown }
        switch state.state {
        case "enabled": return .enabled
        case "disabled": return .disabled
        case "skipped":
            let reason = state.reason?.lowercased() ?? ""
            return reason.contains("permission") || reason.contains("accessibility")
                ? .permissionUnavailable : .dependencyUnavailable
        case "error":
            return state.reason?.lowercased().contains("conflict") == true ? .conflict : .runtimeError
        default: return .unknown
        }
    }

    private static func message(for error: AppControllerError?) -> String? {
        switch error {
        case nil: nil
        case .configurationUnavailable: "无法读取快捷键配置，请检查 Hammerspoon 是否正在运行。"
        case .hotkeyConflict(let conflict):
            switch conflict {
            case .shortcutKit(let actionID): "这个组合已被 ShortcutKit 的 \(actionID) 使用。"
            case .hammerspoon(let description): "这个组合已被 Hammerspoon 使用：\(description)"
            case .system(let description): "这个组合已被 macOS 使用：\(description)"
            }
        case .reloadRolledBack: "新设置没有生效，已自动恢复之前的配置。"
        case .rollbackFailed: "设置失败，自动恢复也未完成，请打开诊断页修复。"
        }
    }
}
