@testable import Noma
import XCTest

@MainActor
final class DailyTaskPersistenceTests: XCTestCase {
    func testMissingPersistenceIsExplicitlyEmpty() {
        let storage = DailyTaskGroupStorage(dataStore: InMemoryDailyTaskDataStore())

        XCTAssertEqual(storage.load(), .empty)
    }

    func testReadFailureIsDistinctFromMissingAndCorruptData() {
        let storage = DailyTaskGroupStorage(
            dataStore: InMemoryDailyTaskDataStore(failsReads: true)
        )

        XCTAssertEqual(storage.load(), .failure(.readFailed))
    }

    func testCurrentRoundTripUsesVersionedEnvelopeWithoutLegacyGroupFields() throws {
        let dataStore = InMemoryDailyTaskDataStore()
        let storage = DailyTaskGroupStorage(dataStore: dataStore)
        let state = persistenceFixtureState()

        assertSaveSucceeds(storage.save(state))

        let data = try XCTUnwrap(dataStore.data)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["schemaVersion"] as? Int, DailyTaskGroupPersistenceEnvelope.currentSchemaVersion)
        let encodedState = try XCTUnwrap(json["state"] as? [String: Any])
        let groups = try XCTUnwrap(encodedState["groups"] as? [[String: Any]])
        let group = try XCTUnwrap(groups.first)
        XCTAssertNil(group["projects"])
        XCTAssertNil(group["selectedProjectID"])
        XCTAssertEqual(
            storage.load(),
            .loaded(
                DailyTaskGroupStateCanonicalizer.canonicalState(state),
                source: .current(version: DailyTaskGroupPersistenceEnvelope.currentSchemaVersion)
            )
        )
    }

    func testLegacyGlobalStateMigratesTasksAndStripsProjectMetadata() async {
        let dataStore = InMemoryDailyTaskDataStore(data: GoldenPersistenceFixtures.legacyGlobalState)
        let storage = DailyTaskGroupStorage(dataStore: dataStore)

        let store = DailyTaskGroupStore(persistenceFactory: { _ in storage })

        XCTAssertEqual(store.groups.map(\.id), ["2026-05-16"])
        XCTAssertEqual(store.allReminders().map(\.text), ["Plan launch"])
        XCTAssertTrue(store.allReminders().allSatisfy { $0.projectID == nil })
        XCTAssertNil(store.persistenceError)
        guard let rewrittenData = dataStore.data,
              let json = try? JSONSerialization.jsonObject(with: rewrittenData) as? [String: Any]
        else {
            return XCTFail("Expected migrated data to be rewritten as an envelope")
        }
        XCTAssertEqual(json["schemaVersion"] as? Int, DailyTaskGroupPersistenceEnvelope.currentSchemaVersion)
        let state = json["state"] as? [String: Any]
        XCTAssertNil(state?["projects"])
        XCTAssertNil(state?["selectedProjectID"])
        XCTAssertNil(state?["recentlyDeletedProjects"])
    }

    func testLegacyDayScopedFixtureKeepsTasksWithoutProjects() {
        let storage = DailyTaskGroupStorage(
            dataStore: InMemoryDailyTaskDataStore(data: GoldenPersistenceFixtures.legacyDayGroups)
        )

        guard case let .loaded(state, source) = storage.load() else {
            return XCTFail("Expected legacy day groups to migrate")
        }

        XCTAssertEqual(source, .legacyDayGroups)
        XCTAssertEqual(state.groups.map(\.id), ["2026-05-16"])
        XCTAssertEqual(state.groups.flatMap(\.reminders).map(\.text), ["Plan launch"])
        XCTAssertTrue(state.groups.flatMap(\.reminders).allSatisfy { $0.projectID == nil })
        XCTAssertTrue(state.projects.isEmpty)
        XCTAssertNil(state.selectedProjectID)
    }

    func testCorruptPayloadIsReportedAndStoreDoesNotOverwriteIt() async {
        let corruptData = Data("{ definitely-not-json".utf8)
        let dataStore = InMemoryDailyTaskDataStore(data: corruptData)
        let storage = DailyTaskGroupStorage(dataStore: dataStore)
        let store = DailyTaskGroupStore(persistenceFactory: { _ in storage })

        XCTAssertEqual(storage.load(), .failure(.corruptedData))
        XCTAssertEqual(store.persistenceError, .corruptedData)
        XCTAssertTrue(store.groups.isEmpty)

        store.setReminders([CreateReminder(text: "Must not replace corrupt data")], forDayID: "2026-05-16")

        XCTAssertEqual(dataStore.data, corruptData)
        XCTAssertEqual(store.persistenceError, .corruptedData)
    }

    func testUnsupportedVersionIsReportedWithoutLegacyFallback() {
        let storage = DailyTaskGroupStorage(
            dataStore: InMemoryDailyTaskDataStore(data: GoldenPersistenceFixtures.unsupportedEnvelope)
        )

        XCTAssertEqual(storage.load(), .failure(.unsupportedVersion(99)))
    }

    func testMigrationRestoresTasksFromObsoleteRecentlyDeletedProjectSnapshots() {
        let project = TaskProject(title: "Legacy")
        let reminder = CreateReminder(text: "Still accessible", projectID: project.id)
        let canonical = DailyTaskGroupStateCanonicalizer.canonicalState(
            DailyTaskGroupState(
                groups: [],
                projects: [],
                selectedProjectID: nil,
                recentlyDeletedProjects: [
                    RecentlyDeletedProject(
                        project: project,
                        deletedAt: Date(),
                        taskSnapshots: [
                            RecentlyDeletedProjectTaskSnapshot(
                                dayID: "2026-05-16",
                                dayDate: Date(),
                                reminder: reminder
                            )
                        ]
                    )
                ]
            )
        )

        XCTAssertEqual(canonical.groups.flatMap(\.reminders).map(\.text), ["Still accessible"])
        XCTAssertNil(canonical.groups.first?.reminders.first?.projectID)
        XCTAssertTrue(canonical.recentlyDeletedProjects.isEmpty)
    }

    func testWriteFailureIsObservableThroughStorageAndStore() async {
        let dataStore = InMemoryDailyTaskDataStore(failsWrites: true)
        let storage = DailyTaskGroupStorage(dataStore: dataStore)
        let state = persistenceFixtureState()

        XCTAssertEqual(storage.save(state).failure, .writeFailed)

        let store = DailyTaskGroupStore(persistenceFactory: { _ in storage })
        store.setReminders([CreateReminder(text: "Retry later")], forDayID: "2026-05-16")

        XCTAssertEqual(store.persistenceError, .writeFailed)
    }

    func testUserDefaultsScopesRemainIndependentAndDeletionIsScoped() throws {
        let suiteName = "DailyTaskPersistenceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = DailyTaskGroupStorage(
            userDefaults: defaults,
            storageKey: DailyTaskGroupStorage.storageKey(forUserID: "first")
        )
        let second = DailyTaskGroupStorage(
            userDefaults: defaults,
            storageKey: DailyTaskGroupStorage.storageKey(forUserID: "second")
        )
        var secondState = persistenceFixtureState()
        secondState.groups[0].reminders = [CreateReminder(text: "Second user")]

        assertSaveSucceeds(first.save(persistenceFixtureState()))
        assertSaveSucceeds(second.save(secondState))
        assertDeleteSucceeds(first.delete())

        XCTAssertEqual(first.load(), .empty)
        guard case let .loaded(loadedSecond, _) = second.load() else {
            return XCTFail("Expected second user state")
        }
        XCTAssertEqual(loadedSecond.groups.first?.reminders.map(\.text), ["Second user"])
    }

    func testLargeHistoryHasDeterministicSizeAndRuntimeBaseline() throws {
        let dataStore = InMemoryDailyTaskDataStore()
        let storage = DailyTaskGroupStorage(dataStore: dataStore)
        let calendar = Calendar(identifier: .gregorian)
        let baseDate = try XCTUnwrap(DateComponents(calendar: calendar, year: 2025, month: 1, day: 1).date)
        let groups = (0..<365).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: baseDate) ?? baseDate
            return DailyTaskGroup(
                id: DailyTaskGroupStore.dayID(for: date, calendar: calendar),
                date: date,
                reminders: (0..<20).map { index in
                    CreateReminder(text: "Task \(dayOffset)-\(index)", createdAt: date)
                }
            )
        }
        let state = DailyTaskGroupState(groups: groups, projects: [], selectedProjectID: nil)

        let start = Date()
        assertSaveSucceeds(storage.save(state))
        guard case .loaded = storage.load() else {
            return XCTFail("Expected large history to round trip")
        }
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(try XCTUnwrap(dataStore.data).count, 2_500_000)
        XCTAssertLessThan(elapsed, 2.0)
    }

    private func assertSaveSucceeds(
        _ result: Result<Void, DailyTaskGroupPersistenceError>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if case let .failure(error) = result {
            XCTFail("Expected save to succeed, got \(error)", file: file, line: line)
        }
    }

    private func assertDeleteSucceeds(
        _ result: Result<Void, DailyTaskGroupPersistenceError>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if case let .failure(error) = result {
            XCTFail("Expected delete to succeed, got \(error)", file: file, line: line)
        }
    }
}

