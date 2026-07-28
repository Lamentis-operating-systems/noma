import SwiftUI

enum ProjectTitleInputLayout {
    static let height = NomaSize.projectControl
    static let cornerRadius = NomaRadius.projectControl
    static let horizontalPadding = NomaSpacing.lg
    static let placeholderKey = "create.project.title.placeholder"
}

struct ProjectTitleInput: View {
    @Binding var title: String
    let focus: FocusState<Bool>.Binding
    let characterLimit: Int

    init(
        title: Binding<String>,
        focus: FocusState<Bool>.Binding,
        characterLimit: Int = NomaLimit.projectTitleCharacters
    ) {
        self._title = title
        self.focus = focus
        self.characterLimit = characterLimit
    }

    var body: some View {
        TextField(
            LocalizedStringKey(ProjectTitleInputLayout.placeholderKey),
            text: limitedTitle
        )
        .focused(focus)
        .font(.body)
        .lineLimit(1)
        .textFieldStyle(.plain)
        .submitLabel(.done)
        .padding(.horizontal, ProjectTitleInputLayout.horizontalPadding)
        .frame(height: ProjectTitleInputLayout.height)
        .frame(maxWidth: .infinity)
        .background {
            Capsule().fill(.secondaryBackground)
        }
        .accessibilityLabel(Text(LocalizedStringKey(ProjectTitleInputLayout.placeholderKey)))
        .accessibilityIdentifier("project-title-input")
    }

    private var limitedTitle: Binding<String> {
        Binding {
            title
        } set: { incomingTitle in
            title = String(incomingTitle.prefix(characterLimit))
        }
    }
}
