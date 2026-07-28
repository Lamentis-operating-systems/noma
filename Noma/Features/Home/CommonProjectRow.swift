import SwiftUI

struct CommonProjectsSectionView: View {
    let summaries: [CommonProjectSummary]
    let onSelectProject: (CommonProjectSummary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(CommonProjectsSection.headerTitleKey)

            VStack(alignment: .leading, spacing: NomaSpacing.xl) {
                ForEach(summaries) { summary in
                    Button {
                        onSelectProject(summary)
                    } label: {
                        CommonProjectRow(summary: summary)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("home-project-\(summary.project.id.uuidString)")
                }
            }
        }
    }
}

struct CommonProjectRow: View {
    let summary: CommonProjectSummary

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            CreateReminderProjectIcon(project: summary.project)
                .padding(.trailing, CreateReminderMetadataIconLayout.spacingToText)

            Text(summary.project.title)
                .font(.headline)
                .foregroundStyle(.textPrimary)

            Spacer(minLength: 0)

            Text(CommonProjectsSection.taskCountText(for: summary))
                .font(.headline)
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
