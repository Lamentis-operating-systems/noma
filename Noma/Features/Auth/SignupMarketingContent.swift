import SwiftUI

struct SignupMarketingContent: View {
    var body: some View {
        VStack(spacing: SignupViewLayout.contentSpacing) {
            Image("NomaLogo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.textPrimary)
                .frame(
                    width: SignupViewLayout.logoSize,
                    height: SignupViewLayout.logoSize
                )
                .accessibilityHidden(true)

            VStack(spacing: NomaSpacing.md) {
                Text(LocalizedStringKey(SignupViewCopy.titleKey))
                    .font(.title.weight(.black))
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("signup-title")

                Text(LocalizedStringKey(SignupViewCopy.subtitleKey))
                    .font(.body)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            SignupWorkflowList()
        }
    }
}

private struct SignupWorkflowList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SignupViewLayout.workflowSpacing) {
            ForEach(SignupViewCopy.workflowSteps, id: \.titleKey) { step in
                SignupWorkflowStepRow(step: step)
            }
        }
    }
}

private struct SignupWorkflowStepRow: View {
    let step: SignupWorkflowStep

    var body: some View {
        HStack(alignment: .top, spacing: SignupViewLayout.workflowRowSpacing) {
            Text("\(step.number).")
                .font(.headline.weight(.black))
                .foregroundStyle(.textSecondary)
                .frame(
                    width: SignupViewLayout.workflowIconColumnWidth,
                    alignment: .leading
                )
                .accessibilityHidden(true)

            Text(LocalizedStringKey(step.titleKey))
                .font(.headline)
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
