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
    static let noticePrefixKey = "signup.consent.notice-prefix"
    static let privacyLinkKey = "signup.consent.privacy-link"
    static var privacyPolicyURL: URL {
        privacyPolicyURL(forLanguageCode: Locale.preferredLanguages.first)
    }

    static func privacyPolicyURL(forLanguageCode languageCode: String?) -> URL {
        let languagePrefix = languageCode?
            .split(separator: "-")
            .first
            .map(String.init)
        let localizedPath = languagePrefix == "de" ? "de" : "en"

        return URL(string: "https://lamentis.de/\(localizedPath)/noma/privacy")!
    }
}

struct SignupView: View {
    let isLoading: Bool
    let errorMessage: String?
    let isSignInAvailable: Bool
    let signInWithApple: () -> Void

    init(
        isLoading: Bool = false,
        errorMessage: String? = nil,
        isSignInAvailable: Bool = true,
        signInWithApple: @escaping () -> Void
    ) {
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.isSignInAvailable = isSignInAvailable
        self.signInWithApple = signInWithApple
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.primaryBackground)
                .ignoresSafeArea()

            VStack(spacing: SignupViewLayout.contentSpacing) {
                GeometryReader { proxy in
                    ScrollView {
                        SignupMarketingContent()
                            .frame(maxWidth: SignupViewLayout.contentMaxWidth)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: proxy.size.height, alignment: .center)
                    }
                    .accessibilityIdentifier("signup-marketing-scroll")
                    .scrollBounceBehavior(.basedOnSize)
                }

                signupFooter
            }
            .padding(.horizontal, SignupViewLayout.edgePadding)
            .padding(.top, SignupViewLayout.edgePadding)
            .padding(.bottom, SignupViewLayout.bottomPadding)
        }
    }

    private var signupFooter: some View {
        VStack(spacing: SignupViewLayout.bottomControlSpacing) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .transition(.blurReplace)
            }

            SignupConsentNotice()

            SignInWithAppleGlassButton(
                isLoading: isLoading,
                isAvailable: isSignInAvailable,
                action: signInWithApple
            )
        }
    }
}

struct SignupConsentNotice: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: NomaSpacing.xs) {
                noticePrefix
                privacyPolicyLink
            }

            VStack(alignment: .leading, spacing: SignupViewLayout.consentSpacing) {
                noticePrefix
                privacyPolicyLink
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var noticePrefix: some View {
        Text(LocalizedStringKey(SignupConsent.noticePrefixKey))
            .foregroundStyle(.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var privacyPolicyLink: some View {
        Link(
            LocalizedStringKey(SignupConsent.privacyLinkKey),
            destination: SignupConsent.privacyPolicyURL
        )
        .underline()
        .foregroundStyle(.controlActive)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("signup-privacy-link")
    }
}

#Preview {
    SignupView {}
}

#Preview("Compact German AX5") {
    SignupView(errorMessage: "Anmeldung derzeit nicht möglich") {}
        .environment(\.locale, Locale(identifier: "de"))
        .environment(\.dynamicTypeSize, .accessibility5)
        .frame(width: 320, height: 568)
}
