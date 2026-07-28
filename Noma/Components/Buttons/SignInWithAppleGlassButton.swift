import SwiftUI

enum SignInWithAppleGlassButtonLayout {
    static let verticalPadding: NomaMetric.Value = NomaSpacing.md
}

struct SignInWithAppleGlassButtonState: Equatable {
    let isLoading: Bool
    let isAvailable: Bool

    init(
        isLoading: Bool,
        isAvailable: Bool = true
    ) {
        self.isLoading = isLoading
        self.isAvailable = isAvailable
    }

    var showsProgressSpinner: Bool { isLoading }
    var allowsInteraction: Bool { !isLoading && isAvailable }
}

struct SignInWithAppleGlassButton: View {
    let isLoading: Bool
    let isAvailable: Bool
    let action: () -> Void

    private var state: SignInWithAppleGlassButtonState {
        SignInWithAppleGlassButtonState(
            isLoading: isLoading,
            isAvailable: isAvailable
        )
    }

    init(
        isLoading: Bool = false,
        isAvailable: Bool = true,
        action: @escaping () -> Void
    ) {
        self.isLoading = isLoading
        self.isAvailable = isAvailable
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
        .accessibilityRepresentation {
            Button(action: action) {
                Text("auth.apple.button.title")
            }
            .disabled(!state.allowsInteraction)
            .accessibilityIdentifier("signup-apple-button")
        }
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
                    .accessibilityHidden(true)
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
                .accessibilityHidden(true)
        }
    }
}
