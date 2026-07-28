@testable import Noma
import SwiftUI
import UserNotifications
import XCTest

final class DailyTaskNotificationTests: XCTestCase {
    func testScheduleUsesMorningAndEveningReminderTimes() {
        XCTAssertEqual(DailyTaskNotificationSchedule.morningComponents.hour, 9)
        XCTAssertEqual(DailyTaskNotificationSchedule.morningComponents.minute, 0)
        XCTAssertEqual(DailyTaskNotificationSchedule.eveningComponents.hour, 21)
        XCTAssertEqual(DailyTaskNotificationSchedule.eveningComponents.minute, 0)
    }

    func testNotificationSettingsDefaultToBothNotificationsEnabled() {
        let settings = DailyTaskNotificationSettings.default

        XCTAssertTrue(settings.morningPlanning.isEnabled)
        XCTAssertEqual(settings.morningPlanning.dateComponents.hour, 9)
        XCTAssertEqual(settings.morningPlanning.dateComponents.minute, 0)
        XCTAssertTrue(settings.eveningOpenTasks.isEnabled)
        XCTAssertEqual(settings.eveningOpenTasks.dateComponents.hour, 21)
        XCTAssertEqual(settings.eveningOpenTasks.dateComponents.minute, 0)
    }

    func testRequestsIncludePlanningAndOpenTaskReminders() {
        let requests = DailyTaskNotificationRequestFactory.requests(
            reminders: [
                CreateReminder(text: "Plan launch"),
                CreateReminder(text: "Done", isCompleted: true)
            ]
        )

        XCTAssertEqual(requests.map(\.identifier), [
            DailyTaskNotificationIdentifier.morningPlanning,
            DailyTaskNotificationIdentifier.eveningOpenTasks
        ])
    }

    func testRequestsSkipEveningReminderWithoutOpenTasks() {
        let requests = DailyTaskNotificationRequestFactory.requests(
            reminders: [
                CreateReminder(text: "Done", isCompleted: true)
            ]
        )

        XCTAssertEqual(requests.map(\.identifier), [
            DailyTaskNotificationIdentifier.morningPlanning
        ])
    }

    func testRequestsRespectDisabledNotificationsAndCustomTimes() {
        var settings = DailyTaskNotificationSettings.default
        settings.morningPlanning.isEnabled = false
        settings.eveningOpenTasks.dateComponents = DateComponents(hour: 18, minute: 30)

        let requests = DailyTaskNotificationRequestFactory.requests(
            reminders: [CreateReminder(text: "Ship settings")],
            settings: settings
        )

        XCTAssertEqual(requests.map(\.identifier), [
            DailyTaskNotificationIdentifier.eveningOpenTasks
        ])
        XCTAssertEqual(requests.first?.dateComponents.hour, 18)
        XCTAssertEqual(requests.first?.dateComponents.minute, 30)
    }

    @MainActor
    func testRefreshClearsExistingRequestsAndRecordsAddFailures() async {
        let center = DailyTaskNotificationCenterSpy(
            authorizationStatus: .authorized,
            failingIdentifiers: [DailyTaskNotificationIdentifier.eveningOpenTasks]
        )
        let scheduler = DailyTaskNotificationScheduler(center: center)
        scheduler.activateAuthenticatedSession()

        await scheduler.refreshDailyTaskReminders(
            for: [CreateReminder(text: "Open task")]
        )

        XCTAssertEqual(center.removedIdentifierBatches, [DailyTaskNotificationIdentifier.all])
        XCTAssertEqual(center.addedIdentifiers, [
            DailyTaskNotificationIdentifier.morningPlanning,
            DailyTaskNotificationIdentifier.eveningOpenTasks
        ])
        XCTAssertEqual(
            scheduler.lastError,
            .schedulingFailed(identifiers: [DailyTaskNotificationIdentifier.eveningOpenTasks])
        )
    }

    @MainActor
    func testRefreshRecordsAuthorizationFailureAndClearsRequests() async {
        let center = DailyTaskNotificationCenterSpy(
            authorizationStatus: .notDetermined,
            authorizationError: NotificationCenterTestError.rejected
        )
        let scheduler = DailyTaskNotificationScheduler(center: center)
        scheduler.activateAuthenticatedSession()

        await scheduler.refreshDailyTaskReminders(for: [])

        XCTAssertEqual(center.removedIdentifierBatches, [DailyTaskNotificationIdentifier.all])
        XCTAssertEqual(scheduler.lastError, .authorizationRequestFailed)
        XCTAssertTrue(center.addedIdentifiers.isEmpty)
    }

    @MainActor
    func testAuthCleanupRemovesAllDailyTaskNotifications() async {
        let center = DailyTaskNotificationCenterSpy(authorizationStatus: .authorized)
        let scheduler = DailyTaskNotificationScheduler(center: center)

        scheduler.clearAfterAuthenticationEnds()

        XCTAssertEqual(center.removedIdentifierBatches, [DailyTaskNotificationIdentifier.all])
    }

