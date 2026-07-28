import SwiftUI

extension CreateSheet {
    @ViewBuilder
    var content: some View {
        if projects.isEmpty {
            VStack {
                Spacer(minLength: 0)
                HintView(
                    systemImage: CreateProjectEmptyState.placeholder.systemImage,
                    title: CreateProjectEmptyState.placeholder.title,
                    subtitle: CreateProjectEmptyState.placeholder.subtitle
                )
                Spacer(minLength: 0)
            }
        } else {
            CreateProjectList(
                projects: projects,
                projectCount: projects.count,
                selectedProjectID: selectedProjectID,
                allReminders: allReminders,
                onSelectProject: selectProject,
                onEditProject: editProject,
                onDeleteProject: deleteProject
            )
        }
    }

    func selectProject(_ projectID: TaskProject.ID?) {
        guard onSelectProject(projectID) else { return }
        dismiss()
    }

    func editProject(_ project: TaskProject) {
        projectEditorPresentation = .edit(project)
    }

    func deleteProject(_ projectID: TaskProject.ID) { pendingDeleteProjectID = projectID }

    func confirmProjectDeletion() {
        guard let pendingDeleteProjectID else { return }
        guard onDeleteProject(pendingDeleteProjectID) else { return }
        self.pendingDeleteProjectID = nil
    }

    var deleteConfirmationBinding: Binding<Bool> {
        Binding {
            pendingDeleteProjectID != nil
        } set: { isPresented in
            if !isPresented {
                pendingDeleteProjectID = nil
            }
        }
    }

    func openAddProjectSheet() {
        projectEditorPresentation = .add
    }

    func saveProject(_ project: TaskProject) -> Bool {
        let didSave: Bool
        if case .edit = projectEditorPresentation {
            didSave = onUpdateProject(project)
        } else {
            didSave = onCreateProject(project)
        }
        guard didSave else { return false }
        projectEditorPresentation = nil
        return true
    }
}
