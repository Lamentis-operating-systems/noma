import SwiftUI

struct HomeSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink("settings.notifications.section-title") {
                        SettingsNotificationsView()
                    }

                    NavigationLink("settings.account.section-title") {
                        SettingsAccountView()
                    }

                    NavigationLink("settings.preferences.section-title") {
                        SettingsPreferencesView()
                    }

                    NavigationLink("settings.appearance.section-title") {
                        SettingsAppearanceView()
                    }
                }
            }
            .navigationTitle("home.settings.title")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                CloseToolbarButton(
                    accessibilityLabelKey: "home.settings.close.accessibility-label",
                    action: { dismiss() }
                )
            }
        }
    }
}
