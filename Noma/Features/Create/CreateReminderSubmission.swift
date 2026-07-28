import Foundation
import SwiftUI

struct CreateReminderSubmissionResult: Equatable {
    let reminder: CreateReminder
    let remainingText: String
}

struct CreateReminderSubmissionRoute: Equatable {
    let originatingDayID: String

    func isOriginatingDayStillActive(_ activeDayID: String) -> Bool {
        activeDayID == originatingDayID
    }
}

enum CreateReminderSubmission {
    static let characterLimit = 1000

    static func normalizedText(from text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    static func reminder(
        from text: String,
        id: UUID = UUID(),
        projectID: TaskProject.ID? = nil
    ) -> CreateReminder? {
        let normalizedText = normalizedText(from: text)
        guard !normalizedText.isEmpty, normalizedText.count <= characterLimit else { return nil }
        return CreateReminder(id: id, text: normalizedText, projectID: projectID)
    }

    static func submit(
        text: String,
        id: UUID = UUID(),
        projectID: TaskProject.ID? = nil
    ) -> CreateReminderSubmissionResult? {
        guard let reminder = reminder(from: text, id: id, projectID: projectID) else { return nil }
        return CreateReminderSubmissionResult(reminder: reminder, remainingText: "")
    }

    static func submit(
        text: String,
        id: UUID = UUID(),
        projects: [TaskProject],
        selectedProjectID: TaskProject.ID? = nil
    ) -> CreateReminderSubmissionResult? {
        let intent = CreateReminderCaptureIntelligence.intent(from: text, projects: projects)
        let projectID = intent.projectID ?? selectedProjectID
        guard let reminder = reminder(from: intent.normalizedText, id: id, projectID: projectID) else { return nil }

        return CreateReminderSubmissionResult(reminder: reminder, remainingText: "")
    }
}

enum CreateReminderSubmittedProjectResolution {
    static func projectID(
        submittedProjectID: TaskProject.ID?,
        currentProjects: [TaskProject],
        selectedProjectID: TaskProject.ID?
    ) -> TaskProject.ID? {
        if let submittedProjectID, currentProjects.contains(where: { $0.id == submittedProjectID }) {
            return submittedProjectID
        }

        if let selectedProjectID, currentProjects.contains(where: { $0.id == selectedProjectID }) {
            return selectedProjectID
        }

        return nil
    }
}

enum CreateReminderSubmissionPersistence {
    static func submittedReminder(
        from submission: CreateReminderSubmissionResult,
        projects: [TaskProject],
        selectedProjectID: TaskProject.ID?
    ) -> CreateReminder {
        let submittedProjectID = CreateReminderSubmittedProjectResolution.projectID(
            submittedProjectID: submission.reminder.projectID,
            currentProjects: projects,
            selectedProjectID: selectedProjectID
        )

        return CreateReminder(
            id: submission.reminder.id,
            text: submission.reminder.text,
            isCompleted: submission.reminder.isCompleted,
            projectID: submittedProjectID,
            createdAt: submission.reminder.createdAt,
            carryForwardCount: submission.reminder.carryForwardCount
        )
    }

    @discardableResult
    static func append(
        _ submission: CreateReminderSubmissionResult,
        to reminders: inout [CreateReminder],
        projects: [TaskProject],
        selectedProjectID: TaskProject.ID?
    ) -> CreateReminder {
        let reminder = submittedReminder(
            from: submission,
            projects: projects,
            selectedProjectID: selectedProjectID
        )
        reminders.append(reminder)
        return reminder
    }
}

enum CreateReminderCompletionFeedback {
    static func feedback(isCompleted: Bool) -> HapticFeedbackClass? {
        isCompleted ? .createTaskSubmit : nil
    }
}

enum CreateReminderListFilter {
    static let completedVisibilityDelayNanoseconds: UInt64 = 700_000_000

