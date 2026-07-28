import Foundation
import Observation

@MainActor
@Observable
final class DailyTaskGroupStore {
    @ObservationIgnored
    private let persistenceFactory: (String?) -> any DailyTaskGroupPersisting

    @ObservationIgnored
    private var persistence: any DailyTaskGroupPersisting

    @ObservationIgnored
    private var blocksPersistenceWrites = false

    @ObservationIgnored
    private let calendar: Calendar

    @ObservationIgnored
    private let now: () -> Date

    @ObservationIgnored
    private var userID: String?
    private(set) var groups: [DailyTaskGroup]

    private(set) var projects: [TaskProject]

    private(set) var recentlyDeletedProjects: [RecentlyDeletedProject]

    private(set) var selectedProjectID: TaskProject.ID?
    private(set) var persistenceError: DailyTaskGroupPersistenceError?
    private(set) var projectExpirationRevision = 0

    init(
        userDefaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        userID: String? = nil,
        storageKey: String? = nil,
        persistenceFactory: ((String?) -> any DailyTaskGroupPersisting)? = nil
    ) {
        self.calendar = calendar
        self.now = now
        self.userID = userID
        let resolvedFactory: (String?) -> any DailyTaskGroupPersisting = persistenceFactory ?? { scopedUserID in
            DailyTaskGroupStorage(
                userDefaults: userDefaults,
                storageKey: storageKey ?? DailyTaskGroupStorage.storageKey(forUserID: scopedUserID)
            )
        }
        self.persistenceFactory = resolvedFactory
        self.persistence = resolvedFactory(userID)
        self.groups = []
        self.projects = []
        self.recentlyDeletedProjects = []
        self.selectedProjectID = nil
        self.persistenceError = nil
        reloadFromPersistence()
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

        return projects
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

    func switchUserID(_ userID: String?) {
        guard self.userID != userID else { return }

        self.userID = userID
        persistence = persistenceFactory(userID)
        reloadFromPersistence()
        expireProjects(asOf: now())
        purgeRecentlyDeletedProjects(asOf: now())
    }

    @discardableResult
    func deleteLocalData(forUserID userID: String?) -> Result<Void, DailyTaskGroupPersistenceError> {
        let result = persistenceFactory(userID).delete()

        if case let .failure(error) = result {
            if self.userID == userID {
                persistenceError = error
            }
            return result
        }

        guard self.userID == userID else { return result }
        groups = []
        projects = []
        recentlyDeletedProjects = []
        selectedProjectID = nil
        persistenceError = nil
        blocksPersistenceWrites = false
        return result
    }

    @discardableResult
    func setReminders(_ reminders: [CreateReminder], for date: Date) -> Bool {
        let dayID = Self.dayID(for: date, calendar: calendar)
        return replaceRemindersAtomically(reminders, forDayID: dayID, date: date)
    }

    @discardableResult
    func setReminders(_ reminders: [CreateReminder], forDayID dayID: String) -> Bool {
        let date = Self.date(forDayID: dayID, calendar: calendar) ?? now()
        return replaceRemindersAtomically(reminders, forDayID: dayID, date: date)
    }

    @discardableResult
    func replaceRemindersAtomically(_ reminders: [CreateReminder], forDayID dayID: String) -> Bool {
        replaceRemindersAtomically(
            reminders,
            forDayID: dayID,
            date: Self.date(forDayID: dayID, calendar: calendar) ?? now()
        )
    }

    @discardableResult
    private func replaceRemindersAtomically(
        _ reminders: [CreateReminder],
        forDayID dayID: String,
        date: Date
    ) -> Bool {
        guard remindersHaveValidProjectReferences(reminders) else { return false }

        var nextState = currentState
        setReminders(
            reminders,
            forDayID: dayID,
            date: date,
            in: &nextState.groups
        )
        return commit(nextState)
    }

    @discardableResult
    func carryForwardReminders(
        _ remindersToCarryForward: [CreateReminder],
        fromDayID sourceDayID: String,
        toDayID targetDayID: String
    ) -> Bool {
        guard sourceDayID != targetDayID, !remindersToCarryForward.isEmpty else { return false }

        let sourceReminders = reminders(forDayID: sourceDayID)
        var sourceReminderByID: [CreateReminder.ID: CreateReminder] = [:]
        sourceReminders.forEach { sourceReminderByID[$0.id] = sourceReminderByID[$0.id] ?? $0 }

        var seenReminderIDs = Set<CreateReminder.ID>()
        var transferredReminders: [CreateReminder] = []
        for requestedReminder in remindersToCarryForward where seenReminderIDs.insert(requestedReminder.id).inserted {
            guard let sourceReminder = sourceReminderByID[requestedReminder.id], !sourceReminder.isCompleted else {
                return false
            }
            transferredReminders.append(sourceReminder)
        }
        guard !transferredReminders.isEmpty else { return false }

        let carriedReminders = transferredReminders.map(CreateReminderCarryForwardTransfer.carriedReminder(from:))
        var nextState = currentState
        setReminders(
            reminders(forDayID: targetDayID) + carriedReminders,
            forDayID: targetDayID,
            date: Self.date(forDayID: targetDayID, calendar: calendar) ?? now(),
            in: &nextState.groups
        )
        setReminders(
            CreateReminderCarryForwardTransfer.sourceRemindersAfterTransfer(
                sourceReminders: sourceReminders,
                transferredReminders: transferredReminders
            ),
            forDayID: sourceDayID,
            date: Self.date(forDayID: sourceDayID, calendar: calendar) ?? now(),
            in: &nextState.groups
        )
        return commit(nextState)
    }

    @discardableResult
    func completeAllReminders(forProjectID projectID: TaskProject.ID) -> Bool {
        guard projects.contains(where: { $0.id == projectID }) else { return false }

        var didChangeReminder = false
        var nextState = currentState
        nextState.groups = nextState.groups.map { group in
            let reminders = group.reminders.map { reminder in
                guard reminder.projectID == projectID, !reminder.isCompleted else { return reminder }
                didChangeReminder = true
                return reminder.togglingCompletion()
            }
            return DailyTaskGroup(id: group.id, date: group.date, reminders: reminders)
        }
        guard didChangeReminder else { return false }

        return commit(nextState)
    }

    @discardableResult
    func addProject(_ project: TaskProject, selecting: Bool) -> Bool {
        guard !projects.contains(where: { $0.id == project.id }) else { return false }

        var nextState = currentState
        nextState.projects.append(project)
        if selecting {
            nextState.selectedProjectID = project.id
        }
        return commit(nextState)
    }

    @discardableResult
    func selectProject(_ projectID: TaskProject.ID?) -> Bool {
        let validProjectID = projectID.flatMap { candidateID in
            projects.contains { $0.id == candidateID } ? candidateID : nil
        }
        guard selectedProjectID != validProjectID else { return true }

        var nextState = currentState
        nextState.selectedProjectID = validProjectID
        return commit(nextState)
    }

    @discardableResult
    func deleteProject(withID projectID: TaskProject.ID) -> Bool {
        deleteProject(withID: projectID, at: now())
    }

    @discardableResult
    func deleteProject(withID projectID: TaskProject.ID, at deletedAt: Date) -> Bool {
        var nextState = currentState
        guard moveProjectToRecentlyDeleted(withID: projectID, at: deletedAt, in: &nextState) else {
            return false
        }
        return commit(nextState)
    }

    @discardableResult
    func expireProjects(asOf date: Date) -> Bool {
        let expiredProjectIDs = projects
            .filter { project in
                isExpired(project, asOf: date)
            }
            .map(\.id)

        guard !expiredProjectIDs.isEmpty else { return true }

        var nextState = currentState
        for projectID in expiredProjectIDs {
            guard moveProjectToRecentlyDeleted(withID: projectID, at: date, in: &nextState) else {
                return false
            }
        }
        guard commit(nextState) else { return false }
        projectExpirationRevision += 1
        return true
    }

    func isExpired(_ project: TaskProject, asOf date: Date) -> Bool {
        guard let expiresAt = project.expiresAt else { return false }
        return calendar.compare(date, to: expiresAt, toGranularity: .day) == .orderedDescending
    }

    @discardableResult
    func restoreRecentlyDeletedProject(withID projectID: TaskProject.ID) -> Bool {
        var nextState = currentState
        guard let index = nextState.recentlyDeletedProjects.firstIndex(where: { $0.project.id == projectID }) else {
            return false
        }
        let deletedProject = nextState.recentlyDeletedProjects.remove(at: index)
        nextState.projects = DailyTaskGroupStateCanonicalizer.uniqueProjects(
            nextState.projects + [deletedProject.project]
        )

        deletedProject.taskSnapshots.forEach { snapshot in
            restore(snapshot: snapshot, in: &nextState.groups)
        }

        nextState.groups.sort { $0.date > $1.date }
        return commit(nextState)
    }

    @discardableResult
    func permanentlyDeleteRecentlyDeletedProject(withID projectID: TaskProject.ID) -> Bool {
        var nextState = currentState
        let originalCount = nextState.recentlyDeletedProjects.count
        nextState.recentlyDeletedProjects.removeAll { $0.project.id == projectID }
        guard nextState.recentlyDeletedProjects.count != originalCount else { return false }
        return commit(nextState)
    }

    @discardableResult
    func purgeRecentlyDeletedProjects(asOf date: Date) -> Bool {
        var nextState = currentState
        let retainedProjects = nextState.recentlyDeletedProjects.filter { deletedProject in
            guard let purgeDate = calendar.date(
                byAdding: .day,
                value: 7,
                to: deletedProject.deletedAt
            ) else { return true }
            return date < purgeDate
        }

        guard retainedProjects != nextState.recentlyDeletedProjects else { return true }
        nextState.recentlyDeletedProjects = retainedProjects
        return commit(nextState)
    }

    private func removeActiveProject(withID projectID: TaskProject.ID, from state: inout DailyTaskGroupState) {
        state.projects.removeAll { $0.id == projectID }

        state.groups = state.groups.compactMap { group in
            var updatedGroup = group
            updatedGroup.reminders.removeAll { $0.projectID == projectID }

            return updatedGroup.reminders.isEmpty ? nil : DailyTaskGroup(
                id: updatedGroup.id,
                date: updatedGroup.date,
                reminders: updatedGroup.reminders
            )
        }

        if state.selectedProjectID == projectID {
            state.selectedProjectID = nil
        }
    }

    @discardableResult
    func updateProject(_ project: TaskProject) -> Bool {
        guard projects.contains(where: { $0.id == project.id }) else { return false }
        guard projects.first(where: { $0.id == project.id }) != project else { return true }

        var nextState = currentState
        nextState.projects = nextState.projects.map { storedProject in
            storedProject.id == project.id ? project : storedProject
        }

        return commit(nextState)
    }

    private func setReminders(
        _ reminders: [CreateReminder],
        forDayID dayID: String,
        date: Date,
        in groups: inout [DailyTaskGroup]
    ) {
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
    }

    private var currentState: DailyTaskGroupState {
        DailyTaskGroupState(
            groups: groups,
            projects: projects,
            selectedProjectID: selectedProjectID,
            recentlyDeletedProjects: recentlyDeletedProjects
        )
    }

    private func remindersHaveValidProjectReferences(_ reminders: [CreateReminder]) -> Bool {
        let validProjectIDs = Set(projects.map(\.id))
        return reminders.allSatisfy { reminder in
            reminder.projectID.map(validProjectIDs.contains) ?? true
        }
    }

    private func commit(_ state: DailyTaskGroupState) -> Bool {
        guard !blocksPersistenceWrites else { return false }
        guard DailyTaskGroupStateCanonicalizer.canonicalState(state) == state else { return false }

        switch persistence.save(state) {
        case .success:
            applyLoadedState(state)
            persistenceError = nil
            return true
        case let .failure(error):
            persistenceError = error
            return false
        }
    }

    private func moveProjectToRecentlyDeleted(
        withID projectID: TaskProject.ID,
        at deletedAt: Date,
        in state: inout DailyTaskGroupState
    ) -> Bool {
        guard let project = state.projects.first(where: { $0.id == projectID }) else { return false }
        let taskSnapshots = state.groups.flatMap { group in
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

        state.recentlyDeletedProjects.removeAll { $0.project.id == projectID }
        state.recentlyDeletedProjects.append(RecentlyDeletedProject(
            project: project,
            deletedAt: deletedAt,
            taskSnapshots: taskSnapshots
        ))
        removeActiveProject(withID: projectID, from: &state)
        return true
    }

    private func restore(snapshot: RecentlyDeletedProjectTaskSnapshot, in groups: inout [DailyTaskGroup]) {
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

    private func reloadFromPersistence() {
        switch persistence.load() {
        case .empty:
            applyLoadedState(.empty)
            persistenceError = nil
            blocksPersistenceWrites = false
        case let .loaded(state, source):
            applyLoadedState(state)
            persistenceError = nil
            blocksPersistenceWrites = false

            guard source != .current(version: DailyTaskGroupPersistenceEnvelope.currentSchemaVersion) else {
                return
            }
            if case let .failure(error) = persistence.save(state) {
                persistenceError = error
            }
        case let .failure(error):
            applyLoadedState(.empty)
            persistenceError = error
            blocksPersistenceWrites = true
        }
    }

    private func applyLoadedState(_ state: DailyTaskGroupState) {
        groups = state.groups
        projects = state.projects
        recentlyDeletedProjects = state.recentlyDeletedProjects
        selectedProjectID = state.selectedProjectID
    }
}
