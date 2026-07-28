import SwiftUI

enum CreateReminderListSection {
    static let headerTitleFormatKey = "create.tasks.date.section-header"
    static let carryForwardPreviewTitleKey = "create.tasks.yesterday.section-header"
    static let carryForwardPreviewSystemImage = "clock.arrow.circlepath"

    static func headerTitle(for date: Date) -> String {
        let format = String(localized: String.LocalizationValue(headerTitleFormatKey))
        let dateText = date.formatted(date: .abbreviated, time: .omitted)
        return String.localizedStringWithFormat(format, dateText)
    }

    static func showsHeader(reminderCount: Int, carryForwardPreviewCount: Int = 0) -> Bool {
        reminderCount > 0
    }

    static func showsEmptyState(reminderCount: Int, carryForwardPreviewCount: Int = 0) -> Bool {
        reminderCount == 0 && carryForwardPreviewCount == 0
    }

    static func showsFilteredEmptyState(
        visibleReminderCount: Int,
        reminderCount: Int,
        carryForwardPreviewCount: Int = 0
    ) -> Bool {
        visibleReminderCount == 0 && reminderCount > 0 && carryForwardPreviewCount == 0
    }

}

enum CreateReminderContextMenuCopy {
    static let editTitleKey = "create.tasks.context-menu.edit"
}

enum CreateReminderListLayout {
    static let bottomScrollPadding = NomaSize.scrollDismissSentinel
    static let bottomAnchorID = "create-reminder-list-bottom-anchor"
}

enum CreateReminderMetadataIconLayout {
    static let columnWidth = NomaSize.taskMetadataIconColumn
    static let spacingToText = NomaSpacing.md
    static let firstLineCenterOffset = NomaSize.taskFirstLineIconOffset
}

struct CreateReminderSectionHeader: View {
    let title: String
    var systemImage = "checklist.unchecked"
    var color: Color = .textPrimary
    var bottomPadding: CGFloat = SectionHeaderLayout.bottomPadding

    var body: some View {
        HStack(alignment: .center, spacing: CreateReminderMetadataIconLayout.spacingToText) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(color)
                .frame(
                    width: CreateReminderMetadataIconLayout.columnWidth,
                    height: NomaSize.radioCheckboxOuter,
                    alignment: .center
                )

            Text(displayText)
                .font(.headline)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, bottomPadding)
    }

    private var displayText: String {
        SectionHeaderTextFormatting.titleCased(title)
    }
}

enum CreateReminderAutoScroll {
    static let currentReminderAnchorPrefix = "create-reminder-current"
    static let layoutSettleDelayNanoseconds: UInt64 = 120_000_000

    static func targetID(for reminder: CreateReminder) -> String {
        "\(currentReminderAnchorPrefix)-\(reminder.id.uuidString)"
    }

    static func targetAfterAppending(_ reminder: CreateReminder) -> String {
        targetID(for: reminder)
    }

    static func targetAfterKeyboardFocus(visibleReminders: [CreateReminder]) -> String? {
        guard let lastReminder = visibleReminders.last else { return nil }
        return targetID(for: lastReminder)
    }

    @MainActor
    static func scrollToPendingTarget(_ targetID: String?, using scrollProxy: ScrollViewProxy) async -> Bool {
        guard let targetID else { return false }

        await Task.yield()
        try? await Task.sleep(nanoseconds: layoutSettleDelayNanoseconds)
        withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            scrollProxy.scrollTo(targetID, anchor: .bottom)
        }
        return true
    }
}

enum CreateReminderFilterToggle {
    static func toggle(
        isActive: Bool,
        hapticFeedback: HapticFeedbackService,
        setIsActive: (Bool) -> Void
    ) {
        hapticFeedback.play(.createTaskSubmit)
        withAnimation(.smooth(duration: NomaTiming.controlFeedback)) {
            setIsActive(!isActive)
        }
    }
}

enum CreateReminderSwipeAction {
    static let deleteThreshold = NomaSize.taskDeleteSwipeThreshold, minimumDistance: CGFloat = 0
    static let horizontalActivationBias = NomaSpacing.xs

    static func shouldTrackSwipe(translation: CGSize) -> Bool {
        translation.width < 0 && abs(translation.width) > abs(translation.height) + horizontalActivationBias
    }

    static func shouldBeginSwipe(translation: CGSize, velocity: CGSize) -> Bool {
        let horizontalVelocity = abs(velocity.width)
        let verticalVelocity = abs(velocity.height)

        return translation.width < 0
            && horizontalVelocity > verticalVelocity * NomaScale.taskSwipeHorizontalDominance
    }

