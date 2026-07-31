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

    func testEmptyHomeKeepsCopyAndBottomToolbarCaptureAccessible() {
        let app = launch(.empty, language: "en")
        let capture = app.buttons["home-create-button"]

        XCTAssertTrue(app.staticTexts["Nothing planned yet"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Create a task to start shaping your day here."].exists)
        XCTAssertFalse(app.staticTexts["Create tasks and projects to start shaping your day here."].exists)
        XCTAssertTrue(capture.waitForExistence(timeout: 3))
        XCTAssertTrue(capture.isEnabled)
        XCTAssertTrue(capture.isHittable)
        XCTAssertEqual(capture.label, "Task")
        XCTAssertGreaterThanOrEqual(capture.frame.width, 44)
        XCTAssertEqual(capture.frame.width, capture.frame.height, accuracy: 1)
        XCTAssertGreaterThan(capture.frame.midX, app.frame.midX)
        XCTAssertGreaterThan(capture.frame.midY, app.frame.height * 0.75)
        let rightEdgeDistance = app.frame.maxX - capture.frame.maxX
        let bottomEdgeDistance = app.frame.maxY - capture.frame.maxY
        let edgeDistances = "right: \(rightEdgeDistance), bottom: \(bottomEdgeDistance)"
        XCTAssertEqual(rightEdgeDistance, 32, accuracy: 1, edgeDistances)
        XCTAssertEqual(bottomEdgeDistance, 32, accuracy: 1, edgeDistances)
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
        XCTAssertEqual(app.buttons.matching(identifier: "recurrence-manage-button").count, 0)

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

    func testRecurringTaskSetupStopAndTodayInstanceRetention() {
        let app = launch(.workspace, language: "en")
        let task = app.staticTexts["UITest Task"].firstMatch
        XCTAssertTrue(task.waitForExistence(timeout: 8))
        task.press(forDuration: 1)
        XCTAssertTrue(app.buttons["Repeat"].waitForExistence(timeout: 3))
        app.buttons["Repeat"].tap()

        let dailyButton = app.buttons["recurrence-daily-button"]
        XCTAssertTrue(dailyButton.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["recurrence-save-button"].exists)
        dailyButton.tap()

        task.press(forDuration: 1)
        let stopButton = app.buttons["recurrence-stop-button"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 3))
        stopButton.tap()

        XCTAssertTrue(task.waitForExistence(timeout: 3))
        task.tap()
        XCTAssertTrue(task.waitForNonExistence(timeout: 5))
    }

    func testRecurringTaskCustomMenuUsesWeekdayTogglesInsteadOfASheet() {
        let app = launch(.workspace, language: "en")
        let task = app.staticTexts["UITest Task"]
        XCTAssertTrue(task.waitForExistence(timeout: 8))
        task.press(forDuration: 1)
        app.buttons["Repeat"].tap()

        let customMenu = app.buttons["recurrence-custom-menu"]
        XCTAssertTrue(customMenu.waitForExistence(timeout: 3))
        customMenu.tap()

        let monday = app.descendants(matching: .any).matching(identifier: "recurrence-weekday-2").firstMatch
        let friday = app.descendants(matching: .any).matching(identifier: "recurrence-weekday-6").firstMatch
        XCTAssertTrue(monday.waitForExistence(timeout: 3))
        XCTAssertTrue(friday.exists)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "recurrence-weekday-1").count, 0)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "recurrence-weekday-7").count, 0)
        XCTAssertTrue(app.buttons["recurrence-custom-save-button"].exists)
        XCTAssertFalse(app.buttons["recurrence-save-button"].exists)

        monday.tap()
        XCTAssertTrue(monday.waitForExistence(timeout: 1))
        XCTAssertTrue(friday.exists)
        XCTAssertTrue(app.buttons["recurrence-custom-save-button"].exists)
    }

    func testRecurringTaskMaterializesAndCanBeStoppedFromHomeWithConfirmation() {
        let app = launch(.recurrence, language: "en")
        XCTAssertTrue(app.staticTexts["Generated Repeat"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.images.matching(identifier: "recurrence-indicator").count, 0)
        let recurrencesSectionTitle = app.descendants(matching: .any)
            .matching(identifier: "home-recurrences-section-title")
            .firstMatch
        XCTAssertTrue(recurrencesSectionTitle.waitForExistence(timeout: 3))
        XCTAssertEqual(recurrencesSectionTitle.label, "Repeating Tasks")

        let recurrenceRow = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH 'home-recurrence-'"))
            .firstMatch
        XCTAssertTrue(recurrenceRow.exists)
        XCTAssertEqual(recurrenceRow.label, "Generated Repeat")
        XCTAssertGreaterThanOrEqual(recurrenceRow.frame.height, 44)
        XCTAssertEqual(
            app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH 'home-recurrence-stop-action-'")
            ).count,
            0
        )

        recurrenceRow.tap()
        XCTAssertTrue(app.staticTexts["Stop repeating this task?"].waitForExistence(timeout: 3))
        app.buttons["home-recurrence-stop-cancel-button"].firstMatch.tap()
        XCTAssertTrue(recurrenceRow.waitForExistence(timeout: 3))

        recurrenceRow.tap()
        XCTAssertTrue(app.staticTexts["Stop repeating this task?"].waitForExistence(timeout: 3))
        app.buttons["home-recurrence-stop-confirm-button"].firstMatch.tap()

        XCTAssertTrue(recurrenceRow.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Generated Repeat"].exists)
    }

    private enum Scenario: String {
        case signup
        case empty
        case workspace
        case recurrence
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
