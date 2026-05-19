//
//  DailyTaskGroupTests.swift
//  NomaTests
//
//  Created by Codex on 16.05.26.
//

@testable import Noma
import XCTest

final class DailyTaskGroupTests: XCTestCase {
    func testCreateReminderDecodesLegacyPayloadWithoutProjectID() throws {
        let legacyJSON = """
        {
          "id": "00000000-0000-0000-0000-000000000031",
          "text": "Legacy reminder",
          "isCompleted": false
        }
        """
        let data = try XCTUnwrap(legacyJSON.data(using: .utf8))

        let reminder = try JSONDecoder().decode(CreateReminder.self, from: data)

        XCTAssertEqual(reminder.id, UUID(uuidString: "00000000-0000-0000-0000-000000000031"))
        XCTAssertEqual(reminder.text, "Legacy reminder")
        XCTAssertFalse(reminder.isCompleted)
        XCTAssertNil(reminder.projectID)
    }

    func testProjectsAreStoredGloballyAcrossDailyGroups() async throws {
        let fixture = DailyTaskGroupTestFixture()
        defer { fixture.cleanUp() }
        let project = taskProject(id: "00000000-0000-0000-0000-000000000021", title: "Work")

        await MainActor.run {
            let store = fixture.makeStore()

            store.save(
                reminders: [],
                projects: [project],
                selectedProjectID: project.id,
                forDayID: "2026-05-16"
            )
            store.save(
                reminders: [CreateReminder(text: "Tomorrow", projectID: project.id)],
                projects: [project],
                selectedProjectID: project.id,
                forDayID: "2026-05-17"
            )

            XCTAssertEqual(store.projects(forDayID: "2026-05-18").map(\.id), [project.id])
            XCTAssertEqual(store.projects(forDayID: "2026-05-18").map(\.title), ["Work"])
            XCTAssertEqual(store.selectedProjectID(forDayID: "2026-05-18"), project.id)
        }
    }

    func testSavingAProjectWithoutTasksDoesNotCreateHiddenDailyGroup() async throws {
        let fixture = DailyTaskGroupTestFixture()
        defer { fixture.cleanUp() }
        let project = taskProject(id: "00000000-0000-0000-0000-000000000022", title: "Personal")

        await MainActor.run {
            let store = fixture.makeStore()

            store.save(
                reminders: [],
                projects: [project],
                selectedProjectID: project.id,
                forDayID: "2026-05-16"
            )

            XCTAssertTrue(store.groups.isEmpty)
            XCTAssertTrue(store.summaries().isEmpty)
            XCTAssertEqual(store.projects(forDayID: "2026-05-17").map(\.id), [project.id])
        }
    }

    func testDeletingProjectRemovesAssignedTasksAcrossDailyGroups() async throws {
        let fixture = DailyTaskGroupTestFixture()
        defer { fixture.cleanUp() }
        let project = taskProject(id: "00000000-0000-0000-0000-000000000023", title: "Work")

        await MainActor.run {
            let store = fixture.makeStore()

            store.save(
                reminders: [CreateReminder(text: "Today", projectID: project.id)],
                projects: [project],
                selectedProjectID: project.id,
                forDayID: "2026-05-16"
            )
            store.save(
                reminders: [CreateReminder(text: "Tomorrow", projectID: project.id)],
                projects: [project],
                selectedProjectID: project.id,
                forDayID: "2026-05-17"
            )

            store.deleteProject(withID: project.id)

            XCTAssertTrue(store.projects(forDayID: "2026-05-18").isEmpty)
            XCTAssertTrue(store.summaries().isEmpty)
            XCTAssertNil(store.selectedProjectID(forDayID: "2026-05-18"))
        }
    }

    func testOpenRemindersFromPreviousDayReturnsOnlyUncompletedPreviousDayTasks() async throws {
        let fixture = DailyTaskGroupTestFixture()
        defer { fixture.cleanUp() }

        await MainActor.run {
            let store = fixture.makeStore()

            store.save(
                reminders: [
                    CreateReminder(text: "Carry forward"),
                    CreateReminder(text: "Already done", isCompleted: true)
                ],
                forDayID: "2026-05-16"
            )
            store.save(
                reminders: [CreateReminder(text: "Current day")],
                forDayID: "2026-05-17"
            )

            XCTAssertEqual(
                store.openRemindersFromPreviousDay(beforeDayID: "2026-05-17").map(\.text),
                ["Carry forward"]
            )
        }
    }

