import SwiftUI

struct TaskWorkspaceToolbar: ToolbarContent {
    let title: String
    let subtitle: String
    let isDoneDisabled: Bool
    let isFilterActive: Bool
    let isFilterDisabled: Bool
    let onDone: () -> Void
    let onFilter: () -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            TaskNavigationTitle(
                title: title,
                subtitle: subtitle
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

private struct TaskNavigationTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.textPrimary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("task-workspace-title")
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
