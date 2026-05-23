import SwiftUI

enum SignInWithAppleGlassButtonLayout {
    static let verticalPadding: NomaMetric.Value = NomaSpacing.md
}

struct SignInWithAppleGlassButtonState: Equatable {
    let isLoading: Bool
    let hasAcceptedPrivacyPolicy: Bool

    init(isLoading: Bool, hasAcceptedPrivacyPolicy: Bool = true) {
        self.isLoading = isLoading
        self.hasAcceptedPrivacyPolicy = hasAcceptedPrivacyPolicy
    }

    var showsProgressSpinner: Bool { isLoading }
    var allowsInteraction: Bool { !isLoading && hasAcceptedPrivacyPolicy }
    var usesBlurReplaceTransition: Bool { isLoading }
    var preservesLabelLayout: Bool { true }
}

struct SignInWithAppleGlassButton: View {
    let isLoading: Bool
    let hasAcceptedPrivacyPolicy: Bool
    let action: () -> Void

    private var state: SignInWithAppleGlassButtonState {
        SignInWithAppleGlassButtonState(
            isLoading: isLoading,
            hasAcceptedPrivacyPolicy: hasAcceptedPrivacyPolicy
        )
    }

    init(
        isLoading: Bool = false,
        hasAcceptedPrivacyPolicy: Bool = true,
        action: @escaping () -> Void
    ) {
        self.isLoading = isLoading
        self.hasAcceptedPrivacyPolicy = hasAcceptedPrivacyPolicy
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            content
            .font(.title3)
            .foregroundStyle(.primaryBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SignInWithAppleGlassButtonLayout.verticalPadding)
            .animation(.smooth, value: isLoading)
        }
        .disabled(!state.allowsInteraction)
        .tint(.controlActive)
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            buttonLabel
                .hidden()
                .accessibilityHidden(true)

            if state.showsProgressSpinner {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.primaryBackground)
                    .transition(.blurReplace)
            } else {
                buttonLabel
                    .transition(.blurReplace)
            }
        }
    }

    private var buttonLabel: some View {
        Label {
            Text("auth.apple.button.title")
        } icon: {
            Image(systemName: "apple.logo")
                .padding(.trailing, NomaSpacing.sm)
        }
    }
}
