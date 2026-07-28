//
//  DailyTaskGroupTests.swift
//  NomaTests
//
//  Created by Codex on 16.05.26.
//

@testable import Noma
import XCTest

final class DailyTaskGroupTests: XCTestCase {
    func testProjectCommandsPersistSelectionAndRejectUnknownProjects() async throws {
        let fixture = DailyTaskGroupTestFixture()
        defer { fixture.cleanUp() }
        let project = taskProject(id: "00000000-0000-0000-0000-000000000020", title: "Work")

        await MainActor.run {
            let store = fixture.makeStore()
            store.addProject(project, selecting: true)

            let reloadedStore = fixture.makeStore()
            XCTAssertEqual(reloadedStore.projects, [project])
            XCTAssertEqual(reloadedStore.selectedProjectID, project.id)

            reloadedStore.selectProject(UUID())
            XCTAssertNil(reloadedStore.selectedProjectID)
        }
    }

    func testProjectsAreStoredGloballyAcrossDailyGroups() async throws {
        let fixture = DailyTaskGroupTestFixture()
        defer { fixture.cleanUp() }
        let project = taskProject(id: "00000000-0000-0000-0000-000000000021", title: "Work")

        await MainActor.run {
            let store = fixture.makeStore()

            store.addProject(project, selecting: true)
            store.setReminders(
                [CreateReminder(text: "Tomorrow", projectID: project.id)],
                forDayID: "2026-05-17"
            )

            XCTAssertEqual(store.projects.map(\.id), [project.id])
            XCTAssertEqual(store.projects.map(\.title), ["Work"])
            XCTAssertEqual(store.selectedProjectID, project.id)
        }
    }

    func testSavingAProjectWithoutTasksDoesNotCreateHiddenDailyGroup() async throws {
        let fixture = DailyTaskGroupTestFixture()
        defer { fixture.cleanUp() }
        let project = taskProject(id: "00000000-0000-0000-0000-000000000022", title: "Personal")

        await MainActor.run {
            let store = fixture.makeStore()

            store.addProject(project, selecting: true)

            XCTAssertTrue(store.groups.isEmpty)
            XCTAssertTrue(store.summaries().isEmpty)
            XCTAssertEqual(store.projects.map(\.id), [project.id])
        }
    }

    func testDeletingProjectRemovesAssignedTasksAcrossDailyGroups() async throws {
        let fixture = DailyTaskGroupTestFixture()
        defer { fixture.cleanUp() }
        let project = taskProject(id: "00000000-0000-0000-0000-000000000023", title: "Work")

        await MainActor.run {
            let store = fixture.makeStore()

            store.addProject(project, selecting: true)
            store.setReminders(
                [CreateReminder(text: "Today", projectID: project.id)],
                forDayID: "2026-05-16"
            )
            store.setReminders(
                [CreateReminder(text: "Tomorrow", projectID: project.id)],
                forDayID: "2026-05-17"
            )

            store.deleteProject(withID: project.id)

            XCTAssertTrue(store.projects.isEmpty)
            XCTAssertTrue(store.summaries().isEmpty)
            XCTAssertNil(store.selectedProjectID)
        }
    }

    func testExpiredProjectMovesProjectAndTasksToRecentlyDeleted() async throws {
        let fixture = DailyTaskGroupTestFixture()
        defer { fixture.cleanUp() }
        let expirationDate = try fixture.date(year: 2026, month: 5, day: 17)
        let project = taskProject(
            id: "00000000-0000-0000-0000-000000000024",
            title: "Launch",
            expiresAt: expirationDate
        )

        await MainActor.run {
            let store = fixture.makeStore()

            store.addProject(project, selecting: true)
            store.setReminders(
                [CreateReminder(text: "Today", projectID: project.id)],
                forDayID: "2026-05-16"
            )
            store.setReminders(
                [
                    CreateReminder(text: "Tomorrow", projectID: project.id),
                    CreateReminder(text: "Inbox")
                ],
                forDayID: "2026-05-17"
            )

            store.expireProjects(asOf: try! fixture.date(year: 2026, month: 5, day: 18))

            XCTAssertTrue(store.projects.isEmpty)
            XCTAssertEqual(store.allReminders().map(\.text), ["Inbox"])
            XCTAssertNil(store.selectedProjectID)
            XCTAssertEqual(store.recentlyDeletedProjects.map(\.project.id), [project.id])
            XCTAssertEqual(store.recentlyDeletedProjects.first?.taskSnapshots.map(\.reminder.text), ["Today", "Tomorrow"])
        }
    }

