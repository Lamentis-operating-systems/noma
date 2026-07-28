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

struct CommonProjectSummary: Equatable, Identifiable {
    let project: TaskProject
    let taskCount: Int
    let unsolvedTaskCount: Int

    var id: TaskProject.ID { project.id }
}

enum DailyTaskGroupStateCanonicalizer {
    static func canonicalState(_ state: DailyTaskGroupState) -> DailyTaskGroupState {
        let projects = uniqueProjects(state.projects)
        let validProjectIDs = Set(projects.map(\.id))
        let groups = state.groups
            .compactMap { group -> DailyTaskGroup? in
                let reminders = group.reminders.filter { reminder in
                    guard let projectID = reminder.projectID else { return true }
                    return validProjectIDs.contains(projectID)
                }
                guard !reminders.isEmpty else { return nil }
                return DailyTaskGroup(id: group.id, date: group.date, reminders: reminders)
            }
            .sorted { $0.date > $1.date }
        let selectedProjectID = state.selectedProjectID.flatMap { projectID in
            validProjectIDs.contains(projectID) ? projectID : nil
        }

        return DailyTaskGroupState(
            groups: groups,
            projects: projects,
            selectedProjectID: selectedProjectID,
            recentlyDeletedProjects: uniqueRecentlyDeletedProjects(state.recentlyDeletedProjects)
        )
    }

    static func uniqueProjects(_ projects: [TaskProject]) -> [TaskProject] {
        var seenIDs = Set<TaskProject.ID>()
        return projects.filter { seenIDs.insert($0.id).inserted }
    }

    private static func uniqueRecentlyDeletedProjects(
        _ projects: [RecentlyDeletedProject]
    ) -> [RecentlyDeletedProject] {
        var seenIDs = Set<TaskProject.ID>()
        return projects.filter { seenIDs.insert($0.project.id).inserted }
    }
}
