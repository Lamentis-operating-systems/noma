//
//  NomaApp.swift
//  Noma
//
//  Created by Elias Papavlassopoulos on 15.05.26.
//

import SwiftUI

@main
struct NomaApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var authState: AuthStateManager
    @State private var dailyTaskNotifications: DailyTaskNotificationScheduler
    @State private var appSettings: AppSettingsStore
    @State private var dailyTaskGroups: DailyTaskGroupStore

    init() {
#if DEBUG
        if let uiTestConfiguration = NomaUITestLaunchConfiguration.current {
            let dependencies = uiTestConfiguration.makeDependencies()
            _dailyTaskNotifications = State(initialValue: dependencies.notifications)
            _authState = State(initialValue: dependencies.authState)
            _appSettings = State(initialValue: dependencies.appSettings)
            _dailyTaskGroups = State(initialValue: dependencies.dailyTaskGroups)
            return
        }
#endif

        let notifications = DailyTaskNotificationScheduler()
        let authState = AuthStateManager(sessionLifecycle: notifications)
        let dailyTaskGroups = DailyTaskGroupStore()

        _dailyTaskNotifications = State(initialValue: notifications)
        _authState = State(initialValue: authState)
        _appSettings = State(initialValue: AppSettingsStore())
        _dailyTaskGroups = State(initialValue: dailyTaskGroups)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authState)
                .environment(dailyTaskNotifications)
                .environment(appSettings)
                .environment(dailyTaskGroups)
                .preferredColorScheme(appSettings.appearancePreference.colorScheme)
                .onChange(of: authState.storageUserID, initial: true) { _, userID in
                    dailyTaskGroups.switchUserID(userID)
                }
                .onChange(of: scenePhase, initial: true) { _, phase in
                    guard phase == .active else { return }
                    dailyTaskGroups.materializeRecurrences()
                }
        }
    }
}
