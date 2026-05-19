import SwiftUI

extension CreateView {
    var composerBar: some View {
        ReminderInputBar(
            text: $message,
            focus: $isInputFocused,
            placeholder: "create.input.placeholder",
            isSubmissionAvailable: canSubmitReminder,
            traySystemImage: selectedProject?.symbolName ?? "tray.full",
            trayColor: TaskProjectIconPresentation.appSurfaceColor,
            onTrayButtonTap: { isProjectSheetPresented = true },
            onSubmit: submitReminder
        )
    }

    func bottomComposerContent(in proxy: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: NomaSpacing.xl) {
            if showsSuggestedProjectButton {
                suggestedProjectButton
            }

            if showsCarryForwardButton {
                carryForwardButton
            }

            if isPlanningDay {
                CreateAIGeneratingStatus(titleKey: "create.ai-generating.task-organization")
            }

            if isSubmittingReminder {
                CreateAIGeneratingStatus(titleKey: "create.ai-generating.smart-capture")
            }

            composerBar
        }
        .frame(width: barWidth(in: proxy), alignment: .leading)
        .padding(.bottom, barBottomPadding(in: proxy))
    }

    var selectedProject: TaskProject? {
        projects.first { $0.id == selectedProjectID }
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
        let filteredReminders = CreateReminderListFilter.visibleReminders(
            reminders,
            showsOnlyUnsolved: showsOnlyUnsolvedTasks
        )
        return CreateReminderListOrganization.sortedReminders(
            filteredReminders,
            using: taskOrganization
        )
    }

    @ToolbarContentBuilder
    var createToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            TaskNavigationTitleButton(
                title: createNavigationTitle,
                subtitle: createNavigationSubtitle,
                accessibilityLabelKey: "create.date-picker.open.accessibility-label",
                action: openDatePickerSheet
            )
        }

        ToolbarItem(placement: .topBarTrailing) {
            TaskDoneToolbarButton(
                isDisabled: !canCompleteAllReminders,
                action: completeAllRemindersForCurrentDay
            )
        }

        ToolbarSpacer(.fixed, placement: .topBarTrailing)

        ToolbarItem(placement: .topBarTrailing) {
            TaskFilterToolbarButton(
                isActive: showsOnlyUnsolvedTasks,
                isDisabled: reminders.isEmpty,
                action: toggleUnsolvedFilter
            )
        }
    }

    func submitReminder(_ submittedText: String) {
        guard canSubmitReminder else { return }
        if let editingReminderID {
            submitEditedReminder(submittedText, editingReminderID: editingReminderID)
            return
        }

        let originatingDayID = activeDayID

        guard subscriptionTier.tier.canUseOnDeviceFoundationModels else {
            submitReminderImmediately(submittedText, originatingDayID: originatingDayID)
            return
        }

        isSubmittingReminder = true

        Task {
            let submission = await CreateReminderAISmartCapture.submit(
                text: submittedText,
                projects: projects,
                selectedProjectID: selectedProjectID,
                tier: subscriptionTier.tier,
                foundationModel: onDeviceFoundationModel
            )

            await MainActor.run {
                isSubmittingReminder = false
                guard let submission else { return }
                appendSubmittedReminder(
                    submission,
                    submittedText: submittedText,
                    originatingDayID: originatingDayID
                )
            }
        }
    }

    func appendSubmittedReminder(
        _ submission: CreateReminderSubmissionResult,
        submittedText: String,
        originatingDayID: String
    ) {
        guard activeDayID == originatingDayID else {
            persistSubmittedReminderToOriginatingDay(
                submission,
                originatingDayID: originatingDayID
            )
            return
        }

        guard let updatedReminders = CreateReminderSubmissionPersistence.updatedRemindersAfterAppending(
            sourceReminders: reminders,
            submission: submission,
            projects: projects,
            selectedProjectID: selectedProjectID,
            tier: subscriptionTier.tier
        ) else { return }
        guard let submittedReminder = updatedReminders.last else { return }

        message = CreateReminderDraftReconciliation.reconciledDraft(
            currentDraft: message,
            submittedText: submittedText,
            remainingText: submission.remainingText
        )
        taskOrganization = nil
        hapticFeedback.play(.createTaskSubmit)
        withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            reminders = updatedReminders
        }
        saveCurrentReminders()
        pendingScrollTargetID = CreateReminderAutoScroll.targetAfterAppending(submittedReminder)
        organizeTasksWithAIAfterUserAddedTask()
    }

    func persistSubmittedReminderToOriginatingDay(
        _ submission: CreateReminderSubmissionResult,
        originatingDayID: String
    ) {
        let sourceReminders = dailyTaskGroups.reminders(forDayID: originatingDayID)
        let sourceProjects = dailyTaskGroups.projects(forDayID: originatingDayID)
        let sourceSelectedProjectID = dailyTaskGroups.selectedProjectID(forDayID: originatingDayID)

        guard let updatedReminders = CreateReminderSubmissionPersistence.updatedRemindersAfterAppending(
            sourceReminders: sourceReminders,
            submission: submission,
            projects: sourceProjects,
            selectedProjectID: sourceSelectedProjectID,
            tier: subscriptionTier.tier
        ) else { return }

        dailyTaskGroups.save(
            reminders: updatedReminders,
            projects: sourceProjects,
            selectedProjectID: sourceSelectedProjectID,
            forDayID: originatingDayID
        )
    }

    var canAddSubmittedReminder: Bool {
        subscriptionTier.tier.canAddTask(toGroupWithTaskCount: reminders.count)
    }

    func submitReminderImmediately(_ submittedText: String, originatingDayID: String) {
        guard let submission = CreateReminderSubmission.submit(
            text: submittedText,
            projects: projects,
            selectedProjectID: selectedProjectID
        ) else { return }

        appendSubmittedReminder(
            submission,
            submittedText: submittedText,
            originatingDayID: originatingDayID
        )
    }

    var canSubmitReminder: Bool {
        !isSubmittingReminder && (editingReminderID != nil || subscriptionTier.tier.canAddTask(toGroupWithTaskCount: reminders.count))
    }

    func unlockMoreTasks() {
        #if DEBUG
        subscriptionTier.debugUnlockPro()
        #else
        isUnlockMoreSheetPresented = true
        #endif
    }

    func unlockMoreProjects() {
        #if DEBUG
        subscriptionTier.debugUnlockPro()
        #else
        isUnlockMoreSheetPresented = true
        #endif
    }

    func addProject(_ project: TaskProject) {
        projects.append(project)
        selectedProjectID = project.id
        saveCurrentDailyGroup()
    }

    func updateProject(_ project: TaskProject) {
        dailyTaskGroups.updateProject(project)
        projects = dailyTaskGroups.projects(forDayID: activeDayID)
    }

    func deleteProject(_ projectID: TaskProject.ID) {
        dailyTaskGroups.deleteProject(withID: projectID)

        withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            reminders = dailyTaskGroups.reminders(forDayID: activeDayID)
        }
        projects = dailyTaskGroups.projects(forDayID: activeDayID)
        selectedProjectID = dailyTaskGroups.selectedProjectID(forDayID: activeDayID)
    }

    func selectProject(_ projectID: TaskProject.ID?) {
        selectedProjectID = projectID
        saveCurrentDailyGroup()
    }

    func scrollToReminderListBottomAfterKeyboardFocus() {
        guard let targetID = CreateReminderAutoScroll.targetAfterKeyboardFocus(visibleReminders: visibleReminders) else {
            return
        }

        pendingScrollTargetID = targetID
    }

    func toggleReminder(_ reminder: CreateReminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        let updatedReminder = reminders[index].togglingCompletion()

        if let feedback = CreateReminderCompletionFeedback.feedback(isCompleted: updatedReminder.isCompleted) {
            hapticFeedback.play(feedback)
        }

        withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            reminders[index] = updatedReminder
        }
        taskOrganization = nil
        saveCurrentDailyGroup()
    }

    func deleteReminder(_ reminder: CreateReminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }

        withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            _ = reminders.remove(at: index)
        }
        if editingReminderID == reminder.id {
            editingReminderID = nil
            message = ""
        }
        taskOrganization = nil
        saveCurrentDailyGroup()
    }

    var canCompleteAllReminders: Bool {
        reminders.contains { !$0.isCompleted }
    }

    func completeAllRemindersForCurrentDay() {
        guard canCompleteAllReminders else { return }

        hapticFeedback.play(.createTaskSubmit)
        withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            reminders = CreateReminderBatchCompletion.completingAll(reminders)
        }
        taskOrganization = nil
        saveCurrentDailyGroup()
    }

    func toggleUnsolvedFilter() {
        CreateReminderFilterToggle.toggle(
            isActive: showsOnlyUnsolvedTasks,
            hapticFeedback: hapticFeedback,
            setIsActive: { showsOnlyUnsolvedTasks = $0 }
        )
    }

    func saveCurrentReminders() {
        saveCurrentDailyGroup()
    }

    func saveCurrentDailyGroup() {
        dailyTaskGroups.save(
            reminders: reminders,
            projects: projects,
            selectedProjectID: selectedProjectID,
            forDayID: activeDayID
        )
    }

    func playSwipeDeleteThresholdFeedback() {
        hapticFeedback.play(.createTaskSubmit)
    }

    var barSpacing: CGFloat { max(0, isKeyboardPresented ? focusedKeyboardSpacing : 0) }

    func barWidth(in proxy: GeometryProxy) -> CGFloat {
        BottomComposerBarLayout.width(in: proxy, edgePadding: barEdgePadding)
    }

    func barBottomPadding(in proxy: GeometryProxy) -> CGFloat {
        BottomComposerBarLayout.bottomPadding(
            isKeyboardPresented: isKeyboardPresented,
            focusedPadding: focusedEdgePadding,
            collapsedPadding: collapsedEdgePadding,
            safeAreaBottom: proxy.safeAreaInsets.bottom
        )
    }

    var barEdgePadding: CGFloat { isKeyboardPresented ? focusedEdgePadding : collapsedEdgePadding }

    var projectSheet: some View {
        CreateSheet(
            projects: $projects,
            selectedProjectID: $selectedProjectID,
            allReminders: dailyTaskGroups.allReminders(),
            tier: subscriptionTier.tier,
            onCreateProject: addProject,
            onSelectProject: selectProject,
            onUpdateProject: updateProject,
            onDeleteProject: deleteProject,
            onUnlockMore: unlockMoreProjects
        )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.resizes)
    }

    var unlockMoreSheet: some View {
        UnlockMoreSheet {
            isUnlockMoreSheetPresented = false
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    var datePickerSheet: some View {
        CreateDatePickerSheet(
            selectedDate: $datePickerSelection,
            onSetDate: { selectDay(datePickerSelection) }
        )
            .presentationDetents([.fraction(NomaScale.datePickerSheetFraction)])
            .presentationDragIndicator(.visible)
    }

    func openDatePickerSheet() {
        datePickerSelection = currentDayDate
        isDatePickerSheetPresented = true
    }

    func selectDay(_ date: Date) {
        let newDayID = DailyTaskGroupStore.dayID(for: date)
        guard newDayID != activeDayID else { return }

        saveCurrentDailyGroup()
        activeDayID = newDayID
        showsOnlyUnsolvedTasks = false
        pendingScrollTargetID = nil
        loadDailyGroup()
    }

    @ViewBuilder
    func content(in proxy: GeometryProxy) -> some View {
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
                    projects: projects,
                    tier: subscriptionTier.tier,
                    onUnlockMore: unlockMoreTasks,
                    onSwipeDeleteThreshold: playSwipeDeleteThresholdFeedback,
                    onToggleReminder: toggleReminder,
                    onEditReminder: beginEditingReminder,
                    onDeleteReminder: deleteReminder,
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