@MainActor
private final class InMemoryDailyTaskDataStore: DailyTaskGroupDataStore {
    var data: Data?
    let failsReads: Bool
    let failsWrites: Bool
    let failsDeletes: Bool

    init(
        data: Data? = nil,
        failsReads: Bool = false,
        failsWrites: Bool = false,
        failsDeletes: Bool = false
    ) {
        self.data = data
        self.failsReads = failsReads
        self.failsWrites = failsWrites
        self.failsDeletes = failsDeletes
    }

    func read() throws -> Data? {
        if failsReads { throw TestDataStoreError.forced }
        return data
    }

    func write(_ data: Data) throws {
        if failsWrites { throw TestDataStoreError.forced }
        self.data = data
    }

    func delete() throws {
        if failsDeletes { throw TestDataStoreError.forced }
        data = nil
    }
}

private extension Result where Success == Void, Failure == DailyTaskGroupPersistenceError {
    var failure: DailyTaskGroupPersistenceError? {
        guard case let .failure(error) = self else { return nil }
        return error
    }
}

private enum TestDataStoreError: Error {
    case forced
}

@MainActor
private func persistenceFixtureState() -> DailyTaskGroupState {
    let project = TaskProject(id: GoldenPersistenceFixtures.projectID, title: "Work")
    return DailyTaskGroupState(
        groups: [
            DailyTaskGroup(
                id: "2026-05-16",
                date: Date(timeIntervalSinceReferenceDate: 0),
                reminders: [
                    CreateReminder(
                        id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
                        text: "Plan launch",
                        projectID: project.id,
                        createdAt: Date(timeIntervalSinceReferenceDate: 0)
                    )
                ]
            )
        ],
        projects: [project],
        selectedProjectID: project.id
    )
}

