import Foundation

extension DailyTaskGroupStorage {
    func deleteState() {
        userDefaults.removeObject(forKey: storageKey)
    }

    static func deleteState(forUserID userID: String?, userDefaults: UserDefaults = .standard) {
        DailyTaskGroupStorage(
            userDefaults: userDefaults,
            storageKey: storageKey(forUserID: userID)
        )
        .deleteState()
    }
}