    func testProjectExpirationKeepsProjectsThroughSelectedCalendarDay() async throws {
        let fixture = DailyTaskGroupTestFixture()
        defer { fixture.cleanUp() }
        let expirationDate = try fixture.date(year: 2026, month: 5, day: 17)
        let project = taskProject(
            id: "00000000-0000-0000-0000-000000000027",
            title: "Launch",
            expiresAt: expirationDate
        )

        await MainActor.run {
            let store = fixture.makeStore()

            store.saveProjectForExpiration(project, dayID: "2026-05-17")

            store.expireProjects(asOf: expirationDate.addingTimeInterval(23 * 60 * 60))
            XCTAssertEqual(store.projects.map(\.id), [project.id])
            XCTAssertEqual(store.projectExpirationRevision, 0)

            store.expireProjects(asOf: try! fixture.date(year: 2026, month: 5, day: 18))
            XCTAssertTrue(store.projects.isEmpty)
            XCTAssertEqual(store.projectExpirationRevision, 1)
        }
    }

    func testRestoringRecentlyDeletedProjectRecreatesProjectAndTasks() async throws {
        let fixture = DailyTaskGroupTestFixture()
        defer { fixture.cleanUp() }
        let deletionDate = try fixture.date(year: 2026, month: 5, day: 18)
        let project = taskProject(id: "00000000-0000-0000-0000-000000000025", title: "Work")

        await MainActor.run {
            let store = fixture.makeStore()

            store.addProject(project, selecting: false)
            store.setReminders(
                [CreateReminder(text: "Today", projectID: project.id)],
                forDayID: "2026-05-16"
            )
            store.deleteProject(withID: project.id, at: deletionDate)

            store.restoreRecentlyDeletedProject(withID: project.id)

            XCTAssertEqual(store.projects.map(\.id), [project.id])
            XCTAssertTrue(store.recentlyDeletedProjects.isEmpty)
            XCTAssertEqual(store.reminders(forDayID: "2026-05-16").map(\.text), ["Today"])
        }
    }

    func testRecentlyDeletedProjectsArePurgedAfterSevenDays() async throws {
        let fixture = DailyTaskGroupTestFixture()
        defer { fixture.cleanUp() }
        let deletionDate = try fixture.date(year: 2026, month: 5, day: 18)
        let project = taskProject(id: "00000000-0000-0000-0000-000000000026", title: "Work")

        await MainActor.run {
            let store = fixture.makeStore()

            store.addProject(project, selecting: false)
            store.setReminders(
                [CreateReminder(text: "Today", projectID: project.id)],
                forDayID: "2026-05-16"
            )
            store.deleteProject(withID: project.id, at: deletionDate)

            store.purgeRecentlyDeletedProjects(asOf: deletionDate.addingTimeInterval(6 * 86_400))
            XCTAssertEqual(store.recentlyDeletedProjects.map(\.project.id), [project.id])

            store.purgeRecentlyDeletedProjects(asOf: deletionDate.addingTimeInterval(7 * 86_400))
            XCTAssertTrue(store.recentlyDeletedProjects.isEmpty)
        }
    }

