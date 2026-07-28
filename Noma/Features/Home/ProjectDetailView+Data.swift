import SwiftUI

struct ProjectTaskDaySection: Identifiable, Equatable {
    let group: DailyTaskGroup
    let reminders: [CreateReminder]

    var id: String { group.id }
    var date: Date { group.date }
}

enum ProjectDetailProgressCopy {
    static let incompleteKey = "project.detail.progress.incomplete"

    static func title(for summary: TaskProjectSummary) -> String {
        let taskUnit = String(localized: String.LocalizationValue(summary.taskUnitKey))
        let incomplete = String(localized: String.LocalizationValue(incompleteKey))
        return "\(summary.taskCount) \(taskUnit), \(summary.unsolvedTaskCount) \(incomplete)"
    }
}

enum ProjectDetailAvailability {
    static func isAvailable(projectID: TaskProject.ID, projects: [TaskProject]) -> Bool {
        projects.contains { $0.id == projectID }
    }
}

extension ProjectDetailView {
    var currentProject: TaskProject? {
        guard ProjectDetailAvailability.isAvailable(projectID: projectID, projects: dailyTaskGroups.projects) else {
            return nil
        }
        return dailyTaskGroups.projects.first { $0.id == projectID }
    }

    var projectSummary: TaskProjectSummary {
        guard let currentProject else {
            return TaskProjectSummary(taskCount: 0, unsolvedTaskCount: 0)
        }

        return TaskProjectSummary.summary(for: currentProject, reminders: dailyTaskGroups.allReminders())
    }

    var navigationTitle: String { currentProject?.title ?? "" }

    var navigationSubtitle: String {
        ProjectDetailProgressCopy.title(for: projectSummary)
    }

    var todayID: String { dailyTaskGroups.todayID() }

    var todaySection: ProjectTaskDaySection {
        let group = dailyTaskGroups.groups.first { $0.id == todayID } ?? DailyTaskGroup(
            id: todayID,
            date: DailyTaskGroupStore.date(forDayID: todayID) ?? Date(),
            reminders: []
        )

        return ProjectTaskDaySection(
            group: group,
            reminders: projectReminders(in: group.reminders)
        )
    }

    var pastSections: [ProjectTaskDaySection] {
        let todayDate = DailyTaskGroupStore.date(forDayID: todayID) ?? Date()

        return dailyTaskGroups.groups.compactMap { group in
            guard group.date < todayDate else { return nil }
            let reminders = projectReminders(in: group.reminders)
            guard !reminders.isEmpty else { return nil }
            return ProjectTaskDaySection(group: group, reminders: reminders)
        }
    }

    var visibleTodayReminders: [CreateReminder] {
        visibleReminders(in: todaySection.reminders)
    }

    var canCompleteAllReminders: Bool {
        dailyTaskGroups.allReminders().contains { $0.projectID == projectID && !$0.isCompleted }
    }

    func projectReminders(in reminders: [CreateReminder]) -> [CreateReminder] {
        reminders.filter { $0.projectID == projectID }
    }

    func visibleReminders(in reminders: [CreateReminder]) -> [CreateReminder] {
        CreateReminderListFilter.visibleReminders(
            reminders,
            showsOnlyUnsolved: showsOnlyUnsolvedTasks,
            temporarilyVisibleCompletedReminderIDs: temporarilyVisibleCompletedReminderIDs
        )
    }
}
