//
//  NomaTests.swift
//  NomaTests
//
//  Created by Elias Papavlassopoulos on 15.05.26.
//

@testable import Noma
import SwiftUI
import XCTest

final class NomaTests: XCTestCase {
    func testSpacingContractExposesXsToken() {
        XCTAssertEqual(NomaSpacing.none, 0)
        XCTAssertEqual(NomaSpacing.xs, 4)
        XCTAssertEqual(NomaSpacing.xl, 24)
        XCTAssertEqual(NomaSpacing.xxl, 32)
    }

    func testProjectEmptyStateUsesSheetBottomBarForAddProjectCTA() {
        let emptyState = CreateProjectEmptyState.placeholder

        XCTAssertNil(emptyState.cta)
        XCTAssertTrue(CreateProjectSheetLayout.usesBottomSafeAreaBar)
    }

    func testDailyTaskGroupRowsUseScaleFeedbackAndCompletionCopy() {
        XCTAssertTrue(DailyTaskGroupRowInteraction.usesScaleButtonStyle)
        XCTAssertEqual(DailyTaskGroupRowLayout.completedIconAdditionalTrailingPadding, NomaSpacing.xs)
        XCTAssertEqual(DailyTaskGroupsProgressCopy.completedKey, "home.daily-groups.progress.completed")
    }

    func testCreateProjectSheetUsesRequestedLayoutAndCopy() {
        XCTAssertEqual(CreateProjectSheetCopy.titleKey, "create.project.add.title")
        XCTAssertEqual(CreateProjectSheetCopy.descriptionKey, "create.project.add.description")
        XCTAssertEqual(CreateProjectSheetLayout.focusedHorizontalPadding, NomaSpacing.sm)
        XCTAssertEqual(CreateProjectSheetLayout.collapsedHorizontalPadding, NomaSpacing.xxl)
        XCTAssertEqual(CreateProjectSheetLayout.keyboardSpacing, NomaSpacing.sm)
        XCTAssertEqual(CreateProjectSheetLayout.collapsedBottomPadding, NomaSpacing.xxl)
        XCTAssertEqual(CreateProjectSheetLayout.bottomPadding(isKeyboardPresented: true), NomaSpacing.sm)
        XCTAssertEqual(CreateProjectSheetLayout.horizontalPadding(isKeyboardPresented: true), NomaSpacing.sm)
        XCTAssertTrue(CreateProjectSheetLayout.usesNativeSheetKeyboardAvoidance)
        XCTAssertTrue(CreateProjectSheetLayout.usesScrollDrivenKeyboardDismissal)
        XCTAssertTrue(CreateProjectSheetLayout.usesBottomSafeAreaBar)
        XCTAssertEqual(
            CreateProjectSheetLayout.bottomPadding(
                isKeyboardPresented: false,
                bottomSafeAreaInset: NomaSpacing.sm
            ),
            NomaSpacing.xl
        )
    }

    func testProjectTitleInputUsesRoundedFortyPointSecondaryBackgroundField() {
        XCTAssertEqual(ProjectTitleInputLayout.height, 40)
        XCTAssertEqual(ProjectTitleInputLayout.cornerRadius, 20)
        XCTAssertEqual(ProjectTitleInputLayout.placeholderKey, "create.project.title.placeholder")
        XCTAssertEqual(TaskProjectTitlePolicy.characterLimit, NomaLimit.projectTitleCharacters)
        XCTAssertEqual(TaskProjectTitlePolicy.characterLimit, 50)
        XCTAssertEqual(TaskProjectTitlePolicy.normalizedTitle(from: "  Home  \n"), "Home")
        XCTAssertTrue(TaskProjectTitlePolicy.canCreateProject(title: "Work"))
        XCTAssertFalse(TaskProjectTitlePolicy.canCreateProject(title: "   "))
        XCTAssertFalse(TaskProjectTitlePolicy.canCreateProject(title: String(repeating: "a", count: 51)))
    }

