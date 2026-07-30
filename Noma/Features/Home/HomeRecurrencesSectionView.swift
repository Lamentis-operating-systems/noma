import SwiftUI

struct HomeRecurrencesSectionView: View {
    let recurrences: [TaskRecurrence]

    var body: some View {
        VStack(alignment: .leading, spacing: NomaSpacing.md) {
            SectionHeader("recurrence.manage")
                .accessibilityIdentifier("home-recurrences-section-title")

            ForEach(recurrences) { recurrence in
                HStack(spacing: NomaSpacing.sm) {
                    Image(systemName: "repeat")
                        .foregroundStyle(.textSecondary)
                        .accessibilityHidden(true)

                    Text(recurrence.sourceText)
                        .font(.headline.weight(.regular))
                        .foregroundStyle(.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(recurrence.sourceText))
                .accessibilityIdentifier("home-recurrence-\(recurrence.id)")
            }
        }
    }
}
