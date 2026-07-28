import SwiftUI

struct CreateTaskEmptyState {
    let systemImage: String?
    let titleKey: String
    let subtitleKey: String

    static let placeholder = CreateTaskEmptyState(
        systemImage: nil,
        titleKey: "create.tasks.empty.today.title",
        subtitleKey: "create.tasks.empty.today.subtitle"
    )
    static let filtered = CreateTaskEmptyState(
        systemImage: "checkmark.circle",
        titleKey: "create.tasks.empty.filtered.title",
        subtitleKey: "create.tasks.empty.filtered.subtitle"
    )
}

struct CreateTaskEmptyHint: View {
    var body: some View {
        HintView(
            systemImage: CreateTaskEmptyState.placeholder.systemImage,
            title: LocalizedStringKey(CreateTaskEmptyState.placeholder.titleKey),
            subtitle: LocalizedStringKey(CreateTaskEmptyState.placeholder.subtitleKey)
        )
    }
}

struct CreateTaskFilteredEmptyHint: View {
    var body: some View {
        HintView(
            systemImage: CreateTaskEmptyState.filtered.systemImage,
            title: LocalizedStringKey(CreateTaskEmptyState.filtered.titleKey),
            subtitle: LocalizedStringKey(CreateTaskEmptyState.filtered.subtitleKey)
        )
    }
}
