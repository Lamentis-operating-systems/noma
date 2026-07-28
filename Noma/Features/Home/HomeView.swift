import SwiftUI

enum HomeRoute: Hashable {
    case create
}

enum HomeViewLayout {
    static let bottomScrollSafeAreaPadding = NomaSpacing.xxl + NomaSpacing.xxl + NomaSpacing.xxl + NomaSpacing.xs
    static let createButtonScreenEdgePadding = NomaSpacing.xxl

    static func createButtonVerticalOffset(bottomSafeAreaInset: CGFloat) -> CGFloat {
        bottomSafeAreaInset - createButtonScreenEdgePadding
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
            ZStack(alignment: .bottomTrailing) {
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
                        .safeAreaPadding(.bottom, HomeViewLayout.bottomScrollSafeAreaPadding)
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
                    .onChange(of: dailyTaskGroups.groups, initial: true) { _, _ in refreshDailyTaskNotifications() }
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

                if path.isEmpty {
                    createButton
                        .padding(.trailing, HomeViewLayout.createButtonScreenEdgePadding)
                        .offset(
                            y: HomeViewLayout.createButtonVerticalOffset(
                                bottomSafeAreaInset: proxy.safeAreaInsets.bottom
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
