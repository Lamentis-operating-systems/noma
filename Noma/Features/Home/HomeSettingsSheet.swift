import SwiftUI

struct HomeSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                SettingsNotificationsSectionView()
                SettingsAccountSectionView()
                SettingsPreferencesSectionView()
                SettingsAppearanceSectionView()
            }
            .scrollContentBackground(.hidden)
            .background(.primaryBackground)
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
