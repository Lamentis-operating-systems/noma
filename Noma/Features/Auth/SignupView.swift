import SwiftUI

enum SignupViewLayout {
    static let edgePadding: NomaMetric.Value = NomaSpacing.xxl
    static let bottomPadding: NomaMetric.Value = NomaSpacing.xxl
    static let contentSpacing: NomaMetric.Value = NomaSpacing.xxl
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

struct SignupView: View {
    let isLoading: Bool
    let errorMessage: String?
    let signInWithApple: () -> Void

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

                SignInWithAppleGlassButton(
                    isLoading: isLoading,
                    action: signInWithApple
                )
                    .padding(.horizontal, SignupViewLayout.edgePadding)
                    .padding(.bottom, SignupViewLayout.bottomPadding)
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}

#Preview {
    SignupView {}
}