    func testProjectIconPickerProvidesColorsAndSFSymbols() {
        XCTAssertEqual(ProjectIconPickerSheetCopy.titleKey, "create.project.icon-picker.title")
        XCTAssertEqual(ProjectIconPickerSheetCopy.doneAccessibilityLabelKey, "create.project.icon-picker.done")
        XCTAssertEqual(ProjectIconPickerSheetLayout.doneSystemImage, "checkmark")
        XCTAssertTrue(ProjectIconPickerSheetLayout.usesLargeDetent)
        XCTAssertTrue(ProjectIconPickerSheetLayout.colorPickerUsesSafeAreaPadding)
        XCTAssertTrue(ProjectIconPickerSheetLayout.iconGridUsesTopSafeAreaPadding)
        XCTAssertLessThan(ProjectIconPickerSheetLayout.colorOptionSize, NomaSize.projectControl)
        XCTAssertEqual(ProjectIconPickerSheetLayout.selectedColorBorderWidth, 4)
        XCTAssertEqual(AddProjectIconButton.placeholderSystemImage, "plus.circle.dashed")
        XCTAssertEqual(ProjectIconPickerOption.defaultColorIndex, 0)
        XCTAssertEqual(ProjectIconPickerOption.defaultSymbol, "folder")
        XCTAssertGreaterThan(ProjectIconPickerOption.colors.count, 4)
        XCTAssertTrue(ProjectIconPickerOption.symbols.contains("folder"))
        XCTAssertFalse(ProjectIconPickerOption.symbols.contains("kettlebell"))
    }

    func testTaskProjectUsesDefaultFolderIconWhenNoIconIsSelected() {
        let project = TaskProject(title: "Personal")

        XCTAssertEqual(project.title, "Personal")
        XCTAssertEqual(project.symbolName, ProjectIconPickerOption.defaultSymbol)
        XCTAssertEqual(project.colorIndex, ProjectIconPickerOption.defaultColorIndex)
    }

    func testHintViewAddsDefaultHorizontalPadding() {
        XCTAssertEqual(HintViewLayout.horizontalPadding, NomaSpacing.xl)
    }

    func testCreateTaskEmptyStateUsesHintCopyAndNoIcon() {
        let emptyState = CreateTaskEmptyState.placeholder

        XCTAssertNil(emptyState.systemImage)
        XCTAssertEqual(emptyState.titleKey, "create.tasks.empty.today.title")
        XCTAssertEqual(emptyState.subtitleKey, "create.tasks.empty.today.subtitle")
        XCTAssertFalse(emptyState.mirrorsImageForRightToLeftLayoutDirection)
        XCTAssertNil(emptyState.cta)
    }

    func testCreateReminderAutoScrollTargetsSubmittedReminderAfterSubmission() {
        let reminder = CreateReminder(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            text: "Last task"
        )

        XCTAssertEqual(
            CreateReminderAutoScroll.targetAfterAppending(reminder),
            CreateReminderAutoScroll.targetID(for: reminder)
        )
    }

    func testCreateReminderAutoScrollTargetsLastVisibleTaskAfterKeyboardFocus() {
        let firstReminder = CreateReminder(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            text: "First task"
        )
        let lastReminder = CreateReminder(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            text: "Last task"
        )

        XCTAssertEqual(
            CreateReminderAutoScroll.targetAfterKeyboardFocus(visibleReminders: [firstReminder, lastReminder]),
            CreateReminderAutoScroll.targetID(for: lastReminder)
        )
    }

    func testCreateReminderAutoScrollIgnoresKeyboardFocusWithoutTasks() {
        XCTAssertNil(CreateReminderAutoScroll.targetAfterKeyboardFocus(visibleReminders: []))
    }

    func testProjectSheetKeepsProjectSelectionCopyWithoutLimits() {
        XCTAssertEqual(CreateProjectListSection.selectionInfoKey, "create.projects.selection.info")
    }

