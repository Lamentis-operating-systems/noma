import SwiftUI

struct HomeEmptyState {
    let titleKey: String
    let subtitleKey: String

    static let placeholder = HomeEmptyState(
        titleKey: "home.empty.title",
        subtitleKey: "home.empty.subtitle"
    )
}

struct HomeEmptyHint: View {
    var body: some View {
        HintView(
            title: LocalizedStringKey(HomeEmptyState.placeholder.titleKey),
            subtitle: LocalizedStringKey(HomeEmptyState.placeholder.subtitleKey)
        )
        .accessibilityIdentifier("home-empty-hint")
    }
}
