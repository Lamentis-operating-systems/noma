import SwiftUI

enum ProjectDetailLayout {
    static let collapsedEdgePadding = NomaSpacing.xxl
    static let focusedEdgePadding = NomaSpacing.md
    static let focusedKeyboardSpacing = NomaOffset.keyboardAccessoryOverlap
}

struct ProjectDetailView: View {
    let projectID: TaskProject.ID

    @Environment(\.hapticFeedback) var hapticFeedback
    @Environment(SubscriptionTierManager.self) var subscriptionTier
    @Environment(DailyTaskGroupStore.self) var dailyTaskGroups
    @State var message = ""
    @State var project: TaskProject?
    @State var isKeyboardPresented = false
    @State var isEditProjectSheetPresented = false
    @AppStorage(CreateReminderFilterPreference.storageKey) var showsOnlyUnsolvedTasks = false
    @State var temporarilyVisibleCompletedReminderIDs: Set<CreateReminder.ID> = []
    @State var pendingScrollTargetID: String?
    @FocusState var isInputFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle()
                    .fill(.primaryBackground)
                    .ignoresSafeArea(.container)

                content
            }
            .safeAreaBar(edge: .bottom, spacing: barSpacing) {
                composerBar
                    .frame(width: barWidth(in: proxy), alignment: .leading)
                    .padding(.bottom, barBottomPadding(in: proxy))
            }
        }
        .background { NavigationKeyboardDismissObserver(isInputFocused: $isInputFocused) }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            guard !isEditProjectSheetPresented else { return }
            isKeyboardPresented = true
            scrollToLastTodayReminderAfterKeyboardFocus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            guard !isEditProjectSheetPresented else { return }
            isKeyboardPresented = false
        }
        .task { loadProject() }
        .toolbarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $isEditProjectSheetPresented) { editProjectSheet }
    }
}