    func testProjectExpirationOptionIsSmallDatePickerForEveryProject() {
        XCTAssertEqual(ProjectExpirationOption.titleKey, "create.project.expiration.title")
        XCTAssertEqual(ProjectExpirationOption.datePickerLabelKey, "create.project.expiration.date-picker")
        XCTAssertEqual(ProjectExpirationOption.controlSize, .small)
        XCTAssertEqual(ProjectExpirationOption.displayedComponents, .date)
        XCTAssertEqual(ProjectExpirationOption.defaultDurationDays, 7)
    }

    @MainActor
    func testReminderInputStateDisablesSubmitWhenUnavailable() {
        let state = ReminderInputState(text: "Next task", isSubmissionAvailable: false)

        XCTAssertFalse(state.canSubmit)
        XCTAssertEqual(state.sendButtonTone, .disabled)
    }

    func testPrimaryButtonUsesSharedLayoutTokens() {
        XCTAssertEqual(PrimaryButtonLayout.horizontalPadding, NomaSpacing.xl)
        XCTAssertEqual(PrimaryButtonLayout.verticalPadding, NomaSpacing.md)
    }

    @MainActor
    func testPrimaryButtonUsesSharedSubmitHapticFeedback() {
        XCTAssertEqual(PrimaryButtonFeedback.feedback, .createTaskSubmit)
    }

    func testCreateReminderListShowsEmptyStateOnlyWithoutTasks() {
        XCTAssertTrue(CreateReminderListSection.showsEmptyState(reminderCount: 0))
        XCTAssertFalse(CreateReminderListSection.showsEmptyState(reminderCount: 1))
    }

    func testCreateViewOnlyUsesScrollViewAfterTasksWereAdded() {
        XCTAssertFalse(CreateViewContentMode.usesScrollView(reminderCount: 0))
        XCTAssertTrue(CreateViewContentMode.usesScrollView(reminderCount: 1))
    }

    func testCreateViewUsesScrollViewForCarryForwardPreview() {
        XCTAssertTrue(CreateViewContentMode.usesScrollView(reminderCount: 0, carryForwardPreviewCount: 1))
    }

    func testCarryForwardPreviewExcludesTasksAlreadyAddedToday() {
        let projectID = UUID(uuidString: "00000000-0000-0000-0000-000000000051")!
        let previousOpenReminders = [
            CreateReminder(text: "Move invoice", projectID: projectID),
            CreateReminder(text: "Send update")
        ]
        let currentReminders = [
            CreateReminder(text: "Move invoice", projectID: projectID)
        ]

        XCTAssertEqual(
            CreateReminderCarryForwardPreview.visibleReminders(
                currentReminders: currentReminders,
                previousOpenReminders: previousOpenReminders
            )
            .map(\.text),
            ["Send update"]
        )
    }

    func testCarryForwardPreviewCompletionMarksOriginalReminderDone() {
        let reminderID = UUID(uuidString: "00000000-0000-0000-0000-000000000052")!
        let targetReminder = CreateReminder(id: reminderID, text: "Send update")
        let reminders = [
            CreateReminder(text: "Keep open"),
            targetReminder
        ]

        let updatedReminders = CreateReminderCarryForwardCompletion.completing(
            targetReminder,
            in: reminders
        )

        XCTAssertFalse(updatedReminders[0].isCompleted)
        XCTAssertTrue(updatedReminders[1].isCompleted)
    }

    func testCreateReminderSubmissionTrimsSubmittedText() {
        let reminder = CreateReminderSubmission.reminder(from: "  Call Mika  ")

        XCTAssertEqual(reminder?.text, "Call Mika")
    }

    func testCreateReminderSubmissionRemovesWhitespaceOnlyLines() {
        let reminder = CreateReminderSubmission.reminder(from: "  Call Mika  \n   \n\n  Bring notes  \n  ")

        XCTAssertEqual(reminder?.text, "Call Mika\nBring notes")
    }

