import SwiftUI

struct CreateReminderRowLayout<Content: View, Accessory: View>: View {
    private let content: Content
    private let accessory: Accessory

    init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.content = content()
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            content

            accessory
                .padding(.leading, NomaSpacing.md)
                .padding(.top, CreateReminderMetadataIconLayout.firstLineCenterOffset)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CreateReminderRow: View {
    @Environment(\.hapticFeedback) private var hapticFeedback

    let reminder: CreateReminder
    let project: TaskProject?
    let dayID: String
    let onToggle: () -> Void, onEdit: (() -> Void)?, onDelete: () -> Void

    @State private var swipeOffset: CGFloat = 0
    @State private var isSwipeActive = false
    @State private var selectedCustomWeekdays = Set(TaskRecurrenceMenu.customWeekdays)

    var body: some View {
        CreateReminderRowLayout {
            ZStack(alignment: .leading) {
                reminderText(.textPrimary).opacity(remainingSwipeProgress)
                reminderText(.textSecondary).opacity(swipeProgress)
            }
        } accessory: {
            swipeActionControl
        }
        .contentShape(Rectangle())
        .overlay {
            CreateReminderRowGestureOverlay(
                onTap: onToggle,
                onSwipeChanged: updateSwipeOffset,
                onSwipeEnded: finishSwipe
            )
        }
        .contextMenu {
            if let onEdit {
                Button(action: onEdit) {
                    Label(LocalizedStringKey(CreateReminderContextMenuCopy.editTitleKey), systemImage: "pencil")
                }
            }
            TaskRecurrenceMenu(
                reminder: reminder,
                dayID: dayID,
                selectedCustomWeekdays: $selectedCustomWeekdays
            )
        } preview: { CreateReminderContextMenuPreview(reminder: reminder) }
        .contentShape(.contextMenuPreview, CreateReminderContextMenuPreviewShape.shape)
    }
}

private extension CreateReminderRow {
    private var swipeProgress: CGFloat { CreateReminderSwipeAction.progress(for: swipeOffset) }
    private var remainingSwipeProgress: CGFloat { CreateReminderSwipeAction.remainingProgress(for: swipeOffset) }
    private var deleteIconScale: CGFloat {
        NomaScale.pressedControl + ((CreateReminderSwipeAction.progress(for: -CreateReminderSwipeAction.deleteThreshold) - NomaScale.pressedControl) * swipeProgress)
    }

    private var swipeActionControl: some View {
        ZStack {
            deleteIcon
            RadioCheckbox(isOn: reminder.isCompleted)
                .opacity(remainingSwipeProgress).scaleEffect(remainingSwipeProgress, anchor: .center)
        }
        .frame(width: NomaSize.radioCheckboxOuter, height: NomaSize.radioCheckboxOuter, alignment: .center)
    }

    private var deleteIcon: some View {
        Image(systemName: "minus.circle.fill")
            .font(.body)
            .foregroundStyle(.controlError)
            .opacity(swipeProgress).scaleEffect(deleteIconScale, anchor: .center)
            .frame(width: NomaSize.radioCheckboxOuter, height: NomaSize.radioCheckboxOuter, alignment: .center)
            .accessibilityHidden(true)
    }

    private func reminderText(_ color: Color) -> some View {
        Text(reminder.text)
            .font(.headline.weight(.regular))
            .foregroundStyle(color)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func updateSwipeOffset(with translation: CGSize) {
        guard isSwipeActive || CreateReminderSwipeAction.shouldTrackSwipe(translation: translation) else { return }
        isSwipeActive = true

        let nextOffset = CreateReminderSwipeAction.offset(for: translation.width)
        CreateReminderSwipeAction.playFeedbackIfNeeded(
            previousOffset: swipeOffset,
            currentOffset: nextOffset,
            using: hapticFeedback
        )
        swipeOffset = nextOffset
    }

    private func finishSwipe() {
        guard isSwipeActive else { swipeOffset = 0; return }

        isSwipeActive = false
        guard CreateReminderSwipeAction.shouldDelete(offset: swipeOffset) else {
            withAnimation(.smooth(duration: NomaTiming.taskSwipeRelease)) { swipeOffset = 0 }
            return
        }

        withAnimation(.smooth(duration: NomaTiming.taskSwipeRelease)) { swipeOffset = -CreateReminderSwipeAction.deleteThreshold }
        onDelete()
    }
}

struct CreateReminderRows: View {
    let reminders: [CreateReminder]
    let projects: [TaskProject]
    let dayID: String
    let onToggleReminder: (CreateReminder) -> Void
    var onEditReminder: ((CreateReminder) -> Void)?
    let onDeleteReminder: (CreateReminder) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CreateReminderRowsLayout.spacingBetweenTasks) {
            ForEach(reminders) { reminder in
                CreateReminderRow(
                    reminder: reminder,
                    project: project(for: reminder),
                    dayID: dayID,
                    onToggle: { onToggleReminder(reminder) },
                    onEdit: onEditAction(for: reminder),
                    onDelete: { onDeleteReminder(reminder) }
                )
                .id(CreateReminderAutoScroll.targetID(for: reminder))
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    )
                )
            }
        }
    }

    private func project(for reminder: CreateReminder) -> TaskProject? {
        guard let projectID = reminder.projectID else { return nil }
        return projects.first { $0.id == projectID }
    }

    private func onEditAction(for reminder: CreateReminder) -> (() -> Void)? {
        guard let onEditReminder else { return nil }
        return { onEditReminder(reminder) }
    }
}

enum CreateReminderRowsLayout {
    static let spacingBetweenTasks = NomaSpacing.md
}
