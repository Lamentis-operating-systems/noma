@testable import Noma
import XCTest

final class ReminderInputStateTests: XCTestCase {
    @MainActor
    func testReminderInputStateDisablesSubmitWhenUnavailable() {
        let state = ReminderInputState(text: "Next task", isSubmissionAvailable: false)

        XCTAssertFalse(state.canSubmit)
        XCTAssertEqual(state.sendButtonTone, .disabled)
    }

    @MainActor
    func testReminderInputStateDisablesAndMarksOverLimitText() {
        let state = ReminderInputState(text: String(repeating: "a", count: CreateReminderSubmission.characterLimit + 1))

        XCTAssertFalse(state.canSubmit)
        XCTAssertTrue(state.isOverLimit)
        XCTAssertEqual(state.sendButtonTone, .error)
    }

    @MainActor
    func testReminderInputStateCountsNormalizedTextForLimit() {
        let validTextWithExtraWhitespace = "\n  \(String(repeating: "a", count: CreateReminderSubmission.characterLimit))  \n"
        let state = ReminderInputState(text: validTextWithExtraWhitespace)

        XCTAssertEqual(state.normalizedText.count, CreateReminderSubmission.characterLimit)
        XCTAssertTrue(state.canSubmit)
        XCTAssertFalse(state.isOverLimit)
        XCTAssertEqual(state.sendButtonTone, .active)
    }

    func testReminderInputRejectsSubmittedTextWrittenBackAfterClear() {
        var staleGuard = ReminderInputStaleTextGuard()

        staleGuard.prepareForSubmit(text: "Call Mika")

        XCTAssertFalse(staleGuard.acceptsIncomingText("Call Mika"))
        XCTAssertTrue(staleGuard.acceptsIncomingText("Call Mika"))
    }

    func testSuccessfulSubmissionClearsDraftOnlyAfterHandlerReturns() {
        var draftState = ReminderInputDraftState()
        var boundText = "Call Mika"
        var textObservedByHandler: String?

        boundText = draftState.textAfterAttemptingSubmission(
            currentText: boundText,
            isSubmissionAvailable: true
        ) { submittedText in
            textObservedByHandler = boundText
            XCTAssertEqual(submittedText, "Call Mika")
            return true
        }

        XCTAssertEqual(textObservedByHandler, "Call Mika")
        XCTAssertEqual(boundText, "")
        XCTAssertFalse(draftState.acceptsIncomingText("Call Mika"))
        XCTAssertTrue(draftState.acceptsIncomingText("Call Mika"))
    }

    func testFailedSubmissionKeepsDraftAndDoesNotArmStaleTextGuard() {
        var draftState = ReminderInputDraftState()
        var boundText = "Retry later"
        var textObservedByHandler: String?

        boundText = draftState.textAfterAttemptingSubmission(
            currentText: boundText,
            isSubmissionAvailable: true
        ) { submittedText in
            textObservedByHandler = boundText
            XCTAssertEqual(submittedText, "Retry later")
            return false
        }

        XCTAssertEqual(textObservedByHandler, "Retry later")
        XCTAssertEqual(boundText, "Retry later")
        XCTAssertTrue(draftState.acceptsIncomingText("Retry later"))
    }
}
