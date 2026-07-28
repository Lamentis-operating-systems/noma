import SwiftUI

extension CreateView {
    var reminders: [CreateReminder] {
        dailyTaskGroups.reminders(forDayID: activeDayID)
    }

    var projects: [TaskProject] {
        dailyTaskGroups.projects
    }

    func availableProjectID(_ projectID: TaskProject.ID?) -> TaskProject.ID? {
        projectID.flatMap { candidateID in
            projects.contains { $0.id == candidateID } ? candidateID : nil
        }
    }

    var suggestedProject: TaskProject? {
        guard let project = dailyTaskGroups.commonProjectSummaries(limit: 1).first?.project,
              draftProjectID != project.id
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
        Button {
            addCarryForwardReminders(carryForwardReminders)
        } label: {
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
        guard dailyTaskGroups.selectProject(project.id) else { return }
        draftProjectID = project.id
        hapticFeedback.play(.createTaskSubmit)
    }

    func addCarryForwardReminders(_ remindersToCarryForward: [CreateReminder]) {
        guard let sourceDayID = previousDayID, !remindersToCarryForward.isEmpty else { return }

        let didCarryForward = withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            dailyTaskGroups.carryForwardReminders(
                remindersToCarryForward,
                fromDayID: sourceDayID,
                toDayID: activeDayID
            )
        }
        guard didCarryForward else { return }

        hapticFeedback.play(.createTaskSubmit)
        pendingScrollTargetID = CreateReminderListLayout.bottomAnchorID
    }

    func completeCarryForwardReminder(_ reminder: CreateReminder) {
        guard let previousDayID else { return }

        let updatedPreviousReminders = CreateReminderCarryForwardCompletion.completing(
            reminder,
            in: previousDayReminders
        )
        let didComplete = withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            dailyTaskGroups.setReminders(updatedPreviousReminders, forDayID: previousDayID)
        }
        guard didComplete else { return }

        hapticFeedback.play(.createTaskSubmit)
    }
}
