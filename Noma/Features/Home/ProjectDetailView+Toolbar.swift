import SwiftUI

extension ProjectDetailView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        TaskWorkspaceToolbar(
            title: navigationTitle,
            subtitle: navigationSubtitle,
            titleAccessibilityLabelKey: "create.project.edit.title",
            isDoneDisabled: !canCompleteAllReminders,
            isFilterActive: showsOnlyUnsolvedTasks,
            isFilterDisabled: projectSummary.taskCount == 0,
            onTitleTap: { isEditProjectSheetPresented = currentProject != nil },
            onDone: completeAllRemindersForProject,
            onFilter: toggleUnsolvedFilter
        )
    }

    @ViewBuilder
    var editProjectSheet: some View {
        if let currentProject {
            AddProjectSheet(project: currentProject) { updatedProject in
                dailyTaskGroups.updateProject(updatedProject)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.resizes)
        }
    }
}
