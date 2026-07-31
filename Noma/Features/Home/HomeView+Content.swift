import SwiftUI

extension HomeView {
    var createButton: some View {
        PrimaryGlassButton(title: "create.button.title", systemImage: "square.and.pencil") {
            path.append(.create)
        }
        .accessibilityIdentifier("home-create-button")
    }

    var dailyGroupsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if todayReminders.isEmpty, dailyTaskGroups.recurrences.isEmpty {
                HomeEmptyHint()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if !todayReminders.isEmpty {
                    todaySection
                }

                if !dailyTaskGroups.recurrences.isEmpty {
                    recurrencesSection
                        .padding(
                            .top,
                            todayReminders.isEmpty
                                ? 0
                                : NomaSpacing.xxl + NomaSpacing.md + NomaSpacing.xl
                        )
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, NomaSpacing.xl)
        .padding(.top, NomaSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    var todayID: String { dailyTaskGroups.todayID() }
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
            projects: [],
            dayID: renderedDayID,
            onToggleReminder: { toggleTodayReminder($0, dayID: renderedDayID) },
            onDeleteReminder: { deleteTodayReminder($0, dayID: renderedDayID) }
        )
    }

    var recurrencesSection: some View {
        HomeRecurrencesSectionView(recurrences: dailyTaskGroups.recurrences)
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
        Task {
            await dailyTaskNotifications.refreshDailyTaskReminders(for: todayReminders)
        }
    }
}
