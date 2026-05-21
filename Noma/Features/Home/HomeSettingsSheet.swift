import SwiftUI

enum RecentlyDeletedProjectsSettingsCopy {
    static let titleKey = "settings.recently-deleted.projects.title"
    static let emptyStateKey = "settings.recently-deleted.projects.empty"
    static let restoreTitleKey = "settings.recently-deleted.projects.restore"
    static let deleteForeverTitleKey = "settings.recently-deleted.projects.delete-forever"
    static let deletedAtKey = "settings.recently-deleted.projects.deleted-at"
    static let taskCountKey = "settings.recently-deleted.projects.task-count"
}

enum RecentlyDeletedProjectsSettingsPolicy {
    static let retentionDays = 7
}

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

                    NavigationLink(RecentlyDeletedProjectsSettingsCopy.titleKey) {
                        RecentlyDeletedProjectsSettingsView()
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

struct RecentlyDeletedProjectsSettingsView: View {
    @Environment(DailyTaskGroupStore.self) private var dailyTaskGroups

    var body: some View {
        Form {
            if dailyTaskGroups.recentlyDeletedProjects.isEmpty {
                Section {
                    Text(RecentlyDeletedProjectsSettingsCopy.emptyStateKey)
                        .foregroundStyle(.textSecondary)
                }
            } else {
                Section {
                    ForEach(dailyTaskGroups.recentlyDeletedProjects) { deletedProject in
                        RecentlyDeletedProjectSettingsRow(deletedProject: deletedProject)
                    }
                }
            }
        }
        .navigationTitle(RecentlyDeletedProjectsSettingsCopy.titleKey)
        .toolbarTitleDisplayMode(.inline)
    }
}

private struct RecentlyDeletedProjectSettingsRow: View {
    @Environment(DailyTaskGroupStore.self) private var dailyTaskGroups
    let deletedProject: RecentlyDeletedProject

    var body: some View {
        VStack(alignment: .leading, spacing: NomaSpacing.sm) {
            HStack(spacing: NomaSpacing.sm) {
                Image(systemName: deletedProject.project.symbolName)
                    .foregroundStyle(TaskProjectIconPresentation.appSurfaceColor)

                VStack(alignment: .leading, spacing: NomaSpacing.xs) {
                    Text(deletedProject.project.title)
                        .font(.headline)

                    Text(metadataText)
                        .font(.subheadline)
                        .foregroundStyle(.textSecondary)
                }
            }

            HStack(spacing: NomaSpacing.md) {
                Button(RecentlyDeletedProjectsSettingsCopy.restoreTitleKey) {
                    dailyTaskGroups.restoreRecentlyDeletedProject(withID: deletedProject.project.id)
                }

                Button(RecentlyDeletedProjectsSettingsCopy.deleteForeverTitleKey, role: .destructive) {
                    dailyTaskGroups.permanentlyDeleteRecentlyDeletedProject(withID: deletedProject.project.id)
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, NomaSpacing.xs)
    }

    private var metadataText: String {
        let deleted = String(localized: String.LocalizationValue(RecentlyDeletedProjectsSettingsCopy.deletedAtKey))
        let tasks = String(localized: String.LocalizationValue(RecentlyDeletedProjectsSettingsCopy.taskCountKey))
        let deletedAt = deletedProject.deletedAt.formatted(date: .abbreviated, time: .omitted)
        return "\(deleted): \(deletedAt) - \(deletedProject.taskSnapshots.count) \(tasks)"
    }
}
