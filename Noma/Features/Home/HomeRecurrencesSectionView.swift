import SwiftUI

struct HomeRecurrencesSectionView: View {
    let recurrences: [TaskRecurrence]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("recurrence.manage")
                .accessibilityIdentifier("home-recurrences-section-title")

            VStack(alignment: .leading, spacing: CreateReminderRowsLayout.spacingBetweenTasks) {
                ForEach(recurrences) { recurrence in
                    HStack(alignment: .top, spacing: 0) {
                        Text(recurrence.sourceText)
                            .font(.headline.weight(.regular))
                            .foregroundStyle(.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "repeat")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.textSecondary)
                            .frame(
                                width: NomaSize.radioCheckboxOuter,
                                height: NomaSize.radioCheckboxOuter,
                                alignment: .center
                            )
                            .padding(.leading, NomaSpacing.md)
                            .padding(.top, CreateReminderMetadataIconLayout.firstLineCenterOffset)
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(recurrence.sourceText))
                    .accessibilityIdentifier("home-recurrence-\(recurrence.id)")
                }
            }
        }
    }
}
