import RuntimeAtlasCore
import SwiftUI

@main
struct RuntimeAtlasApp: App {
    @StateObject private var model = AtlasAppModel()
    @StateObject private var updates = UpdateModel()

    var body: some Scene {
        WindowGroup("Runtime Atlas", id: "main") {
            RootView()
                .environmentObject(model)
                .environmentObject(updates)
                .environment(\.atlasCopy, model.copy)
                .environment(\.locale, model.language.locale)
                .preferredColorScheme(.dark)
                .tint(RuntimeAtlasTheme.accent)
                .frame(minWidth: 920, minHeight: 620)
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
