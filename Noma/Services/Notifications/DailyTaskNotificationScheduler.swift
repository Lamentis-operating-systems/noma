import Foundation
import Observation
import UserNotifications

enum DailyTaskNotificationIdentifier {
    static let morningPlanning = "daily-task-planning-morning"
    static let eveningOpenTasks = "daily-task-open-tasks-evening"

    static let all = [
        morningPlanning,
        eveningOpenTasks
    ]
}

enum DailyTaskNotificationSchedule {
    static var morningComponents: DateComponents {
        DailyTaskNotificationSettings.default.morningPlanning.dateComponents
    }

    static var eveningComponents: DateComponents {
        DailyTaskNotificationSettings.default.eveningOpenTasks.dateComponents
    }
}

struct DailyTaskNotificationRequest: Equatable {
    let identifier: String
    let titleKey: String
    let bodyKey: String
    let dateComponents: DateComponents

    func userNotificationRequest() -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = String(localized: String.LocalizationValue(titleKey))
        content.body = String(localized: String.LocalizationValue(bodyKey))
        content.sound = .default

        return UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )
        )
    }
}

enum DailyTaskNotificationRequestFactory {
    static func requests(
        reminders: [CreateReminder],
        settings: DailyTaskNotificationSettings = .default
    ) -> [DailyTaskNotificationRequest] {
        var requests: [DailyTaskNotificationRequest] = []

        if settings.morningPlanning.isEnabled {
            requests.append(
                DailyTaskNotificationRequest(
                    identifier: DailyTaskNotificationIdentifier.morningPlanning,
                    titleKey: "notifications.daily-planning.title",
                    bodyKey: "notifications.daily-planning.body",
                    dateComponents: settings.morningPlanning.dateComponents
                )
            )
        }

        if settings.eveningOpenTasks.isEnabled, reminders.contains(where: { !$0.isCompleted }) {
            requests.append(
                DailyTaskNotificationRequest(
                    identifier: DailyTaskNotificationIdentifier.eveningOpenTasks,
                    titleKey: "notifications.open-tasks.title",
                    bodyKey: "notifications.open-tasks.body",
                    dateComponents: settings.eveningOpenTasks.dateComponents
                )
            )
        }

        return requests
    }

}

@MainActor
@Observable
final class DailyTaskNotificationScheduler {
    @ObservationIgnored private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func refreshDailyTaskReminders(
        for reminders: [CreateReminder],
        settings: DailyTaskNotificationSettings = .default
    ) async {
        guard await canScheduleNotifications() else {
            center.removePendingNotificationRequests(withIdentifiers: DailyTaskNotificationIdentifier.all)
            return
        }

        center.removePendingNotificationRequests(withIdentifiers: DailyTaskNotificationIdentifier.all)

        for request in DailyTaskNotificationRequestFactory.requests(reminders: reminders, settings: settings) {
            try? await center.add(request.userNotificationRequest())
        }
    }

    private func canScheduleNotifications() async -> Bool {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return await requestAuthorization()
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }
}
