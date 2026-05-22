import SwiftUI

enum DailyTaskGroupRowInteraction {
    static let usesScaleButtonStyle = true
}

enum DailyTaskGroupRowLayout {
    static let statusIconWidth = NomaSize.taskMetadataIconColumn
    static let statusIconHeight = NomaSize.radioCheckboxOuter
}

struct DailyGroupsSectionView: View {
    let summaries: [DailyTaskGroupSummary]
    let onSelectGroup: (DailyTaskGroupSummary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(DailyTaskGroupsSection.headerTitleKey)

            VStack(alignment: .leading, spacing: NomaSpacing.xl) {
                ForEach(summaries) { summary in
                    Button {
                        onSelectGroup(summary)
                    } label: {
                        DailyTaskGroupRow(summary: summary)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }
}

struct DailyTaskGroupRow: View {
    let summary: DailyTaskGroupSummary

    var body: some View {
        HStack(spacing: NomaSpacing.md) {
            VStack(alignment: .leading, spacing: NomaSpacing.xs) {
                Text(summary.title)
                    .font(.headline)
                    .fontWeight(.regular)
                    .foregroundStyle(.textPrimary)

                DailyTaskGroupProgressText(summary: summary)
            }

            Spacer(minLength: 0)

            DailyTaskGroupStatusIcon(status: DailyTaskGroupRowStatus.status(for: summary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

}

struct DailyTaskGroupStatusIcon: View {
    let status: DailyTaskGroupRowStatus

    var body: some View {
        Image(systemName: status.systemImage)
            .font(.title3.weight(.bold))
            .foregroundStyle(status.color)
            .frame(
                width: DailyTaskGroupRowLayout.statusIconWidth,
                height: DailyTaskGroupRowLayout.statusIconHeight,
                alignment: .center
            )
            .accessibilityHidden(!status.isCompleted)
    }
}

struct DailyTaskGroupProgressText: View {
    let summary: DailyTaskGroupSummary

    var body: some View {
        Text(DailyTaskGroupsProgressCopy.title(for: summary))
        .font(.headline)
        .fontWeight(.regular)
        .foregroundStyle(.textSecondary)
    }
}

enum DailyTaskGroupRowStatus {
    static let completedSystemImage = "checkmark.circle.fill"
    static let openSystemImage = "inset.filled.circle.dashed"

    case completed
    case open

    static func status(for summary: DailyTaskGroupSummary) -> DailyTaskGroupRowStatus {
        summary.isCompleted ? .completed : .open
    }

    var systemImage: String {
        switch self {
        case .completed: Self.completedSystemImage
        case .open: Self.openSystemImage
        }
    }

    var color: Color {
        switch self {
        case .completed: .controlSuccess
        case .open: .textSecondary
        }
    }

    var isCompleted: Bool {
        switch self {
        case .completed: true
        case .open: false
        }
    }
}
