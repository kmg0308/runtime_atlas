import RuntimeAtlasCore
import SwiftUI

struct LanguageSettingsView: View {
    @EnvironmentObject private var model: AtlasAppModel
    @Environment(\.atlasCopy) private var copy

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(copy.settingsTitle)
                    .font(.system(size: 18, weight: .semibold))
                Text(copy.settingsDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(RuntimeAtlasTheme.secondaryText)
            }

            Picker(copy.languageChoice, selection: languageBinding) {
                Text(copy.koreanName).tag(AppLanguage.korean)
                Text(copy.englishName).tag(AppLanguage.english)
            }
            .pickerStyle(.radioGroup)
            .accessibilityLabel(copy.languageChoice)

            if let error = model.languageSaveError {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(RuntimeAtlasTheme.red)
            }

            Divider().overlay(RuntimeAtlasTheme.border)

            Text(copy.settingsPersistence)
                .font(.system(size: 10))
                .foregroundStyle(RuntimeAtlasTheme.tertiaryText)
        }
        .padding(24)
        .frame(width: 420, height: 220, alignment: .topLeading)
        .foregroundStyle(RuntimeAtlasTheme.primaryText)
        .background(RuntimeAtlasTheme.background)
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { model.language },
            set: { model.setLanguage($0) }
        )
    }
}