    func testCommonProjectSummariesReturnTopThreeProjectsByTaskCount() async throws {
        let fixture = DailyTaskGroupTestFixture()
        defer { fixture.cleanUp() }
        let work = taskProject(id: "00000000-0000-0000-0000-000000000041", title: "Work")
        let home = taskProject(id: "00000000-0000-0000-0000-000000000042", title: "Home")
        let personal = taskProject(id: "00000000-0000-0000-0000-000000000043", title: "Personal")
        let travel = taskProject(id: "00000000-0000-0000-0000-000000000044", title: "Travel")
        let projects = [work, home, personal, travel]

        await MainActor.run {
            let store = fixture.makeStore()

            store.save(
                reminders: [
                    CreateReminder(text: "Work 1", projectID: work.id),
                    CreateReminder(text: "Work 2", isCompleted: true, projectID: work.id),
                    CreateReminder(text: "Home 1", projectID: home.id)
                ],
                projects: projects,
                selectedProjectID: nil,
                forDayID: "2026-05-16"
            )
            store.save(
                reminders: [
                    CreateReminder(text: "Personal 1", projectID: personal.id),
                    CreateReminder(text: "Personal 2", projectID: personal.id),
                    CreateReminder(text: "Personal 3", isCompleted: true, projectID: personal.id),
                    CreateReminder(text: "Travel 1", projectID: travel.id)
                ],
                projects: projects,
                selectedProjectID: nil,
                forDayID: "2026-05-17"
            )

            let summaries = store.commonProjectSummaries()

            XCTAssertEqual(summaries.map(\.project.id), [personal.id, work.id, home.id])
            XCTAssertEqual(summaries.map(\.taskCount), [3, 2, 1])
            XCTAssertEqual(summaries.map(\.unsolvedTaskCount), [2, 1, 1])
            XCTAssertEqual(CommonProjectsSection.headerTitleKey, "home.common-projects.section-header")
            XCTAssertEqual(CommonProjectsSection.taskCountText(for: summaries[0]), "3")
            XCTAssertTrue(TaskProjectIconPresentation.usesNeutralTintInAppSurfaces)
        }
    }

    func testMockFixtureProvidesPreviousOpenTasksAndCommonProjects() async throws {
        let fixture = DailyTaskGroupTestFixture()
        defer { fixture.cleanUp() }

        await MainActor.run {
            let store = fixture.makeStore(usesMockData: true)
            let todayID = DailyTaskGroupStore.todayID(calendar: fixture.calendar)

            XCTAssertFalse(store.openRemindersFromPreviousDay(beforeDayID: todayID).isEmpty)
            XCTAssertFalse(store.commonProjectSummaries().isEmpty)
        }
    }

    func testDailyTaskGroupStoragePersistsGlobalProjectsAndTaskGroups() throws {
        let storageKey = "NomaTests-\(UUID().uuidString)"
        let defaults = UserDefaults.standard
        defer { defaults.removeObject(forKey: storageKey) }
        let calendar = Calendar(identifier: .gregorian)
        let date = try XCTUnwrap(DateComponents(calendar: calendar, year: 2026, month: 5, day: 16).date)
        let reminder = CreateReminder(id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!, text: "Plan launch")
        let project = TaskProject(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!,
            title: "Work"
        )
        let selectedProject = DailyTaskGroup(
            id: "2026-05-19",
            date: date.addingTimeInterval(259_200),
            reminders: [],
            projects: [project],
            selectedProjectID: project.id
        )
        let storage = DailyTaskGroupStorage(userDefaults: defaults, storageKey: storageKey)

        storage.save(groups: [
            DailyTaskGroup(id: "2026-05-16", date: date, reminders: [reminder]),
            DailyTaskGroup(id: "2026-05-17", date: date.addingTimeInterval(86_400), reminders: [], projects: [project]),
            DailyTaskGroup(id: "2026-05-18", date: date.addingTimeInterval(172_800), reminders: []),
            selectedProject
        ])

        XCTAssertEqual(storage.loadGroups().map(\.id), ["2026-05-16"])
        XCTAssertEqual(storage.loadGroups().first?.reminders, [reminder])
        XCTAssertEqual(storage.loadState().projects, [project])
        XCTAssertEqual(storage.loadState().selectedProjectID, project.id)
    }

