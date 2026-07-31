import SwiftUI

enum HomeRoute: Hashable {
    case create
}

enum HomeViewLayout {
    private static let createButtonTrailingStyleInset: CGFloat = 5

    static func createButtonInsetPadding(safeAreaInset: CGFloat) -> CGFloat {
        NomaSpacing.xxl - safeAreaInset
    }

    static func createButtonTrailingPadding(safeAreaInset: CGFloat) -> CGFloat {
        createButtonInsetPadding(safeAreaInset: safeAreaInset) - createButtonTrailingStyleInset
    }
}

struct HomeView: View {
    @Environment(\.hapticFeedback) var hapticFeedback
    @Environment(DailyTaskGroupStore.self) var dailyTaskGroups
    @Environment(DailyTaskNotificationScheduler.self) var dailyTaskNotifications
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
                        dailyGroupsList
                    }
                    .accessibilityIdentifier("home-scroll")
                    .scrollIndicators(.hidden)
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        HomeScrollPosition.normalizedOffsetY(
                            contentOffsetY: geometry.contentOffset.y,
                            topContentInset: geometry.contentInsets.top
                        )
                    } action: { _, contentOffsetY in
                        updateHomeHeaderVisibility(for: contentOffsetY)
                    }
                }
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case .create:
                        CreateView()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        HomeMenu()
                    }
                }
                .onChange(of: dailyTaskGroups.groups, initial: true) { _, _ in
                    refreshDailyTaskNotifications()
                }
                .task {
                    dailyTaskGroups.materializeRecurrences()
                }
            }
            .overlay(alignment: .topLeading) {
                if path.isEmpty {
                    HomeTopBar()
                        .padding(.leading, NomaSpacing.xl)
                        .opacity(HomeHeaderOpacity.value(isVisible: isHomeHeaderVisible))
                        .allowsHitTesting(false)
                        .accessibilityHidden(!isHomeHeaderVisible)
                        .accessibilityRepresentation {
                            if isHomeHeaderVisible {
                                Text("Noma")
                                    .accessibilityIdentifier("home-header")
                            } else {
                                EmptyView()
                            }
                        }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if path.isEmpty {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        createTaskToolbarButton
                    }
                    .padding(
                        .trailing,
                        HomeViewLayout.createButtonTrailingPadding(
                            safeAreaInset: proxy.safeAreaInsets.trailing
                        )
                    )
                    .padding(
                        .bottom,
                        HomeViewLayout.createButtonInsetPadding(
                            safeAreaInset: proxy.safeAreaInsets.bottom
                        )
                    )
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

enum HomeScrollPosition {
    static func normalizedOffsetY(contentOffsetY: CGFloat, topContentInset: CGFloat) -> CGFloat {
        let offset = contentOffsetY + topContentInset
        return offset.isFinite ? offset : NomaSpacing.none
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
