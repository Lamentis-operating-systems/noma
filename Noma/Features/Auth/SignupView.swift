import SwiftUI

enum SignupViewLayout {
    static let edgePadding: NomaMetric.Value = NomaSpacing.xxl
    static let bottomPadding: NomaMetric.Value = NomaSpacing.xxl
    static let contentSpacing: NomaMetric.Value = NomaSpacing.xxl
    static let bottomControlSpacing: NomaMetric.Value = NomaSpacing.lg
    static let consentSpacing: NomaMetric.Value = NomaSpacing.sm
    static let logoSize: NomaMetric.Value = NomaSize.projectIconPreview + NomaSpacing.sm
    static let workflowSpacing: NomaMetric.Value = NomaSpacing.lg
    static let workflowRowSpacing: NomaMetric.Value = NomaSpacing.md
    static let workflowIconColumnWidth: NomaMetric.Value = NomaSize.taskMetadataIconColumn
    static let contentMaxWidth: NomaMetric.Value = NomaSize.taskPreview
}

struct SignupWorkflowStep: Equatable {
    let number: Int
    let titleKey: String
}

enum SignupViewCopy {
    static let titleKey = "signup.title"
    static let subtitleKey = "signup.subtitle"
    static let workflowSteps = [
        SignupWorkflowStep(
            number: 1,
            titleKey: "signup.workflow.create"
        ),
        SignupWorkflowStep(
            number: 2,
            titleKey: "signup.workflow.complete"
        ),
        SignupWorkflowStep(
            number: 3,
            titleKey: "signup.workflow.carry-forward"
        ),
        SignupWorkflowStep(
            number: 4,
            titleKey: "signup.workflow.decide"
        )
    ]
}

enum SignupConsent {
    static let acceptanceStorageKey = "noma.signup.privacy-policy-accepted"
    static let acceptanceKey = "signup.consent.acceptance"
    static let privacyLinkKey = "signup.consent.privacy-link"
    static let privacyPolicyURL = URL(string: "https://lamentis.de/naome/privacy")!
}

struct SignupView: View {
    let isLoading: Bool
    let errorMessage: String?
    let signInWithApple: () -> Void
    @AppStorage(SignupConsent.acceptanceStorageKey)
    private var hasAcceptedPrivacyPolicy = false

    init(
        isLoading: Bool = false,
        errorMessage: String? = nil,
        signInWithApple: @escaping () -> Void
    ) {
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.signInWithApple = signInWithApple
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.primaryBackground)
                .ignoresSafeArea()

            VStack(spacing: SignupViewLayout.contentSpacing) {
                Spacer()

                SignupMarketingContent()
                    .frame(maxWidth: SignupViewLayout.contentMaxWidth)
                    .padding(.horizontal, SignupViewLayout.edgePadding)

                Spacer()
                Spacer()
            }

            VStack {
                Spacer()

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SignupViewLayout.edgePadding)
                        .transition(.blurReplace)
                }

                VStack(spacing: SignupViewLayout.bottomControlSpacing) {
                    consentControls

                    SignInWithAppleGlassButton(
                        isLoading: isLoading,
                        hasAcceptedPrivacyPolicy: hasAcceptedPrivacyPolicy,
                        action: signInWithApple
                    )
                }
                .padding(.horizontal, SignupViewLayout.edgePadding)
                .padding(.bottom, SignupViewLayout.bottomPadding)
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    private var consentControls: some View {
        SignupConsentControls(hasAcceptedPrivacyPolicy: $hasAcceptedPrivacyPolicy)
    }
}

struct SignupConsentControls: View {
    @Binding var hasAcceptedPrivacyPolicy: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SignupViewLayout.consentSpacing) {
            acceptanceToggle
            privacyPolicyLink
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var acceptanceToggle: some View {
        Toggle(isOn: $hasAcceptedPrivacyPolicy) {
            Text(LocalizedStringKey(SignupConsent.acceptanceKey))
                .font(.subheadline)
                .foregroundStyle(.textPrimary)
        }
        .tint(.controlActive)
    }

    private var privacyPolicyLink: some View {
        Link(
            LocalizedStringKey(SignupConsent.privacyLinkKey),
            destination: SignupConsent.privacyPolicyURL
        )
        .font(.subheadline)
        .foregroundStyle(.controlActive)
    }
}

#Preview {
    SignupView {}
}
