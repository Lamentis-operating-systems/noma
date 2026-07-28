import SwiftUI

enum ProjectIconPickerSheetCopy {
    static let titleKey = "create.project.icon-picker.title"
    static let doneAccessibilityLabelKey = "create.project.icon-picker.done"
    static let colorAccessibilityLabelKey = "create.project.icon-picker.color.accessibility-label"
    static let selectedAccessibilityValueKey = "create.project.icon-picker.color.selected"

    static func colorAccessibilityLabel(for index: Int) -> String {
        let format = String(localized: String.LocalizationValue(colorAccessibilityLabelKey))
        return String.localizedStringWithFormat(format, index + 1)
    }
}

enum ProjectIconPickerSheetLayout {
    static let colorOptionSize = NomaSize.projectColorOption
    static let selectedColorBorderWidth = NomaSize.projectColorSelectionBorder
    static let doneSystemImage = "checkmark"
}

struct ProjectIconOption: Identifiable, Equatable {
    let symbolName: String
    let accessibilityLabelKey: String

    var id: String { symbolName }
}

enum ProjectIconPickerOption {
    static let defaultColorIndex = 0
    static let defaultSymbol = "folder"

    static let colors: [Color] = [
        .primary,
        .red,
        .orange,
        .yellow,
        .green,
        .blue,
        .purple
    ]

    static let icons = [
        ProjectIconOption(symbolName: "folder", accessibilityLabelKey: "create.project.icon.accessibility.folder"),
        ProjectIconOption(symbolName: "dollarsign.circle", accessibilityLabelKey: "create.project.icon.accessibility.finances"),
        ProjectIconOption(symbolName: "book.closed", accessibilityLabelKey: "create.project.icon.accessibility.book"),
        ProjectIconOption(symbolName: "graduationcap", accessibilityLabelKey: "create.project.icon.accessibility.education"),
        ProjectIconOption(symbolName: "pencil", accessibilityLabelKey: "create.project.icon.accessibility.pencil"),
        ProjectIconOption(symbolName: "pencil.tip", accessibilityLabelKey: "create.project.icon.accessibility.pen-tip"),
        ProjectIconOption(symbolName: "curlybraces", accessibilityLabelKey: "create.project.icon.accessibility.code"),
        ProjectIconOption(symbolName: "terminal", accessibilityLabelKey: "create.project.icon.accessibility.terminal"),
        ProjectIconOption(symbolName: "music.note", accessibilityLabelKey: "create.project.icon.accessibility.music"),
        ProjectIconOption(symbolName: "popcorn", accessibilityLabelKey: "create.project.icon.accessibility.movie"),
        ProjectIconOption(symbolName: "paintbrush", accessibilityLabelKey: "create.project.icon.accessibility.paintbrush"),
        ProjectIconOption(symbolName: "paintpalette", accessibilityLabelKey: "create.project.icon.accessibility.palette"),
        ProjectIconOption(symbolName: "stethoscope", accessibilityLabelKey: "create.project.icon.accessibility.health"),
        ProjectIconOption(symbolName: "asterisk", accessibilityLabelKey: "create.project.icon.accessibility.general"),
        ProjectIconOption(symbolName: "leaf", accessibilityLabelKey: "create.project.icon.accessibility.nature"),
        ProjectIconOption(symbolName: "briefcase", accessibilityLabelKey: "create.project.icon.accessibility.work"),
        ProjectIconOption(symbolName: "chart.bar", accessibilityLabelKey: "create.project.icon.accessibility.chart"),
        ProjectIconOption(symbolName: "dumbbell", accessibilityLabelKey: "create.project.icon.accessibility.fitness"),
        ProjectIconOption(symbolName: "calendar", accessibilityLabelKey: "create.project.icon.accessibility.calendar"),
        ProjectIconOption(symbolName: "scalemass", accessibilityLabelKey: "create.project.icon.accessibility.weight"),
        ProjectIconOption(symbolName: "globe.europe.africa", accessibilityLabelKey: "create.project.icon.accessibility.europe"),
        ProjectIconOption(symbolName: "airplane", accessibilityLabelKey: "create.project.icon.accessibility.travel"),
        ProjectIconOption(symbolName: "globe", accessibilityLabelKey: "create.project.icon.accessibility.world"),
        ProjectIconOption(symbolName: "wrench", accessibilityLabelKey: "create.project.icon.accessibility.tools"),
        ProjectIconOption(symbolName: "pawprint", accessibilityLabelKey: "create.project.icon.accessibility.pets"),
        ProjectIconOption(symbolName: "flask", accessibilityLabelKey: "create.project.icon.accessibility.science"),
        ProjectIconOption(symbolName: "brain", accessibilityLabelKey: "create.project.icon.accessibility.mind"),
        ProjectIconOption(symbolName: "heart", accessibilityLabelKey: "create.project.icon.accessibility.heart"),
        ProjectIconOption(symbolName: "gift", accessibilityLabelKey: "create.project.icon.accessibility.gift")
    ]

    static func normalizedColorIndex(_ index: Int) -> Int {
        colors.indices.contains(index) ? index : defaultColorIndex
    }

    static func color(for index: Int) -> Color {
        colors[normalizedColorIndex(index)]
    }
}

struct ProjectIconPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedColorIndex: Int
    @Binding var selectedSymbol: String

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: NomaSpacing.xxl),
        count: 5
    )

    private var selectedColor: Color {
        ProjectIconPickerOption.color(for: selectedColorIndex)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: NomaSpacing.xl) {
                ProjectIconPreview(symbol: selectedSymbol, color: selectedColor)

                ProjectColorPicker(selectedColorIndex: $selectedColorIndex)

                Divider()

                ProjectIconGrid(
                    columns: columns,
                    selectedSymbol: $selectedSymbol,
                    selectedColor: selectedColor
                )
            }
            .padding(.top, NomaSpacing.xl)
            .navigationTitle(LocalizedStringKey(ProjectIconPickerSheetCopy.titleKey))
            .toolbarTitleDisplayMode(.inline)
            .toolbar { doneButton }
        }
    }

    private var doneButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: ProjectIconPickerSheetLayout.doneSystemImage)
            }
            .tint(.primary)
            .foregroundStyle(.primaryBackground)
            .buttonStyle(.glassProminent)
            .accessibilityLabel(Text(LocalizedStringKey(ProjectIconPickerSheetCopy.doneAccessibilityLabelKey)))
            .accessibilityIdentifier("project-icon-picker-done")
        }
    }
}