    @MainActor
    func testRefreshCannotRescheduleAfterAuthCleanupAndSignInReenablesIt() async {
        let center = DailyTaskNotificationCenterSpy(authorizationStatus: .authorized)
        let scheduler = DailyTaskNotificationScheduler(center: center)
        let reminders = [CreateReminder(text: "Open task")]

        await scheduler.refreshDailyTaskReminders(for: reminders)
        XCTAssertTrue(center.addedIdentifiers.isEmpty)

        scheduler.activateAuthenticatedSession()
        await scheduler.refreshDailyTaskReminders(for: reminders)
        let authenticatedAddCount = center.addedIdentifiers.count
        XCTAssertEqual(authenticatedAddCount, 2)

        scheduler.clearAfterAuthenticationEnds()
        let removalCountAfterCleanup = center.removedIdentifierBatches.count
        await scheduler.refreshDailyTaskReminders(for: reminders)

        XCTAssertEqual(center.addedIdentifiers.count, authenticatedAddCount)
        XCTAssertEqual(center.removedIdentifierBatches.count, removalCountAfterCleanup)

        scheduler.activateAuthenticatedSession()
        await scheduler.refreshDailyTaskReminders(for: reminders)
        XCTAssertEqual(center.addedIdentifiers.count, authenticatedAddCount + 2)
    }

    @MainActor
    func testSignOutDuringSuspendedAddClearsTheLateRequest() async {
        let center = DailyTaskNotificationCenterSpy(
            authorizationStatus: .authorized,
            suspendsNextAdd: true
        )
        let scheduler = DailyTaskNotificationScheduler(center: center)
        scheduler.activateAuthenticatedSession()

        let refreshTask = Task {
            await scheduler.refreshDailyTaskReminders(for: [CreateReminder(text: "Open task")])
        }
        await center.waitUntilAddIsSuspended()

        scheduler.clearAfterAuthenticationEnds()
        center.resumeSuspendedAdd()
        await refreshTask.value

        XCTAssertEqual(center.addedIdentifiers, [DailyTaskNotificationIdentifier.morningPlanning])
        XCTAssertEqual(center.operations.last, .remove)
        XCTAssertEqual(center.removedIdentifierBatches.count, 3)
    }

    @MainActor
    func testAppSettingsPersistenceSavesNotificationAndAppearancePreferences() async {
        let suiteName = "NomaTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated user defaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(AppSettingsPersistence.loadAppearancePreference(from: defaults), .system)
        XCTAssertNil(AppSettingsPersistence.loadAppearancePreference(from: defaults).colorScheme)

        var notificationSettings = DailyTaskNotificationSettings.default
        notificationSettings.morningPlanning.isEnabled = false
        notificationSettings.morningPlanning.dateComponents = DateComponents(hour: 7, minute: 15)
        AppSettingsPersistence.saveNotificationSettings(notificationSettings, in: defaults)
        AppSettingsPersistence.saveAppearancePreference(.dark, in: defaults)

        let restoredNotificationSettings = AppSettingsPersistence.loadNotificationSettings(from: defaults)
        let restoredAppearancePreference = AppSettingsPersistence.loadAppearancePreference(from: defaults)

        XCTAssertFalse(restoredNotificationSettings.morningPlanning.isEnabled)
        XCTAssertEqual(restoredNotificationSettings.morningPlanning.dateComponents.hour, 7)
        XCTAssertEqual(restoredNotificationSettings.morningPlanning.dateComponents.minute, 15)
        XCTAssertEqual(restoredAppearancePreference, .dark)
        XCTAssertEqual(restoredAppearancePreference.colorScheme, .dark)
    }
}

@MainActor
private final class DailyTaskNotificationCenterSpy: DailyTaskNotificationCenter {
    enum Operation: Equatable {
        case addStarted(String)
        case addFinished(String)
        case remove
    }

    let authorizationStatusValue: DailyTaskNotificationAuthorizationStatus
    let authorizationError: Error?
    let failingIdentifiers: Set<String>
    private var suspendsNextAdd: Bool
    private var suspendedAddContinuation: CheckedContinuation<Void, Never>?
    private(set) var removedIdentifierBatches: [[String]] = []
    private(set) var addedIdentifiers: [String] = []
    private(set) var operations: [Operation] = []

    init(
        authorizationStatus: DailyTaskNotificationAuthorizationStatus,
        authorizationError: Error? = nil,
        failingIdentifiers: Set<String> = [],
        suspendsNextAdd: Bool = false
    ) {
        authorizationStatusValue = authorizationStatus
        self.authorizationError = authorizationError
        self.failingIdentifiers = failingIdentifiers
        self.suspendsNextAdd = suspendsNextAdd
    }

    func authorizationStatus() async -> DailyTaskNotificationAuthorizationStatus {
        authorizationStatusValue
    }

    func requestAuthorization() async throws -> Bool {
        if let authorizationError {
            throw authorizationError
        }
        return true
    }

    func add(_ request: UNNotificationRequest) async throws {
        operations.append(.addStarted(request.identifier))
        if suspendsNextAdd {
            suspendsNextAdd = false
            await withCheckedContinuation { continuation in
                suspendedAddContinuation = continuation
            }
        }
        addedIdentifiers.append(request.identifier)
        operations.append(.addFinished(request.identifier))
        if failingIdentifiers.contains(request.identifier) {
            throw NotificationCenterTestError.rejected
        }
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        removedIdentifierBatches.append(identifiers)
        operations.append(.remove)
    }

    func waitUntilAddIsSuspended() async {
        while suspendedAddContinuation == nil {
            await Task.yield()
        }
    }

    func resumeSuspendedAdd() {
        suspendedAddContinuation?.resume()
        suspendedAddContinuation = nil
    }
}

private enum NotificationCenterTestError: Error {
    case rejected
}
