import SwiftUI

struct AddProjectSheetContent: View {
    @Binding var title: String
    let focus: FocusState<Bool>.Binding
    let iconSystemImage: String
    let iconColor: Color
    @Binding var expirationDate: Date
    @Binding var isExpirationEnabled: Bool
    let onIconButtonTap: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CreateProjectSheetLayout.contentSpacing) {
                Text(LocalizedStringKey(CreateProjectSheetCopy.descriptionKey))
                    .font(.body)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: CreateProjectSheetLayout.iconInputSpacing) {
                    AddProjectIconButtonView(
                        systemImage: iconSystemImage,
                        color: iconColor,
                        action: onIconButtonTap
                    )

                    ProjectTitleInput(title: $title, focus: focus)
                }

                ProjectExpirationDatePicker(
                    expirationDate: $expirationDate,
                    isExpirationEnabled: $isExpirationEnabled
                )
            }
            .padding(.horizontal, NomaSpacing.xl)
            .padding(.top, NomaSpacing.xl)
            .padding(.bottom, NomaSpacing.xl)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

private struct ProjectExpirationDatePicker: View {
    @Binding var expirationDate: Date
    @Binding var isExpirationEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: NomaSpacing.sm) {
            Toggle(isOn: $isExpirationEnabled) {
                Text(LocalizedStringKey(ProjectExpirationOption.titleKey))
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
            }
            .toggleStyle(.switch)

            if isExpirationEnabled {
                DatePicker(
                    LocalizedStringKey(ProjectExpirationOption.datePickerLabelKey),
                    selection: $expirationDate,
                    displayedComponents: ProjectExpirationOption.displayedComponents
                )
                .datePickerStyle(.compact)
                .controlSize(ProjectExpirationOption.controlSize)
            }
        }
    }
}

private struct AddProjectIconButtonView: View {
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: NomaSize.projectControl, height: NomaSize.projectControl)
                .background {
                    Circle().fill(.secondaryBackground)
                }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(Text("create.project.icon-button.accessibility-label"))
        .accessibilityIdentifier("project-icon-button")
    }
}
