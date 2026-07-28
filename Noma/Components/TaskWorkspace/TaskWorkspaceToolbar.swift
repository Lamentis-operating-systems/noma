import SwiftUI

struct TaskWorkspaceToolbar: ToolbarContent {
    let title: String
    let subtitle: String
    let titleAccessibilityLabelKey: String
    let isDoneDisabled: Bool
    let isFilterActive: Bool
    let isFilterDisabled: Bool
    let onTitleTap: () -> Void
    let onDone: () -> Void
    let onFilter: () -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            TaskNavigationTitleButton(
                title: title,
                subtitle: subtitle,
                accessibilityLabelKey: titleAccessibilityLabelKey,
                action: onTitleTap
            )
        }

        ToolbarItem(placement: .topBarTrailing) {
            TaskDoneToolbarButton(isDisabled: isDoneDisabled, action: onDone)
        }

        ToolbarSpacer(.fixed, placement: .topBarTrailing)

        ToolbarItem(placement: .topBarTrailing) {
            TaskFilterToolbarButton(
                isActive: isFilterActive,
                isDisabled: isFilterDisabled,
                action: onFilter
            )
        }
    }
}

private struct TaskNavigationTitleButton: View {
    let title: String
    let subtitle: String
    let accessibilityLabelKey: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.textPrimary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(accessibilityLabelKey)))
        .accessibilityIdentifier("task-workspace-title-button")
    }
}

private struct TaskDoneToolbarButton: View {
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("create.toolbar.done.title")
        }
        .disabled(isDisabled)
        .accessibilityIdentifier("task-workspace-done-button")
    }
}

private struct TaskFilterToolbarButton: View {
    let isActive: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "line.3.horizontal.decrease")
        }
        .foregroundStyle(isActive ? Color.accentColor : .textPrimary)
        .accessibilityLabel(Text("create.toolbar.filter.unsolved.accessibility-label"))
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .accessibilityIdentifier("task-workspace-filter-button")
        .disabled(isDisabled)
    }
}
