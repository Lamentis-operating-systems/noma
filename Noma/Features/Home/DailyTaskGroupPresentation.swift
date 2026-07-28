import Foundation

extension DailyTaskGroupSummary {
    var taskCountUnitKey: String {
        taskCount == 1 ? "home.daily-groups.task-count.singular" : "home.daily-groups.task-count.plural"
    }

    var title: String {
        group.date.formatted(date: .abbreviated, time: .omitted)
    }
}

enum HomeTodaySection {
    static let headerTitleKey = "home.today.section-header"
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
