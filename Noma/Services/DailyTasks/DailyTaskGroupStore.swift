import Foundation
import Observation

@MainActor
@Observable
final class DailyTaskGroupStore {
    @ObservationIgnored private let persistenceFactory: (String?) -> any DailyTaskGroupPersisting
    @ObservationIgnored private var persistence: any DailyTaskGroupPersisting
    @ObservationIgnored private var blocksPersistenceWrites = false
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var userID: String?

    private(set) var groups: [DailyTaskGroup] = []
    private(set) var persistenceError: DailyTaskGroupPersistenceError?

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
        let factory = persistenceFactory ?? { scopedUserID in
            DailyTaskGroupStorage(
                userDefaults: userDefaults,
                storageKey: storageKey ?? DailyTaskGroupStorage.storageKey(forUserID: scopedUserID)
            )
        }
        self.persistenceFactory = factory
        self.persistence = factory(userID)
        reloadFromPersistence()
    }

    nonisolated static func todayID(calendar: Calendar = .current) -> String {
        dayID(for: Date(), calendar: calendar)
    }

    nonisolated static func dayID(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    nonisolated static func date(forDayID dayID: String, calendar: Calendar = .current) -> Date? {
        let parts = dayID.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return DateComponents(calendar: calendar, year: parts[0], month: parts[1], day: parts[2]).date
    }

    func todayID() -> String {
        Self.todayID(calendar: calendar)
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
        return reminders(forDayID: Self.dayID(for: previousDate, calendar: calendar))
            .filter { !$0.isCompleted }
    }

    func switchUserID(_ userID: String?) {
        guard self.userID != userID else { return }
        self.userID = userID
        persistence = persistenceFactory(userID)
        reloadFromPersistence()
    }

    @discardableResult
    func deleteLocalData(forUserID userID: String?) -> Result<Void, DailyTaskGroupPersistenceError> {
        let result = persistenceFactory(userID).delete()
        if case let .failure(error) = result {
            if self.userID == userID { persistenceError = error }
            return result
        }
        guard self.userID == userID else { return result }
        groups = []
        persistenceError = nil
        blocksPersistenceWrites = false
        return result
    }

    @discardableResult
    func setReminders(_ reminders: [CreateReminder], for date: Date) -> Bool {
        replaceRemindersAtomically(
            reminders,
            forDayID: Self.dayID(for: date, calendar: calendar),
            date: date
        )
    }

    @discardableResult
    func setReminders(_ reminders: [CreateReminder], forDayID dayID: String) -> Bool {
        replaceRemindersAtomically(
            reminders,
            forDayID: dayID,
            date: Self.date(forDayID: dayID, calendar: calendar) ?? now()
        )
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
        var nextGroups = groups
        setReminders(reminders, forDayID: dayID, date: date, in: &nextGroups)
        return commit(groups: nextGroups)
    }

    @discardableResult
    func carryForwardReminders(
        _ requestedReminders: [CreateReminder],
        fromDayID sourceDayID: String,
        toDayID targetDayID: String
    ) -> Bool {
        guard sourceDayID != targetDayID, !requestedReminders.isEmpty else { return false }
        let sourceReminders = reminders(forDayID: sourceDayID)
        let sourceByID = Dictionary(uniqueKeysWithValues: sourceReminders.map { ($0.id, $0) })
        var seenIDs = Set<CreateReminder.ID>()
        let transferred = requestedReminders.compactMap { requested -> CreateReminder? in
            guard seenIDs.insert(requested.id).inserted,
                  let source = sourceByID[requested.id],
                  !source.isCompleted
            else { return nil }
            return source
        }
        guard transferred.count == Set(requestedReminders.map(\.id)).count else { return false }

        var nextGroups = groups
        setReminders(
            reminders(forDayID: targetDayID)
                + transferred.map(CreateReminderCarryForwardTransfer.carriedReminder(from:)),
            forDayID: targetDayID,
            date: Self.date(forDayID: targetDayID, calendar: calendar) ?? now(),
            in: &nextGroups
        )
        setReminders(
            CreateReminderCarryForwardTransfer.sourceRemindersAfterTransfer(
                sourceReminders: sourceReminders,
                transferredReminders: transferred
            ),
            forDayID: sourceDayID,
            date: Self.date(forDayID: sourceDayID, calendar: calendar) ?? now(),
            in: &nextGroups
        )
        return commit(groups: nextGroups)
    }

    private func setReminders(
        _ reminders: [CreateReminder],
        forDayID dayID: String,
        date: Date,
        in groups: inout [DailyTaskGroup]
    ) {
        let reminders = reminders.map { $0.removingProjectAssociation() }
        if reminders.isEmpty {
            groups.removeAll { $0.id == dayID }
        } else if let index = groups.firstIndex(where: { $0.id == dayID }) {
            groups[index] = DailyTaskGroup(id: dayID, date: date, reminders: reminders)
        } else {
            groups.append(DailyTaskGroup(id: dayID, date: date, reminders: reminders))
        }
        groups.sort { $0.date > $1.date }
    }

    private func commit(groups: [DailyTaskGroup]) -> Bool {
        guard !blocksPersistenceWrites else { return false }
        let state = DailyTaskGroupStateCanonicalizer.canonicalState(
            DailyTaskGroupState(groups: groups, projects: [], selectedProjectID: nil)
        )
        switch persistence.save(state) {
        case .success:
            self.groups = state.groups
            persistenceError = nil
            return true
        case let .failure(error):
            persistenceError = error
            return false
        }
    }

    private func reloadFromPersistence() {
        switch persistence.load() {
        case .empty:
            groups = []
            persistenceError = nil
            blocksPersistenceWrites = false
        case let .loaded(state, source):
            let migratedState = DailyTaskGroupStateCanonicalizer.canonicalState(state)
            groups = migratedState.groups
            persistenceError = nil
            blocksPersistenceWrites = false
            guard source != .current(version: DailyTaskGroupPersistenceEnvelope.currentSchemaVersion) else {
                return
            }
            if case let .failure(error) = persistence.save(migratedState) {
                persistenceError = error
            }
        case let .failure(error):
            groups = []
            persistenceError = error
            blocksPersistenceWrites = true
        }
    }
}
