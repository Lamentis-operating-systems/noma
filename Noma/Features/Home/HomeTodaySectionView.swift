import SwiftUI

struct HomeTodaySectionView: View {
    let reminders: [CreateReminder]
    let projects: [TaskProject]
    let onToggleReminder: (CreateReminder) -> Void
    let onDeleteReminder: (CreateReminder) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(HomeTodaySection.headerTitleKey)

            CreateReminderRows(
                reminders: reminders,
                projects: projects,
                onToggleReminder: onToggleReminder,
                onDeleteReminder: onDeleteReminder
            )
        }
    }
}
