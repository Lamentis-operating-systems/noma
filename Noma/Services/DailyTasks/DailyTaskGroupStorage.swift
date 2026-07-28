import Foundation

enum DailyTaskGroupPersistenceError: Error, Equatable {
    case readFailed
    case corruptedData
    case unsupportedVersion(Int)
    case encodingFailed
    case writeFailed
    case deleteFailed
}

enum DailyTaskGroupLoadSource: Equatable {
    case current(version: Int)
    case legacyState
    case legacyDayGroups
}

enum DailyTaskGroupLoadResult: Equatable {
    case empty
    case loaded(DailyTaskGroupState, source: DailyTaskGroupLoadSource)
    case failure(DailyTaskGroupPersistenceError)
}

protocol DailyTaskGroupPersisting {
    func load() -> DailyTaskGroupLoadResult
    func save(_ state: DailyTaskGroupState) -> Result<Void, DailyTaskGroupPersistenceError>
    func delete() -> Result<Void, DailyTaskGroupPersistenceError>
}

protocol DailyTaskGroupDataStore {
    func read() throws -> Data?
    func write(_ data: Data) throws
    func delete() throws
}

struct UserDefaultsDailyTaskGroupDataStore: DailyTaskGroupDataStore {
    let userDefaults: UserDefaults
    let storageKey: String

    func read() throws -> Data? {
        userDefaults.data(forKey: storageKey)
    }

    func write(_ data: Data) throws {
        userDefaults.set(data, forKey: storageKey)
    }

    func delete() throws {
        userDefaults.removeObject(forKey: storageKey)
        guard userDefaults.synchronize() else {
            throw UserDefaultsDailyTaskGroupDataStoreError.commitFailed
        }
    }
}

private enum UserDefaultsDailyTaskGroupDataStoreError: Error {
    case commitFailed
}

struct DailyTaskGroupPersistenceEnvelope: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let state: DailyTaskGroupState

    init(state: DailyTaskGroupState) {
        schemaVersion = Self.currentSchemaVersion
        self.state = state
    }
}

struct DailyTaskGroupStorage: DailyTaskGroupPersisting {
    nonisolated static let defaultStorageKey = "noma.daily-task-groups"
    nonisolated static let signedOutStorageScope = "signed-out"

    let dataStore: any DailyTaskGroupDataStore

    nonisolated static func storageKey(forUserID userID: String?) -> String {
        let scope = userID ?? signedOutStorageScope
        return "\(defaultStorageKey).\(scope)"
    }

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = DailyTaskGroupStorage.defaultStorageKey
    ) {
        dataStore = UserDefaultsDailyTaskGroupDataStore(
            userDefaults: userDefaults,
            storageKey: storageKey
        )
    }

    init(dataStore: any DailyTaskGroupDataStore) {
        self.dataStore = dataStore
    }

    func load() -> DailyTaskGroupLoadResult {
        let data: Data
        do {
            guard let storedData = try dataStore.read() else { return .empty }
            data = storedData
        } catch {
            return .failure(.readFailed)
        }

        let decoder = JSONDecoder()
        if let header = try? decoder.decode(DailyTaskGroupEnvelopeHeader.self, from: data) {
            guard header.schemaVersion == DailyTaskGroupPersistenceEnvelope.currentSchemaVersion else {
                return .failure(.unsupportedVersion(header.schemaVersion))
            }

            do {
                let envelope = try decoder.decode(DailyTaskGroupPersistenceEnvelope.self, from: data)
                return .loaded(
                    DailyTaskGroupStateCanonicalizer.canonicalState(envelope.state),
                    source: .current(version: envelope.schemaVersion)
                )
            } catch {
                return .failure(.corruptedData)
            }
        }

        if let legacyState = try? decoder.decode(LegacyDailyTaskGroupStateDTO.self, from: data) {
            return .loaded(legacyState.migratedState(), source: .legacyState)
        }

        if let legacyGroups = try? decoder.decode([LegacyDailyTaskGroupDTO].self, from: data) {
            return .loaded(
                LegacyDailyTaskGroupStateDTO(groups: legacyGroups).migratedState(),
                source: .legacyDayGroups
            )
        }

        return .failure(.corruptedData)
    }

    func save(_ state: DailyTaskGroupState) -> Result<Void, DailyTaskGroupPersistenceError> {
        let data: Data
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            data = try encoder.encode(
                DailyTaskGroupPersistenceEnvelope(
                    state: DailyTaskGroupStateCanonicalizer.canonicalState(state)
                )
            )
        } catch {
            return .failure(.encodingFailed)
        }

        do {
            try dataStore.write(data)
            return .success(())
        } catch {
            return .failure(.writeFailed)
        }
    }

    func delete() -> Result<Void, DailyTaskGroupPersistenceError> {
        do {
            try dataStore.delete()
            return .success(())
        } catch {
            return .failure(.deleteFailed)
        }
    }
}

