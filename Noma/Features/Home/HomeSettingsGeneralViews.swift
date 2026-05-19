import SwiftUI

struct SettingsAccountView: View {
    var body: some View {
        Form {
            Section("settings.account.section-title") {}
        }
        .navigationTitle("settings.account.section-title")
        .toolbarTitleDisplayMode(.inline)
    }
}

struct SettingsPreferencesView: View {
    var body: some View {
        Form {
            Section("settings.preferences.section-title") {}
        }
        .navigationTitle("settings.preferences.section-title")
        .toolbarTitleDisplayMode(.inline)
    }
}

struct SettingsAppearanceView: View {
    @Environment(AppSettingsStore.self) private var appSettings

    var body: some View {
        Form {
            Section("settings.appearance.section-title") {
                Picker("settings.appearance.mode", selection: appearancePreference) {
                    Text("settings.appearance.dark").tag(AppAppearancePreference.dark)
                    Text("settings.appearance.light").tag(AppAppearancePreference.light)
                    Text("settings.appearance.system").tag(AppAppearancePreference.system)
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("settings.appearance.section-title")
        .toolbarTitleDisplayMode(.inline)
    }

    private var appearancePreference: Binding<AppAppearancePreference> {
        Binding(
            get: { appSettings.appearancePreference },
            set: { appSettings.appearancePreference = $0 }
        )
    }
}