    func testDailyTaskGroupStorageScopesSavedGroupsByUserID() throws {
        let defaults = UserDefaults.standard
        let firstUserID = UUID().uuidString
        let secondUserID = UUID().uuidString
        let firstStorageKey = DailyTaskGroupStorage.storageKey(forUserID: firstUserID)
        let secondStorageKey = DailyTaskGroupStorage.storageKey(forUserID: secondUserID)
        defaults.removeObject(forKey: firstStorageKey)
        defaults.removeObject(forKey: secondStorageKey)
        defer {
            defaults.removeObject(forKey: firstStorageKey)
            defaults.removeObject(forKey: secondStorageKey)
        }
        let calendar = Calendar(identifier: .gregorian)
        let date = try XCTUnwrap(DateComponents(calendar: calendar, year: 2026, month: 5, day: 16).date)
        let firstStorage = DailyTaskGroupStorage(userDefaults: defaults, storageKey: firstStorageKey)
        let secondStorage = DailyTaskGroupStorage(userDefaults: defaults, storageKey: secondStorageKey)

        firstStorage.save(groups: [
            DailyTaskGroup(id: "2026-05-16", date: date, reminders: [CreateReminder(text: "Private task")])
        ])

        XCTAssertTrue(secondStorage.loadGroups().isEmpty)

        secondStorage.save(groups: [
            DailyTaskGroup(id: "2026-05-16", date: date, reminders: [CreateReminder(text: "Other account task")])
        ])

        XCTAssertEqual(firstStorage.loadGroups().first?.reminders.map(\.text), ["Private task"])
        XCTAssertEqual(secondStorage.loadGroups().first?.reminders.map(\.text), ["Other account task"])
    }

    @MainActor
    func testDailyTaskGroupSummaryUsesDailyGroupsProgressCopyAndCompletionState() throws {
        let calendar = Calendar(identifier: .gregorian)
        let date = try XCTUnwrap(DateComponents(calendar: calendar, year: 2026, month: 5, day: 16).date)
        let summary = DailyTaskGroupSummary(
            group: DailyTaskGroup(
                id: "2026-05-16",
                date: date,
                reminders: [
                    CreateReminder(text: "One"),
                    CreateReminder(text: "Two")
                ]
            )
        )
        let completedSummary = DailyTaskGroupSummary(
            group: DailyTaskGroup(
                id: "2026-05-17",
                date: date,
                reminders: [
                    CreateReminder(text: "One", isCompleted: true)
                ]
            )
        )

        XCTAssertEqual(DailyTaskGroupsSection.headerTitleKey, "home.daily-groups.section-header")
        XCTAssertEqual(summary.taskCount, 2)
        XCTAssertEqual(summary.completedTaskCount, 0)
        XCTAssertEqual(summary.taskCountUnitKey, "home.daily-groups.task-count.plural")
        XCTAssertFalse(summary.isCompleted)
        XCTAssertTrue(completedSummary.isCompleted)
        XCTAssertEqual(completedSummary.completedTaskCount, 1)
        XCTAssertEqual(completedSummary.taskCountUnitKey, "home.daily-groups.task-count.singular")
        XCTAssertEqual(DailyTaskGroupsProgressCopy.ofKey, "home.daily-groups.progress.of")
        XCTAssertEqual(DailyTaskGroupsProgressCopy.completedKey, "home.daily-groups.progress.completed")
    }

    func testDailyTaskGroupRowShowsCompletionIconOnlyWhenAllTasksAreDone() throws {
        let calendar = Calendar(identifier: .gregorian)
        let date = try XCTUnwrap(DateComponents(calendar: calendar, year: 2026, month: 5, day: 16).date)
        let incompleteSummary = DailyTaskGroupSummary(
            group: DailyTaskGroup(
                id: "2026-05-16",
                date: date,
                reminders: [
                    CreateReminder(text: "One", isCompleted: true),
                    CreateReminder(text: "Two")
                ]
            )
        )
        let completedSummary = DailyTaskGroupSummary(
            group: DailyTaskGroup(
                id: "2026-05-17",
                date: date,
                reminders: [
                    CreateReminder(text: "One", isCompleted: true)
                ]
            )
        )

        XCTAssertNil(DailyTaskGroupRowStatus.systemImage(for: incompleteSummary))
        XCTAssertEqual(
            DailyTaskGroupRowStatus.systemImage(for: completedSummary),
            DailyTaskGroupRowStatus.completedSystemImage
        )
    }

    func testCreateReminderFilterShowsOnlyUnsolvedTasksWhenEnabled() throws {
        let completedReminder = CreateReminder(text: "Done", isCompleted: true)
        let unsolvedReminder = CreateReminder(text: "Open")
        let reminders = [completedReminder, unsolvedReminder]

        XCTAssertEqual(
            CreateReminderListFilter.visibleReminders(reminders, showsOnlyUnsolved: false),
            reminders
        )
        XCTAssertEqual(
            CreateReminderListFilter.visibleReminders(reminders, showsOnlyUnsolved: true),
            [unsolvedReminder]
        )
    }

