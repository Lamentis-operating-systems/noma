import SwiftUI

extension CreateView {
    func reconcileEditingState(with reminders: [CreateReminder]) {
        guard CreateReminderEditingReconciliation.shouldResetEditingState(
            editingReminderID: editingReminderID,
            reminders: reminders
        ) else { return }

        editingReminderID = nil
        message = ""
        isInputFocused = false
    }

    func resetEditingIfDraftWasCleared(_ draftText: String) {
        guard CreateReminderEditingDraftReset.shouldResetEditingDraft(
            text: draftText,
            editingReminderID: editingReminderID
        ) else { return }

        editingReminderID = nil
    }

    func submitEditedReminder(_ submittedText: String, editingReminderID: CreateReminder.ID) -> Bool {
        guard let updatedReminders = CreateReminderSubmissionPersistence.updatedRemindersAfterEditing(
            sourceReminders: reminders,
            editingReminderID: editingReminderID,
            submittedText: submittedText,
            projects: projects,
            selectedProjectID: nil
        ) else { return false }

        let didPersist = withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            dailyTaskGroups.replaceRemindersAtomically(updatedReminders, forDayID: activeDayID)
        }
        self.editingReminderID = CreateReminderEditingReconciliation.editingReminderIDAfterPersistence(
            didPersist: didPersist,
            currentEditingReminderID: editingReminderID
        )
        guard didPersist else { return false }

        hapticFeedback.play(.createTaskSubmit)
        return true
    }

    func beginEditingReminder(_ reminder: CreateReminder) {
        editingReminderID = reminder.id
        message = reminder.text
        isInputFocused = true
    }
}
