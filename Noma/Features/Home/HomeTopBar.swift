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
    @Environment(AuthStateManager.self) private var authState
    @Environment(AppSettingsStore.self) private var appSettings
    @State private var isNotificationsPresented = false

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
    }

    private var appearancePreference: Binding<AppAppearancePreference> {
        Binding(
            get: { appSettings.appearancePreference },
            set: { appSettings.appearancePreference = $0 }
        )
    }
}
