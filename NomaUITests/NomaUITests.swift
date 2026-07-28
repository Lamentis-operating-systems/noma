import XCTest

@MainActor
final class NomaUITests: XCTestCase {
    private enum Scenario: String {
        case signup
        case workspace
    }

    private enum AppLocale: String, CaseIterable {
        case english = "en"
        case german = "de"

        var appleLocale: String {
            switch self {
            case .english: "en_US"
            case .german: "de_DE"
            }
        }

        var privacyLabel: String {
            switch self {
            case .english: "Privacy Policy"
            case .german: "Datenschutzbestimmungen"
            }
        }

        var appleButtonLabel: String {
            switch self {
            case .english: "Sign in with Apple"
            case .german: "Mit Apple anmelden"
            }
        }
    }

    private enum DynamicType: String, CaseIterable {
        case standard = "default"
        case accessibility5 = "AX5"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func testSignupLocaleAndDynamicTypeMatrix() throws {
        var titleHeights: [AppLocale: [DynamicType: CGFloat]] = [:]

        for locale in AppLocale.allCases {
            for dynamicType in DynamicType.allCases {
                let app = launchApp(
                    scenario: .signup,
                    locale: locale,
                    dynamicType: dynamicType
                )
                let variant = "signup-\(locale.rawValue)-\(dynamicType.rawValue)"

                let title = staticText("signup-title", in: app)
                XCTAssertTrue(title.waitForExistence(timeout: 8), "Missing title in \(variant)")
                titleHeights[locale, default: [:]][dynamicType] = title.frame.height
                attachScreenshot(named: "\(variant)-top")

                let scrollView = app.scrollViews.matching(
                    identifier: "signup-marketing-scroll"
                ).firstMatch
                let privacyLink = button("signup-privacy-link", in: app)
                let appleButton = button("signup-apple-button", in: app)

                XCTAssertTrue(scrollView.waitForExistence(timeout: 3))
                XCTAssertEqual(
                    app.switches.matching(identifier: "signup-consent-toggle").count,
                    0,
                    "Signup must not require a separate consent toggle"
                )
                XCTAssertTrue(privacyLink.waitForExistence(timeout: 3))
                XCTAssertEqual(privacyLink.label, locale.privacyLabel)
                XCTAssertTrue(privacyLink.isEnabled)
                XCTAssertTrue(privacyLink.isHittable)
                XCTAssertEqual(
                    app.buttons.matching(identifier: "signup-privacy-link").count,
                    1,
                    "Privacy policy must expose exactly one button node"
                )
                XCTAssertEqual(privacyLink.descendants(matching: .button).count, 0)
                assertContained(privacyLink, in: app)

                XCTAssertTrue(appleButton.waitForExistence(timeout: 3))
                XCTAssertEqual(appleButton.label, locale.appleButtonLabel)
                XCTAssertEqual(
                    app.buttons.matching(identifier: "signup-apple-button").count,
                    1,
                    "Apple sign-in must expose exactly one button node"
                )
                XCTAssertEqual(appleButton.descendants(matching: .button).count, 0)
                XCTAssertTrue(appleButton.isEnabled, "Apple sign-in must be immediately available")
                XCTAssertTrue(appleButton.isHittable)
                assertContained(appleButton, in: app)
                assertNoRawAppleSymbol(in: app)
                if locale == .english, dynamicType == .standard {
                    attachAccessibilityTree(of: app, named: "signup-ax-tree-en-default")
                }

                let privacyLinkFrame = privacyLink.frame
                let appleButtonFrame = appleButton.frame
                scrollView.swipeUp()
                XCTAssertEqual(
                    privacyLink.frame.minY,
                    privacyLinkFrame.minY,
                    accuracy: 1,
                    "Privacy link must remain fixed while marketing content scrolls"
                )
                XCTAssertEqual(
                    appleButton.frame.minY,
                    appleButtonFrame.minY,
                    accuracy: 1,
                    "Apple sign-in must remain fixed while marketing content scrolls"
                )

                attachScreenshot(named: variant)

                app.terminate()
            }
        }

        for locale in AppLocale.allCases {
            let standardHeight = try XCTUnwrap(titleHeights[locale]?[.standard])
            let accessibilityHeight = try XCTUnwrap(titleHeights[locale]?[.accessibility5])
            XCTAssertGreaterThan(
                accessibilityHeight,
                standardHeight,
                "AX5 title should render larger than default for \(locale.rawValue)"
            )
        }
    }

