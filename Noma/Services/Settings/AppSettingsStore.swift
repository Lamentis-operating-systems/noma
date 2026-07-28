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

@Observable
final class AppSettingsStore {
    @ObservationIgnored private let userDefaults: UserDefaults

    var appearancePreference: AppAppearancePreference {
        didSet { AppSettingsPersistence.saveAppearancePreference(appearancePreference, in: userDefaults) }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        appearancePreference = AppSettingsPersistence.loadAppearancePreference(from: userDefaults)
    }
}

enum AppSettingsPersistence {
    private static let appearanceStorageKey = "settings.appearance"

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
