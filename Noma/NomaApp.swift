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
    @State private var authState = AuthStateManager()
    @State private var dailyTaskNotifications = DailyTaskNotificationScheduler()
    @State private var appSettings = AppSettingsStore()
    #if DEBUG
    @State private var dailyTaskGroups = DailyTaskGroupStore(usesMockData: true)
    #else
    @State private var dailyTaskGroups = DailyTaskGroupStore()
    #endif

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
                    let now = Date()
                    dailyTaskGroups.expireProjects(asOf: now)
                    dailyTaskGroups.purgeRecentlyDeletedProjects(asOf: now)
                }
        }
    }
}
