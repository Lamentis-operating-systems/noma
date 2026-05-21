import SwiftUI

struct CreateProjectEmptyState {
    let systemImage: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let cta: HintCTA?

    static let placeholder = CreateProjectEmptyState()

    init() {
        self.systemImage = "tray.full"
        self.title = "create.project.empty.title"
        self.subtitle = "create.project.empty.subtitle"
        self.cta = nil
    }
}

enum CreateProjectListSection {
    static let titleKey = "create.projects.sheet.title"
    static let createNewProjectTitleKey = "create.projects.create-new.title"
    static let selectionInfoKey = "create.projects.selection.info"
    static let noProjectTitleKey = "create.projects.no-project.title"
    static let noProjectSubtitleKey = "create.projects.no-project.subtitle"
    static let editProjectTitleKey = "create.projects.edit.title"
    static let deleteProjectTitleKey = "create.projects.delete.title"
    static let deleteProjectMessageKey = "create.projects.delete.message"
    static let unlockMoreTitleKey = CreateReminderListSection.unlockMoreTitleKey
    static let unlockMoreMessageKey = "create.projects.unlock-more.message"

    static func showsUnlockMoreButton(tier: SubscriptionTier, projectCount: Int) -> Bool {
        !tier.canAddProject(toProjectCount: projectCount)
    }
}

enum CreateProjectEditorPresentation: Identifiable {
    case add
    case edit(TaskProject)

    var id: String {
        switch self {
        case .add:
            "add"
        case let .edit(project):
            project.id.uuidString
        }
    }

    var project: TaskProject? {
        switch self {
        case .add:
            nil
        case let .edit(project):
            project
        }
    }
}

struct CreateSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var projects: [TaskProject]
    @Binding var selectedProjectID: TaskProject.ID?
    let allReminders: [CreateReminder]
    let tier: SubscriptionTier
    let onCreateProject: (TaskProject) -> Void
    let onSelectProject: (TaskProject.ID?) -> Void
    let onUpdateProject: (TaskProject) -> Void
    let onDeleteProject: (TaskProject.ID) -> Void
    let onUnlockMore: () -> Void
    @State var projectEditorPresentation: CreateProjectEditorPresentation?
    @State var pendingDeleteProjectID: TaskProject.ID?
    @State var isUnlockMoreSheetPresented = false

    var body: some View {
        GeometryReader { proxy in
            NavigationStack {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle(LocalizedStringKey(CreateProjectListSection.titleKey))
                    .toolbarTitleDisplayMode(.inline)
                    .toolbar {
                        CloseToolbarButton(accessibilityLabelKey: "create.project.close.accessibility-label", action: { dismiss() })
                    }
                    .safeAreaBar(edge: .bottom, spacing: 0) {
                        if tier.canAddProject(toProjectCount: projects.count) {
                            CreateDatePickerSubmitButton(
                                title: String(
                                    localized: String.LocalizationValue(CreateProjectListSection.createNewProjectTitleKey)
                                ),
                                action: openAddProjectSheet
                            )
                            .padding(.horizontal, NomaSpacing.xxl)
                            .padding(.bottom, max(0, NomaSpacing.xxl - proxy.safeAreaInsets.bottom))
                        }
                    }
            }
        }
        .sheet(item: $projectEditorPresentation) { presentation in
            AddProjectSheet(project: presentation.project, tier: tier) { project in
                saveProject(project)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $isUnlockMoreSheetPresented) {
            UnlockMoreSheet {
                isUnlockMoreSheetPresented = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            LocalizedStringKey(CreateProjectListSection.deleteProjectTitleKey),
            isPresented: deleteConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button(LocalizedStringKey(CreateProjectListSection.deleteProjectTitleKey), role: .destructive) {
                confirmProjectDeletion()
            }
        } message: {
            Text(LocalizedStringKey(CreateProjectListSection.deleteProjectMessageKey))
        }
    }
}
