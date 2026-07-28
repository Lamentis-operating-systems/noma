@testable import Noma
import XCTest

@MainActor
final class DailyTaskGroupAtomicMutationTests: XCTestCase {
    func testCarryForwardUpdatesSourceAndTargetWithOneSave() throws {
        let fixture = AtomicMutationFixture()
        let persistence = RecordingDailyTaskGroupPersistence(state: fixture.initialState)
        let store = DailyTaskGroupStore(calendar: fixture.calendar, persistenceFactory: { _ in persistence })
        RetainedDailyTaskGroupStores.retain(store)

        let didCarryForward = store.carryForwardReminders(
            [fixture.sourceReminder],
            fromDayID: fixture.sourceDayID,
            toDayID: fixture.targetDayID
        )
        XCTAssertTrue(didCarryForward)

        XCTAssertEqual(persistence.saveCallCount, 1)
        XCTAssertEqual(
            store.reminders(forDayID: fixture.sourceDayID).map(\.id),
            [fixture.remainingSourceReminder.id, fixture.unassignedReminder.id]
        )
        let targetReminders = store.reminders(forDayID: fixture.targetDayID)
        XCTAssertEqual(targetReminders.count, 3)
        XCTAssertEqual(targetReminders.first?.id, fixture.existingTargetReminder.id)
        XCTAssertEqual(targetReminders.last?.text, fixture.sourceReminder.text)
        XCTAssertEqual(targetReminders.last?.projectID, fixture.project.id)
        XCTAssertEqual(targetReminders.last?.createdAt, fixture.sourceReminder.createdAt)
        XCTAssertEqual(targetReminders.last?.carryForwardCount, fixture.sourceReminder.carryForwardCount + 1)
        XCTAssertEqual(stateSnapshot(persistence.state.groups), stateSnapshot(store.groups))
    }

    func testCarryForwardWriteFailureLeavesBothDaysUnchanged() {
        let fixture = AtomicMutationFixture()
        let persistence = RecordingDailyTaskGroupPersistence(state: fixture.initialState, failsSaves: true)
        let store = DailyTaskGroupStore(calendar: fixture.calendar, persistenceFactory: { _ in persistence })
        RetainedDailyTaskGroupStores.retain(store)
        let initialGroups = stateSnapshot(store.groups)

        let didCarryForward = store.carryForwardReminders(
            [fixture.sourceReminder],
            fromDayID: fixture.sourceDayID,
            toDayID: fixture.targetDayID
        )
        XCTAssertFalse(didCarryForward)

        XCTAssertEqual(persistence.saveCallCount, 1)
        XCTAssertEqual(stateSnapshot(store.groups), initialGroups)
        XCTAssertEqual(stateSnapshot(persistence.state.groups), initialGroups)
        XCTAssertEqual(store.persistenceError, .writeFailed)
    }

    func testCompleteAllProjectRemindersAcrossDaysUsesOneSave() {
        let fixture = AtomicMutationFixture()
        let persistence = RecordingDailyTaskGroupPersistence(state: fixture.initialState)
        let store = DailyTaskGroupStore(calendar: fixture.calendar, persistenceFactory: { _ in persistence })
        RetainedDailyTaskGroupStores.retain(store)

        let didComplete = store.completeAllReminders(forProjectID: fixture.project.id)
        XCTAssertTrue(didComplete)

        XCTAssertEqual(persistence.saveCallCount, 1)
        let projectReminders = store.allReminders().filter { $0.projectID == fixture.project.id }
        XCTAssertTrue(projectReminders.allSatisfy(\.isCompleted))
        XCTAssertFalse(store.allReminders().first { $0.id == fixture.unassignedReminder.id }?.isCompleted ?? true)
        XCTAssertEqual(stateSnapshot(persistence.state.groups), stateSnapshot(store.groups))
    }

    func testCompleteAllWriteFailureLeavesEveryDayUnchanged() {
        let fixture = AtomicMutationFixture()
        let persistence = RecordingDailyTaskGroupPersistence(state: fixture.initialState, failsSaves: true)
        let store = DailyTaskGroupStore(calendar: fixture.calendar, persistenceFactory: { _ in persistence })
        RetainedDailyTaskGroupStores.retain(store)
        let initialGroups = stateSnapshot(store.groups)

        let didComplete = store.completeAllReminders(forProjectID: fixture.project.id)
        XCTAssertFalse(didComplete)

        XCTAssertEqual(persistence.saveCallCount, 1)
        XCTAssertEqual(stateSnapshot(store.groups), initialGroups)
        XCTAssertEqual(stateSnapshot(persistence.state.groups), initialGroups)
        XCTAssertEqual(store.persistenceError, .writeFailed)
    }

    func testSetRemindersRejectsOrphanProjectReferenceBeforeSaving() {
        let persistence = RecordingDailyTaskGroupPersistence(state: .empty)
        let store = DailyTaskGroupStore(persistenceFactory: { _ in persistence })
        RetainedDailyTaskGroupStores.retain(store)
        let orphanReminder = CreateReminder(text: "Orphan", projectID: UUID())

        let didSetReminders = store.setReminders([orphanReminder], forDayID: "2026-05-17")
        XCTAssertFalse(didSetReminders)
        XCTAssertTrue(store.groups.isEmpty)
        XCTAssertEqual(persistence.saveCallCount, 0)
    }

