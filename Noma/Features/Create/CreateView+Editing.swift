import SwiftUI

extension CreateView {
    func resetEditingIfDraftWasCleared(_ draftText: String) {
        guard CreateReminderEditingDraftReset.shouldResetEditingDraft(
            text: draftText,
            editingReminderID: editingReminderID
        ) else { return }

        editingReminderID = nil
    }

    func submitEditedReminder(_ submittedText: String, editingReminderID: CreateReminder.ID) {
        guard let updatedReminders = CreateReminderSubmissionPersistence.updatedRemindersAfterEditing(
            sourceReminders: reminders,
            editingReminderID: editingReminderID,
            submittedText: submittedText,
            projects: projects,
            selectedProjectID: selectedProjectID
        ) else { return }

        self.editingReminderID = nil
        message = ""
        taskOrganization = nil
        hapticFeedback.play(.createTaskSubmit)
        withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            reminders = updatedReminders
        }
        saveCurrentDailyGroup()
    }

    func beginEditingReminder(_ reminder: CreateReminder) {
        editingReminderID = reminder.id
        message = reminder.text
        selectedProjectID = reminder.projectID.flatMap { projectID in
            projects.contains { $0.id == projectID } ? projectID : nil
        }
        isInputFocused = true
    }
}
