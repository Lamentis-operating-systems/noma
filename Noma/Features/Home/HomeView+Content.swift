import SwiftUI

extension HomeView {
    var createButton: some View {
        PrimaryGlassButton(title: "create.button.title", systemImage: "square.and.pencil") {
            path.append(.create(dayID: dailyTaskGroups.todayID()))
        }
        .accessibilityIdentifier("home-create-button")
    }

    var dailyGroupsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsEmptyState {
                HomeEmptyHint()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if showsTodaySection {
                todaySection
            }

            if showsProjectSection {
                if showsTodaySection {
                    HomeSectionDivider()
                }

                CommonProjectsSectionView(
                    summaries: commonProjectSummaries,
                    onSelectProject: { path.append(.project($0.project.id)) }
                )
            }

            if showsDailyGroupsSection {
                if showsTodaySection || showsProjectSection {
                    HomeSectionDivider()
                }

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
    var showsEmptyState: Bool {
        HomeContentVisibility.showsEmptyState(
            showsTodaySection: showsTodaySection,
            showsProjectSection: showsProjectSection,
            showsDailyGroupsSection: showsDailyGroupsSection
        )
    }
    var showsTodaySection: Bool { !todayReminders.isEmpty }
    var showsProjectSection: Bool { !commonProjectSummaries.isEmpty }
    var showsDailyGroupsSection: Bool { !dailyGroupSummaries.isEmpty }
    var todayID: String { dailyTaskGroups.todayID() }
    var todayProjects: [TaskProject] { dailyTaskGroups.projects }
    var todayReminders: [CreateReminder] {
        CreateReminderListFilter.visibleReminders(
            dailyTaskGroups.reminders(forDayID: todayID),
            showsOnlyUnsolved: true,
            temporarilyVisibleCompletedReminderIDs: temporarilyVisibleCompletedReminderIDs
        )
    }

    var todaySection: some View {
        let renderedDayID = todayID

        return HomeTodaySectionView(
            reminders: todayReminders,
            projects: todayProjects,
            onToggleReminder: { toggleTodayReminder($0, dayID: renderedDayID) },
            onDeleteReminder: { deleteTodayReminder($0, dayID: renderedDayID) }
        )
    }

    func toggleTodayReminder(_ reminder: CreateReminder, dayID: String) {
        var reminders = dailyTaskGroups.reminders(forDayID: dayID)
        _ = CreateReminderCompletionVisibility.toggleReminderWithCompletionFeedback(
            reminder,
            in: &reminders,
            showsOnlyUnsolved: true,
            visibleIDs: $temporarilyVisibleCompletedReminderIDs,
            hapticFeedback: hapticFeedback,
            persist: { dailyTaskGroups.setReminders($0, forDayID: dayID) }
        )
    }

    func deleteTodayReminder(_ reminder: CreateReminder, dayID: String) {
        var reminders = dailyTaskGroups.reminders(forDayID: dayID)
        reminders.removeAll { $0.id == reminder.id }
        let didDelete = withAnimation(.smooth(duration: NomaTiming.taskSwipeRelease)) {
            guard dailyTaskGroups.setReminders(reminders, forDayID: dayID) else { return false }
            temporarilyVisibleCompletedReminderIDs.remove(reminder.id)
            return true
        }
        guard didDelete else { return }
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

private struct HomeSectionDivider: View {
    var body: some View {
        Divider()
            .padding(.top, NomaSpacing.xxl + NomaSpacing.md)
            .padding(.bottom, NomaSpacing.xl)
    }
}
