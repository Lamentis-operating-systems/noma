import SwiftUI

extension CreateView {
    var reminders: [CreateReminder] {
        dailyTaskGroups.reminders(forDayID: activeDayID)
    }

    var projects: [TaskProject] { [] }

    var carryForwardReminders: [CreateReminder] {
        CreateReminderCarryForwardPreview.visibleReminders(
            currentReminders: reminders,
            previousOpenReminders: previousDayReminders.filter { !$0.isCompleted }
        )
    }

    var previousDayID: String? {
        guard let activeDate = DailyTaskGroupStore.date(forDayID: activeDayID),
              let previousDate = Calendar.current.date(byAdding: .day, value: -1, to: activeDate)
        else { return nil }

        return DailyTaskGroupStore.dayID(for: previousDate)
    }

    var previousDayReminders: [CreateReminder] {
        guard let previousDayID else { return [] }
        return dailyTaskGroups.reminders(forDayID: previousDayID)
    }

    var showsCarryForwardButton: Bool {
        CreateReminderSubmission.normalizedText(from: message).isEmpty
            && !carryForwardReminders.isEmpty
    }

    var carryForwardPreviewReminders: [CreateReminder] {
        showsCarryForwardButton ? carryForwardReminders : []
    }

    func addCarryForwardReminders(_ remindersToCarryForward: [CreateReminder]) {
        guard let sourceDayID = previousDayID, !remindersToCarryForward.isEmpty else { return }

        let didCarryForward = withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            dailyTaskGroups.carryForwardReminders(
                remindersToCarryForward,
                fromDayID: sourceDayID,
                toDayID: activeDayID
            )
        }
        guard didCarryForward else { return }

        hapticFeedback.play(.createTaskSubmit)
        pendingScrollTargetID = CreateReminderListLayout.bottomAnchorID
    }

    func completeCarryForwardReminder(_ reminder: CreateReminder) {
        guard let previousDayID else { return }

        let updatedPreviousReminders = CreateReminderCarryForwardCompletion.completing(
            reminder,
            in: previousDayReminders
        )
        let didComplete = withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            dailyTaskGroups.setReminders(updatedPreviousReminders, forDayID: previousDayID)
        }
        guard didComplete else { return }

        hapticFeedback.play(.createTaskSubmit)
    }
}
