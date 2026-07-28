import Foundation

struct DailyTaskGroup: Codable, Equatable, Identifiable {
    let id: String
    let date: Date
    var reminders: [CreateReminder]

    var taskCount: Int { reminders.count }
}

struct DailyTaskGroupState: Codable, Equatable {
    var groups: [DailyTaskGroup]
    var projects: [TaskProject]
    var selectedProjectID: TaskProject.ID?
    var recentlyDeletedProjects: [RecentlyDeletedProject]

    init(
        groups: [DailyTaskGroup],
        projects: [TaskProject],
        selectedProjectID: TaskProject.ID?,
        recentlyDeletedProjects: [RecentlyDeletedProject] = []
    ) {
        self.groups = groups
        self.projects = projects
        self.selectedProjectID = selectedProjectID
        self.recentlyDeletedProjects = recentlyDeletedProjects
    }

    static let empty = DailyTaskGroupState(
        groups: [],
        projects: [],
        selectedProjectID: nil
    )

    enum CodingKeys: String, CodingKey {
        case groups
        case projects
        case selectedProjectID
        case recentlyDeletedProjects
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        groups = try container.decode([DailyTaskGroup].self, forKey: .groups)
        projects = try container.decodeIfPresent([TaskProject].self, forKey: .projects) ?? []
        selectedProjectID = try container.decodeIfPresent(TaskProject.ID.self, forKey: .selectedProjectID)
        recentlyDeletedProjects = try container.decodeIfPresent(
            [RecentlyDeletedProject].self,
            forKey: .recentlyDeletedProjects
        ) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(groups, forKey: .groups)
    }
}

struct RecentlyDeletedProject: Codable, Equatable, Identifiable {
    let project: TaskProject
    let deletedAt: Date
    let taskSnapshots: [RecentlyDeletedProjectTaskSnapshot]

    var id: TaskProject.ID { project.id }
}

struct RecentlyDeletedProjectTaskSnapshot: Codable, Equatable, Identifiable {
    let dayID: String
    let dayDate: Date
    let reminder: CreateReminder

    var id: CreateReminder.ID { reminder.id }
}

struct DailyTaskGroupSummary: Equatable, Identifiable {
    let group: DailyTaskGroup

    var id: String { group.id }
    var taskCount: Int { group.taskCount }
    var completedTaskCount: Int { group.reminders.filter(\.isCompleted).count }
    var isCompleted: Bool { taskCount > 0 && completedTaskCount == taskCount }
}

enum DailyTaskGroupStateCanonicalizer {
    static func canonicalState(_ state: DailyTaskGroupState) -> DailyTaskGroupState {
        var groupsByID = Dictionary(uniqueKeysWithValues: state.groups.map { ($0.id, $0) })

        for deletedProject in state.recentlyDeletedProjects {
            for snapshot in deletedProject.taskSnapshots {
                if var group = groupsByID[snapshot.dayID] {
                    if !group.reminders.contains(where: { $0.id == snapshot.reminder.id }) {
                        group.reminders.append(snapshot.reminder)
                        groupsByID[snapshot.dayID] = group
                    }
                } else {
                    groupsByID[snapshot.dayID] = DailyTaskGroup(
                        id: snapshot.dayID,
                        date: snapshot.dayDate,
                        reminders: [snapshot.reminder]
                    )
                }
            }
        }

        return DailyTaskGroupState(
            groups: groupsByID.values
                .compactMap { group in
                    let reminders = uniqueReminders(group.reminders)
                        .map { $0.removingProjectAssociation() }
                    guard !reminders.isEmpty else { return nil }
                    return DailyTaskGroup(id: group.id, date: group.date, reminders: reminders)
                }
                .sorted { $0.date > $1.date },
            projects: [],
            selectedProjectID: nil,
            recentlyDeletedProjects: []
        )
    }

    private static func uniqueReminders(_ reminders: [CreateReminder]) -> [CreateReminder] {
        var seenIDs = Set<CreateReminder.ID>()
        return reminders.filter { seenIDs.insert($0.id).inserted }
    }

}
