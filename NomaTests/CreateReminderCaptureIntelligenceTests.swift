@testable import Noma
import Foundation
import XCTest

final class CreateReminderCaptureIntelligenceTests: XCTestCase {
    func testTaskCaptureIntelligenceAssignsExplicitHashProject() {
        let project = TaskProject(id: UUID(uuidString: "00000000-0000-0000-0000-000000000061")!, title: "Work")
        let intent = CreateReminderCaptureIntelligence.intent(
            from: "Send launch update #work",
            projects: [project]
        )

        XCTAssertEqual(intent.normalizedText, "Send launch update")
        XCTAssertEqual(intent.projectID, project.id)
    }

    func testTaskCaptureIntelligenceKeepsUnknownProjectMarker() {
        let project = TaskProject(id: UUID(uuidString: "00000000-0000-0000-0000-000000000062")!, title: "Home")
        let intent = CreateReminderCaptureIntelligence.intent(
            from: "Send launch update #work",
            projects: [project]
        )

        XCTAssertEqual(intent.normalizedText, "Send launch update #work")
        XCTAssertNil(intent.projectID)
    }

    func testTaskCaptureIntelligenceRequiresHashMarkerBoundary() {
        let project = TaskProject(id: UUID(uuidString: "00000000-0000-0000-0000-000000000066")!, title: "Work")
        let intent = CreateReminderCaptureIntelligence.intent(
            from: "Read #workflow notes",
            projects: [project]
        )

        XCTAssertEqual(intent.normalizedText, "Read #workflow notes")
        XCTAssertNil(intent.projectID)
    }
}
