import SwiftUI

private enum CreateProjectListLayout {
    static var cardPadding: NomaMetric.Value { NomaSpacing.xs }
    static var cardHorizontalPadding: NomaMetric.Value { NomaSpacing.xl - cardPadding }
    static var contentHorizontalPadding: NomaMetric.Value { NomaSpacing.xl }
    static var cardRadius: NomaMetric.Value { NomaRadius.composer }
    static var radioTrailingPadding: NomaMetric.Value { NomaSpacing.sm }
}

struct CreateProjectRow: View {
    let project: TaskProject
    let isSelected: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let action: () -> Void

    var body: some View {
        CreateProjectSelectionRow(
            title: project.title,
            isSelected: isSelected,
            icon: projectIcon,
            action: action
        )
        .contextMenu {
            Button(action: onEdit) {
                Label(LocalizedStringKey(CreateProjectListSection.editProjectTitleKey), systemImage: "pencil")
            }

            Button(role: .destructive, action: onDelete) {
                Label(LocalizedStringKey(CreateProjectListSection.deleteProjectTitleKey), systemImage: "trash")
            }
            .tint(.controlError)
        }
    }

    private var projectIcon: some View {
        Image(systemName: project.symbolName)
            .font(.headline.weight(.bold))
            .foregroundStyle(TaskProjectIconPresentation.appSurfaceColor)
            .frame(width: NomaSize.projectControl, height: NomaSize.projectControl)
            .background {
                Circle().fill(.secondaryBackground)
            }
    }

}

struct CreateProjectClearSelectionRow: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        CreateProjectSelectionRow(
            title: String(localized: String.LocalizationValue(CreateProjectListSection.noProjectTitleKey)),
            isSelected: isSelected,
            icon: icon,
            action: action
        )
    }

    private var icon: some View {
        Image(systemName: "tray.full")
            .font(.headline.weight(.bold))
            .foregroundStyle(.textSecondary)
            .frame(width: NomaSize.projectControl, height: NomaSize.projectControl)
            .background {
                Circle().fill(.secondaryBackground)
            }
    }
}

struct CreateProjectSelectionRow<Icon: View>: View {
    let title: String
    let isSelected: Bool
    let icon: Icon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: NomaSpacing.md) {
                icon

                VStack(alignment: .leading, spacing: NomaSpacing.none) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                RadioCheckbox(isOn: isSelected)
                    .padding(.trailing, CreateProjectListLayout.radioTrailingPadding)
            }
            .padding(CreateProjectListLayout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: CreateProjectListLayout.cardRadius, style: .continuous)
                    .fill(.primaryBackground)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .contentShape(
            .contextMenuPreview,
            RoundedRectangle(cornerRadius: CreateProjectListLayout.cardRadius, style: .continuous)
        )
        .padding(.horizontal, CreateProjectListLayout.cardHorizontalPadding)
    }
}

struct CreateProjectList: View {
    let projects: [TaskProject]
    let projectCount: Int
    let selectedProjectID: TaskProject.ID?
    let allReminders: [CreateReminder]
    let onSelectProject: (TaskProject.ID?) -> Void
    let onEditProject: (TaskProject) -> Void
    let onDeleteProject: (TaskProject.ID) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NomaSpacing.xl) {
                Text(LocalizedStringKey(CreateProjectListSection.selectionInfoKey))
                    .font(.body)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, CreateProjectListLayout.contentHorizontalPadding)

                CreateProjectClearSelectionRow(
                    isSelected: selectedProjectID == nil
                ) {
                    onSelectProject(nil)
                }

                ForEach(projects) { project in
                    CreateProjectRow(
                        project: project,
                        isSelected: project.id == selectedProjectID,
                        onEdit: { onEditProject(project) },
                        onDelete: { onDeleteProject(project.id) }
                    ) {
                        onSelectProject(project.id)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.top, NomaSpacing.xl)
        }
        .scrollIndicators(.hidden)
    }
}
