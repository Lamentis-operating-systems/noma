import SwiftUI

struct CreateReminderProjectIcon: View {
    let project: TaskProject?
    var color: Color = TaskProjectIconPresentation.appSurfaceColor

    var body: some View {
        ZStack(alignment: .center) {
            if let project {
                Image(systemName: project.symbolName)
                    .font(.headline)
                    .foregroundStyle(color)
            }
        }
        .frame(
            width: CreateReminderMetadataIconLayout.columnWidth,
            height: NomaSize.radioCheckboxOuter,
            alignment: .leading
        )
        .padding(.top, CreateReminderMetadataIconLayout.firstLineCenterOffset)
    }
}

struct CreateReminderRow: View {
    let reminder: CreateReminder
    let project: TaskProject?
    let onToggle: () -> Void, onEdit: (() -> Void)?, onDelete: () -> Void, onSwipeDeleteThreshold: () -> Void

    @State private var swipeOffset: CGFloat = 0
    @State private var isSwipeActive = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            CreateReminderProjectIcon(project: project)
                .padding(.trailing, CreateReminderMetadataIconLayout.spacingToText)

            ZStack(alignment: .leading) {
                reminderText(.textPrimary).opacity(remainingSwipeProgress)
                reminderText(.textSecondary).opacity(swipeProgress)
            }

            swipeActionControl
                .padding(.leading, NomaSpacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        } preview: { CreateReminderContextMenuPreview(reminder: reminder, project: project) }
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
        .padding(.top, CreateReminderMetadataIconLayout.firstLineCenterOffset)
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
        if CreateReminderSwipeAction.feedback(previousOffset: swipeOffset, currentOffset: nextOffset) != nil {
            onSwipeDeleteThreshold()
        }
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
    let onToggleReminder: (CreateReminder) -> Void
    var onEditReminder: ((CreateReminder) -> Void)?
    let onDeleteReminder: (CreateReminder) -> Void
    let onSwipeDeleteThreshold: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CreateReminderRowsLayout.spacingBetweenTasks) {
            ForEach(reminders) { reminder in
                CreateReminderRow(
                    reminder: reminder,
                    project: project(for: reminder),
                    onToggle: { onToggleReminder(reminder) },
                    onEdit: onEditAction(for: reminder),
                    onDelete: { onDeleteReminder(reminder) },
                    onSwipeDeleteThreshold: onSwipeDeleteThreshold
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
