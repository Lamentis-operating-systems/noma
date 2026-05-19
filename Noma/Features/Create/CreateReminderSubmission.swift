import Foundation
import SwiftUI

struct CreateReminder: Codable, Equatable, Identifiable {
    let id: UUID
    let text: String
    let isCompleted: Bool
    let projectID: TaskProject.ID?

    init(
        id: UUID = UUID(),
        text: String,
        isCompleted: Bool = false,
        projectID: TaskProject.ID? = nil
    ) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.projectID = projectID
    }

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case isCompleted
        case projectID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        projectID = try container.decodeIfPresent(TaskProject.ID.self, forKey: .projectID)
    }

    func togglingCompletion() -> CreateReminder {
        CreateReminder(id: id, text: text, isCompleted: !isCompleted, projectID: projectID)
    }
}

struct CreateReminderSubmissionResult: Equatable {
    let reminder: CreateReminder
    let remainingText: String
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

enum CreateReminderDraftReconciliation {
    static func reconciledDraft(
        currentDraft: String,
        submittedText: String,
        remainingText: String
    ) -> String {
        guard currentDraft.isEmpty || currentDraft == submittedText else {
            return currentDraft
        }

        return remainingText
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
            projectID: submittedProjectID
        )
    }

    static func updatedRemindersAfterAppending(
        sourceReminders: [CreateReminder],
        submission: CreateReminderSubmissionResult,
        projects: [TaskProject],
        selectedProjectID: TaskProject.ID?,
        tier: SubscriptionTier
    ) -> [CreateReminder]? {
        guard tier.canAddTask(toGroupWithTaskCount: sourceReminders.count) else { return nil }

        return sourceReminders + [
            submittedReminder(
                from: submission,
                projects: projects,
                selectedProjectID: selectedProjectID
            )
        ]
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
        persist: ([CreateReminder]) -> Void
    ) -> Bool {
        var keepsVisible = false
        var updatedReminder: CreateReminder?
        withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            let visibility = toggleReminder(
                reminder,
                in: &reminders,
                showsOnlyUnsolved: showsOnlyUnsolved,
                visibleIDs: &visibleIDs.wrappedValue
            )
            updatedReminder = visibility?.updatedReminder
            keepsVisible = visibility?.keepsVisible ?? false
            persist(reminders)
        }
        guard let updatedReminder else { return false }

        if let feedback = CreateReminderCompletionFeedback.feedback(isCompleted: updatedReminder.isCompleted) {
            hapticFeedback.play(feedback)
        }

        scheduleRemoval(of: [updatedReminder.id], isNeeded: keepsVisible, visibleIDs: visibleIDs)
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

    @MainActor
    static func scheduleRemoval(
        of reminderIDs: [CreateReminder.ID],
        isNeeded: Bool,
        visibleIDs: Binding<Set<CreateReminder.ID>>
    ) {
        guard isNeeded, !reminderIDs.isEmpty else { return }

        Task {
            try? await Task.sleep(nanoseconds: CreateReminderListFilter.completedVisibilityDelayNanoseconds)
            await MainActor.run {
                withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
                    reminderIDs.forEach { visibleIDs.wrappedValue.remove($0) }
                }
            }
        }
    }
}

enum CreateReminderListOrganization {
    static func sortedReminders(
        _ reminders: [CreateReminder],
        using organization: CreateReminderAIPlanningResult?
    ) -> [CreateReminder] {
        guard let organization, !organization.organizedTasks.isEmpty else { return reminders }

        let originalOffsets = Dictionary(uniqueKeysWithValues: reminders.enumerated().map { ($0.element.id, $0.offset) })
        let organizationByID = Dictionary(uniqueKeysWithValues: organization.organizedTasks.map { ($0.reminderID, $0) })

        return reminders.sorted { first, second in
            sortKey(for: first, organizationByID: organizationByID, originalOffsets: originalOffsets)
                < sortKey(for: second, organizationByID: organizationByID, originalOffsets: originalOffsets)
        }
    }

    private static func sortKey(
        for reminder: CreateReminder,
        organizationByID: [CreateReminder.ID: CreateReminderAIOrganizedTask],
        originalOffsets: [CreateReminder.ID: Int]
    ) -> SortKey {
        let organization = organizationByID[reminder.id]
        return SortKey(
            completionRank: reminder.isCompleted ? 1 : 0,
            priorityRank: organization?.priorityRank ?? Int.max,
            category: organization?.category ?? "",
            originalOffset: originalOffsets[reminder.id] ?? Int.max
        )
    }

    private struct SortKey: Comparable {
        let completionRank: Int
        let priorityRank: Int
        let category: String
        let originalOffset: Int

        static func < (lhs: SortKey, rhs: SortKey) -> Bool {
            if lhs.completionRank != rhs.completionRank { return lhs.completionRank < rhs.completionRank }
            if lhs.priorityRank != rhs.priorityRank { return lhs.priorityRank < rhs.priorityRank }
            if lhs.category != rhs.category { return lhs.category < rhs.category }
            return lhs.originalOffset < rhs.originalOffset
        }
    }
}

enum CreateReminderBatchCompletion {
    static func completingAll(_ reminders: [CreateReminder]) -> [CreateReminder] {
        reminders.map { reminder in
            reminder.isCompleted ? reminder : reminder.togglingCompletion()
        }
    }
}

enum CreateReminderFilterToolbarIcon {
    static func systemImage(isActive _: Bool) -> String {
        "line.3.horizontal.decrease"
    }

    static func usesActiveTint(isActive: Bool) -> Bool {
        isActive
    }

    static func foregroundColor(isActive: Bool) -> Color {
        usesActiveTint(isActive: isActive) ? .accentColor : .textPrimary
    }
}
