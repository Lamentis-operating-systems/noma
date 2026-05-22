@testable import Noma
import SwiftUI
import XCTest

final class CreateReminderCompletionVisibilityTests: XCTestCase {
    @MainActor
    func testCompletionVisibilityIgnoresStaleDelayedRemovalAfterRetoggle() async throws {
        let reminderID = UUID(uuidString: "00000000-0000-0000-0000-000000000073")!
        var visibleIDs: Set<CreateReminder.ID> = [reminderID]
        let binding = Binding<Set<CreateReminder.ID>> {
            visibleIDs
        } set: { newValue in
            visibleIDs = newValue
        }

        CreateReminderCompletionVisibility.scheduleRemoval(
            of: [reminderID],
            isNeeded: true,
            visibleIDs: binding
        )
        try await Task.sleep(nanoseconds: 350_000_000)
        CreateReminderCompletionVisibility.scheduleRemoval(
            of: [reminderID],
            isNeeded: true,
            visibleIDs: binding
        )

        try await Task.sleep(nanoseconds: 450_000_000)
        XCTAssertTrue(visibleIDs.contains(reminderID))

        try await Task.sleep(nanoseconds: 350_000_000)
        XCTAssertFalse(visibleIDs.contains(reminderID))
    }
}
