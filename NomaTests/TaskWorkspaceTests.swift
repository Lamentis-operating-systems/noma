@testable import Noma
import XCTest

final class TaskWorkspaceTests: XCTestCase {
    func testComposerLayoutAdaptsToKeyboardAndSafeArea() {
        XCTAssertEqual(
            TaskWorkspaceLayout.composerWidth(containerWidth: 390, isKeyboardPresented: false),
            326
        )
        XCTAssertEqual(
            TaskWorkspaceLayout.composerWidth(containerWidth: 390, isKeyboardPresented: true),
            366
        )
        XCTAssertEqual(
            TaskWorkspaceLayout.composerBottomPadding(isKeyboardPresented: false, safeAreaBottom: 34),
            0
        )
        XCTAssertEqual(
            TaskWorkspaceLayout.composerBottomPadding(isKeyboardPresented: true, safeAreaBottom: 34),
            NomaSpacing.md
        )
        XCTAssertEqual(TaskWorkspaceLayout.composerWidth(containerWidth: .infinity, isKeyboardPresented: false), 0)
    }

    func testModalPresentationSuppressesWorkspaceKeyboardTransitions() {
        XCTAssertFalse(
            TaskWorkspaceKeyboardPolicy.resolvedPresentationState(
                currentState: false,
                keyboardWillBePresented: true,
                isModalPresented: true
            )
        )
        XCTAssertTrue(
            TaskWorkspaceKeyboardPolicy.resolvedPresentationState(
                currentState: true,
                keyboardWillBePresented: false,
                isModalPresented: true
            )
        )
        XCTAssertTrue(
            TaskWorkspaceKeyboardPolicy.resolvedPresentationState(
                currentState: false,
                keyboardWillBePresented: true,
                isModalPresented: false
            )
        )
        XCTAssertFalse(
            TaskWorkspaceKeyboardPolicy.resolvedPresentationState(
                currentState: true,
                keyboardWillBePresented: false,
                isModalPresented: false
            )
        )
    }
}