private struct DailyTaskGroupEnvelopeHeader: Decodable {
    let schemaVersion: Int
}

private struct LegacyDailyTaskGroupDTO: Decodable {
    let id: String
    let date: Date
    let reminders: [CreateReminder]
    let projects: [TaskProject]
    let selectedProjectID: TaskProject.ID?

    init(
        id: String,
        date: Date,
        reminders: [CreateReminder],
        projects: [TaskProject] = [],
        selectedProjectID: TaskProject.ID? = nil
    ) {
        self.id = id
        self.date = date
        self.reminders = reminders
        self.projects = projects
        self.selectedProjectID = selectedProjectID
    }

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case reminders
        case projects
        case selectedProjectID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        reminders = try container.decode([CreateReminder].self, forKey: .reminders)
        projects = try container.decodeIfPresent([TaskProject].self, forKey: .projects) ?? []
        selectedProjectID = try container.decodeIfPresent(TaskProject.ID.self, forKey: .selectedProjectID)
    }

    var currentGroup: DailyTaskGroup {
        DailyTaskGroup(id: id, date: date, reminders: reminders)
    }
}

private struct LegacyDailyTaskGroupStateDTO: Decodable {
    let groups: [LegacyDailyTaskGroupDTO]
    let projects: [TaskProject]
    let selectedProjectID: TaskProject.ID?
    let recentlyDeletedProjects: [RecentlyDeletedProject]

    init(
        groups: [LegacyDailyTaskGroupDTO],
        projects: [TaskProject] = [],
        selectedProjectID: TaskProject.ID? = nil,
        recentlyDeletedProjects: [RecentlyDeletedProject] = []
    ) {
        self.groups = groups
        self.projects = projects
        self.selectedProjectID = selectedProjectID
        self.recentlyDeletedProjects = recentlyDeletedProjects
    }

    enum CodingKeys: String, CodingKey {
        case groups
        case projects
        case selectedProjectID
        case recentlyDeletedProjects
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        groups = try container.decode([LegacyDailyTaskGroupDTO].self, forKey: .groups)
        projects = try container.decodeIfPresent([TaskProject].self, forKey: .projects) ?? []
        selectedProjectID = try container.decodeIfPresent(TaskProject.ID.self, forKey: .selectedProjectID)
        recentlyDeletedProjects = try container.decodeIfPresent(
            [RecentlyDeletedProject].self,
            forKey: .recentlyDeletedProjects
        ) ?? []
    }

    func migratedState() -> DailyTaskGroupState {
        let allProjects = DailyTaskGroupStateCanonicalizer.uniqueProjects(
            projects + groups.flatMap(\.projects)
        )
        let validProjectIDs = Set(allProjects.map(\.id))
        let migratedSelectedProjectID = selectedProjectID ?? groups
            .compactMap(\.selectedProjectID)
            .first { validProjectIDs.contains($0) }

        return DailyTaskGroupStateCanonicalizer.canonicalState(
            DailyTaskGroupState(
                groups: groups.map(\.currentGroup),
                projects: allProjects,
                selectedProjectID: migratedSelectedProjectID,
                recentlyDeletedProjects: recentlyDeletedProjects
            )
        )
    }
}
