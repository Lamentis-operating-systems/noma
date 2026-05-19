import Foundation
import Observation
import SwiftUI

enum AppAppearancePreference: String, CaseIterable, Codable, Identifiable {
    case dark
    case light
    case system

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark:
            .dark
        case .light:
            .light
        case .system:
            nil
        }
    }
}

struct DailyTaskNotificationPreference: Codable, Equatable {
    var isEnabled: Bool
    var hour: Int
    var minute: Int

    var dateComponents: DateComponents {
        get { DateComponents(hour: hour, minute: minute) }
        set {
            hour = newValue.hour ?? hour
            minute = newValue.minute ?? minute
        }
    }

    func date(on calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: hour, minute: minute)) ?? Date()
    }

    mutating func updateTime(from date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        hour = components.hour ?? hour
        minute = components.minute ?? minute
    }
}

struct DailyTaskNotificationSettings: Codable, Equatable {
    var morningPlanning: DailyTaskNotificationPreference
    var eveningOpenTasks: DailyTaskNotificationPreference

    static var `default`: DailyTaskNotificationSettings {
        DailyTaskNotificationSettings(
            morningPlanning: DailyTaskNotificationPreference(isEnabled: true, hour: 9, minute: 0),
            eveningOpenTasks: DailyTaskNotificationPreference(isEnabled: true, hour: 21, minute: 0)
        )
    }
}

@Observable
final class AppSettingsStore {
    @ObservationIgnored private let userDefaults: UserDefaults

    private(set) var notificationSettings: DailyTaskNotificationSettings {
        didSet { persistNotificationSettings() }
    }

    var appearancePreference: AppAppearancePreference {
        didSet { AppSettingsPersistence.saveAppearancePreference(appearancePreference, in: userDefaults) }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        notificationSettings = AppSettingsPersistence.loadNotificationSettings(from: userDefaults)
        appearancePreference = AppSettingsPersistence.loadAppearancePreference(from: userDefaults)
    }

    func updateNotificationSettings(_ update: (inout DailyTaskNotificationSettings) -> Void) {
        var settings = notificationSettings
        update(&settings)
        notificationSettings = settings
    }

    private func persistNotificationSettings() {
        AppSettingsPersistence.saveNotificationSettings(notificationSettings, in: userDefaults)
    }
}

enum AppSettingsPersistence {
    private static let notificationsStorageKey = "settings.notifications"
    private static let appearanceStorageKey = "settings.appearance"

    static func loadNotificationSettings(from defaults: UserDefaults = .standard) -> DailyTaskNotificationSettings {
        guard
            let data = defaults.data(forKey: notificationsStorageKey),
            let settings = try? JSONDecoder().decode(DailyTaskNotificationSettings.self, from: data)
        else {
            return .default
        }

        return settings
    }

    static func saveNotificationSettings(
        _ settings: DailyTaskNotificationSettings,
        in defaults: UserDefaults = .standard
    ) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: notificationsStorageKey)
    }

    static func loadAppearancePreference(from defaults: UserDefaults = .standard) -> AppAppearancePreference {
        guard
            let rawValue = defaults.string(forKey: appearanceStorageKey),
            let preference = AppAppearancePreference(rawValue: rawValue)
        else {
            return .system
        }

        return preference
    }

    static func saveAppearancePreference(
        _ preference: AppAppearancePreference,
        in defaults: UserDefaults = .standard
    ) {
        defaults.set(preference.rawValue, forKey: appearanceStorageKey)
    }
}