    func testAtomicReminderReplacementFailureLeavesStoreUnchanged() {
        let fixture = AtomicMutationFixture()
        let persistence = RecordingDailyTaskGroupPersistence(state: fixture.initialState, failsSaves: true)
        let store = DailyTaskGroupStore(calendar: fixture.calendar, persistenceFactory: { _ in persistence })
        RetainedDailyTaskGroupStores.retain(store)
        let initialGroups = stateSnapshot(store.groups)

        let didReplace = store.replaceRemindersAtomically(
            [CreateReminder(text: "Unsaved")],
            forDayID: fixture.targetDayID
        )
        XCTAssertFalse(didReplace)
        XCTAssertEqual(persistence.saveCallCount, 1)
        XCTAssertEqual(stateSnapshot(store.groups), initialGroups)
        XCTAssertEqual(store.persistenceError, .writeFailed)
    }

    func testSetRemindersWriteFailureLeavesStoreUnchanged() {
        let fixture = AtomicMutationFixture()
        let persistence = RecordingDailyTaskGroupPersistence(state: fixture.initialState, failsSaves: true)
        let store = DailyTaskGroupStore(calendar: fixture.calendar, persistenceFactory: { _ in persistence })
        RetainedDailyTaskGroupStores.retain(store)
        let initialGroups = stateSnapshot(store.groups)

        let didSet = store.setReminders(
            [CreateReminder(text: "Unsaved replacement")],
            forDayID: fixture.targetDayID
        )

        XCTAssertFalse(didSet)
        XCTAssertEqual(stateSnapshot(store.groups), initialGroups)
        XCTAssertEqual(stateSnapshot(persistence.state.groups), initialGroups)
        XCTAssertEqual(store.persistenceError, .writeFailed)
    }

    func testProjectMutationsRollBackWhenWritesFail() {
        let fixture = AtomicMutationFixture()
        let persistence = RecordingDailyTaskGroupPersistence(state: fixture.initialState, failsSaves: true)
        let store = DailyTaskGroupStore(calendar: fixture.calendar, persistenceFactory: { _ in persistence })
        RetainedDailyTaskGroupStores.retain(store)
        let initialGroups = stateSnapshot(store.groups)
        let initialProjects = store.projects
        let initialSelectedProjectID = store.selectedProjectID
        let initialRecentlyDeletedProjects = store.recentlyDeletedProjects

        XCTAssertFalse(store.addProject(TaskProject(title: "Unsaved"), selecting: true))
        XCTAssertFalse(store.selectProject(nil))
        XCTAssertFalse(store.updateProject(TaskProject(id: fixture.project.id, title: "Renamed")))
        XCTAssertFalse(store.deleteProject(withID: fixture.project.id))

        XCTAssertEqual(stateSnapshot(store.groups), initialGroups)
        XCTAssertEqual(store.projects, initialProjects)
        XCTAssertEqual(store.selectedProjectID, initialSelectedProjectID)
        XCTAssertEqual(store.recentlyDeletedProjects, initialRecentlyDeletedProjects)
        XCTAssertEqual(persistence.saveCallCount, 4)
    }