private enum GoldenPersistenceFixtures {
    static let projectID = UUID(uuidString: "00000000-0000-0000-0000-000000000012")!

    static let legacyGlobalState = Data(
        """
        {
          "groups": [{
            "id": "2026-05-16",
            "date": 0,
            "reminders": [{
              "id": "00000000-0000-0000-0000-000000000011",
              "text": "Plan launch",
              "isCompleted": false,
              "projectID": "00000000-0000-0000-0000-000000000012"
            }]
          }],
          "projects": [{
            "id": "00000000-0000-0000-0000-000000000012",
            "title": "Work",
            "symbolName": "folder",
            "colorIndex": 0
          }],
          "selectedProjectID": "00000000-0000-0000-0000-000000000012"
        }
        """.utf8
    )

    static let legacyDayGroups = Data(
        """
        [{
          "id": "2026-05-16",
          "date": 0,
          "reminders": [{
            "id": "00000000-0000-0000-0000-000000000011",
            "text": "Plan launch",
            "isCompleted": false,
            "projectID": "00000000-0000-0000-0000-000000000012"
          }],
          "projects": [{
            "id": "00000000-0000-0000-0000-000000000012",
            "title": "Work",
            "symbolName": "folder",
            "colorIndex": 0
          }],
          "selectedProjectID": "00000000-0000-0000-0000-000000000012"
        }]
        """.utf8
    )

    static let unsupportedEnvelope = Data(
        """
        {"schemaVersion": 99, "state": {}}
        """.utf8
    )
}
