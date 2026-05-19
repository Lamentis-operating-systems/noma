import SwiftUI

enum CreateReminderListSection {
    static let headerTitleFormatKey = "create.tasks.date.section-header", unlockMoreTitleKey = "create.tasks.unlock-more", unlockMoreMessageKey = "create.tasks.unlock-more.today.message"
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

    static func showsUnlockMoreButton(tier: SubscriptionTier, reminderCount: Int) -> Bool {
        !tier.canAddTask(toGroupWithTaskCount: reminderCount)
    }
}

enum CreateReminderContextMenuCopy {
    static let editTitleKey = "create.tasks.context-menu.edit"
}

enum CreateReminderLimitCalloutLayout {
    static var topPadding: CGFloat { UnlockMoreCalloutLayout.topPadding(after: NomaSpacing.md) }
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
        !shouldDelete(offset: previousOffset) && shouldDelete(offset: currentOffset) ? .createTaskSubmit : nil
    }
}

struct CreateTaskEmptyState {
    let systemImage: String?, titleKey: String, subtitleKey: String
    let cta: HintCTA?, mirrorsImageForRightToLeftLayoutDirection: Bool

    static let placeholder = CreateTaskEmptyState(systemImage: nil, titleKey: "create.tasks.empty.today.title", subtitleKey: "create.tasks.empty.today.subtitle", cta: nil, mirrorsImageForRightToLeftLayoutDirection: false)
}

struct CreateTaskEmptyHint: View {
    var body: some View {
        HintView(
            systemImage: CreateTaskEmptyState.placeholder.systemImage,
            title: LocalizedStringKey(CreateTaskEmptyState.placeholder.titleKey),
            subtitle: LocalizedStringKey(CreateTaskEmptyState.placeholder.subtitleKey),
            cta: CreateTaskEmptyState.placeholder.cta,
            mirrorsSystemImageForRightToLeftLayoutDirection: CreateTaskEmptyState.placeholder.mirrorsImageForRightToLeftLayoutDirection
        )
    }
}

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
            alignment: .center
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
    let tier: SubscriptionTier
    let onUnlockMore: () -> Void, onSwipeDeleteThreshold: () -> Void
    let onToggleReminder: (CreateReminder) -> Void, onEditReminder: (CreateReminder) -> Void, onDeleteReminder: (CreateReminder) -> Void
    let onCompleteCarryForwardReminder: (CreateReminder) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if CreateReminderListSection.showsHeader(
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
                    onDeleteReminder: onDeleteReminder,
                    onSwipeDeleteThreshold: onSwipeDeleteThreshold
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
                if CreateReminderListSection.showsUnlockMoreButton(tier: tier, reminderCount: reminderCount) {
                    UnlockMoreCallout(
                        messageKey: CreateReminderListSection.unlockMoreMessageKey,
                        buttonTitleKey: CreateReminderListSection.unlockMoreTitleKey,
                        action: onUnlockMore
                    )
                        .padding(.top, CreateReminderLimitCalloutLayout.topPadding)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

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
