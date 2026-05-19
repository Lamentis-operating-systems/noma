import SwiftUI

enum CreateReminderContextMenuPreviewLayout {
    static let cornerRadius = NomaRadius.taskPreview
    static let contentPadding = NomaSpacing.md
    static let outerPadding = NomaSpacing.md
    static let cardWidth = NomaSize.taskPreview
}

enum CreateReminderContextMenuPreviewShape {
    static var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: CreateReminderContextMenuPreviewLayout.cornerRadius, style: .continuous)
    }
}

struct CreateReminderContextMenuPreview: View {
    let reminder: CreateReminder
    let project: TaskProject?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            CreateReminderProjectIcon(project: project)
                .padding(.trailing, CreateReminderMetadataIconLayout.spacingToText)

            Text(reminder.text)
                .font(.headline.weight(.regular))
                .foregroundStyle(.textPrimary)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            RadioCheckbox(isOn: reminder.isCompleted)
                .padding(.leading, NomaSpacing.md)
                .padding(.top, CreateReminderMetadataIconLayout.firstLineCenterOffset)
        }
        .frame(width: CreateReminderContextMenuPreviewLayout.cardWidth, alignment: .leading)
        .padding(CreateReminderContextMenuPreviewLayout.contentPadding)
        .background {
            RoundedRectangle(cornerRadius: CreateReminderContextMenuPreviewLayout.cornerRadius, style: .continuous)
                .fill(.primaryBackground)
        }
        .padding(CreateReminderContextMenuPreviewLayout.outerPadding)
    }
}
