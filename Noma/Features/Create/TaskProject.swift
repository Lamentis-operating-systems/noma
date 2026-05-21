import SwiftUI

struct TaskProject: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let symbolName: String
    let colorIndex: Int
    let expiresAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        symbolName: String = ProjectIconPickerOption.defaultSymbol,
        colorIndex: Int = ProjectIconPickerOption.defaultColorIndex,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.colorIndex = colorIndex
        self.expiresAt = expiresAt
    }

    var color: Color {
        guard ProjectIconPickerOption.colors.indices.contains(colorIndex) else {
            return ProjectIconPickerOption.colors[ProjectIconPickerOption.defaultColorIndex]
        }
        return ProjectIconPickerOption.colors[colorIndex]
    }
}

enum TaskProjectIconPresentation {
    static let usesNeutralTintInAppSurfaces = true

    static var appSurfaceColor: Color { .textPrimary }
}

enum TaskProjectTitlePolicy {
    static let characterLimit = NomaLimit.projectTitleCharacters

    static func normalizedTitle(from title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func canCreateProject(title: String) -> Bool {
        let normalizedTitle = normalizedTitle(from: title)
        return !normalizedTitle.isEmpty && normalizedTitle.count <= characterLimit
    }
}

struct TaskProjectSummary: Equatable {
    let taskCount: Int
    let unsolvedTaskCount: Int

    var taskUnitKey: String {
        taskCount == 1 ? "create.projects.stats.task.singular" : "create.projects.stats.task.plural"
    }

    static func summary(for project: TaskProject, reminders: [CreateReminder]) -> TaskProjectSummary {
        let projectReminders = reminders.filter { $0.projectID == project.id }
        return TaskProjectSummary(
            taskCount: projectReminders.count,
            unsolvedTaskCount: projectReminders.filter { !$0.isCompleted }.count
        )
    }

    static func withoutProject(reminders: [CreateReminder]) -> TaskProjectSummary {
        let unassignedReminders = reminders.filter { $0.projectID == nil }
        return TaskProjectSummary(
            taskCount: unassignedReminders.count,
            unsolvedTaskCount: unassignedReminders.filter { !$0.isCompleted }.count
        )
    }
}

enum TaskProjectStatsCopy {
    static let unsolvedKey = "create.projects.stats.unsolved"
}
