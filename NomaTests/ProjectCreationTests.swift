@testable import Noma
import SwiftUI
import XCTest

final class ProjectCreationTests: XCTestCase {
    func testCreateProjectSheetPaddingAdaptsToKeyboardAndSafeArea() {
        XCTAssertLessThan(
            CreateProjectSheetLayout.horizontalPadding(isKeyboardPresented: true),
            CreateProjectSheetLayout.horizontalPadding(isKeyboardPresented: false)
        )
        XCTAssertLessThan(
            CreateProjectSheetLayout.bottomPadding(isKeyboardPresented: true),
            CreateProjectSheetLayout.bottomPadding(isKeyboardPresented: false)
        )
        XCTAssertEqual(
            CreateProjectSheetLayout.bottomPadding(
                isKeyboardPresented: false,
                bottomSafeAreaInset: NomaSpacing.sm
            ),
            CreateProjectSheetLayout.bottomPadding(isKeyboardPresented: false) - NomaSpacing.sm
        )
        XCTAssertEqual(
            CreateProjectSheetLayout.bottomPadding(
                isKeyboardPresented: false,
                bottomSafeAreaInset: CreateProjectSheetLayout.collapsedBottomPadding * 2
            ),
            0
        )
    }

    func testProjectTitlePolicyNormalizesAndValidatesTitles() {
        XCTAssertEqual(TaskProjectTitlePolicy.normalizedTitle(from: "  Home  \n"), "Home")
        XCTAssertTrue(TaskProjectTitlePolicy.canCreateProject(title: "Work"))
        XCTAssertFalse(TaskProjectTitlePolicy.canCreateProject(title: "   "))
        XCTAssertTrue(
            TaskProjectTitlePolicy.canCreateProject(
                title: String(repeating: "a", count: TaskProjectTitlePolicy.characterLimit)
            )
        )
        XCTAssertFalse(
            TaskProjectTitlePolicy.canCreateProject(
                title: String(repeating: "a", count: TaskProjectTitlePolicy.characterLimit + 1)
            )
        )
    }

    func testProjectIconPickerNormalizesColorSelection() {
        let lastColorIndex = ProjectIconPickerOption.colors.index(before: ProjectIconPickerOption.colors.endIndex)

        XCTAssertEqual(
            ProjectIconPickerOption.normalizedColorIndex(ProjectIconPickerOption.defaultColorIndex),
            ProjectIconPickerOption.defaultColorIndex
        )
        XCTAssertEqual(ProjectIconPickerOption.normalizedColorIndex(lastColorIndex), lastColorIndex)
        XCTAssertEqual(
            ProjectIconPickerOption.normalizedColorIndex(-1),
            ProjectIconPickerOption.defaultColorIndex
        )
        XCTAssertEqual(
            ProjectIconPickerOption.normalizedColorIndex(ProjectIconPickerOption.colors.endIndex),
            ProjectIconPickerOption.defaultColorIndex
        )
    }

    func testTaskProjectUsesDefaultFolderIconWhenNoIconIsSelected() {
        let project = TaskProject(title: "Personal")

        XCTAssertEqual(project.title, "Personal")
        XCTAssertEqual(project.symbolName, ProjectIconPickerOption.defaultSymbol)
        XCTAssertEqual(project.colorIndex, ProjectIconPickerOption.defaultColorIndex)
    }

    func testProjectExpirationDefaultsToConfiguredDurationFromNow() throws {
        let calendar = Calendar.current
        let before = Date()
        let expirationDate = ProjectExpirationOption.defaultDate()
        let after = Date()
        let earliestExpiration = try XCTUnwrap(
            calendar.date(
                byAdding: .day,
                value: ProjectExpirationOption.defaultDurationDays,
                to: before
            )
        )
        let latestExpiration = try XCTUnwrap(
            calendar.date(
                byAdding: .day,
                value: ProjectExpirationOption.defaultDurationDays,
                to: after
            )
        )

        XCTAssertGreaterThanOrEqual(expirationDate, earliestExpiration)
        XCTAssertLessThanOrEqual(expirationDate, latestExpiration)
    }
}