    func testCreateReminderSubmissionRejectsTextOverCharacterLimit() {
        let overLimitText = String(repeating: "a", count: CreateReminderSubmission.characterLimit + 1)

        XCTAssertNil(CreateReminderSubmission.reminder(from: overLimitText))
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

    func testCreateReminderSubmissionRejectsEmptyText() {
        XCTAssertNil(CreateReminderSubmission.reminder(from: "   \n  "))
    }

    func testCreateReminderSubmissionClearsInputAfterSuccessfulSubmit() {
        let result = CreateReminderSubmission.submit(
            text: "  Call Mika  ",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        )

        XCTAssertEqual(result?.reminder.text, "Call Mika")
        XCTAssertEqual(result?.remainingText, "")
    }

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

    func testCreateReminderSubmissionUsesExplicitProjectOverSelectedProject() {
        let work = TaskProject(id: UUID(uuidString: "00000000-0000-0000-0000-000000000063")!, title: "Work")
        let home = TaskProject(id: UUID(uuidString: "00000000-0000-0000-0000-000000000064")!, title: "Home")
        let result = CreateReminderSubmission.submit(
            text: "Work: Send launch update",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000065")!,
            projects: [work, home],
            selectedProjectID: home.id
        )

        XCTAssertEqual(result?.reminder.text, "Send launch update")
        XCTAssertEqual(result?.reminder.projectID, work.id)
        XCTAssertEqual(result?.remainingText, "")
    }

    func testDraftReconciliationPreservesNewDraftTypedDuringAsyncSubmit() {
        XCTAssertEqual(
            CreateReminderDraftReconciliation.reconciledDraft(
                currentDraft: "Next task",
                submittedText: "Call Mika",
                remainingText: ""
            ),
            "Next task"
        )
    }

    func testDraftReconciliationClearsOnlyUnchangedAsyncSubmitDraft() {
        XCTAssertEqual(
            CreateReminderDraftReconciliation.reconciledDraft(
                currentDraft: "",
                submittedText: "Call Mika",
                remainingText: ""
            ),
            ""
        )
    }

    func testSubmittedReminderDropsDeletedProjectReference() {
        let deletedProjectID = UUID(uuidString: "00000000-0000-0000-0000-000000000067")!
        let selectedProject = TaskProject(id: UUID(uuidString: "00000000-0000-0000-0000-000000000068")!, title: "Inbox")

        XCTAssertEqual(
            CreateReminderSubmittedProjectResolution.projectID(
                submittedProjectID: deletedProjectID,
                currentProjects: [selectedProject],
                selectedProjectID: selectedProject.id
            ),
            selectedProject.id
        )
    }

    func testSubmittedReminderPersistenceAppendsToOriginatingDayAfterActiveDayChanges() {
        let existingReminder = CreateReminder(text: "Existing source task")
        let submittedReminder = CreateReminder(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000069")!,
            text: "Submitted while switching days"
        )
        let submission = CreateReminderSubmissionResult(reminder: submittedReminder, remainingText: "")

        XCTAssertEqual(
            CreateReminderSubmissionPersistence.updatedRemindersAfterAppending(
                sourceReminders: [existingReminder],
                submission: submission,
                projects: [],
                selectedProjectID: nil
            ),
            [existingReminder, submittedReminder]
        )
    }

    func testCarryForwardTransferRemovesTransferredTasksFromSourceDay() {
        let transferredReminder = CreateReminder(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000070")!,
            text: "Move invoice"
        )
        let remainingReminder = CreateReminder(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000071")!,
            text: "Keep yesterday"
        )

        XCTAssertEqual(
            CreateReminderCarryForwardTransfer.sourceRemindersAfterTransfer(
                sourceReminders: [transferredReminder, remainingReminder],
                transferredReminders: [transferredReminder]
            ),
            [remainingReminder]
        )
    }

    func testReminderInputRejectsSubmittedTextWrittenBackAfterClear() {
        var staleGuard = ReminderInputStaleTextGuard()

        staleGuard.prepareForSubmit(text: "Call Mika")

        XCTAssertFalse(staleGuard.acceptsIncomingText("Call Mika"))
        XCTAssertTrue(staleGuard.acceptsIncomingText("Next task"))
    }

    func testCreateReminderListLayoutUsesOnlySentinelBottomAnchor() {
        XCTAssertEqual(
            CreateReminderListLayout.bottomScrollPadding,
            NomaSize.scrollDismissSentinel
        )
    }

    func testCreateReminderRowsUseLargerVerticalSpacingBetweenTasks() {
        XCTAssertEqual(CreateReminderRowsLayout.spacingBetweenTasks, NomaSpacing.md)
    }

    func testSectionHeaderLayoutUsesTwentyFourPointBottomPadding() {
        XCTAssertEqual(SectionHeaderLayout.bottomPadding, 24)
    }

    func testSectionHeaderTextFormattingUsesTitleCase() {
        XCTAssertEqual(
            SectionHeaderTextFormatting.titleCased("tasks for today"),
            "Tasks For Today"
        )
    }

    func testCreateReminderStartsIncompleteAndCanToggleCompletion() {
        let reminder = CreateReminder(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, text: "Call Mika")

        XCTAssertFalse(reminder.isCompleted)
        XCTAssertTrue(reminder.togglingCompletion().isCompleted)
        XCTAssertFalse(reminder.togglingCompletion().togglingCompletion().isCompleted)
    }

    func testRadioCheckboxStateOnlyShowsInnerCircleWhenOn() {
        XCTAssertFalse(RadioCheckboxState(isOn: false).showsInnerCircle)
        XCTAssertTrue(RadioCheckboxState(isOn: true).showsInnerCircle)
    }

    func testCreateReminderListSectionUsesLocalizedTaskHeaderForEnteredTasks() {
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 5, day: 18))!
        let headerTitle = CreateReminderListSection.headerTitle(for: date)
        let dateText = date.formatted(date: .abbreviated, time: .omitted)