    static func offset(for translation: CGFloat) -> CGFloat {
        max(-deleteThreshold, min(0, translation * NomaScale.taskDeleteSwipeDamping))
    }

    static func progress(for offset: CGFloat) -> CGFloat {
        guard deleteThreshold > 0 else { return 0 }
        return min(CreateReminderSwipeAction.deleteThreshold / deleteThreshold, abs(offset) / deleteThreshold)
    }

    static func remainingProgress(for offset: CGFloat) -> CGFloat {
        progress(for: -deleteThreshold) - progress(for: offset)
    }

    static func shouldDelete(offset: CGFloat) -> Bool { abs(offset) >= deleteThreshold }

    static func feedback(previousOffset: CGFloat, currentOffset: CGFloat) -> HapticFeedbackClass? {
        !shouldDelete(offset: previousOffset) && shouldDelete(offset: currentOffset)
            ? .taskSwipeDeleteThreshold
            : nil
    }

    static func playFeedbackIfNeeded(
        previousOffset: CGFloat,
        currentOffset: CGFloat,
        using hapticFeedback: HapticFeedbackService
    ) {
        guard let feedback = feedback(
            previousOffset: previousOffset,
            currentOffset: currentOffset
        ) else { return }

        hapticFeedback.play(feedback)
    }
}

struct CreateReminderScrollContainer<Content: View>: View {
    @Binding var pendingScrollTargetID: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                content()
            }
            .safeAreaPadding(.bottom, CreateViewScrollLayout.bottomSafeAreaPadding)
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .task(id: pendingScrollTargetID) {
                if await CreateReminderAutoScroll.scrollToPendingTarget(pendingScrollTargetID, using: scrollProxy) {
                    pendingScrollTargetID = nil
                }
            }
        }
    }
}

struct CreateReminderList: View {
    let reminders: [CreateReminder]
    let carryForwardPreviewReminders: [CreateReminder]
    let sectionTitle: String
    let reminderCount: Int
    let projects: [TaskProject]
    let onToggleReminder: (CreateReminder) -> Void, onEditReminder: (CreateReminder) -> Void, onDeleteReminder: (CreateReminder) -> Void
    var onRepeatReminder: ((CreateReminder) -> Void)?
    let onCarryForwardReminder: (CreateReminder) -> Void
    let onCompleteCarryForwardReminder: (CreateReminder) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if CreateReminderListSection.showsFilteredEmptyState(
                visibleReminderCount: reminders.count,
                reminderCount: reminderCount,
                carryForwardPreviewCount: carryForwardPreviewReminders.count
            ) {
                CreateTaskFilteredEmptyHint()
                    .transition(.opacity)
            } else if CreateReminderListSection.showsHeader(
                reminderCount: reminderCount,
                carryForwardPreviewCount: carryForwardPreviewReminders.count
            ) {
                CreateReminderSectionHeader(title: sectionTitle)
            }

            VStack(alignment: .leading, spacing: NomaSpacing.md) {
                CreateReminderRows(
                    reminders: reminders,
                    projects: projects,
                    onToggleReminder: onToggleReminder,
                    onEditReminder: onEditReminder,
                    onRepeatReminder: onRepeatReminder,
                    onDeleteReminder: onDeleteReminder
                )

                if !carryForwardPreviewReminders.isEmpty {
                    if !reminders.isEmpty {
                        Divider()
                            .padding(.top, NomaSpacing.xxl)
                            .padding(.bottom, NomaSpacing.xl)
                    }

                    CreateReminderSectionHeader(
                        title: String(localized: String.LocalizationValue(CreateReminderListSection.carryForwardPreviewTitleKey)),
                        systemImage: CreateReminderListSection.carryForwardPreviewSystemImage,
                        color: .textSecondary,
                        bottomPadding: SectionHeaderLayout.bottomPadding - NomaSpacing.md
                    )

                    ForEach(carryForwardPreviewReminders) { reminder in
                        CreateReminderCarryForwardPreviewRow(
                            reminder: reminder,
                            project: carryForwardProject(for: reminder),
                            onCarryForward: { onCarryForwardReminder(reminder) },
                            onComplete: { onCompleteCarryForwardReminder(reminder) }
                        )
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .move(edge: .top))
                            )
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: NomaSpacing.md) {
                Spacer(minLength: CreateReminderListLayout.bottomScrollPadding)
                    .frame(height: CreateReminderListLayout.bottomScrollPadding)
                    .id(CreateReminderListLayout.bottomAnchorID)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, NomaSpacing.xl)
        .padding(.top, NomaSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func carryForwardProject(for reminder: CreateReminder) -> TaskProject? {
        guard let projectID = reminder.projectID else { return nil }
        return projects.first { $0.id == projectID }
    }
}
