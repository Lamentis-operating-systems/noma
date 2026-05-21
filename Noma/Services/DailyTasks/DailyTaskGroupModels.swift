import Foundation

struct DailyTaskGroup: Codable, Equatable, Identifiable {
    let id: String
    let date: Date
    var reminders: [CreateReminder]
    // Kept for decoding legacy day-scoped project payloads. New writes keep
    // projects in DailyTaskGroupState so projects remain available across days.
    var projects: [TaskProject]
    var selectedProjectID: TaskProject.ID?

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

    enum CodingKeys: String, CodingKey {
        case groups
        case projects
        case selectedProjectID
        case recentlyDeletedProjects
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        groups = try container.decode([DailyTaskGroup].self, forKey: .groups)
        projects = try container.decode([TaskProject].self, forKey: .projects)
        selectedProjectID = try container.decodeIfPresent(TaskProject.ID.self, forKey: .selectedProjectID)
        recentlyDeletedProjects = try container.decodeIfPresent(
            [RecentlyDeletedProject].self,
            forKey: .recentlyDeletedProjects
        ) ?? []
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
    var taskCountUnitKey: String {
        taskCount == 1 ? "home.daily-groups.task-count.singular" : "home.daily-groups.task-count.plural"
    }

    var title: String {
        group.date.formatted(date: .abbreviated, time: .omitted)
    }
}

struct CommonProjectSummary: Equatable, Identifiable {
    let project: TaskProject
    let taskCount: Int
    let unsolvedTaskCount: Int

    var id: TaskProject.ID { project.id }
    var taskUnitKey: String {
        taskCount == 1 ? "create.projects.stats.task.singular" : "create.projects.stats.task.plural"
    }
}

enum CommonProjectsSection {
    static let headerTitleKey = "home.common-projects.section-header"

    static func taskCountText(for summary: CommonProjectSummary) -> String {
        "\(summary.taskCount)"
    }
}

enum HomeTodaySection {
    static let headerTitleKey = "home.today.section-header"
}

enum DailyTaskGroupsSection {
    static let headerTitleKey = "home.daily-groups.section-header"
}

enum DailyTaskGroupsProgressCopy {
    static let ofKey = "home.daily-groups.progress.of"
    static let completedKey = "home.daily-groups.progress.completed"

    static func title(for summary: DailyTaskGroupSummary) -> String {
        let of = String(localized: String.LocalizationValue(ofKey))
        let taskCountUnit = String(localized: String.LocalizationValue(summary.taskCountUnitKey))
        let completed = String(localized: String.LocalizationValue(completedKey))
        return "\(summary.completedTaskCount) \(of) \(summary.taskCount) \(taskCountUnit) \(completed)"
    }
}
