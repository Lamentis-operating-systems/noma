import SwiftUI

struct SettingsAccountView: View {
    var body: some View {
        Form {
            Section("settings.account.section-title") {}
        }
        .settingsSubviewNavigation("settings.account.section-title")
    }
}

struct SettingsPreferencesView: View {
    var body: some View {
        Form {
            Section("settings.preferences.section-title") {}
        }
        .settingsSubviewNavigation("settings.preferences.section-title")
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
        .settingsSubviewNavigation("settings.appearance.section-title")
    }

    private var appearancePreference: Binding<AppAppearancePreference> {
        Binding(
            get: { appSettings.appearancePreference },
            set: { appSettings.appearancePreference = $0 }
        )
    }
}

extension View {
    func settingsSubviewNavigation(_ titleKey: LocalizedStringKey) -> some View {
        scrollContentBackground(.hidden)
            .background(.primaryBackground)
            .navigationTitle(titleKey)
            .toolbarTitleDisplayMode(.inline)
    }
}
