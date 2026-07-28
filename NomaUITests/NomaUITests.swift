import XCTest

@MainActor
final class NomaUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func testSignupKeepsPrivacyAndAppleSignInAccessible() {
        let app = launch(.signup, language: "en")

        XCTAssertTrue(app.buttons["signup-privacy-link"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["signup-apple-button"].isHittable)
        XCTAssertEqual(app.switches.matching(identifier: "signup-consent-toggle").count, 0)
    }

    func testEmptyHomeKeepsCopyAndCaptureWithoutCircularPlusIcon() {
        let app = launch(.empty, language: "en")
        let capture = app.buttons["home-create-button"]

        XCTAssertTrue(app.staticTexts["Nothing planned yet"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Create a task to start shaping your day here."].exists)
        XCTAssertFalse(app.staticTexts["Create tasks and projects to start shaping your day here."].exists)
        XCTAssertTrue(capture.waitForExistence(timeout: 3))
        XCTAssertTrue(capture.isEnabled)
        XCTAssertTrue(capture.isHittable)
        XCTAssertEqual(app.images.matching(identifier: "plus.circle").count, 0)
    }

    func testTodayCaptureCompleteAndSimplifiedSurfaces() {
        let app = launch(.workspace, language: "en")
        XCTAssertTrue(app.buttons["home-create-button"].waitForExistence(timeout: 8))

        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'home-project-'")).count, 0)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'home-daily-group-'")).count, 0)
        app.buttons["home-create-button"].tap()

        let input = app.textFields["create-reminder-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "create-reminder-tray-button").count, 0)
        XCTAssertEqual(app.buttons.matching(identifier: "project-sheet-create-button").count, 0)

        input.tap()
        input.typeText("Captured today")
        app.buttons["Send"].tap()
        XCTAssertTrue(app.staticTexts["Captured today"].waitForExistence(timeout: 5))

        let done = app.buttons["task-workspace-done-button"]
        XCTAssertTrue(done.isEnabled)
        done.tap()
        XCTAssertFalse(done.isEnabled)
    }

    func testSettingsMenuHasNoNotificationRouteAndTextOnlyDestructiveActions() {
        let app = launch(.workspace, language: "en")
        let settingsMenu = app.buttons["home-settings-menu"]
        XCTAssertTrue(settingsMenu.waitForExistence(timeout: 8))
        settingsMenu.tap()

        XCTAssertEqual(app.buttons.matching(identifier: "Notifications").count, 0)
        XCTAssertEqual(app.staticTexts.matching(identifier: "Notifications").count, 0)

        let deleteAccount = app.buttons["home-delete-account-action"]
        let signOut = app.buttons["home-sign-out-action"]
        XCTAssertTrue(deleteAccount.waitForExistence(timeout: 3))
        XCTAssertTrue(signOut.exists)
        XCTAssertEqual(deleteAccount.label, "Delete account")
        XCTAssertEqual(signOut.label, "Sign out")
        XCTAssertEqual(deleteAccount.descendants(matching: .image).count, 0)
        XCTAssertEqual(signOut.descendants(matching: .image).count, 0)

        let appearance = app.buttons["Appearance"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 3))
        appearance.tap()
        XCTAssertTrue(app.buttons["System"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Light"].exists)
        XCTAssertTrue(app.buttons["Dark"].exists)
    }

    private enum Scenario: String {
        case signup
        case empty
        case workspace
    }

    private func launch(_ scenario: Scenario, language: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--noma-ui-test-scenario", scenario.rawValue,
            "--noma-ui-test-locale", language,
            "--noma-ui-test-dynamic-type", "default",
            "--noma-ui-test-run-id", UUID().uuidString,
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", language == "de" ? "de_DE" : "en_US"
        ]
        app.launch()
        return app
    }
}
