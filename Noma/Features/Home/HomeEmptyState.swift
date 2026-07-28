import SwiftUI

struct HomeEmptyState {
    let systemImage: String
    let titleKey: String
    let subtitleKey: String

    static let placeholder = HomeEmptyState(
        systemImage: "plus.circle",
        titleKey: "home.empty.title",
        subtitleKey: "home.empty.subtitle"
    )
}

struct HomeContentVisibility {
    static func showsEmptyState(
        showsTodaySection: Bool,
        showsProjectSection: Bool,
        showsDailyGroupsSection: Bool
    ) -> Bool {
        !showsTodaySection && !showsProjectSection && !showsDailyGroupsSection
    }
}

struct HomeEmptyHint: View {
    var body: some View {
        HintView(
            systemImage: HomeEmptyState.placeholder.systemImage,
            title: LocalizedStringKey(HomeEmptyState.placeholder.titleKey),
            subtitle: LocalizedStringKey(HomeEmptyState.placeholder.subtitleKey)
        )
    }
}
