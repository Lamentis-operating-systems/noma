import SwiftUI

struct HomeTopBar: View {
    @Environment(SubscriptionTierManager.self) private var subscriptionTier

    var body: some View {
        HStack(spacing: NomaSpacing.sm) {
            Text("Noma")
                .font(Font.title)
                .fontWeight(.medium)

            subscriptionTierText
        }
        .padding(.top, NomaSpacing.sm)
    }

    @ViewBuilder
    private var subscriptionTierText: some View {
        let text = Text(LocalizedStringKey(subscriptionTier.tier.titleKey))
            .font(Font.title)
            .fontWeight(.medium)

        if subscriptionTier.tier.usesProminentTextGradient {
            text.foregroundStyle(NomaGradient.proTierText)
        } else {
            text.foregroundStyle(.secondary)
        }
    }
}

struct HomeSettingsMenu: View {
    @Environment(AuthStateManager.self) private var authState
    @Environment(SubscriptionTierManager.self) private var subscriptionTier
    @State private var isSettingsPresented = false
    @State private var isUnlockMorePresented = false

    var body: some View {
        Menu {
            if !subscriptionTier.isPro {
                Button {
                    getPro()
                } label: {
                    Label(
                        "home.settings.menu.get-pro",
                        systemImage: "flame"
                    )
                }
            }

            Button {
                isSettingsPresented = true
            } label: {
                Label(
                    "home.settings.menu.settings",
                    systemImage: "gear"
                )
            }

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
        .sheet(isPresented: $isSettingsPresented) {
            HomeSettingsSheet()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $isUnlockMorePresented) {
            UnlockMoreSheet(close: { isUnlockMorePresented = false })
                .presentationDetents([.large])
        }
    }

    private func getPro() {
        #if DEBUG
        subscriptionTier.updateTier(.pro)
        #else
        isUnlockMorePresented = true
        #endif
    }
}
