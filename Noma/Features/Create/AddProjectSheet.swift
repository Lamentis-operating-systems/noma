import SwiftUI

struct CreateProjectSheetCopy {
    static let titleKey = "create.project.add.title"
    static let editTitleKey = "create.project.edit.title"
    static let descriptionKey = "create.project.add.description"
    static let createButtonKey = "create.project.create-button"
    static let saveButtonKey = "create.project.save-button"
}

enum ProjectExpirationOption {
    static let titleKey = "create.project.expiration.title"
    static let datePickerLabelKey = "create.project.expiration.date-picker"
    static let controlSize: ControlSize = .small
    static let displayedComponents: DatePickerComponents = .date
    static let defaultDurationDays = 7

    static func defaultDate() -> Date {
        Calendar.current.date(byAdding: .day, value: defaultDurationDays, to: Date()) ?? Date()
    }
}

enum CreateProjectSheetLayout {
    static let focusedHorizontalPadding = NomaSpacing.sm
    static let collapsedHorizontalPadding = NomaSpacing.xxl
    static let keyboardSpacing = NomaSpacing.sm
    static let collapsedBottomPadding = NomaSpacing.xxl
    static let contentSpacing = NomaSpacing.xl
    static let iconInputSpacing = NomaSpacing.md
    static let usesNativeSheetKeyboardAvoidance = true
    static let usesScrollDrivenKeyboardDismissal = true
    static let usesBottomSafeAreaBar = true

    static func bottomPadding(
        isKeyboardPresented: Bool,
        bottomSafeAreaInset: CGFloat = 0
    ) -> CGFloat {
        isKeyboardPresented ? keyboardSpacing : max(0, collapsedBottomPadding - bottomSafeAreaInset)
    }

    static func horizontalPadding(isKeyboardPresented: Bool) -> CGFloat {
        isKeyboardPresented ? focusedHorizontalPadding : collapsedHorizontalPadding
    }
}

enum AddProjectIconButton {
    static let placeholderSystemImage = "plus.circle.dashed"
}

struct AddProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    let project: TaskProject?
    let onSave: (TaskProject) -> Void
    @State private var title = ""
    @State private var selectedColorIndex = 0
    @State private var selectedSymbol = ProjectIconPickerOption.defaultSymbol
    @State private var expirationDate = Date()
    @State private var isExpirationEnabled = false
    @State private var hasSelectedIcon = false
    @State private var isIconPickerPresented = false
    @State private var isKeyboardPresented = false
    @FocusState private var isTitleFocused: Bool

    init(project: TaskProject? = nil, onSave: @escaping (TaskProject) -> Void) {
        self.project = project
        self.onSave = onSave
        _title = State(initialValue: project?.title ?? "")
        _selectedColorIndex = State(initialValue: ProjectIconPickerOption.normalizedColorIndex(
            project?.colorIndex ?? ProjectIconPickerOption.defaultColorIndex
        ))
        _selectedSymbol = State(initialValue: project?.symbolName ?? ProjectIconPickerOption.defaultSymbol)
        _expirationDate = State(initialValue: project?.expiresAt ?? ProjectExpirationOption.defaultDate())
        _isExpirationEnabled = State(initialValue: project?.expiresAt != nil)
        _hasSelectedIcon = State(initialValue: project != nil)
    }

    var body: some View {
        GeometryReader { proxy in
            NavigationStack {
                AddProjectSheetContent(
                    title: $title,
                    focus: $isTitleFocused,
                    iconSystemImage: iconButtonSystemImage,
                    iconColor: selectedColor,
                    expirationDate: $expirationDate,
                    isExpirationEnabled: $isExpirationEnabled,
                    onIconButtonTap: { isIconPickerPresented = true }
                )
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle(LocalizedStringKey(navigationTitleKey))
                .toolbarTitleDisplayMode(.inline)
                .toolbar { closeButton }
                .safeAreaBar(edge: .bottom, spacing: 0) {
                    CreateProjectSubmitButton(titleKey: submitButtonTitleKey, action: saveProject)
                    .disabled(!canCreateProject)
                    .opacity(canCreateProject ? 1 : NomaOpacity.disabledControlBackground)
                        .padding(.horizontal, CreateProjectSheetLayout.horizontalPadding(isKeyboardPresented: isKeyboardPresented))
                        .padding(.bottom, CreateProjectSheetLayout.bottomPadding(isKeyboardPresented: isKeyboardPresented, bottomSafeAreaInset: proxy.safeAreaInsets.bottom))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in isKeyboardPresented = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in isKeyboardPresented = false }
        .task {
            await Task.yield()
            isTitleFocused = true
        }
        .sheet(isPresented: $isIconPickerPresented) {
            ProjectIconPickerSheet(selectedColorIndex: $selectedColorIndex, selectedSymbol: selectedIconBinding)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
    }
}

private extension AddProjectSheet {
    var selectedColor: Color { ProjectIconPickerOption.color(for: selectedColorIndex) }
    var canCreateProject: Bool { TaskProjectTitlePolicy.canCreateProject(title: title) }
    var normalizedTitle: String { TaskProjectTitlePolicy.normalizedTitle(from: title) }
    var navigationTitleKey: String { project == nil ? CreateProjectSheetCopy.titleKey : CreateProjectSheetCopy.editTitleKey }
    var submitButtonTitleKey: String { project == nil ? CreateProjectSheetCopy.createButtonKey : CreateProjectSheetCopy.saveButtonKey }
    var iconButtonSystemImage: String { hasSelectedIcon ? selectedSymbol : AddProjectIconButton.placeholderSystemImage }

    private func saveProject() {
        guard canCreateProject else { return }
        onSave(TaskProject(
            id: project?.id ?? UUID(),
            title: normalizedTitle,
            symbolName: selectedSymbol,
            colorIndex: ProjectIconPickerOption.normalizedColorIndex(selectedColorIndex),
            expiresAt: isExpirationEnabled ? expirationDate : nil
        ))
        dismiss()
    }

    private var selectedIconBinding: Binding<String> {
        Binding {
            selectedSymbol
        } set: { newValue in
            selectedSymbol = newValue
            hasSelectedIcon = true
        }
    }

    private var closeButton: some ToolbarContent { CloseToolbarButton(accessibilityLabelKey: "create.project.close.accessibility-label", action: { dismiss() }) }
}
