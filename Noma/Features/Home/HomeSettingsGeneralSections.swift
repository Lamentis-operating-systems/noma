import SwiftUI

struct SettingsAccountSectionView: View {
    var body: some View {
        Section("settings.account.section-title") {}
    }
}

struct SettingsPreferencesSectionView: View {
    var body: some View {
        Section("settings.preferences.section-title") {}
    }
}

struct SettingsAppearanceSectionView: View {
    @Environment(AppSettingsStore.self) private var appSettings

    var body: some View {
        Section("settings.appearance.section-title") {
            Picker("settings.appearance.mode", selection: appearancePreference) {
                Text("settings.appearance.dark").tag(AppAppearancePreference.dark)
                Text("settings.appearance.light").tag(AppAppearancePreference.light)
                Text("settings.appearance.system").tag(AppAppearancePreference.system)
            }
            .pickerStyle(.segmented)
        }
    }

    private var appearancePreference: Binding<AppAppearancePreference> {
        Binding(
            get: { appSettings.appearancePreference },
            set: { appSettings.appearancePreference = $0 }
        )
    }
}