        XCTAssertEqual(CreateReminderListSection.headerTitleFormatKey, "create.tasks.date.section-header")
        XCTAssertEqual(CreateReminderListSection.carryForwardPreviewTitleKey, "create.tasks.yesterday.section-header")
        XCTAssertEqual(CreateReminderListSection.carryForwardPreviewSystemImage, "clock.arrow.circlepath")
        XCTAssertTrue(headerTitle.contains(dateText))
        XCTAssertFalse(CreateReminderListSection.showsHeader(reminderCount: 0))
        XCTAssertTrue(CreateReminderListSection.showsHeader(reminderCount: 1))
    }

    func testReminderCompletionHapticOnlyPlaysWhenToggledOn() {
        XCTAssertEqual(CreateReminderCompletionFeedback.feedback(isCompleted: true), .createTaskSubmit)
        XCTAssertNil(CreateReminderCompletionFeedback.feedback(isCompleted: false))
    }

    func testReminderSwipeOnlyTracksLeftDragAndDeletesAfterThreshold() {
        XCTAssertEqual(CreateReminderSwipeAction.minimumDistance, 0)
        XCTAssertTrue(CreateReminderSwipeAction.shouldTrackSwipe(translation: CGSize(width: -24, height: 4)))
        XCTAssertFalse(CreateReminderSwipeAction.shouldTrackSwipe(translation: CGSize(width: -4, height: 24)))
        XCTAssertFalse(CreateReminderSwipeAction.shouldTrackSwipe(translation: CGSize(width: 24, height: 4)))
        XCTAssertEqual(CreateReminderSwipeAction.offset(for: 24), 0)
        XCTAssertEqual(CreateReminderSwipeAction.offset(for: -24), -24 * NomaScale.taskDeleteSwipeDamping)
        XCTAssertFalse(CreateReminderSwipeAction.shouldDelete(offset: -24))
        XCTAssertFalse(CreateReminderSwipeAction.shouldDelete(offset: CreateReminderSwipeAction.offset(for: -24)))
        XCTAssertTrue(CreateReminderSwipeAction.shouldDelete(offset: -CreateReminderSwipeAction.deleteThreshold))
    }

    func testReminderSwipeProgressTracksDeleteThreshold() {
        XCTAssertEqual(CreateReminderSwipeAction.progress(for: 0), 0)
        XCTAssertEqual(CreateReminderSwipeAction.remainingProgress(for: 0), 1)
        XCTAssertEqual(
            CreateReminderSwipeAction.progress(for: -CreateReminderSwipeAction.deleteThreshold),
            1
        )
        XCTAssertEqual(
            CreateReminderSwipeAction.remainingProgress(for: -CreateReminderSwipeAction.deleteThreshold),
            0
        )
    }

    func testReminderSwipeFeedbackOnlyPlaysWhenCrossingDeleteThreshold() {
        XCTAssertEqual(
            CreateReminderSwipeAction.feedback(previousOffset: -24, currentOffset: -CreateReminderSwipeAction.deleteThreshold),
            .createTaskSubmit
        )
        XCTAssertNil(
            CreateReminderSwipeAction.feedback(
                previousOffset: -CreateReminderSwipeAction.deleteThreshold,
                currentOffset: -CreateReminderSwipeAction.deleteThreshold - 1
            )
        )
        XCTAssertNil(CreateReminderSwipeAction.feedback(previousOffset: 0, currentOffset: -24))
    }

    func testHapticFeedbackServiceRoutesSubmitFeedback() {
        var playedFeedback: [HapticFeedbackClass] = []
        let haptics = HapticFeedbackService { feedback in
            playedFeedback.append(feedback)
        }

        haptics.play(.createTaskSubmit)

        XCTAssertEqual(playedFeedback, [.createTaskSubmit])
    }

    func testSupabaseConfigurationTargetsNomaProject() {
        XCTAssertEqual(
            SupabaseClientProvider.projectURL.absoluteString,
            "https://ejulpxdohfnojevqntks.supabase.co"
        )
    }

    func testSupabaseConfigurationRequiresPublishableKey() {
        let configuration = SupabaseConfiguration(
            projectURL: SupabaseClientProvider.projectURL,
            publishableKey: ""
        )

        XCTAssertFalse(configuration.isConfigured)
    }

    func testSupabaseCurrentConfigurationIncludesPublishableKey() {
        XCTAssertTrue(SupabaseClientProvider.currentConfiguration.isConfigured)
        XCTAssertEqual(
            SupabaseClientProvider.currentConfiguration.publishableKey,
            SupabaseClientProvider.bundledPublishableKey
        )
    }

    func testSupabaseClientOptionsOptIntoLocalInitialSessionEmission() {
        XCTAssertTrue(SupabaseClientProvider.emitsLocalSessionAsInitialSession)
    }

    func testSignupLayoutUsesRequestedSpacing() {
        XCTAssertEqual(SignInWithAppleGlassButtonLayout.verticalPadding, 12)
        XCTAssertEqual(SignupViewLayout.edgePadding, 32)
        XCTAssertEqual(SignupViewLayout.bottomPadding, 32)
    }

    func testSignInWithAppleLoadingStateUsesSpinnerAndBlocksRepeatedTaps() {
        XCTAssertTrue(SignInWithAppleGlassButtonState(isLoading: true).showsProgressSpinner)
        XCTAssertFalse(SignInWithAppleGlassButtonState(isLoading: true).allowsInteraction)
        XCTAssertTrue(SignInWithAppleGlassButtonState(isLoading: true).usesBlurReplaceTransition)
        XCTAssertTrue(SignInWithAppleGlassButtonState(isLoading: true).preservesLabelLayout)
    }

}
