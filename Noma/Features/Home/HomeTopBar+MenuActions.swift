import SwiftUI

extension HomeMenu {
    var appearancePreference: Binding<AppAppearancePreference> {
        Binding(
            get: { appSettings.appearancePreference },
            set: { appSettings.appearancePreference = $0 }
        )
    }

    func deleteAccount() {
        let userID = authState.storageUserID
        Task {
            let didDelete = await authState.deleteAccountFlow()
            guard didDelete else {
                deleteAccountErrorMessage = authState.errorMessage
                return
            }
            dailyTaskGroups.deleteLocalData(forUserID: userID)
        }
    }

    var isDeleteAccountErrorPresented: Binding<Bool> {
        Binding(
            get: { deleteAccountErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    deleteAccountErrorMessage = nil
                }
            }
        )
    }
}
