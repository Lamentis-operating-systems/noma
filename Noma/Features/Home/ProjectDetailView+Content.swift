import SwiftUI

extension ProjectDetailView {
    var composerBar: some View {
        ReminderInputBar(
            text: $message,
            focus: $isInputFocused,
            placeholder: "create.input.placeholder",
            isSubmissionAvailable: currentProject != nil,
            traySystemImage: currentProject?.symbolName ?? "tray.full",
            trayColor: TaskProjectIconPresentation.appSurfaceColor,
            onSubmit: submitReminder
        )
        .disabled(currentProject == nil)
    }

    var content: some View {
        CreateReminderScrollContainer(pendingScrollTargetID: $pendingScrollTargetID) {
            VStack(alignment: .leading, spacing: 0) {
                if showsFilteredEmptyState {
                    CreateTaskFilteredEmptyHint()
                        .transition(.opacity)
                } else if !visibleTodayReminders.isEmpty {
                    CreateReminderSectionHeader(
                        title: String(localized: "project.detail.today.section-header")
                    )
                }

                if !showsFilteredEmptyState {
                    VStack(alignment: .leading, spacing: NomaSpacing.md) {
                        todayTaskRows
                        pastTaskSections
                    }
                }

                bottomScrollAnchor
            }
            .padding(.horizontal, NomaSpacing.xl)
            .padding(.top, NomaSpacing.xxl)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    var showsFilteredEmptyState: Bool {
        showsOnlyUnsolvedTasks
            && projectSummary.taskCount > 0
            && visibleTodayReminders.isEmpty
            && visiblePastSections.isEmpty
    }

    var todayTaskRows: some View {
        CreateReminderRows(
            reminders: visibleTodayReminders,
            projects: currentProject.map { [$0] } ?? [],
            onToggleReminder: { reminder in toggleReminder(reminder, inDayID: todayID) },
            onDeleteReminder: { reminder in deleteReminder(reminder, inDayID: todayID) }
        )
    }

    var pastTaskSections: some View {
        ForEach(Array(visiblePastSections.enumerated()), id: \.element.id) { index, section in
            if !visibleTodayReminders.isEmpty || index > 0 {
                Divider()
                    .padding(.top, NomaSpacing.xxl)
                    .padding(.bottom, NomaSpacing.xl)
            }

            CreateReminderSectionHeader(
                title: CreateReminderListSection.headerTitle(for: section.date),
                bottomPadding: SectionHeaderLayout.bottomPadding - NomaSpacing.md
            )

            CreateReminderRows(
                reminders: section.reminders,
                projects: currentProject.map { [$0] } ?? [],
                onToggleReminder: { reminder in toggleReminder(reminder, inDayID: section.id) },
                onDeleteReminder: { reminder in deleteReminder(reminder, inDayID: section.id) }
            )
        }
    }

    var visiblePastSections: [ProjectTaskDaySection] {
        pastSections.compactMap { section in
            let sectionReminders = visibleReminders(in: section.reminders)
            guard !sectionReminders.isEmpty else { return nil }
            return ProjectTaskDaySection(group: section.group, reminders: sectionReminders)
        }
    }

    var bottomScrollAnchor: some View {
        Spacer(minLength: CreateReminderListLayout.bottomScrollPadding)
            .frame(height: CreateReminderListLayout.bottomScrollPadding)
            .id(CreateReminderListLayout.bottomAnchorID)
            .accessibilityHidden(true)
    }

}
