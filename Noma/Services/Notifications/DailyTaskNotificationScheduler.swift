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
    static let morningComponents = DateComponents(hour: 9, minute: 0)
    static let eveningComponents = DateComponents(hour: 21, minute: 0)
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
    static func requests(reminders: [CreateReminder]) -> [DailyTaskNotificationRequest] {
        var requests = [
            DailyTaskNotificationRequest(
                identifier: DailyTaskNotificationIdentifier.morningPlanning,
                titleKey: "notifications.daily-planning.title",
                bodyKey: "notifications.daily-planning.body",
                dateComponents: DailyTaskNotificationSchedule.morningComponents
            )
        ]

        if reminders.contains(where: { !$0.isCompleted }) {
            requests.append(
                DailyTaskNotificationRequest(
                    identifier: DailyTaskNotificationIdentifier.eveningOpenTasks,
                    titleKey: "notifications.open-tasks.title",
                    bodyKey: "notifications.open-tasks.body",
                    dateComponents: DailyTaskNotificationSchedule.eveningComponents
                )
            )
        }

        return requests
    }

}

enum DailyTaskNotificationAuthorizationStatus {
    case authorized
    case notDetermined
    case denied
}

@MainActor
protocol DailyTaskNotificationCenter: AnyObject {
    func authorizationStatus() async -> DailyTaskNotificationAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingRequests(withIdentifiers identifiers: [String])
}

@MainActor
final class SystemDailyTaskNotificationCenter: DailyTaskNotificationCenter {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> DailyTaskNotificationAuthorizationStatus {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        @unknown default:
            return .denied
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

enum DailyTaskNotificationSchedulerError: Equatable {
    case authorizationRequestFailed
    case schedulingFailed(identifiers: [String])
}

@MainActor
@Observable
final class DailyTaskNotificationScheduler: AuthSessionLifecycle {
    @ObservationIgnored private let center: any DailyTaskNotificationCenter
    @ObservationIgnored private var isAuthenticationActive = false
    @ObservationIgnored private var desiredRequests: [DailyTaskNotificationRequest] = []
    @ObservationIgnored private var stateRevision: UInt = 0
    @ObservationIgnored private var isReconciling = false
    @ObservationIgnored private var reconciliationWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var lastError: DailyTaskNotificationSchedulerError?

    convenience init() {
        self.init(center: SystemDailyTaskNotificationCenter())
    }

    init(center: any DailyTaskNotificationCenter) {
        self.center = center
    }

    func refreshDailyTaskReminders(for reminders: [CreateReminder]) async {
        guard isAuthenticationActive else { return }

        lastError = nil
        desiredRequests = DailyTaskNotificationRequestFactory.requests(reminders: reminders)
        stateRevision &+= 1

        await reconcileDesiredRequests()
    }

    func activateAuthenticatedSession() {
        guard !isAuthenticationActive else { return }
        isAuthenticationActive = true
        stateRevision &+= 1
    }

    func clearAfterAuthenticationEnds() {
        isAuthenticationActive = false
        desiredRequests = []
        lastError = nil
        stateRevision &+= 1
        clearDailyTaskReminders()
    }

    func clearDailyTaskReminders() {
        center.removePendingRequests(withIdentifiers: DailyTaskNotificationIdentifier.all)
    }

    private func reconcileDesiredRequests() async {
        if isReconciling {
            await withCheckedContinuation { continuation in
                reconciliationWaiters.append(continuation)
            }
            return
        }

        isReconciling = true
        defer {
            isReconciling = false
            let waiters = reconciliationWaiters
            reconciliationWaiters.removeAll()
            waiters.forEach { $0.resume() }
        }

        while true {
            let revision = stateRevision

            guard isAuthenticationActive else {
                clearDailyTaskReminders()
                return
            }

            let requests = desiredRequests
            guard !requests.isEmpty else {
                clearDailyTaskReminders()
                guard isCurrent(revision) else { continue }
                return
            }

            guard await canScheduleNotifications(revision: revision) else {
                guard isCurrent(revision) else {
                    if !isAuthenticationActive {
                        clearDailyTaskReminders()
                        return
                    }
                    continue
                }
                clearDailyTaskReminders()
                return
            }

            guard isCurrent(revision) else { continue }
            clearDailyTaskReminders()

            var failedIdentifiers: [String] = []
            var mustReconcileAgain = false

            for request in requests {
                guard isCurrent(revision) else {
                    mustReconcileAgain = true
                    break
                }

                do {
                    try await center.add(request.userNotificationRequest())
                } catch {
                    if isCurrent(revision) {
                        failedIdentifiers.append(request.identifier)
                    }
                }

                guard isCurrent(revision) else {
                    mustReconcileAgain = true
                    break
                }
            }

            if mustReconcileAgain {
                if !isAuthenticationActive {
                    clearDailyTaskReminders()
                    return
                }
                continue
            }

            lastError = failedIdentifiers.isEmpty
                ? nil
                : .schedulingFailed(identifiers: failedIdentifiers)
            return
        }
    }

    private func isCurrent(_ revision: UInt) -> Bool {
        isAuthenticationActive && stateRevision == revision
    }

    private func canScheduleNotifications(revision: UInt) async -> Bool {
        switch await center.authorizationStatus() {
        case .authorized:
            return isCurrent(revision)
        case .notDetermined:
            return await requestAuthorization(revision: revision)
        case .denied:
            return false
        }
    }

    private func requestAuthorization(revision: UInt) async -> Bool {
        do {
            let isAuthorized = try await center.requestAuthorization()
            return isAuthorized && isCurrent(revision)
        } catch {
            if isCurrent(revision) {
                lastError = .authorizationRequestFailed
            }
            return false
        }
    }
}
