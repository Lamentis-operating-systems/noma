#if DEBUG
import Foundation
import SwiftUI
import UserNotifications

enum NomaUITestScenario: String {
    case signup
    case workspace
}

struct NomaUITestLaunchConfiguration: Equatable {
    static let scenarioArgument = "--noma-ui-test-scenario"
    static let localeArgument = "--noma-ui-test-locale"
    static let dynamicTypeArgument = "--noma-ui-test-dynamic-type"
    static let runIdentifierArgument = "--noma-ui-test-run-id"

    let scenario: NomaUITestScenario
    let localeIdentifier: String
    let dynamicTypeSize: DynamicTypeSize
    let runIdentifier: UUID

    static var current: NomaUITestLaunchConfiguration? {
        parse(arguments: ProcessInfo.processInfo.arguments)
    }

    static func parse(arguments: [String]) -> NomaUITestLaunchConfiguration? {
        guard let scenarioValue = value(after: scenarioArgument, in: arguments),
              let scenario = NomaUITestScenario(rawValue: scenarioValue),
              let localeIdentifier = value(after: localeArgument, in: arguments),
              ["en", "de"].contains(localeIdentifier),
              let dynamicTypeIdentifier = value(after: dynamicTypeArgument, in: arguments),
              ["default", "AX5"].contains(dynamicTypeIdentifier),
              let runIdentifierValue = value(after: runIdentifierArgument, in: arguments),
              let runIdentifier = UUID(uuidString: runIdentifierValue)
        else { return nil }

        let dynamicTypeSize: DynamicTypeSize = dynamicTypeIdentifier == "AX5"
            ? .accessibility5
            : .large

        return NomaUITestLaunchConfiguration(
            scenario: scenario,
            localeIdentifier: localeIdentifier,
            dynamicTypeSize: dynamicTypeSize,
            runIdentifier: runIdentifier
        )
    }

    var isolatedDefaults: UserDefaults {
        let suiteName = "noma.ui-tests.\(runIdentifier.uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @MainActor
    func makeDependencies() -> NomaUITestDependencies {
        let defaults = isolatedDefaults
        let notifications = DailyTaskNotificationScheduler(center: NomaUITestNotificationCenter())
        let authState = AuthStateManager(
            authClient: UnconfiguredAuthClient(error: NomaUITestLaunchError.authenticationUnavailable)
        )
        authState.phase = scenario == .workspace ? .signedIn : .signedOut

        let persistence = NomaUITestDailyTaskGroupPersistence(initialState: seedState)
        let dailyTaskGroups = DailyTaskGroupStore(
            persistenceFactory: { _ in persistence }
        )

        return NomaUITestDependencies(
            authState: authState,
            notifications: notifications,
            appSettings: AppSettingsStore(userDefaults: defaults),
            dailyTaskGroups: dailyTaskGroups
        )
    }

    private var seedState: DailyTaskGroupState {
        guard scenario == .workspace else { return .empty }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let project = TaskProject(
            id: Self.workspaceProjectID,
            title: "UITest Project",
            symbolName: "folder",
            colorIndex: 0
        )
        let todayGroup = DailyTaskGroup(
            id: DailyTaskGroupStore.dayID(for: today, calendar: calendar),
            date: today,
            reminders: [
                CreateReminder(
                    id: Self.workspaceTodayReminderID,
                    text: "UITest Task",
                    projectID: project.id,
                    createdAt: today
                )
            ]
        )
        let historicalGroups = (1...14).compactMap { dayOffset -> DailyTaskGroup? in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today),
                  let reminderID = UUID(
                    uuidString: String(
                        format: "00000000-0000-0000-0000-00000000A%03d",
                        dayOffset + 2
                    )
                  )
            else { return nil }

            return DailyTaskGroup(
                id: DailyTaskGroupStore.dayID(for: date, calendar: calendar),
                date: date,
                reminders: [
                    CreateReminder(
                        id: reminderID,
                        text: "UITest History \(dayOffset)",
                        projectID: project.id,
                        createdAt: date
                    )
                ]
            )
        }

        return DailyTaskGroupState(
            groups: [todayGroup] + historicalGroups,
            projects: [project],
            selectedProjectID: project.id
        )
    }

    private static func value(after argument: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: argument) else { return nil }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return arguments[valueIndex]
    }

    static let workspaceProjectID = UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!
    static let workspaceTodayReminderID = UUID(uuidString: "00000000-0000-0000-0000-00000000A002")!
}

@MainActor
struct NomaUITestDependencies {
    let authState: AuthStateManager
    let notifications: DailyTaskNotificationScheduler
    let appSettings: AppSettingsStore
    let dailyTaskGroups: DailyTaskGroupStore
}

@MainActor
private final class NomaUITestDailyTaskGroupPersistence: DailyTaskGroupPersisting {
    private var state: DailyTaskGroupState

    init(initialState: DailyTaskGroupState) {
        state = initialState
    }

    func load() -> DailyTaskGroupLoadResult {
        state == .empty
            ? .empty
            : .loaded(
                state,
                source: .current(version: DailyTaskGroupPersistenceEnvelope.currentSchemaVersion)
            )
    }

    func save(_ state: DailyTaskGroupState) -> Result<Void, DailyTaskGroupPersistenceError> {
        self.state = state
        return .success(())
    }

    func delete() -> Result<Void, DailyTaskGroupPersistenceError> {
        state = .empty
        return .success(())
    }
}

@MainActor
private final class NomaUITestNotificationCenter: DailyTaskNotificationCenter {
    func authorizationStatus() async -> DailyTaskNotificationAuthorizationStatus { .authorized }
    func requestAuthorization() async throws -> Bool { true }
    func add(_ request: UNNotificationRequest) async throws {}
    func removePendingRequests(withIdentifiers identifiers: [String]) {}
}

private enum NomaUITestLaunchError: LocalizedError {
    case authenticationUnavailable

    var errorDescription: String? { "Authentication is unavailable in UI-test composition." }
}

struct NomaUITestRootView: View {
    let configuration: NomaUITestLaunchConfiguration

    var body: some View {
        Group {
            switch configuration.scenario {
            case .signup:
                SignupView {}
            case .workspace:
                HomeView()
            }
        }
        .environment(\.locale, Locale(identifier: configuration.localeIdentifier))
        .environment(\.dynamicTypeSize, configuration.dynamicTypeSize)
        .defaultAppStorage(configuration.isolatedDefaults)
    }
}
#endif
