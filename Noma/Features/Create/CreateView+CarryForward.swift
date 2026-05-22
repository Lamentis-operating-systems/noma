import SwiftUI

extension CreateView {
    func loadDailyGroup() {
        reminders = dailyTaskGroups.reminders(forDayID: activeDayID)
        projects = dailyTaskGroups.projects(forDayID: activeDayID)

        let storedSelectedProjectID = dailyTaskGroups.selectedProjectID(forDayID: activeDayID)
        selectedProjectID = projects.contains { $0.id == storedSelectedProjectID } ? storedSelectedProjectID : nil
    }

    var suggestedProject: TaskProject? {
        guard let project = dailyTaskGroups.commonProjectSummaries(limit: 1).first?.project,
              selectedProjectID != project.id
        else { return nil }

        return projects.first { $0.id == project.id } ?? project
    }

    var showsSuggestedProjectButton: Bool {
        CreateReminderSubmission.normalizedText(from: message).isEmpty
            && suggestedProject != nil
    }

    var carryForwardReminders: [CreateReminder] {
        CreateReminderCarryForwardPreview.visibleReminders(
            currentReminders: reminders,
            previousOpenReminders: previousDayReminders.filter { !$0.isCompleted }
        )
    }

    var previousDayID: String? {
        guard let activeDate = DailyTaskGroupStore.date(forDayID: activeDayID),
              let previousDate = Calendar.current.date(byAdding: .day, value: -1, to: activeDate)
        else { return nil }

        return DailyTaskGroupStore.dayID(for: previousDate)
    }

    var previousDayReminders: [CreateReminder] {
        guard let previousDayID else { return [] }
        return dailyTaskGroups.reminders(forDayID: previousDayID)
    }

    var showsCarryForwardButton: Bool {
        CreateReminderSubmission.normalizedText(from: message).isEmpty
            && !carryForwardReminders.isEmpty
    }

    var carryForwardPreviewReminders: [CreateReminder] {
        showsCarryForwardButton ? carryForwardReminders : []
    }

    @ViewBuilder
    var suggestedProjectButton: some View {
        if let suggestedProject {
            Button {
                selectSuggestedProject(suggestedProject)
            } label: {
                HStack(spacing: NomaSpacing.sm) {
                    Image(systemName: suggestedProject.symbolName)
                        .font(.headline)
                        .foregroundStyle(TaskProjectIconPresentation.appSurfaceColor)
                        .frame(width: ReminderInputBarLayout.minimumHeight)

                    Text(suggestedProjectTitle(for: suggestedProject))
                        .font(.headline)
                        .foregroundStyle(.textPrimary)
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    var carryForwardButton: some View {
        Button(action: carryForwardOpenTasks) {
            HStack(spacing: NomaSpacing.sm) {
                Image(systemName: "chevron.down.forward.2")
                    .font(.headline)
                    .frame(width: ReminderInputBarLayout.minimumHeight)

                Text("create.carry-forward-yesterday.title")
                    .font(.headline)
            }
            .foregroundStyle(.textPrimary)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    func suggestedProjectTitle(for project: TaskProject) -> String {
        String.localizedStringWithFormat(
            String(localized: "create.suggested-project.title"),
            project.title
        )
    }

    func selectSuggestedProject(_ project: TaskProject) {
        selectedProjectID = project.id
        hapticFeedback.play(.createTaskSubmit)
        saveCurrentDailyGroup()
    }

    func addCarryForwardReminders(_ remindersToCarryForward: [CreateReminder]) {
        let remindersToAdd = remindersToCarryForward.map { reminder in
            CreateReminder(text: reminder.text, projectID: reminder.projectID)
        }
        guard !remindersToAdd.isEmpty else { return }
        let sourceDayID = previousDayID
        let sourceReminders = previousDayReminders

        hapticFeedback.play(.createTaskSubmit)
        withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            reminders.append(contentsOf: remindersToAdd)
        }
        saveCurrentDailyGroup()
        if let sourceDayID {
            dailyTaskGroups.save(
                reminders: CreateReminderCarryForwardTransfer.sourceRemindersAfterTransfer(
                    sourceReminders: sourceReminders,
                    transferredReminders: remindersToCarryForward
                ),
                forDayID: sourceDayID
            )
        }
        pendingScrollTargetID = CreateReminderListLayout.bottomAnchorID
    }

    func completeCarryForwardReminder(_ reminder: CreateReminder) {
        guard let previousDayID else { return }

        hapticFeedback.play(.createTaskSubmit)
        let updatedPreviousReminders = CreateReminderCarryForwardCompletion.completing(
            reminder,
            in: previousDayReminders
        )
        withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            dailyTaskGroups.save(reminders: updatedPreviousReminders, forDayID: previousDayID)
        }
    }
}
