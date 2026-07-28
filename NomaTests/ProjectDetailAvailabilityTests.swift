@testable import Noma
import XCTest

@MainActor
final class ProjectDetailAvailabilityTests: XCTestCase {
    func testAvailabilityAndCreateEditingTrackExternalStoreRefresh() throws {
        let suiteName = "ProjectDetailAvailabilityRefreshTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let project = TaskProject(title: "Work")
        let reminder = CreateReminder(text: "Refresh me", projectID: project.id)
        let store = DailyTaskGroupStore(userDefaults: defaults, userID: "first-user")
        RetainedDailyTaskGroupStores.retain(store)
        XCTAssertTrue(store.addProject(project, selecting: true))
        XCTAssertTrue(store.setReminders([reminder], forDayID: "2026-05-17"))

        XCTAssertTrue(ProjectDetailAvailability.isAvailable(projectID: project.id, projects: store.projects))
        XCTAssertFalse(
            CreateReminderEditingReconciliation.shouldResetEditingState(
                editingReminderID: reminder.id,
                reminders: store.reminders(forDayID: "2026-05-17")
            )
        )

        store.switchUserID("second-user")

        XCTAssertFalse(ProjectDetailAvailability.isAvailable(projectID: project.id, projects: store.projects))
        XCTAssertTrue(
            CreateReminderEditingReconciliation.shouldResetEditingState(
                editingReminderID: reminder.id,
                reminders: store.reminders(forDayID: "2026-05-17")
            )
        )

        store.switchUserID("first-user")

        XCTAssertTrue(ProjectDetailAvailability.isAvailable(projectID: project.id, projects: store.projects))
        XCTAssertEqual(store.reminders(forDayID: "2026-05-17").map(\.id), [reminder.id])
    }

    func testExpirationInvalidatesProjectAndRemovesItsTasks() throws {
        let suiteName = "ProjectDetailAvailabilityTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let calendar = Calendar(identifier: .gregorian)
        let expirationDate = try XCTUnwrap(
            DateComponents(calendar: calendar, year: 2026, month: 5, day: 17).date
        )
        let project = TaskProject(title: "Launch", expiresAt: expirationDate)
        let store = DailyTaskGroupStore(
            userDefaults: defaults,
            calendar: calendar,
            now: { expirationDate },
            storageKey: suiteName
        )
        RetainedDailyTaskGroupStores.retain(store)
        store.addProject(project, selecting: true)
        let didSetReminders = store.setReminders(
            [CreateReminder(text: "Ship", projectID: project.id)],
            forDayID: "2026-05-17"
        )
        XCTAssertTrue(didSetReminders)

        XCTAssertTrue(ProjectDetailAvailability.isAvailable(projectID: project.id, projects: store.projects))

        let nextDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: expirationDate))
        store.expireProjects(asOf: nextDay)

        XCTAssertFalse(ProjectDetailAvailability.isAvailable(projectID: project.id, projects: store.projects))
        XCTAssertFalse(store.allReminders().contains { $0.projectID == project.id })
    }
}