    func testOpenRemindersFromPreviousDayReturnsOnlyUncompletedPreviousDayTasks() async throws {
        let fixture = DailyTaskGroupTestFixture()
        defer { fixture.cleanUp() }

        await MainActor.run {
            let store = fixture.makeStore()

            store.setReminders(
                [
                    CreateReminder(text: "Carry forward"),
                    CreateReminder(text: "Already done", isCompleted: true)
                ],
                forDayID: "2026-05-16"
            )
            store.setReminders(
                [CreateReminder(text: "Current day")],
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

            projects.forEach { store.addProject($0, selecting: false) }
            store.setReminders(
                [
                    CreateReminder(text: "Work 1", projectID: work.id),
                    CreateReminder(text: "Work 2", isCompleted: true, projectID: work.id),
                    CreateReminder(text: "Home 1", projectID: home.id)
                ],
                forDayID: "2026-05-16"
            )
            store.setReminders(
                [
                    CreateReminder(text: "Personal 1", projectID: personal.id),
                    CreateReminder(text: "Personal 2", projectID: personal.id),
                    CreateReminder(text: "Personal 3", isCompleted: true, projectID: personal.id),
                    CreateReminder(text: "Travel 1", projectID: travel.id)
                ],
                forDayID: "2026-05-17"
            )

            let summaries = store.commonProjectSummaries()

            XCTAssertEqual(summaries.map(\.project.id), [personal.id, work.id, home.id])
            XCTAssertEqual(summaries.map(\.taskCount), [3, 2, 1])
            XCTAssertEqual(summaries.map(\.unsolvedTaskCount), [2, 1, 1])
            XCTAssertEqual(CommonProjectsSection.headerTitleKey, "home.common-projects.section-header")
            XCTAssertEqual(CommonProjectsSection.taskCountText(for: summaries[0]), "3")
        }
    }

    func testTestSeedProvidesPreviousOpenTasksAndCommonProjects() async throws {
        let fixture = DailyTaskGroupTestFixture()
        defer { fixture.cleanUp() }

        await MainActor.run {
            let store = fixture.makeStore()
            seedDailyTaskGroupTestData(in: store, calendar: fixture.calendar)
            let todayID = DailyTaskGroupStore.todayID(calendar: fixture.calendar)

            XCTAssertFalse(store.openRemindersFromPreviousDay(beforeDayID: todayID).isEmpty)
            XCTAssertFalse(store.commonProjectSummaries().isEmpty)
        }
    }

}

private struct DailyTaskGroupTestFixture {
    let storageKey = "NomaTests-\(UUID().uuidString)"
    let defaults = UserDefaults.standard
    let calendar = Calendar(identifier: .gregorian)

    @MainActor
    func makeStore() -> DailyTaskGroupStore {
        DailyTaskGroupStore(
            userDefaults: defaults,
            calendar: calendar,
            storageKey: storageKey
        )
    }

    func cleanUp() {
        defaults.removeObject(forKey: storageKey)
    }

    func date(year: Int, month: Int, day: Int) throws -> Date {
        try XCTUnwrap(DateComponents(calendar: calendar, year: year, month: month, day: day).date)
    }
}

@MainActor
private func seedDailyTaskGroupTestData(
    in store: DailyTaskGroupStore,
    calendar: Calendar
) {
    let projects = [
        TaskProject(title: "Work", symbolName: "terminal", colorIndex: 5),
        TaskProject(title: "Personal", symbolName: "heart", colorIndex: 1),
        TaskProject(title: "Home", symbolName: "wrench", colorIndex: 3)
    ]
    let today = calendar.startOfDay(for: Date())
    let groups: [(offset: Int, reminders: [CreateReminder])] = [
        (0, [
            CreateReminder(text: "Review Noma task flow", projectID: projects[0].id),
            CreateReminder(text: "Plan dinner", projectID: projects[1].id)
        ]),
        (-1, [
            CreateReminder(text: "Send project update", projectID: projects[0].id),
            CreateReminder(text: "Buy groceries", projectID: projects[2].id),
            CreateReminder(text: "Call back Alex", isCompleted: true, projectID: projects[1].id)
        ]),
        (-2, [
            CreateReminder(text: "Draft sprint notes", isCompleted: true, projectID: projects[0].id),
            CreateReminder(text: "Clean kitchen", projectID: projects[2].id)
        ])
    ]

    projects.forEach { store.addProject($0, selecting: false) }
    for group in groups {
        let date = calendar.date(byAdding: .day, value: group.offset, to: today) ?? today
        store.setReminders(
            group.reminders,
            forDayID: DailyTaskGroupStore.dayID(for: date, calendar: calendar)
        )
    }
}

private func taskProject(id: String, title: String, expiresAt: Date? = nil) -> TaskProject {
    TaskProject(id: UUID(uuidString: id)!, title: title, expiresAt: expiresAt)
}

@MainActor
private extension DailyTaskGroupStore {
    func saveProjectForExpiration(_ project: TaskProject, dayID: String) {
        addProject(project, selecting: true)
        setReminders(
            [CreateReminder(text: "Ship beta", projectID: project.id)],
            forDayID: dayID
        )
    }
}