    func testHomeCreateButtonKeepsThirtyTwoPointBottomInset() {
        let app = launchApp(scenario: .workspace, locale: .english)
        let createButton = button("home-create-button", in: app)

        XCTAssertTrue(createButton.waitForExistence(timeout: 8))
        XCTAssertEqual(
            app.windows.firstMatch.frame.maxY - createButton.frame.maxY,
            32,
            accuracy: 1,
            "Home create button must remain 32pt from the lower screen edge"
        )

        app.terminate()
    }

    func testCreateWorkspaceKeyboardProjectSheetsAndLongGermanLabel() {
        let app = launchApp(scenario: .workspace, locale: .german)

        let homeScroll = app.scrollViews.matching(identifier: "home-scroll").firstMatch
        XCTAssertTrue(homeScroll.waitForExistence(timeout: 8))
        let createButton = button("home-create-button", in: app)
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.tap()

        let input = textField("create-reminder-input", in: app)
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("Entwurf fuer den Modaltest")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        assertInput(input, sitsAbove: app.keyboards.firstMatch)
        attachScreenshot(named: "create-keyboard-de")

        let trayButton = button("create-reminder-tray-button", in: app)
        XCTAssertTrue(trayButton.isHittable)
        trayButton.tap()

        let createProjectButton = button("project-sheet-create-button", in: app)
        XCTAssertTrue(createProjectButton.waitForExistence(timeout: 5))
        XCTAssertEqual(createProjectButton.label, "Neues Projekt erstellen")
        XCTAssertTrue(createProjectButton.isHittable)
        assertContained(createProjectButton, in: app)
        attachScreenshot(named: "project-list-sheet-de")
        createProjectButton.tap()

        let saveButton = button("project-editor-save-button", in: app)
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        XCTAssertEqual(saveButton.label, "Projekt erstellen")
        XCTAssertFalse(saveButton.isEnabled)

        let iconButton = button("project-icon-button", in: app)
        XCTAssertTrue(iconButton.waitForExistence(timeout: 3))
        iconButton.tap()

        let pickerDone = button("project-icon-picker-done", in: app)
        XCTAssertTrue(pickerDone.waitForExistence(timeout: 5))
        let folderButton = app.buttons["Ordner"]
        let financesButton = app.buttons["Finanzen"]
        XCTAssertTrue(folderButton.waitForExistence(timeout: 3))
        XCTAssertTrue(financesButton.exists)
        XCTAssertTrue(folderButton.isSelected)
        financesButton.tap()
        XCTAssertTrue(waitForSelected(financesButton))
        XCTAssertFalse(folderButton.isSelected)
        XCTAssertEqual(rawImageCount(named: "folder", in: folderButton), 0)
        XCTAssertEqual(rawImageCount(named: "dollarsign.circle", in: financesButton), 0)
        XCTAssertFalse(app.images["project-icon-preview"].exists)
        attachScreenshot(named: "project-icon-picker-de")
        attachAccessibilityTree(of: app, named: "project-icon-picker-ax-de")

        XCTAssertEqual(pickerDone.label, "Fertig")
        pickerDone.tap()
        XCTAssertTrue(pickerDone.waitForNonExistence(timeout: 5))

        let titleInput = textField("project-title-input", in: app)
        XCTAssertTrue(titleInput.waitForExistence(timeout: 3))
        titleInput.tap()
        titleInput.typeText("Ein besonders langes Projekt fuer UI Tests")
        XCTAssertTrue(waitForEnabled(saveButton))
        XCTAssertEqual(saveButton.label, "Projekt erstellen")
        XCTAssertTrue(saveButton.isHittable)
        assertContained(saveButton, in: app)
        attachScreenshot(named: "project-editor-long-cta-de")
        saveButton.tap()

        XCTAssertTrue(titleInput.waitForNonExistence(timeout: 5))
        XCTAssertTrue(createProjectButton.exists)
        let closeButton = button("close-toolbar-button", in: app)
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3))
        closeButton.tap()
        XCTAssertTrue(createProjectButton.waitForNonExistence(timeout: 5))
        XCTAssertTrue(input.exists)

        if app.keyboards.firstMatch.exists {
            app.swipeDown()
        }

