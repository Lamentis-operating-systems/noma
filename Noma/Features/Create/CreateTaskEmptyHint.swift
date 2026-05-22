import SwiftUI

struct CreateTaskEmptyState {
    let systemImage: String?, titleKey: String, subtitleKey: String
    let cta: HintCTA?, mirrorsImageForRightToLeftLayoutDirection: Bool

    static let placeholder = CreateTaskEmptyState(
        systemImage: nil,
        titleKey: "create.tasks.empty.today.title",
        subtitleKey: "create.tasks.empty.today.subtitle",
        cta: nil,
        mirrorsImageForRightToLeftLayoutDirection: false
    )
    static let filtered = CreateTaskEmptyState(
        systemImage: "checkmark.circle",
        titleKey: "create.tasks.empty.filtered.title",
        subtitleKey: "create.tasks.empty.filtered.subtitle",
        cta: nil,
        mirrorsImageForRightToLeftLayoutDirection: false
    )
}

struct CreateTaskEmptyHint: View {
    var body: some View {
        HintView(
            systemImage: CreateTaskEmptyState.placeholder.systemImage,
            title: LocalizedStringKey(CreateTaskEmptyState.placeholder.titleKey),
            subtitle: LocalizedStringKey(CreateTaskEmptyState.placeholder.subtitleKey),
            cta: CreateTaskEmptyState.placeholder.cta,
            mirrorsSystemImageForRightToLeftLayoutDirection: CreateTaskEmptyState.placeholder.mirrorsImageForRightToLeftLayoutDirection
        )
    }
}

struct CreateTaskFilteredEmptyHint: View {
    var body: some View {
        HintView(
            systemImage: CreateTaskEmptyState.filtered.systemImage,
            title: LocalizedStringKey(CreateTaskEmptyState.filtered.titleKey),
            subtitle: LocalizedStringKey(CreateTaskEmptyState.filtered.subtitleKey),
            cta: CreateTaskEmptyState.filtered.cta,
            mirrorsSystemImageForRightToLeftLayoutDirection: CreateTaskEmptyState.filtered.mirrorsImageForRightToLeftLayoutDirection
        )
    }
}
