import Foundation
import Observation

@MainActor
@Observable
final class DailyTaskGroupStore {
    @ObservationIgnored
    private let userDefaults: UserDefaults

    @ObservationIgnored
    private var storage: DailyTaskGroupStorage

    @ObservationIgnored
    private let calendar: Calendar

    @ObservationIgnored
    private let now: () -> Date

    @ObservationIgnored
    private let usesMockData: Bool

    @ObservationIgnored
    private var userID: String?
    private(set) var groups: [DailyTaskGroup]

    @ObservationIgnored
    private(set) var storedProjects: [TaskProject]

    private(set) var recentlyDeletedProjects: [RecentlyDeletedProject]

    @ObservationIgnored
    private(set) var storedSelectedProjectID: TaskProject.ID?

    init(
        userDefaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        userID: String? = nil,
        storageKey: String? = nil,
        usesMockData: Bool = false
    ) {
        self.userDefaults = userDefaults
        self.calendar = calendar
        self.now = now
        self.usesMockData = usesMockData
        self.userID = userID
        self.storage = DailyTaskGroupStorage(
            userDefaults: userDefaults,
            storageKey: storageKey ?? DailyTaskGroupStorage.storageKey(forUserID: userID)
        )
        let state = storage.loadState(usesMockData: usesMockData, calendar: calendar)
        self.groups = state.groups
        self.storedProjects = state.projects
        self.recentlyDeletedProjects = state.recentlyDeletedProjects
        self.storedSelectedProjectID = state.selectedProjectID
        expireProjects(asOf: now())
        purgeRecentlyDeletedProjects(asOf: now())
    }

    nonisolated static func todayID(calendar: Calendar = .current) -> String {
        dayID(for: Date(), calendar: calendar)
    }

