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

struct CreateView: View {
    @Environment(\.hapticFeedback) var hapticFeedback
    @Environment(DailyTaskGroupStore.self) var dailyTaskGroups
    @State var message = ""
    @State var draftProjectID: TaskProject.ID?
    @State var editingReminderID: CreateReminder.ID?
    @State var isKeyboardPresented = false
    @State var isProjectSheetPresented = false
    @State var isDatePickerSheetPresented = false
    @State var activeDayID: String
    @State var datePickerSelection: Date
    @AppStorage(CreateReminderFilterPreference.storageKey) var showsOnlyUnsolvedTasks = false
    @State var temporarilyVisibleCompletedReminderIDs: Set<CreateReminder.ID> = []
    @State var pendingScrollTargetID: String?
    @FocusState var isInputFocused: Bool

    init(dayID: String = DailyTaskGroupStore.todayID()) {
        _activeDayID = State(initialValue: dayID)
        _datePickerSelection = State(initialValue: DailyTaskGroupStore.date(forDayID: dayID) ?? Date())
    }

    var body: some View {
        TaskWorkspaceShell(
            isKeyboardPresented: $isKeyboardPresented,
            isModalPresented: isProjectSheetPresented,
            isInputFocused: $isInputFocused,
            onKeyboardPresented: scrollToReminderListBottomAfterKeyboardFocus
        ) {
            content
        } composer: {
            bottomComposerContent
        }
        .onChange(of: dailyTaskGroups.selectedProjectID, initial: true) { _, selectedProjectID in
            guard editingReminderID == nil else { return }
            draftProjectID = availableProjectID(selectedProjectID)
        }
        .onChange(of: message) { _, draftText in
            resetEditingIfDraftWasCleared(draftText)
        }
        .onChange(of: reminders, initial: true) { _, currentReminders in
            reconcileEditingState(with: currentReminders)
        }
        .onChange(of: dailyTaskGroups.projectExpirationRevision) { _, _ in
            draftProjectID = availableProjectID(draftProjectID)
        }
        .toolbarTitleDisplayMode(.inline)
        .toolbar { createToolbar }
        .sheet(isPresented: $isProjectSheetPresented) { projectSheet }
        .sheet(isPresented: $isDatePickerSheetPresented) { datePickerSheet }
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
                    PrimaryGlassButton(
                        verbatimTitle: CreateDatePickerSheetCopy.setDateTitle(for: selectedDate),
                        width: .fullWidth,
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
