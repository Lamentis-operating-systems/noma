import SwiftUI

struct ProjectDetailView: View {
    let projectID: TaskProject.ID

    @Environment(\.dismiss) var dismiss
    @Environment(\.hapticFeedback) var hapticFeedback
    @Environment(DailyTaskGroupStore.self) var dailyTaskGroups
    @State var message = ""
    @State var isKeyboardPresented = false
    @State var isEditProjectSheetPresented = false
    @AppStorage(CreateReminderFilterPreference.storageKey) var showsOnlyUnsolvedTasks = false
    @State var temporarilyVisibleCompletedReminderIDs: Set<CreateReminder.ID> = []
    @State var pendingScrollTargetID: String?
    @FocusState var isInputFocused: Bool

    var body: some View {
        TaskWorkspaceShell(
            isKeyboardPresented: $isKeyboardPresented,
            isModalPresented: isEditProjectSheetPresented,
            isInputFocused: $isInputFocused,
            onKeyboardPresented: scrollToLastTodayReminderAfterKeyboardFocus
        ) {
            content
        } composer: {
            composerBar
        }
        .toolbarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $isEditProjectSheetPresented) { editProjectSheet }
        .onChange(of: currentProject?.id, initial: true) { _, currentProjectID in
            guard currentProjectID == nil else { return }
            leaveUnavailableProject()
        }
    }
}