    nonisolated static func dayID(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    nonisolated static func date(forDayID dayID: String, calendar: Calendar = .current) -> Date? {
        let parts = dayID.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return DateComponents(calendar: calendar, year: parts[0], month: parts[1], day: parts[2]).date
    }

    func todayID() -> String {
        Self.todayID(calendar: calendar)
    }

    func summaries() -> [DailyTaskGroupSummary] {
        groups
            .filter { !$0.reminders.isEmpty }
            .map(DailyTaskGroupSummary.init(group:))
    }

    func commonProjectSummaries(limit: Int = 3) -> [CommonProjectSummary] {
        let reminders = allReminders()

        return storedProjects
            .map { project in
                let projectReminders = reminders.filter { $0.projectID == project.id }
                return CommonProjectSummary(
                    project: project,
                    taskCount: projectReminders.count,
                    unsolvedTaskCount: projectReminders.filter { !$0.isCompleted }.count
                )
            }
            .filter { $0.taskCount > 0 }
            .sorted {
                if $0.taskCount == $1.taskCount {
                    return $0.project.title.localizedStandardCompare($1.project.title) == .orderedAscending
                }
                return $0.taskCount > $1.taskCount
            }
            .prefix(limit)
            .map(\.self)
    }

    func reminders(forDayID dayID: String) -> [CreateReminder] {
        groups.first { $0.id == dayID }?.reminders ?? []
    }

    func allReminders() -> [CreateReminder] {
        groups.flatMap(\.reminders)
    }

    func openRemindersFromPreviousDay(beforeDayID dayID: String) -> [CreateReminder] {
        guard let date = Self.date(forDayID: dayID, calendar: calendar),
              let previousDate = calendar.date(byAdding: .day, value: -1, to: date)
        else { return [] }
        let previousDayID = Self.dayID(for: previousDate, calendar: calendar)
        return reminders(forDayID: previousDayID).filter { !$0.isCompleted }
    }

    func projects(forDayID _: String) -> [TaskProject] {
        storedProjects
    }

    func selectedProjectID(forDayID _: String) -> TaskProject.ID? {
        storedSelectedProjectID
    }

    func switchUserID(_ userID: String?) {
        guard self.userID != userID else { return }

        self.userID = userID
        storage = DailyTaskGroupStorage(
            userDefaults: userDefaults,
            storageKey: DailyTaskGroupStorage.storageKey(forUserID: userID)
        )
        let state = storage.loadState(usesMockData: usesMockData, calendar: calendar)
        groups = state.groups
        storedProjects = state.projects
        recentlyDeletedProjects = state.recentlyDeletedProjects
        storedSelectedProjectID = state.selectedProjectID
        expireProjects(asOf: now())
        purgeRecentlyDeletedProjects(asOf: now())
    }

    func deleteLocalData(forUserID userID: String?) {
        DailyTaskGroupStorage.deleteState(forUserID: userID, userDefaults: userDefaults)

        guard self.userID == userID else { return }
        groups = []
        storedProjects = []
        recentlyDeletedProjects = []
        storedSelectedProjectID = nil
    }

    func save(reminders: [CreateReminder], for date: Date) {
        let dayID = Self.dayID(for: date, calendar: calendar)
        save(reminders: reminders, forDayID: dayID, date: date)
    }

    func save(reminders: [CreateReminder], forDayID dayID: String) {
        let date = Self.date(forDayID: dayID, calendar: calendar) ?? Date()
        save(reminders: reminders, forDayID: dayID, date: date)
    }

    private func save(reminders: [CreateReminder], forDayID dayID: String, date: Date) {
        save(
            reminders: reminders,
            projects: storedProjects,
            selectedProjectID: storedSelectedProjectID,
            forDayID: dayID,
            date: date
        )
    }

    func save(
        reminders: [CreateReminder],
        projects: [TaskProject],
        selectedProjectID: TaskProject.ID?,
        forDayID dayID: String
    ) {
        let date = Self.date(forDayID: dayID, calendar: calendar) ?? Date()
        save(
            reminders: reminders,
            projects: projects,
            selectedProjectID: selectedProjectID,
            forDayID: dayID,
            date: date
        )
    }

    func deleteProject(withID projectID: TaskProject.ID) {
        deleteProject(withID: projectID, at: now())
    }

    func deleteProject(withID projectID: TaskProject.ID, at deletedAt: Date) {
        guard let project = storedProjects.first(where: { $0.id == projectID }) else { return }
        let taskSnapshots = groups.flatMap { group in
            group.reminders
                .filter { $0.projectID == projectID }
                .map {
                    RecentlyDeletedProjectTaskSnapshot(
                        dayID: group.id,
                        dayDate: group.date,
                        reminder: $0
                    )
                }
        }
        .sorted { $0.dayDate < $1.dayDate }

        recentlyDeletedProjects.removeAll { $0.project.id == projectID }
        recentlyDeletedProjects.append(RecentlyDeletedProject(
            project: project,
            deletedAt: deletedAt,
            taskSnapshots: taskSnapshots
        ))

        removeActiveProject(withID: projectID)
        persist()
    }

    func expireProjects(asOf date: Date) {
        let expiredProjectIDs = storedProjects
            .filter { project in
                guard let expiresAt = project.expiresAt else { return false }
                return expiresAt <= date
            }
            .map(\.id)

        guard !expiredProjectIDs.isEmpty else { return }

        expiredProjectIDs.forEach { deleteProject(withID: $0, at: date) }
    }

    func restoreRecentlyDeletedProject(withID projectID: TaskProject.ID) {
        guard let index = recentlyDeletedProjects.firstIndex(where: { $0.project.id == projectID }) else { return }
        let deletedProject = recentlyDeletedProjects.remove(at: index)
        storedProjects = uniqueProjects(in: storedProjects + [deletedProject.project])

        deletedProject.taskSnapshots.forEach { snapshot in
            restore(snapshot: snapshot)
        }

        groups.sort { $0.date > $1.date }
        persist()
    }

    func permanentlyDeleteRecentlyDeletedProject(withID projectID: TaskProject.ID) {
        recentlyDeletedProjects.removeAll { $0.project.id == projectID }
        persist()
    }

    func purgeRecentlyDeletedProjects(asOf date: Date) {
        let retainedProjects = recentlyDeletedProjects.filter { deletedProject in
            guard let purgeDate = calendar.date(
                byAdding: .day,
                value: 7,
                to: deletedProject.deletedAt
            ) else { return true }
            return date < purgeDate
        }

        guard retainedProjects != recentlyDeletedProjects else { return }
        recentlyDeletedProjects = retainedProjects
        persist()
    }

    private func removeActiveProject(withID projectID: TaskProject.ID) {
        storedProjects.removeAll { $0.id == projectID }

        groups = groups.compactMap { group in
            var updatedGroup = group
            updatedGroup.reminders.removeAll { $0.projectID == projectID }

            return updatedGroup.reminders.isEmpty ? nil : DailyTaskGroup(
                id: updatedGroup.id,
                date: updatedGroup.date,
                reminders: updatedGroup.reminders
            )
        }

        if storedSelectedProjectID == projectID {
            storedSelectedProjectID = nil
        }
    }

    func updateProject(_ project: TaskProject) {
        storedProjects = storedProjects.map { storedProject in
            storedProject.id == project.id ? project : storedProject
        }

        persist()
    }

    private func save(
        reminders: [CreateReminder],
        projects: [TaskProject],
        selectedProjectID: TaskProject.ID?,
        forDayID dayID: String,
        date: Date
    ) {
        storedProjects = uniqueProjects(in: projects)
        storedSelectedProjectID = selectedProjectID.flatMap { projectID in
            storedProjects.contains { $0.id == projectID } ? projectID : nil
        }

        if reminders.isEmpty {
            groups.removeAll { $0.id == dayID }
        } else if let index = groups.firstIndex(where: { $0.id == dayID }) {
            groups[index] = DailyTaskGroup(
                id: dayID,
                date: date,
                reminders: reminders
            )
        } else {
            groups.append(DailyTaskGroup(
                id: dayID,
                date: date,
                reminders: reminders
            ))
        }

        groups.sort { $0.date > $1.date }
        persist()
    }

    private func persist() {
        storage.save(
            state: DailyTaskGroupState(
                groups: groups,
                projects: storedProjects,
                selectedProjectID: storedSelectedProjectID,
                recentlyDeletedProjects: recentlyDeletedProjects
            )
        )
    }

    private func restore(snapshot: RecentlyDeletedProjectTaskSnapshot) {
        if let index = groups.firstIndex(where: { $0.id == snapshot.dayID }) {
            guard !groups[index].reminders.contains(where: { $0.id == snapshot.reminder.id }) else { return }
            groups[index].reminders.append(snapshot.reminder)
            return
        }

        groups.append(DailyTaskGroup(
            id: snapshot.dayID,
            date: snapshot.dayDate,
            reminders: [snapshot.reminder]
        ))
    }

    private func uniqueProjects(in projects: [TaskProject]) -> [TaskProject] {
        var seenIDs = Set<TaskProject.ID>()
        return projects.filter { project in
            seenIDs.insert(project.id).inserted
        }
    }
}
