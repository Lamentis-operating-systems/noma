import SwiftUI

struct HomeTopBar: View {
    var body: some View {
        Text("Noma")
            .font(Font.title)
            .fontWeight(.medium)
        .padding(.top, NomaSpacing.sm)
    }
}

struct HomeMenu: View {
    @Environment(AuthStateManager.self) var authState
    @Environment(DailyTaskGroupStore.self) var dailyTaskGroups
    @Environment(AppSettingsStore.self) var appSettings
    @State var isDeleteAccountAlertPresented = false
    @State var deleteAccountErrorMessage: String?

    var body: some View {
        Menu {
            Menu {
                Picker("settings.appearance.section-title", selection: appearancePreference) {
                    Text("settings.appearance.system").tag(AppAppearancePreference.system)
                    Text("settings.appearance.light").tag(AppAppearancePreference.light)
                    Text("settings.appearance.dark").tag(AppAppearancePreference.dark)
                }
                .pickerStyle(.inline)
            } label: {
                Text("settings.appearance.section-title")
            }

            Divider()

            Button(role: .destructive) {
                isDeleteAccountAlertPresented = true
            } label: {
                Text("auth.delete-account.title")
            }
            .disabled(authState.isDeletingAccount)
            .accessibilityLabel(Text("auth.delete-account.title"))
            .accessibilityIdentifier("home-delete-account-action")

            Button(role: .destructive) {
                authState.signOut()
            } label: {
                Text("auth.logout.title")
            }
            .disabled(!HomeMenuActionAvailability.allowsSignOut(
                isDeletingAccount: authState.isDeletingAccount
            ))
            .accessibilityLabel(Text("auth.logout.title"))
            .accessibilityIdentifier("home-sign-out-action")
        } label: {
            Image(systemName: "gearshape")
        }
        .accessibilityIdentifier("home-settings-menu")
        .alert("auth.delete-account.alert.title", isPresented: $isDeleteAccountAlertPresented) {
            Button("common.cancel", role: .cancel) {}
            Button("auth.delete-account.confirm", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("auth.delete-account.alert.message")
        }
        .alert("auth.delete-account.error.title", isPresented: isDeleteAccountErrorPresented) {
            Button("common.ok", role: .cancel) {
                deleteAccountErrorMessage = nil
            }
        } message: {
            Text(deleteAccountErrorMessage ?? "")
        }
    }
}

enum HomeMenuActionAvailability {
    static func allowsSignOut(isDeletingAccount: Bool) -> Bool {
        !isDeletingAccount
    }
}