    static func visibleReminders(
        _ reminders: [CreateReminder],
        showsOnlyUnsolved: Bool,
        temporarilyVisibleCompletedReminderIDs: Set<CreateReminder.ID> = []
    ) -> [CreateReminder] {
        guard showsOnlyUnsolved else { return reminders }
        return reminders.filter { reminder in
            !reminder.isCompleted || temporarilyVisibleCompletedReminderIDs.contains(reminder.id)
        }
    }

    static func keepsCompletedReminderTemporarilyVisible(
        _ reminder: CreateReminder,
        showsOnlyUnsolved: Bool
    ) -> Bool {
        showsOnlyUnsolved && reminder.isCompleted
    }
}

enum CreateReminderFilterPreference {
    static let storageKey = "create.showsOnlyUnsolvedTasks"

    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: storageKey)
    }

    static func setIsEnabled(_ isEnabled: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(isEnabled, forKey: storageKey)
    }
}

enum CreateReminderCompletionVisibility {
    static func toggleReminder(
        _ reminder: CreateReminder,
        in reminders: inout [CreateReminder],
        showsOnlyUnsolved: Bool,
        visibleIDs: inout Set<CreateReminder.ID>
    ) -> (updatedReminder: CreateReminder, keepsVisible: Bool)? {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return nil }

        let updatedReminder = reminders[index].togglingCompletion()
        let keepsVisible = updateTemporarilyVisibleCompletedReminderIDs(
            for: updatedReminder,
            showsOnlyUnsolved: showsOnlyUnsolved,
            visibleIDs: &visibleIDs
        )
        reminders[index] = updatedReminder

        return (updatedReminder, keepsVisible)
    }

    @MainActor
    static func toggleReminderWithCompletionFeedback(
        _ reminder: CreateReminder,
        in reminders: inout [CreateReminder],
        showsOnlyUnsolved: Bool,
        visibleIDs: Binding<Set<CreateReminder.ID>>,
        hapticFeedback: HapticFeedbackService,
        persist: ([CreateReminder]) -> Bool
    ) -> Bool {
        let originalReminders = reminders
        var nextVisibleIDs = visibleIDs.wrappedValue
        guard let visibility = toggleReminder(
            reminder,
            in: &reminders,
            showsOnlyUnsolved: showsOnlyUnsolved,
            visibleIDs: &nextVisibleIDs
        ) else { return false }

        let didPersist = withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            persist(reminders)
        }
        guard didPersist else {
            reminders = originalReminders
            return false
        }

        withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            visibleIDs.wrappedValue = nextVisibleIDs
        }

        if let feedback = CreateReminderCompletionFeedback.feedback(
            isCompleted: visibility.updatedReminder.isCompleted
        ) {
            hapticFeedback.play(feedback)
        }

        scheduleRemoval(
            of: [visibility.updatedReminder.id],
            isNeeded: visibility.keepsVisible,
            visibleIDs: visibleIDs
        )
        return true
    }

    static func updateTemporarilyVisibleCompletedReminderIDs(
        for reminder: CreateReminder,
        showsOnlyUnsolved: Bool,
        visibleIDs: inout Set<CreateReminder.ID>
    ) -> Bool {
        let isRetained = CreateReminderListFilter.keepsCompletedReminderTemporarilyVisible(
            reminder,
            showsOnlyUnsolved: showsOnlyUnsolved
        )

        if isRetained {
            visibleIDs.insert(reminder.id)
        } else {
            visibleIDs.remove(reminder.id)
        }

        return isRetained
    }

    static func retainCompletedReminderIDs(
        _ reminderIDs: [CreateReminder.ID],
        isNeeded: Bool,
        visibleIDs: inout Set<CreateReminder.ID>
    ) {
        guard isNeeded else { return }
        visibleIDs.formUnion(reminderIDs)
    }

}

enum CreateReminderBatchCompletion {
    static func completingAll(_ reminders: [CreateReminder]) -> [CreateReminder] {
        reminders.map { reminder in
            reminder.isCompleted ? reminder : reminder.togglingCompletion()
        }
    }
}
