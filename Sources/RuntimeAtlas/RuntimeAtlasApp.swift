import AppKit
import RuntimeAtlasCore
import SwiftUI

@MainActor
final class RuntimeAtlasAppDelegate: NSObject, NSApplicationDelegate {
    var stopActions: (() -> Void)?
    func applicationWillTerminate(_ notification: Notification) { stopActions?() }
}

@main
struct RuntimeAtlasApp: App {
    @NSApplicationDelegateAdaptor(RuntimeAtlasAppDelegate.self) private var appDelegate
    @StateObject private var model: AtlasAppModel
    @StateObject private var updates = UpdateModel()
    @StateObject private var actionRunner: ActionRunner

    init() {
        let model = AtlasAppModel()
        let actionRunner = ActionRunner()
        model.statusDidChange = { [weak model, weak actionRunner] status in
            guard let model, let actionRunner else { return }
            actionRunner.reconcile(
                actions: model.customActions,
                repositories: status.repositories
            )
        }
        _model = StateObject(wrappedValue: model)
        _actionRunner = StateObject(wrappedValue: actionRunner)
    }

    var body: some Scene {
        WindowGroup("Runtime Atlas", id: "main") {
            RootView()
                .environmentObject(model)
                .environmentObject(updates)
                .environmentObject(actionRunner)
                .environment(\.atlasCopy, model.copy)
                .environment(\.locale, model.language.locale)
                .preferredColorScheme(.dark)
                .tint(RuntimeAtlasTheme.accent)
                .frame(
                    minWidth: RuntimeAtlasTheme.minimumWindowWidth,
                    minHeight: RuntimeAtlasTheme.minimumWindowHeight
                )
                .onAppear {
                    actionRunner.refreshHandler = { model.refresh() }
                    appDelegate.stopActions = { actionRunner.stopAll() }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu(model.copy.atlasMenu) {
                Button(model.copy.addRepositoryEllipsis) {
                    model.chooseRepository()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button(model.copy.refresh) {
                    model.refresh()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Divider()

                Button(model.copy.checkForUpdatesEllipsis) {
                    updates.checkLatestRelease(silent: false)
                }
            }
        }

        Settings {
            LanguageSettingsView()
                .environmentObject(model)
                .environment(\.atlasCopy, model.copy)
                .environment(\.locale, model.language.locale)
                .preferredColorScheme(.dark)
                .tint(RuntimeAtlasTheme.accent)
        }
    }
}