    func testCreateReminderFilterTemporarilyKeepsJustCompletedTasksVisible() throws {
        let completedReminder = CreateReminder(text: "Done", isCompleted: true)
        let unsolvedReminder = CreateReminder(text: "Open")
        let reminders = [completedReminder, unsolvedReminder]

        XCTAssertEqual(
            CreateReminderListFilter.visibleReminders(
                reminders,
                showsOnlyUnsolved: true,
                temporarilyVisibleCompletedReminderIDs: [completedReminder.id]
            ),
            reminders
        )
    }

    func testCreateReminderFilterPreferencePersistsUnsolvedMode() throws {
        let suiteName = "NomaTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertFalse(CreateReminderFilterPreference.isEnabled(in: defaults))

        CreateReminderFilterPreference.setIsEnabled(true, in: defaults)
        XCTAssertTrue(CreateReminderFilterPreference.isEnabled(in: defaults))

        CreateReminderFilterPreference.setIsEnabled(false, in: defaults)
        XCTAssertFalse(CreateReminderFilterPreference.isEnabled(in: defaults))
    }

    func testCreateReminderOrganizationSortsByHiddenPriorityWithoutChangingTasks() throws {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000041")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!
        let thirdID = UUID(uuidString: "00000000-0000-0000-0000-000000000043")!
        let reminders = [
            CreateReminder(id: firstID, text: "Low priority"),
            CreateReminder(id: secondID, text: "High priority"),
            CreateReminder(id: thirdID, text: "Done", isCompleted: true)
        ]
        let organization = CreateReminderAIPlanningResult(
            organizedTasks: [
                CreateReminderAIOrganizedTask(reminderID: thirdID, priorityRank: 1, category: "work"),
                CreateReminderAIOrganizedTask(reminderID: secondID, priorityRank: 1, category: "work"),
                CreateReminderAIOrganizedTask(reminderID: firstID, priorityRank: 3, category: "admin")
            ],
            carryForwardReminderIDs: []
        )

        let sortedReminders = CreateReminderListOrganization.sortedReminders(reminders, using: organization)

        XCTAssertEqual(sortedReminders.map(\.id), [secondID, firstID, thirdID])
        XCTAssertEqual(sortedReminders.map(\.text), ["High priority", "Low priority", "Done"])
    }

    func testCreateReminderBatchCompletionCompletesEveryTaskWithoutChangingIdentity() throws {
        let projectID = UUID(uuidString: "00000000-0000-0000-0000-000000000031")!
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000032")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000033")!
        let reminders = [
            CreateReminder(id: firstID, text: "Open", projectID: projectID),
            CreateReminder(id: secondID, text: "Already done", isCompleted: true)
        ]

        let completedReminders = CreateReminderBatchCompletion.completingAll(reminders)

        XCTAssertTrue(completedReminders.allSatisfy(\.isCompleted))
        XCTAssertEqual(completedReminders.map(\.id), [firstID, secondID])
        XCTAssertEqual(completedReminders.map(\.projectID), [projectID, nil])
        XCTAssertEqual(completedReminders.map(\.text), ["Open", "Already done"])
    }

    func testCreateReminderFilterToolbarUsesPlainFilterIcon() throws {
        XCTAssertEqual(
            CreateReminderFilterToolbarIcon.systemImage(isActive: false),
            "line.3.horizontal.decrease"
        )
        XCTAssertEqual(
            CreateReminderFilterToolbarIcon.systemImage(isActive: true),
            "line.3.horizontal.decrease"
        )
    }

    func testCreateReminderToolbarUsesActiveFilterFeedback() throws {
        XCTAssertFalse(CreateReminderFilterToolbarIcon.usesActiveTint(isActive: false))
        XCTAssertTrue(CreateReminderFilterToolbarIcon.usesActiveTint(isActive: true))
    }
}

private struct DailyTaskGroupTestFixture {
    let storageKey = "NomaTests-\(UUID().uuidString)"
    let defaults = UserDefaults.standard
    let calendar = Calendar(identifier: .gregorian)

    @MainActor
    func makeStore(usesMockData: Bool = false) -> DailyTaskGroupStore {
        DailyTaskGroupStore(
            userDefaults: defaults,
            calendar: calendar,
            storageKey: storageKey,
            usesMockData: usesMockData
        )
    }

    func cleanUp() {
        defaults.removeObject(forKey: storageKey)
    }
}

private func taskProject(id: String, title: String) -> TaskProject {
    TaskProject(id: UUID(uuidString: id)!, title: title)
}
