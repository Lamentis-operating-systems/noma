import SwiftUI

extension ProjectDetailView {
    func leaveUnavailableProject() {
        message = ""
        isInputFocused = false
        isEditProjectSheetPresented = false
        dismiss()
    }

    func submitReminder(_ submittedText: String) -> Bool {
        guard currentProject != nil else {
            leaveUnavailableProject()
            return false
        }
        guard let submission = CreateReminderSubmission.submit(
            text: submittedText,
            projectID: projectID
        ) else { return false }

        var todayReminders = dailyTaskGroups.reminders(forDayID: todayID)
        let didPersist = withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            todayReminders.append(submission.reminder)
            return dailyTaskGroups.replaceRemindersAtomically(todayReminders, forDayID: todayID)
        }
        guard didPersist else { return false }

        hapticFeedback.play(.createTaskSubmit)
        pendingScrollTargetID = CreateReminderAutoScroll.targetAfterAppending(submission.reminder)
        return true
    }

    func toggleReminder(_ reminder: CreateReminder, inDayID dayID: String) {
        var reminders = dailyTaskGroups.reminders(forDayID: dayID)
        _ = CreateReminderCompletionVisibility.toggleReminderWithCompletionFeedback(
            reminder,
            in: &reminders,
            showsOnlyUnsolved: showsOnlyUnsolvedTasks,
            visibleIDs: $temporarilyVisibleCompletedReminderIDs,
            hapticFeedback: hapticFeedback,
            persist: { dailyTaskGroups.setReminders($0, forDayID: dayID) }
        )
    }

    func deleteReminder(_ reminder: CreateReminder, inDayID dayID: String) {
        var reminders = dailyTaskGroups.reminders(forDayID: dayID)
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }

        let didDelete = withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            _ = reminders.remove(at: index)
            guard dailyTaskGroups.setReminders(reminders, forDayID: dayID) else { return false }
            temporarilyVisibleCompletedReminderIDs.remove(reminder.id)
            return true
        }
        guard didDelete else { return }
    }

    func completeAllRemindersForProject() {
        guard canCompleteAllReminders else { return }

        let completedReminderIDs = dailyTaskGroups.groups.flatMap(\.reminders).compactMap(openProjectReminderID)
        let didComplete = withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            guard dailyTaskGroups.completeAllReminders(forProjectID: projectID) else { return false }
            CreateReminderCompletionVisibility.retainCompletedReminderIDs(
                completedReminderIDs,
                isNeeded: showsOnlyUnsolvedTasks,
                visibleIDs: &temporarilyVisibleCompletedReminderIDs
            )
            return true
        }
        guard didComplete else { return }

        hapticFeedback.play(.createTaskSubmit)
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

    func openProjectReminderID(_ reminder: CreateReminder) -> CreateReminder.ID? {
        reminder.projectID == projectID && !reminder.isCompleted ? reminder.id : nil
    }

}