        let doneButton = button("task-workspace-done-button", in: app)
        let filterButton = button("task-workspace-filter-button", in: app)
        XCTAssertTrue(doneButton.isEnabled)
        XCTAssertTrue(filterButton.isEnabled)
        doneButton.tap()
        XCTAssertTrue(waitForDisabled(doneButton))
        filterButton.tap()
        XCTAssertTrue(waitForSelected(filterButton))
        attachScreenshot(named: "create-toolbar-completed-filtered-de")
    }

    func testProjectDetailKeyboardFilterCompletionAndEditSheet() {
        let app = launchApp(scenario: .workspace, locale: .english)

        let homeScroll = app.scrollViews.matching(identifier: "home-scroll").firstMatch
        XCTAssertTrue(homeScroll.waitForExistence(timeout: 8))
        let projectRow = button(
            "home-project-00000000-0000-0000-0000-00000000A001",
            in: app
        )
        scrollUntilHittable(projectRow, in: homeScroll)
        projectRow.tap()

        let input = textField("create-reminder-input", in: app)
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        let doneButton = button("task-workspace-done-button", in: app)
        let filterButton = button("task-workspace-filter-button", in: app)
        XCTAssertTrue(doneButton.isEnabled)
        XCTAssertTrue(filterButton.isEnabled)

        filterButton.tap()
        XCTAssertTrue(waitForSelected(filterButton))
        filterButton.tap()
        XCTAssertTrue(waitForNotSelected(filterButton))

        input.tap()
        input.typeText("Project detail draft")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        assertInput(input, sitsAbove: app.keyboards.firstMatch)
        attachScreenshot(named: "project-detail-keyboard-en")

        app.swipeDown()
        doneButton.tap()
        XCTAssertTrue(waitForDisabled(doneButton))

        let titleButton = button("task-workspace-title-button", in: app)
        XCTAssertTrue(titleButton.isHittable)
        titleButton.tap()

        let saveButton = button("project-editor-save-button", in: app)
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        XCTAssertEqual(saveButton.label, "Save Project")
        XCTAssertTrue(saveButton.isEnabled)
        XCTAssertTrue(saveButton.isHittable)
        assertContained(saveButton, in: app)
        attachScreenshot(named: "project-detail-edit-sheet-en")

        let iconButton = button("project-icon-button", in: app)
        iconButton.tap()
        let pickerDone = button("project-icon-picker-done", in: app)
        XCTAssertTrue(pickerDone.waitForExistence(timeout: 5))
        let folderButton = app.buttons["Folder"]
        let financesButton = app.buttons["Finances"]
        XCTAssertTrue(folderButton.waitForExistence(timeout: 3))
        XCTAssertTrue(financesButton.exists)
        XCTAssertTrue(folderButton.isSelected)
        financesButton.tap()
        XCTAssertTrue(waitForSelected(financesButton))
        XCTAssertFalse(folderButton.isSelected)
        XCTAssertEqual(rawImageCount(named: "folder", in: folderButton), 0)
        XCTAssertEqual(rawImageCount(named: "dollarsign.circle", in: financesButton), 0)
        XCTAssertFalse(app.images["project-icon-preview"].exists)
        attachScreenshot(named: "project-icon-picker-en")
        attachAccessibilityTree(of: app, named: "project-icon-picker-ax-en")
        pickerDone.tap()
        XCTAssertTrue(pickerDone.waitForNonExistence(timeout: 5))
    }

    func testHomeHeaderScrollRotationAndRelaunch() {
        let runIdentifier = UUID()
        let app = launchApp(
            scenario: .workspace,
            locale: .english,
            runIdentifier: runIdentifier
        )

        let homeScroll = app.scrollViews.matching(identifier: "home-scroll").firstMatch
        let homeHeader = staticText("home-header", in: app)
        XCTAssertTrue(homeScroll.waitForExistence(timeout: 8))
        XCTAssertTrue(homeHeader.waitForExistence(timeout: 5))
        assertContained(homeHeader, in: app)
        attachScreenshot(named: "home-header-top-en")

        for _ in 0..<3 where homeHeader.exists {
            homeScroll.swipeUp()
        }
        XCTAssertTrue(homeHeader.waitForNonExistence(timeout: 5))
        attachScreenshot(named: "home-header-gone-en")

        for _ in 0..<8 where !homeHeader.exists {
            homeScroll.swipeDown()
        }
        XCTAssertTrue(homeHeader.waitForExistence(timeout: 5))
        assertContained(homeHeader, in: app)
        attachScreenshot(named: "home-header-restored-en")

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(homeScroll.waitForExistence(timeout: 5))
        XCTAssertTrue(homeHeader.waitForExistence(timeout: 5))
        XCTAssertEqual(XCUIDevice.shared.orientation, .landscapeLeft)
        XCTAssertGreaterThan(app.windows.firstMatch.frame.height, app.windows.firstMatch.frame.width)
        attachScreenshot(named: "home-header-landscape-en")

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(homeScroll.waitForExistence(timeout: 5))
        XCTAssertTrue(homeHeader.waitForExistence(timeout: 5))
        XCTAssertEqual(XCUIDevice.shared.orientation, .portrait)
        XCTAssertGreaterThan(app.windows.firstMatch.frame.height, app.windows.firstMatch.frame.width)
        attachScreenshot(named: "home-header-portrait-en")

        app.terminate()
        app.launch()

        let relaunchedScroll = app.scrollViews.matching(identifier: "home-scroll").firstMatch
        let relaunchedHeader = staticText("home-header", in: app)
        XCTAssertTrue(relaunchedScroll.waitForExistence(timeout: 8))
        XCTAssertTrue(relaunchedHeader.waitForExistence(timeout: 5))
        assertContained(relaunchedHeader, in: app)
        attachScreenshot(named: "home-header-relaunch-en")
        app.terminate()
    }

    private func launchApp(
        scenario: Scenario,
        locale: AppLocale,
        dynamicType: DynamicType = .standard,
        runIdentifier: UUID = UUID()
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--noma-ui-test-scenario", scenario.rawValue,
            "--noma-ui-test-locale", locale.rawValue,
            "--noma-ui-test-dynamic-type", dynamicType.rawValue,
            "--noma-ui-test-run-id", runIdentifier.uuidString,
            "-AppleLanguages", "(\(locale.rawValue))",
            "-AppleLocale", locale.appleLocale
        ]
        app.launch()
        return app
    }

    private func button(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(identifier: identifier).firstMatch
    }

    private func staticText(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(identifier: identifier).firstMatch
    }

    private func textField(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.textFields.matching(identifier: identifier).firstMatch
    }

    private func scrollUntilHittable(
        _ target: XCUIElement,
        in scrollView: XCUIElement,
        maxSwipes: Int = 8
    ) {
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3))
        var remainingSwipes = maxSwipes
        while (!target.exists || !target.isHittable), remainingSwipes > 0 {
            if target.exists, target.frame.midY < scrollView.frame.midY {
                scrollView.swipeDown()
            } else {
                scrollView.swipeUp()
            }
            remainingSwipes -= 1
        }
        XCTAssertTrue(target.exists, "Element never appeared: \(target)")
        XCTAssertTrue(target.isHittable, "Element never became hittable: \(target)")
    }

    private func waitForEnabled(_ element: XCUIElement) -> Bool {
        let expectation = expectation(
            for: NSPredicate(format: "enabled == true"),
            evaluatedWith: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: 3) == .completed
    }

    private func waitForDisabled(_ element: XCUIElement) -> Bool {
        let expectation = expectation(
            for: NSPredicate(format: "enabled == false"),
            evaluatedWith: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: 3) == .completed
    }

    private func waitForSelected(_ element: XCUIElement) -> Bool {
        let expectation = expectation(
            for: NSPredicate(format: "selected == true"),
            evaluatedWith: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: 3) == .completed
    }

    private func waitForNotSelected(_ element: XCUIElement) -> Bool {
        let expectation = expectation(
            for: NSPredicate(format: "selected == false"),
            evaluatedWith: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: 3) == .completed
    }

    private func assertInput(
        _ input: XCUIElement,
        sitsAbove keyboard: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertLessThanOrEqual(
            input.frame.maxY,
            keyboard.frame.minY + 2,
            "Composer input overlaps the keyboard",
            file: file,
            line: line
        )
    }

    private func assertContained(
        _ element: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let windowFrame = app.windows.firstMatch.frame
        XCTAssertTrue(
            windowFrame.insetBy(dx: -1, dy: -1).contains(element.frame),
            "Element is clipped outside the app window: \(element)",
            file: file,
            line: line
        )
    }

    private func assertNoRawAppleSymbol(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(rawImageCount(named: "apple.logo", in: app), 0, file: file, line: line)
    }

    private func rawImageCount(named name: String, in app: XCUIApplication) -> Int {
        app.images.matching(
            NSPredicate(format: "identifier == %@ OR label == %@", name, name)
        ).count
    }

    private func rawImageCount(named name: String, in element: XCUIElement) -> Int {
        element.descendants(matching: .image).matching(
            NSPredicate(format: "identifier == %@ OR label == %@", name, name)
        ).count
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func attachAccessibilityTree(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

}
