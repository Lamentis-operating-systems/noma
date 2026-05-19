@testable import Noma
import SwiftUI
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

    func testAppSettingsPersistenceSavesNotificationAndAppearancePreferences() throws {
        let suiteName = "NomaTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
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
