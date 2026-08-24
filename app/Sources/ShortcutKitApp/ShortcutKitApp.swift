import Darwin
import Foundation
import ShortcutKitCore
import SwiftUI

@main
struct ShortcutKitApplication: App {
    @StateObject private var model: AppViewModel

    init() {
        if CommandLine.arguments.contains("--self-test") { Self.runSelfTestAndExit() }
        let catalog = (try? Self.loadCatalog()) ?? []
        let defaults = Dictionary(uniqueKeysWithValues: catalog.flatMap(\.actions).compactMap { action in
            action.defaultHotkey.map { (action.id, $0) }
        })
        let controller = AppController(
            configStore: ConfigStore.defaultStore(),
            bridge: HammerspoonBridge(executableURL: HammerspoonLocator.executableURL()),
            defaultHotkeys: defaults
        )
        _model = StateObject(wrappedValue: AppViewModel(controller: controller, catalog: catalog))
    }

    var body: some Scene {
        MenuBarExtra("ShortcutKit", systemImage: "keyboard") {
            MenuBarContentView(model: model)
        }
        .menuBarExtraStyle(.menu)
        Window("ShortcutKit 快捷键", id: "settings") {
            SettingsRootView(model: model)
                .frame(minWidth: 760, minHeight: 580)
                .task { await model.refresh() }
        }
        .defaultSize(width: 880, height: 680)
    }

    private static func loadCatalog() throws -> [ShortcutDefinition] {
        guard let url = Bundle.module.url(forResource: "shortcut-catalog", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try ShortcutCatalog.load(data: Data(contentsOf: url))
    }

    private static func runSelfTestAndExit() -> Never {
        do {
            let catalog = try loadCatalog()
            guard catalog.count == 12 else { throw SelfTestError.invalidCatalog }
            let actions = catalog.flatMap(\.actions).filter(\.isEditable)
            guard !actions.isEmpty, Set(actions.compactMap(\.defaultHotkey)).count == actions.count else {
                throw SelfTestError.invalidCatalog
            }
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("ShortcutKitSelfTest-\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = ConfigStore(directory: directory)
            let replacement = try HotkeySpec(modifiers: ["ctrl", "shift"], key: "5")
            var config = AppConfiguration()
            config.setHotkey("window_screenshot", to: replacement)
            try store.save(config)
            guard try store.load().hotkeys["window_screenshot"] == replacement else {
                throw SelfTestError.configRoundTrip
            }
            config = try store.load()
            config.resetHotkey("window_screenshot")
            try store.save(config)
            guard try store.load().hotkeys["window_screenshot"] == nil else {
                throw SelfTestError.configRoundTrip
            }
            print("ShortcutKitApp self-test: PASS")
            exit(0)
        } catch {
            fputs("ShortcutKitApp self-test: FAIL\n", stderr)
            exit(1)
        }
    }
}

private enum SelfTestError: Error { case invalidCatalog, configRoundTrip }

enum HammerspoonLocator {
    static func executableURL(fileManager: FileManager = .default) -> URL {
        let candidates = [
            "/opt/homebrew/bin/hs",
            "/usr/local/bin/hs",
            "/Applications/Hammerspoon.app/Contents/Frameworks/hs",
        ]
        return candidates.map(URL.init(fileURLWithPath:))
            .first(where: { fileManager.isExecutableFile(atPath: $0.path) })
            ?? URL(fileURLWithPath: candidates[0])
    }
}
