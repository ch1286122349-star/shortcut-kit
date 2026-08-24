import Foundation

public enum AppControllerError: Error, Equatable, Sendable {
    case configurationUnavailable
    case hotkeyConflict(HotkeyConflict)
    case reloadRolledBack
    case rollbackFailed
}

@MainActor
public final class AppController {
    private let configStore: any ConfigStoring
    private let bridge: any HammerspoonBridging
    private let defaultHotkeys: [String: HotkeySpec]

    public private(set) var configuration: AppConfiguration
    public private(set) var runtimeReport: RuntimeReport?
    public private(set) var error: AppControllerError?
    public private(set) var isBusy = false

    public init(
        configStore: any ConfigStoring,
        bridge: any HammerspoonBridging,
        defaultHotkeys: [String: HotkeySpec] = [:]
    ) {
        self.configStore = configStore
        self.bridge = bridge
        self.defaultHotkeys = defaultHotkeys
        self.configuration = (try? configStore.load()) ?? AppConfiguration()
    }

    public func refresh() async {
        error = nil
        configuration = (try? configStore.load()) ?? configuration
        runtimeReport = try? await bridge.status()
    }

    public func reloadRuntime() async {
        error = nil
        do {
            runtimeReport = try await bridge.reloadAndWait(expected: [:], timeout: 5)
            configuration = try configStore.load()
        } catch {
            self.error = .configurationUnavailable
        }
    }

    public func setModule(id: String, enabled: Bool) async {
        await transact(expected: [id: enabled]) { config in
            config.setModule(id, enabled: enabled)
        }
    }

    public func setAll(ids: [String], enabled: Bool) async {
        await transact(expected: Dictionary(uniqueKeysWithValues: ids.map { ($0, enabled) })) { config in
            for id in ids { config.setModule(id, enabled: enabled) }
        }
    }

    public func setHotkey(actionID: String, spec: HotkeySpec) async {
        guard !isBusy else { return }
        error = nil

        var bindings = defaultHotkeys
        if let current = try? configStore.load() {
            bindings.merge(current.hotkeys) { _, override in override }
        }
        if let conflict = HotkeyConflictValidator.duplicate(
            proposed: spec,
            actionID: actionID,
            activeBindings: bindings
        ) {
            error = .hotkeyConflict(conflict)
            return
        }
        do {
            if let conflict = try await bridge.checkConflict(spec: spec, excludingActionID: actionID) {
                error = .hotkeyConflict(conflict)
                return
            }
        } catch {
            self.error = .configurationUnavailable
            return
        }

        await transactHotkeys(expected: [actionID: spec]) { config in
            config.setHotkey(actionID, to: spec)
        }
    }

    public func resetHotkey(actionID: String) async {
        guard let defaultSpec = defaultHotkeys[actionID] else { return }
        await transactHotkeys(expected: [actionID: defaultSpec]) { config in
            config.resetHotkey(actionID)
        }
    }

    public func resetAllHotkeys() async {
        await transactHotkeys(expected: defaultHotkeys) { config in
            for actionID in defaultHotkeys.keys { config.resetHotkey(actionID) }
        }
    }

    public func setRecordingMode(_ active: Bool) async {
        do { try await bridge.setRecordingMode(active) }
        catch { self.error = .configurationUnavailable }
    }

    private func transact(
        expected: [String: Bool],
        mutation: (inout AppConfiguration) -> Void
    ) async {
        guard !isBusy else { return }
        isBusy = true
        error = nil
        defer { isBusy = false }

        let original: AppConfiguration
        do { original = try configStore.load() }
        catch { self.error = .configurationUnavailable; return }
        do {
            var next = original
            mutation(&next)
            try configStore.save(next)
            let report = try await bridge.reloadAndWait(expected: expected, timeout: 5)
            configuration = next
            runtimeReport = report
        } catch {
            await restoreAfterFailure(original: original, expectedIDs: Array(expected.keys))
        }
    }

    private func restoreAfterFailure(original: AppConfiguration, expectedIDs: [String]) async {
        do {
            try configStore.save(original)
            let restored = original
            let expected = Dictionary(uniqueKeysWithValues: expectedIDs.map {
                ($0, restored.setting($0))
            })
            let report = try await bridge.reloadAndWait(expected: expected, timeout: 5)
            configuration = restored
            runtimeReport = report
            error = .reloadRolledBack
        } catch {
            self.error = .rollbackFailed
        }
    }

    private func transactHotkeys(
        expected: [String: HotkeySpec],
        mutation: (inout AppConfiguration) -> Void
    ) async {
        guard !isBusy else { return }
        isBusy = true
        error = nil
        defer { isBusy = false }

        let original: AppConfiguration
        do { original = try configStore.load() }
        catch { self.error = .configurationUnavailable; return }
        do {
            var next = original
            mutation(&next)
            try configStore.save(next)
            let report = try await bridge.reloadAndWait(
                expectedModules: [:],
                expectedHotkeys: expected,
                timeout: 5
            )
            configuration = next
            runtimeReport = report
        } catch {
            await restoreHotkeysAfterFailure(
                original: original,
                actionIDs: Array(expected.keys)
            )
        }
    }

    private func restoreHotkeysAfterFailure(original: AppConfiguration, actionIDs: [String]) async {
        do {
            try configStore.save(original)
            let restored = original
            var restoredBindings = defaultHotkeys
            restoredBindings.merge(restored.hotkeys) { _, override in override }
            let expected = Dictionary(uniqueKeysWithValues: actionIDs.compactMap { id in
                restoredBindings[id].map { (id, $0) }
            })
            let report = try await bridge.reloadAndWait(
                expectedModules: [:],
                expectedHotkeys: expected,
                timeout: 5
            )
            configuration = restored
            runtimeReport = report
            error = .reloadRolledBack
        } catch {
            self.error = .rollbackFailed
        }
    }
}
