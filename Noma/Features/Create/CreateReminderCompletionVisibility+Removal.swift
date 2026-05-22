import SwiftUI

extension CreateReminderCompletionVisibility {
    @MainActor
    private static var removalGenerationByReminderID: [CreateReminder.ID: Int] = [:]

    @MainActor
    static func scheduleRemoval(
        of reminderIDs: [CreateReminder.ID],
        isNeeded: Bool,
        visibleIDs: Binding<Set<CreateReminder.ID>>
    ) {
        guard isNeeded, !reminderIDs.isEmpty else { return }
        let generations = removalGenerations(for: reminderIDs)

        Task {
            try? await Task.sleep(nanoseconds: CreateReminderListFilter.completedVisibilityDelayNanoseconds)
            await MainActor.run {
                removeVisibleIDs(reminderIDs, matching: generations, visibleIDs: visibleIDs)
            }
        }
    }

    @MainActor
    private static func removalGenerations(
        for reminderIDs: [CreateReminder.ID]
    ) -> [CreateReminder.ID: Int] {
        reminderIDs.reduce(into: [CreateReminder.ID: Int]()) { result, reminderID in
            let nextGeneration = (removalGenerationByReminderID[reminderID] ?? 0) + 1
            removalGenerationByReminderID[reminderID] = nextGeneration
            result[reminderID] = nextGeneration
        }
    }

    @MainActor
    private static func removeVisibleIDs(
        _ reminderIDs: [CreateReminder.ID],
        matching generations: [CreateReminder.ID: Int],
        visibleIDs: Binding<Set<CreateReminder.ID>>
    ) {
        withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            reminderIDs.forEach { reminderID in
                guard removalGenerationByReminderID[reminderID] == generations[reminderID] else { return }
                visibleIDs.wrappedValue.remove(reminderID)
                removalGenerationByReminderID[reminderID] = nil
            }
        }
    }
}