    func testExpirationWriteFailureLeavesEveryExpiredProjectAndRevisionUnchanged() throws {
        let calendar = Calendar(identifier: .gregorian)
        let expirationDate = try XCTUnwrap(
            DateComponents(calendar: calendar, year: 2026, month: 5, day: 17).date
        )
        let nextDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: expirationDate))
        let firstProject = TaskProject(title: "First", expiresAt: expirationDate)
        let secondProject = TaskProject(title: "Second", expiresAt: expirationDate)
        let state = DailyTaskGroupState(
            groups: [
                DailyTaskGroup(
                    id: "2026-05-17",
                    date: expirationDate,
                    reminders: [
                        CreateReminder(text: "First task", projectID: firstProject.id),
                        CreateReminder(text: "Second task", projectID: secondProject.id)
                    ]
                )
            ],
            projects: [firstProject, secondProject],
            selectedProjectID: firstProject.id
        )
        let persistence = RecordingDailyTaskGroupPersistence(state: state, failsSaves: true)
        let store = DailyTaskGroupStore(
            calendar: calendar,
            now: { expirationDate },
            persistenceFactory: { _ in persistence }
        )
        RetainedDailyTaskGroupStores.retain(store)

        XCTAssertFalse(store.expireProjects(asOf: nextDay))

        XCTAssertEqual(store.projects, state.projects)
        XCTAssertEqual(stateSnapshot(store.groups), stateSnapshot(state.groups))
        XCTAssertTrue(store.recentlyDeletedProjects.isEmpty)
        XCTAssertEqual(store.projectExpirationRevision, 0)
        XCTAssertEqual(persistence.saveCallCount, 1)
    }

    func testRecentlyDeletedProjectMutationsRollBackWhenWritesFail() throws {
        let calendar = Calendar(identifier: .gregorian)
        let deletedAt = try XCTUnwrap(
            DateComponents(calendar: calendar, year: 2026, month: 5, day: 1).date
        )
        let purgeDate = try XCTUnwrap(calendar.date(byAdding: .day, value: 8, to: deletedAt))
        let project = TaskProject(title: "Recoverable")
        let deletedProject = RecentlyDeletedProject(
            project: project,
            deletedAt: deletedAt,
            taskSnapshots: [
                RecentlyDeletedProjectTaskSnapshot(
                    dayID: "2026-05-01",
                    dayDate: deletedAt,
                    reminder: CreateReminder(text: "Restore me", projectID: project.id)
                )
            ]
        )
        let state = DailyTaskGroupState(
            groups: [],
            projects: [],
            selectedProjectID: nil,
            recentlyDeletedProjects: [deletedProject]
        )

        for mutation in [
            { (store: DailyTaskGroupStore) in store.restoreRecentlyDeletedProject(withID: project.id) },
            { (store: DailyTaskGroupStore) in store.permanentlyDeleteRecentlyDeletedProject(withID: project.id) },
            { (store: DailyTaskGroupStore) in store.purgeRecentlyDeletedProjects(asOf: purgeDate) }
        ] {
            let persistence = RecordingDailyTaskGroupPersistence(state: state, failsSaves: true)
            let store = DailyTaskGroupStore(
                calendar: calendar,
                now: { deletedAt },
                persistenceFactory: { _ in persistence }
            )
            RetainedDailyTaskGroupStores.retain(store)

            XCTAssertFalse(mutation(store))
            XCTAssertEqual(store.projects, state.projects)
            XCTAssertEqual(store.groups, state.groups)
            XCTAssertEqual(store.recentlyDeletedProjects, state.recentlyDeletedProjects)
            XCTAssertEqual(persistence.saveCallCount, 1)
        }
    }
}

@MainActor
enum RetainedDailyTaskGroupStores {
    private static var stores: [DailyTaskGroupStore] = []

    static func retain(_ store: DailyTaskGroupStore) {
        stores.append(store)
    }
}

@MainActor
private struct AtomicMutationFixture {
    let calendar = Calendar(identifier: .gregorian)
    let sourceDayID = "2026-05-16"
    let targetDayID = "2026-05-17"
    let project = TaskProject(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!,
        title: "Work"
    )
    let sourceReminder = CreateReminder(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000302")!,
        text: "Carry me",
        projectID: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!,
        createdAt: Date(timeIntervalSinceReferenceDate: 100),
        carryForwardCount: 2
    )
    let remainingSourceReminder = CreateReminder(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000303")!,
        text: "Leave me"
    )
    let existingTargetReminder = CreateReminder(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000304")!,
        text: "Already today"
    )
    let unassignedReminder = CreateReminder(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000305")!,
        text: "Inbox"
    )

    var initialState: DailyTaskGroupState {
        DailyTaskGroupState(
            groups: [
                DailyTaskGroup(
                    id: targetDayID,
                    date: date(year: 2026, month: 5, day: 17),
                    reminders: [
                        existingTargetReminder,
                        CreateReminder(text: "Target project task", projectID: project.id)
                    ]
                ),
                DailyTaskGroup(
                    id: sourceDayID,
                    date: date(year: 2026, month: 5, day: 16),
                    reminders: [sourceReminder, remainingSourceReminder, unassignedReminder]
                )
            ],
            projects: [project],
            selectedProjectID: project.id
        )
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        DateComponents(calendar: calendar, year: year, month: month, day: day).date!
    }
}

@MainActor
private final class RecordingDailyTaskGroupPersistence: DailyTaskGroupPersisting {
    var state: DailyTaskGroupState
    var saveCallCount = 0
    let failsSaves: Bool

    init(state: DailyTaskGroupState, failsSaves: Bool = false) {
        self.state = state
        self.failsSaves = failsSaves
    }

    func load() -> DailyTaskGroupLoadResult {
        .loaded(
            state,
            source: .current(version: DailyTaskGroupPersistenceEnvelope.currentSchemaVersion)
        )
    }

    func save(_ state: DailyTaskGroupState) -> Result<Void, DailyTaskGroupPersistenceError> {
        saveCallCount += 1
        guard !failsSaves else { return .failure(.writeFailed) }
        self.state = state
        return .success(())
    }

    func delete() -> Result<Void, DailyTaskGroupPersistenceError> {
        state = .empty
        return .success(())
    }
}

@MainActor
private func stateSnapshot(_ groups: [DailyTaskGroup]) -> [String] {
    groups.flatMap { group in
        group.reminders.map { reminder in
            [
                group.id,
                reminder.id.uuidString,
                reminder.text,
                String(reminder.isCompleted),
                reminder.projectID?.uuidString ?? "none",
                String(reminder.carryForwardCount)
            ].joined(separator: "|")
        }
    }
}
