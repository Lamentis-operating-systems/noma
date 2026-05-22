import Foundation

struct DailyTaskGroupStorage {
    nonisolated static let defaultStorageKey = "noma.daily-task-groups"
    nonisolated static let signedOutStorageScope = "signed-out"

    let userDefaults: UserDefaults
    let storageKey: String

    nonisolated static func storageKey(forUserID userID: String?) -> String {
        let scope = userID ?? signedOutStorageScope
        return "\(defaultStorageKey).\(scope)"
    }

    init(userDefaults: UserDefaults = .standard, storageKey: String = DailyTaskGroupStorage.defaultStorageKey) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    func loadState(usesMockData: Bool = false, calendar: Calendar = .current) -> DailyTaskGroupState {
        guard let data = userDefaults.data(forKey: storageKey) else {
            if usesMockData {
                return DailyTaskGroupFixtures.state(calendar: calendar)
            }
            return DailyTaskGroupState(groups: [], projects: [], selectedProjectID: nil)
        }

        if let state = try? JSONDecoder().decode(DailyTaskGroupState.self, from: data) {
            return sanitized(state: state)
        }

        guard let groups = try? JSONDecoder().decode([DailyTaskGroup].self, from: data) else {
            return DailyTaskGroupState(groups: [], projects: [], selectedProjectID: nil)
        }

        return migratedState(from: groups)
    }

    func loadGroups() -> [DailyTaskGroup] {
        loadState().groups
    }

    func save(groups: [DailyTaskGroup]) {
        save(state: migratedState(from: groups))
    }

    func save(state: DailyTaskGroupState) {
        guard let data = try? JSONEncoder().encode(sanitized(state: state)) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    private func migratedState(from groups: [DailyTaskGroup]) -> DailyTaskGroupState {
        let projects = uniqueProjects(in: groups.flatMap(\.projects))
        let selectedProjectID = groups.first { group in
            projects.contains { $0.id == group.selectedProjectID }
        }?.selectedProjectID

        return sanitized(
            state: DailyTaskGroupState(
                groups: groups,
                projects: projects,
                selectedProjectID: selectedProjectID
            )
        )
    }

    private func sanitized(state: DailyTaskGroupState) -> DailyTaskGroupState {
        let projects = uniqueProjects(in: state.projects)
        let validProjectIDs = Set(projects.map(\.id))
        let groups = state.groups
            .compactMap { group -> DailyTaskGroup? in
                let reminders = group.reminders.filter { reminder in
                    guard let projectID = reminder.projectID else { return true }
                    return validProjectIDs.contains(projectID)
                }
                guard !reminders.isEmpty else { return nil }
                return DailyTaskGroup(
                    id: group.id,
                    date: group.date,
                    reminders: reminders
                )
            }
            .sorted { $0.date > $1.date }
        let selectedProjectID = state.selectedProjectID.flatMap { projectID in
            validProjectIDs.contains(projectID) ? projectID : nil
        }
        let recentlyDeletedProjects = uniqueRecentlyDeletedProjects(in: state.recentlyDeletedProjects)

        return DailyTaskGroupState(
            groups: groups,
            projects: projects,
            selectedProjectID: selectedProjectID,
            recentlyDeletedProjects: recentlyDeletedProjects
        )
    }

}
