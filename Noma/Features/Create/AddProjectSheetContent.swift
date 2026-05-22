import SwiftUI

struct AddProjectSheetContent: View {
    @Binding var title: String
    let focus: FocusState<Bool>.Binding
    let iconSystemImage: String
    let iconColor: Color
    @Binding var expirationDate: Date
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

                ProjectExpirationDatePicker(expirationDate: $expirationDate)
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

    var body: some View {
        VStack(alignment: .leading, spacing: NomaSpacing.xs) {
            Text(LocalizedStringKey(ProjectExpirationOption.titleKey))
                .font(.subheadline)
                .foregroundStyle(.textSecondary)

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
    }
}

struct CreateProjectSubmitButton: View {
    let titleKey: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Text(LocalizedStringKey(titleKey))
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, NomaSpacing.md)
        }
        .tint(.primary)
        .foregroundStyle(.primaryBackground)
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
    }
}
