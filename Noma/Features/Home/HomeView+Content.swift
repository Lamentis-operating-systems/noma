import SwiftUI

extension HomeView {
    var createButton: some View {
        PrimaryGlassButton(title: "create.button.title", systemImage: "square.and.pencil") {
            path.append(.create(dayID: dailyTaskGroups.todayID()))
        }
    }

    var dailyGroupsList: some View {
        VStack(alignment: .leading, spacing: NomaSpacing.xxl) {
            if !todayReminders.isEmpty {
                HomeTodaySectionView(
                    reminders: todayReminders,
                    projects: todayProjects,
                    onToggleReminder: toggleTodayReminder,
                    onDeleteReminder: deleteTodayReminder,
                    onSwipeDeleteThreshold: {}
                )
            }

            if !commonProjectSummaries.isEmpty {
                CommonProjectsSectionView(
                    summaries: commonProjectSummaries,
                    onSelectProject: { path.append(.project($0.project.id)) }
                )
            }

            if !dailyGroupSummaries.isEmpty {
                DailyGroupsSectionView(
                    summaries: dailyGroupSummaries,
                    onSelectGroup: { path.append(.create(dayID: $0.id)) }
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, NomaSpacing.xl)
        .padding(.top, NomaSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    var dailyGroupSummaries: [DailyTaskGroupSummary] { dailyTaskGroups.summaries() }
    var commonProjectSummaries: [CommonProjectSummary] { dailyTaskGroups.commonProjectSummaries() }
    var todayID: String { dailyTaskGroups.todayID() }
    var todayProjects: [TaskProject] { dailyTaskGroups.projects(forDayID: todayID) }
    var todayReminders: [CreateReminder] {
        CreateReminderListFilter.visibleReminders(
            dailyTaskGroups.reminders(forDayID: todayID),
            showsOnlyUnsolved: true,
            temporarilyVisibleCompletedReminderIDs: temporarilyVisibleCompletedReminderIDs
        )
    }

    func toggleTodayReminder(_ reminder: CreateReminder) {
        var reminders = dailyTaskGroups.reminders(forDayID: todayID)
        _ = CreateReminderCompletionVisibility.toggleReminderWithCompletionFeedback(
            reminder,
            in: &reminders,
            showsOnlyUnsolved: true,
            visibleIDs: $temporarilyVisibleCompletedReminderIDs,
            hapticFeedback: hapticFeedback,
            persist: { dailyTaskGroups.save(reminders: $0, forDayID: todayID) }
        )
    }

    func deleteTodayReminder(_ reminder: CreateReminder) {
        var reminders = dailyTaskGroups.reminders(forDayID: todayID)
        reminders.removeAll { $0.id == reminder.id }
        withAnimation(.smooth(duration: NomaTiming.taskSwipeRelease)) {
            temporarilyVisibleCompletedReminderIDs.remove(reminder.id)
            dailyTaskGroups.save(reminders: reminders, forDayID: todayID)
        }
    }

    func refreshDailyTaskNotifications() {
        let todayReminders = dailyTaskGroups.reminders(forDayID: dailyTaskGroups.todayID())
        let notificationSettings = appSettings.notificationSettings
        Task {
            await dailyTaskNotifications.refreshDailyTaskReminders(
                for: todayReminders,
                settings: notificationSettings
            )
        }
    }
}
