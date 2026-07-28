import SwiftUI

extension TaskProject {
    var color: Color {
        guard ProjectIconPickerOption.colors.indices.contains(colorIndex) else {
            return ProjectIconPickerOption.colors[ProjectIconPickerOption.defaultColorIndex]
        }
        return ProjectIconPickerOption.colors[colorIndex]
    }
}

enum TaskProjectIconPresentation {
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
}
