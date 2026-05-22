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
    @State var isNotificationsPresented = false
    @State var isDeleteAccountAlertPresented = false
    @State var deleteAccountErrorMessage: String?

    var body: some View {
        Menu {
            Button {
                isNotificationsPresented = true
            } label: {
                Label(
                    "settings.notifications.section-title",
                    systemImage: "bell"
                )
            }

            Picker("settings.appearance.section-title", selection: appearancePreference) {
                Text("settings.appearance.system").tag(AppAppearancePreference.system)
                Text("settings.appearance.light").tag(AppAppearancePreference.light)
                Text("settings.appearance.dark").tag(AppAppearancePreference.dark)
            }
            .pickerStyle(.inline)

            Divider()

            Button(role: .destructive) {
                isDeleteAccountAlertPresented = true
            } label: {
                Label(
                    "auth.delete-account.title",
                    systemImage: "person.crop.circle.badge.xmark"
                )
            }
            .disabled(authState.isDeletingAccount)

            Button(role: .destructive) {
                authState.signOut()
            } label: {
                Label(
                    "auth.logout.title",
                    systemImage: "rectangle.portrait.and.arrow.right"
                )
            }
        } label: {
            Image(systemName: "gearshape")
        }
        .sheet(isPresented: $isNotificationsPresented) {
            NavigationStack {
                HomeNotificationsView()
            }
                .presentationDetents([.large])
        }
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
