import SwiftUI

struct SettingsNotificationsView: View {
    @Environment(AppSettingsStore.self) private var appSettings

    var body: some View {
        Form {
            Section("settings.notifications.daily-planning") {
                Toggle("settings.notifications.daily-planning", isOn: morningPlanningEnabled)

                DatePicker(
                    "settings.notifications.time",
                    selection: morningPlanningTime,
                    displayedComponents: .hourAndMinute
                )
                .disabled(!appSettings.notificationSettings.morningPlanning.isEnabled)
            }

            Section("settings.notifications.open-tasks") {
                Toggle("settings.notifications.open-tasks", isOn: eveningOpenTasksEnabled)

                DatePicker(
                    "settings.notifications.time",
                    selection: eveningOpenTasksTime,
                    displayedComponents: .hourAndMinute
                )
                .disabled(!appSettings.notificationSettings.eveningOpenTasks.isEnabled)
            }
        }
        .settingsSubviewNavigation("settings.notifications.section-title")
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
