import SwiftUI

extension CreateView {
    var composerBar: some View {
        ReminderInputBar(
            text: $message,
            focus: $isInputFocused,
            placeholder: "create.input.placeholder",
            onSubmit: submitReminder
        )
    }

    var bottomComposerContent: some View {
        VStack(alignment: .leading, spacing: NomaSpacing.xl) {
            composerBar
        }
    }

    var currentDaySummary: DailyTaskGroupSummary {
        DailyTaskGroupSummary(
            group: DailyTaskGroup(
                id: activeDayID,
                date: currentDayDate,
                reminders: reminders
            )
        )
    }

    var currentDayDate: Date {
        DailyTaskGroupStore.date(forDayID: activeDayID) ?? Date()
    }

    var createNavigationTitle: String {
        currentDaySummary.title
    }

    var createNavigationSubtitle: String {
        DailyTaskGroupsProgressCopy.title(for: currentDaySummary)
    }

    var visibleReminders: [CreateReminder] {
        CreateReminderListFilter.visibleReminders(
            reminders,
            showsOnlyUnsolved: showsOnlyUnsolvedTasks,
            temporarilyVisibleCompletedReminderIDs: temporarilyVisibleCompletedReminderIDs
        )
    }

    @ToolbarContentBuilder
    var createToolbar: some ToolbarContent {
        TaskWorkspaceToolbar(
            title: createNavigationTitle,
            subtitle: createNavigationSubtitle,
            isDoneDisabled: !canCompleteAllReminders,
            isFilterActive: showsOnlyUnsolvedTasks,
            isFilterDisabled: reminders.isEmpty,
            onDone: completeAllRemindersForCurrentDay,
            onFilter: toggleUnsolvedFilter
        )
    }

    func submitReminder(_ submittedText: String) -> Bool {
        if let editingReminderID {
            return submitEditedReminder(submittedText, editingReminderID: editingReminderID)
        }

        let route = CreateReminderSubmissionRoute(originatingDayID: activeDayID)

        return submitReminderImmediately(submittedText, route: route)
    }

    @discardableResult
    func appendSubmittedReminder(
        _ submission: CreateReminderSubmissionResult,
        route: CreateReminderSubmissionRoute
    ) -> Bool {
        guard route.isOriginatingDayStillActive(activeDayID) else {
            return persistSubmittedReminderToOriginatingDay(
                submission,
                originatingDayID: route.originatingDayID
            )
        }

        var updatedReminders = reminders
        let submittedReminder = CreateReminderSubmissionPersistence.append(
            submission,
            to: &updatedReminders,
            projects: projects,
            selectedProjectID: nil
        )

        let didPersist = withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            dailyTaskGroups.replaceRemindersAtomically(updatedReminders, forDayID: activeDayID)
        }
        guard didPersist else { return false }

        hapticFeedback.play(.createTaskSubmit)
        pendingScrollTargetID = CreateReminderAutoScroll.targetAfterAppending(submittedReminder)
        return true
    }

    @discardableResult
    func persistSubmittedReminderToOriginatingDay(
        _ submission: CreateReminderSubmissionResult,
        originatingDayID: String
    ) -> Bool {
        let sourceReminders = dailyTaskGroups.reminders(forDayID: originatingDayID)
        var updatedReminders = sourceReminders
        CreateReminderSubmissionPersistence.append(
            submission,
            to: &updatedReminders,
            projects: [],
            selectedProjectID: nil
        )

        return dailyTaskGroups.replaceRemindersAtomically(updatedReminders, forDayID: originatingDayID)
    }

    func submitReminderImmediately(_ submittedText: String, route: CreateReminderSubmissionRoute) -> Bool {
        guard let submission = CreateReminderSubmission.submit(
            text: submittedText,
            projects: projects,
            selectedProjectID: nil
        ) else { return false }

        return appendSubmittedReminder(
            submission,
            route: route
        )
    }


    func scrollToReminderListBottomAfterKeyboardFocus() {
        guard let targetID = CreateReminderAutoScroll.targetAfterKeyboardFocus(visibleReminders: visibleReminders) else {
            return
        }

        pendingScrollTargetID = targetID
    }

    func toggleReminder(_ reminder: CreateReminder) {
        var updatedReminders = reminders
        let didToggle = CreateReminderCompletionVisibility.toggleReminderWithCompletionFeedback(
            reminder,
            in: &updatedReminders,
            showsOnlyUnsolved: showsOnlyUnsolvedTasks,
            visibleIDs: $temporarilyVisibleCompletedReminderIDs,
            hapticFeedback: hapticFeedback,
            persist: { dailyTaskGroups.setReminders($0, forDayID: activeDayID) }
        )
        guard didToggle else { return }
    }

    func deleteReminder(_ reminder: CreateReminder) {
        var updatedReminders = reminders
        guard let index = updatedReminders.firstIndex(where: { $0.id == reminder.id }) else { return }

        let didDelete = withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            _ = updatedReminders.remove(at: index)
            guard dailyTaskGroups.setReminders(updatedReminders, forDayID: activeDayID) else {
                return false
            }
            temporarilyVisibleCompletedReminderIDs.remove(reminder.id)
            return true
        }
        guard didDelete else { return }

        if editingReminderID == reminder.id {
            editingReminderID = nil
            message = ""
        }
    }

    var canCompleteAllReminders: Bool {
        reminders.contains { !$0.isCompleted }
    }

    func completeAllRemindersForCurrentDay() {
        guard canCompleteAllReminders else { return }

        let completedReminderIDs = reminders.filter { !$0.isCompleted }.map(\.id)
        let completedReminders = CreateReminderBatchCompletion.completingAll(reminders)
        let didComplete = withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            guard dailyTaskGroups.setReminders(completedReminders, forDayID: activeDayID) else {
                return false
            }
            CreateReminderCompletionVisibility.retainCompletedReminderIDs(
                completedReminderIDs,
                isNeeded: showsOnlyUnsolvedTasks,
                visibleIDs: &temporarilyVisibleCompletedReminderIDs
            )
            return true
        }
        guard didComplete else { return }

        hapticFeedback.play(.createTaskSubmit)
        CreateReminderCompletionVisibility.scheduleRemoval(of: completedReminderIDs, isNeeded: showsOnlyUnsolvedTasks, visibleIDs: $temporarilyVisibleCompletedReminderIDs)
    }

    func toggleUnsolvedFilter() {
        CreateReminderFilterToggle.toggle(
            isActive: showsOnlyUnsolvedTasks,
            hapticFeedback: hapticFeedback,
            setIsActive: { showsOnlyUnsolvedTasks = $0 }
        )
    }


    @ViewBuilder
    var content: some View {
        if CreateViewContentMode.usesScrollView(
            reminderCount: reminders.count,
            carryForwardPreviewCount: carryForwardPreviewReminders.count
        ) {
            CreateReminderScrollContainer(pendingScrollTargetID: $pendingScrollTargetID) {
                CreateReminderList(
                    reminders: visibleReminders,
                    carryForwardPreviewReminders: carryForwardPreviewReminders,
                    sectionTitle: CreateReminderListSection.headerTitle(for: currentDayDate),
                    reminderCount: reminders.count,
                    projects: [],
                    dayID: activeDayID,
                    onToggleReminder: toggleReminder,
                    onEditReminder: beginEditingReminder,
                    onDeleteReminder: deleteReminder,
                    onCarryForwardReminder: { reminder in addCarryForwardReminders([reminder]) },
                    onCompleteCarryForwardReminder: completeCarryForwardReminder
                )
            }
        } else {
            CreateTaskEmptyHint()
                .padding(.horizontal, NomaSpacing.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

}
