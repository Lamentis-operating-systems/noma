import Foundation

enum CreateReminderEditingDraftReset {
    static func shouldResetEditingDraft(
        text: String,
        editingReminderID: CreateReminder.ID?
    ) -> Bool {
        editingReminderID != nil && CreateReminderSubmission.normalizedText(from: text).isEmpty
    }
}

extension CreateReminderSubmissionPersistence {
    static func updatedRemindersAfterEditing(
        sourceReminders: [CreateReminder],
        editingReminderID: CreateReminder.ID,
        submittedText: String,
        projects: [TaskProject],
        selectedProjectID: TaskProject.ID?
    ) -> [CreateReminder]? {
        guard let index = sourceReminders.firstIndex(where: { $0.id == editingReminderID }) else { return nil }
        guard let submission = CreateReminderSubmission.submit(
            text: submittedText,
            id: editingReminderID,
            projects: projects,
            selectedProjectID: selectedProjectID
        ) else { return nil }

        let submittedReminder = submittedReminder(
            from: submission,
            projects: projects,
            selectedProjectID: selectedProjectID
        )
        var updatedReminders = sourceReminders
        updatedReminders[index] = CreateReminder(
            id: submittedReminder.id,
            text: submittedReminder.text,
            isCompleted: sourceReminders[index].isCompleted,
            projectID: submittedReminder.projectID
        )
        return updatedReminders
    }
}
