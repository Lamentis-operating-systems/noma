import SwiftUI

enum CreateViewContentMode {
    static func usesScrollView(reminderCount: Int, carryForwardPreviewCount: Int = 0) -> Bool {
        !CreateReminderListSection.showsEmptyState(
            reminderCount: reminderCount,
            carryForwardPreviewCount: carryForwardPreviewCount
        )
    }
}

enum CreateViewScrollLayout {
    static let bottomSafeAreaPadding = NomaSpacing.xxl
}

enum BottomComposerBarLayout {
    static func width(in proxy: GeometryProxy, edgePadding: CGFloat) -> CGFloat {
        let width = max(0, proxy.size.width - (edgePadding * 2))
        return width.isFinite ? width : 0
    }

    static func bottomPadding(
        isKeyboardPresented: Bool,
        focusedPadding: CGFloat,
        collapsedPadding: CGFloat,
        safeAreaBottom: CGFloat
    ) -> CGFloat {
        let padding = isKeyboardPresented ? focusedPadding : max(0, collapsedPadding - safeAreaBottom)
        return padding.isFinite ? padding : 0
    }
}

struct CreateView: View {
    let collapsedEdgePadding = NomaSpacing.xxl
    let focusedEdgePadding = NomaSpacing.md
    let focusedKeyboardSpacing = NomaOffset.keyboardAccessoryOverlap

    @Environment(\.hapticFeedback) var hapticFeedback
    @Environment(SubscriptionTierManager.self) var subscriptionTier
    @Environment(OnDeviceFoundationModelService.self) var onDeviceFoundationModel
    @Environment(DailyTaskGroupStore.self) var dailyTaskGroups
    @State var message = ""
    @State var reminders: [CreateReminder] = []
    @State var projects: [TaskProject] = []
    @State var selectedProjectID: TaskProject.ID?
    @State var editingReminderID: CreateReminder.ID?
    @State var isKeyboardPresented = false
    @State var isProjectSheetPresented = false
    @State var isUnlockMoreSheetPresented = false
    @State var isDatePickerSheetPresented = false
    @State var isSubmittingReminder = false
    @State var isPlanningDay = false
    @State var shouldPlanAgainAfterCurrentPlanning = false
    @State var taskOrganization: CreateReminderAIPlanningResult?
    @State var activeDayID: String
    @State var datePickerSelection: Date
    @State var showsOnlyUnsolvedTasks = false
    @State var pendingScrollTargetID: String?
    @FocusState var isInputFocused: Bool

    init(dayID: String = DailyTaskGroupStore.todayID()) {
        _activeDayID = State(initialValue: dayID)
        _datePickerSelection = State(initialValue: DailyTaskGroupStore.date(forDayID: dayID) ?? Date())
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle()
                    .fill(.primaryBackground)
                    .ignoresSafeArea(.container)

                content(in: proxy)
            }
            .safeAreaBar(edge: .bottom, spacing: barSpacing) {
                bottomComposerContent(in: proxy)
            }
        }
        .background { NavigationKeyboardDismissObserver(isInputFocused: $isInputFocused) }
        .ignoresSafeArea(
            .keyboard,
            edges: isProjectSheetPresented || isUnlockMoreSheetPresented ? .bottom : []
        )
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            guard !isProjectSheetPresented, !isUnlockMoreSheetPresented else { return }
            isKeyboardPresented = true
            scrollToReminderListBottomAfterKeyboardFocus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            guard !isProjectSheetPresented, !isUnlockMoreSheetPresented else { return }
            isKeyboardPresented = false
        }
        .task {
            loadDailyGroup()
        }
        .onChange(of: message) { _, draftText in
            resetEditingIfDraftWasCleared(draftText)
        }
        .toolbarTitleDisplayMode(.inline)
        .toolbar { createToolbar }
        .sheet(isPresented: $isProjectSheetPresented) { projectSheet }
        .sheet(isPresented: $isUnlockMoreSheetPresented) { unlockMoreSheet }
        .sheet(isPresented: $isDatePickerSheetPresented) { datePickerSheet }
    }

}

struct TaskNavigationTitleButton: View {
    let title: String, subtitle: String
    let accessibilityLabelKey: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.textPrimary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(accessibilityLabelKey)))
    }
}

struct TaskDoneToolbarButton: View {
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("create.toolbar.done.title")
        }
        .disabled(isDisabled)
    }
}

struct TaskFilterToolbarButton: View {
    let isActive: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: CreateReminderFilterToolbarIcon.systemImage(isActive: isActive))
        }
        .foregroundStyle(CreateReminderFilterToolbarIcon.foregroundColor(isActive: isActive))
        .accessibilityLabel(Text("create.toolbar.filter.unsolved.accessibility-label"))
        .disabled(isDisabled)
    }
}

struct CreateDatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date
    let onSetDate: () -> Void

    var body: some View {
        GeometryReader { proxy in
            NavigationStack {
                VStack(spacing: 0) {
                    DatePicker("create.date-picker.label", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .tint(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, NomaSpacing.xl)
                        .padding(.top, NomaSpacing.xl)

                    Spacer(minLength: 0)
                }
                .navigationTitle(LocalizedStringKey("create.date-picker.title"))
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    CloseToolbarButton(
                        accessibilityLabelKey: "create.date-picker.close.accessibility-label",
                        action: { dismiss() }
                    )
                }
                .safeAreaBar(edge: .bottom, spacing: 0) {
                    CreateDatePickerSubmitButton(
                        title: CreateDatePickerSheetCopy.setDateTitle(for: selectedDate),
                        action: { onSetDate(); dismiss() }
                    )
                    .padding(.horizontal, NomaSpacing.xxl)
                    .padding(.bottom, max(0, NomaSpacing.xxl - proxy.safeAreaInsets.bottom))
                }
            }
        }
    }
}

enum CreateDatePickerSheetCopy {
    static let setDateTitleKey = "create.date-picker.set-date"

    static func setDateTitle(for date: Date) -> String {
        let format = String(localized: String.LocalizationValue(setDateTitleKey))
        let dateText = date.formatted(date: .abbreviated, time: .omitted)
        return String.localizedStringWithFormat(format, dateText)
    }
}

struct CreateDatePickerSubmitButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: NomaSpacing.sm) {
                Text(title)
                    .font(.headline)
            }
                .frame(maxWidth: .infinity)
                .padding(.vertical, NomaSpacing.md)
        }
        .tint(.primary)
        .foregroundStyle(.primaryBackground)
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
    }
}
