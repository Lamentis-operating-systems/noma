import SwiftUI

struct SettingsNotificationsSectionView: View {
    @Environment(AppSettingsStore.self) private var appSettings

    var body: some View {
        Section("settings.notifications.section-title") {
            SettingsNotificationRow(
                titleKey: "settings.notifications.daily-planning",
                isEnabled: morningPlanningEnabled,
                time: morningPlanningTime
            )

            SettingsNotificationRow(
                titleKey: "settings.notifications.open-tasks",
                isEnabled: eveningOpenTasksEnabled,
                time: eveningOpenTasksTime
            )
        }
    }

    private var morningPlanningEnabled: Binding<Bool> {
        Binding(
            get: { appSettings.notificationSettings.morningPlanning.isEnabled },
            set: { isEnabled in
                appSettings.updateNotificationSettings { $0.morningPlanning.isEnabled = isEnabled }
            }
        )
    }

    private var eveningOpenTasksEnabled: Binding<Bool> {
        Binding(
            get: { appSettings.notificationSettings.eveningOpenTasks.isEnabled },
            set: { isEnabled in
                appSettings.updateNotificationSettings { $0.eveningOpenTasks.isEnabled = isEnabled }
            }
        )
    }

    private var morningPlanningTime: Binding<Date> {
        Binding(
            get: { appSettings.notificationSettings.morningPlanning.date() },
            set: { date in
                appSettings.updateNotificationSettings { $0.morningPlanning.updateTime(from: date) }
            }
        )
    }

    private var eveningOpenTasksTime: Binding<Date> {
        Binding(
            get: { appSettings.notificationSettings.eveningOpenTasks.date() },
            set: { date in
                appSettings.updateNotificationSettings { $0.eveningOpenTasks.updateTime(from: date) }
            }
        )
    }
}

private struct SettingsNotificationRow: View {
    let titleKey: LocalizedStringKey
    @Binding var isEnabled: Bool
    @Binding var time: Date

    var body: some View {
        Toggle(titleKey, isOn: $isEnabled)

        DatePicker(
            "settings.notifications.time",
            selection: $time,
            displayedComponents: .hourAndMinute
        )
        .disabled(!isEnabled)
    }
}
