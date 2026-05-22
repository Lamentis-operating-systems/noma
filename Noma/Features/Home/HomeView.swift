import SwiftUI

enum HomeRoute: Hashable {
    case create(dayID: String)
    case project(TaskProject.ID)
}

struct HomeView: View {
    @Environment(\.hapticFeedback) var hapticFeedback
    @Environment(DailyTaskGroupStore.self) var dailyTaskGroups
    @Environment(DailyTaskNotificationScheduler.self) var dailyTaskNotifications
    @Environment(AppSettingsStore.self) var appSettings
    @State var path: [HomeRoute] = []
    @State var temporarilyVisibleCompletedReminderIDs: Set<CreateReminder.ID> = []
    @State var isHomeHeaderVisible = true

    var body: some View {
        GeometryReader { proxy in
            NavigationStack(path: $path) {
                ZStack {
                    Rectangle()
                        .fill(.primaryBackground)
                        .ignoresSafeArea()

                    ScrollView {
                        HomeScrollOffsetObserver { contentOffsetY in
                            updateHomeHeaderVisibility(for: contentOffsetY)
                        }
                        .frame(height: NomaSize.scrollDismissSentinel)
                        .accessibilityHidden(true)

                        dailyGroupsList
                    }
                    .scrollIndicators(.hidden)
                }
                .safeAreaBar(edge: .bottom, alignment: .trailing, spacing: 0) {
                    createButton
                        .padding(.trailing, NomaSpacing.xxl)
                        .padding(.bottom, max(0, NomaSpacing.xxl - proxy.safeAreaInsets.bottom))
                        .offset(y: max(0, proxy.safeAreaInsets.bottom - NomaSpacing.xxl))
                }
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case let .create(dayID):
                        CreateView(dayID: dayID)
                    case let .project(projectID):
                        ProjectDetailView(projectID: projectID)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        HomeMenu()
                    }
                }
                .onChange(of: dailyTaskGroups.groups, initial: true) { _, _ in refreshDailyTaskNotifications() }
                .onChange(of: appSettings.notificationSettings) { _, _ in refreshDailyTaskNotifications() }
            }
            .overlay(alignment: .topLeading) {
                if path.isEmpty {
                    HomeTopBar()
                        .padding(.leading, NomaSpacing.xl)
                        .opacity(HomeHeaderOpacity.value(isVisible: isHomeHeaderVisible))
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

enum HomeHeaderVisibility {
    static func isVisible(contentOffsetY: CGFloat) -> Bool {
        contentOffsetY <= NomaSpacing.none
    }
}

enum HomeHeaderOpacity {
    static func value(isVisible: Bool) -> CGFloat {
        isVisible ? 1 : NomaSpacing.none
    }
}

extension HomeView {
    func updateHomeHeaderVisibility(for contentOffsetY: CGFloat) {
        let isVisible = HomeHeaderVisibility.isVisible(contentOffsetY: contentOffsetY)
        guard isVisible != isHomeHeaderVisible else { return }

        isHomeHeaderVisible = isVisible
    }
}
