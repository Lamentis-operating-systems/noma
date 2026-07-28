import SwiftUI

extension HomeMenu {
    var appearancePreference: Binding<AppAppearancePreference> {
        Binding(
            get: { appSettings.appearancePreference },
            set: { appSettings.appearancePreference = $0 }
        )
    }

    func deleteAccount() {
        Task {
            let result = await AccountDeletionCoordinator.deleteAccount(
                authState: authState,
                dailyTaskGroups: dailyTaskGroups
            )
            guard result.completedCleanly else {
                deleteAccountErrorMessage = authState.errorMessage
                return
            }
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
