import SwiftUI

extension ProjectDetailView {
    func loadProject() {
        project = dailyTaskGroups.projects(forDayID: dailyTaskGroups.todayID()).first { $0.id == projectID }
    }

    func submitReminder(_ submittedText: String) {
        guard canSubmitReminder else { return }
        guard let submission = CreateReminderSubmission.submit(
            text: submittedText,
            projectID: projectID
        ) else { return }

        message = submission.remainingText
        var todayReminders = dailyTaskGroups.reminders(forDayID: todayID)
        hapticFeedback.play(.createTaskSubmit)
        withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            todayReminders.append(submission.reminder)
            dailyTaskGroups.save(reminders: todayReminders, forDayID: todayID)
        }
        pendingScrollTargetID = CreateReminderAutoScroll.targetAfterAppending(submission.reminder)
    }

    func toggleReminder(_ reminder: CreateReminder, inDayID dayID: String) {
        var reminders = dailyTaskGroups.reminders(forDayID: dayID)
        _ = CreateReminderCompletionVisibility.toggleReminderWithCompletionFeedback(
            reminder,
            in: &reminders,
            showsOnlyUnsolved: showsOnlyUnsolvedTasks,
            visibleIDs: $temporarilyVisibleCompletedReminderIDs,
            hapticFeedback: hapticFeedback,
            persist: { dailyTaskGroups.save(reminders: $0, forDayID: dayID) }
        )
    }

    func deleteReminder(_ reminder: CreateReminder, inDayID dayID: String) {
        var reminders = dailyTaskGroups.reminders(forDayID: dayID)
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }

        withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            temporarilyVisibleCompletedReminderIDs.remove(reminder.id)
            _ = reminders.remove(at: index)
            dailyTaskGroups.save(reminders: reminders, forDayID: dayID)
        }
    }

    func completeAllRemindersForProject() {
        guard canCompleteAllReminders else { return }

        hapticFeedback.play(.createTaskSubmit)
        let groups = dailyTaskGroups.groups
        let completedReminderIDs = groups.flatMap(\.reminders).compactMap(openProjectReminderID)
        withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            CreateReminderCompletionVisibility.retainCompletedReminderIDs(
                completedReminderIDs,
                isNeeded: showsOnlyUnsolvedTasks,
                visibleIDs: &temporarilyVisibleCompletedReminderIDs
            )
            for group in groups {
                let updatedReminders = group.reminders.map { reminder in
                    reminder.projectID == projectID && !reminder.isCompleted
                        ? reminder.togglingCompletion()
                        : reminder
                }
                dailyTaskGroups.save(reminders: updatedReminders, forDayID: group.id)
            }
        }
        CreateReminderCompletionVisibility.scheduleRemoval(of: completedReminderIDs, isNeeded: showsOnlyUnsolvedTasks, visibleIDs: $temporarilyVisibleCompletedReminderIDs)
    }

    func toggleUnsolvedFilter() {
        CreateReminderFilterToggle.toggle(
            isActive: showsOnlyUnsolvedTasks,
            hapticFeedback: hapticFeedback,
            setIsActive: { showsOnlyUnsolvedTasks = $0 }
        )
    }

    func scrollToLastTodayReminderAfterKeyboardFocus() {
        guard let targetID = CreateReminderAutoScroll.targetAfterKeyboardFocus(visibleReminders: visibleTodayReminders) else {
            return
        }

        pendingScrollTargetID = targetID
    }

    func playSwipeDeleteThresholdFeedback() {
        hapticFeedback.play(.createTaskSubmit)
    }

    func openProjectReminderID(_ reminder: CreateReminder) -> CreateReminder.ID? {
        reminder.projectID == projectID && !reminder.isCompleted ? reminder.id : nil
    }

}
