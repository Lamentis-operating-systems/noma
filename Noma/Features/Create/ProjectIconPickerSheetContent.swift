import SwiftUI

struct ProjectIconPreview: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.largeTitle.weight(.bold))
            .scaleEffect(NomaScale.hintIcon)
            .foregroundStyle(color)
            .frame(height: NomaSize.projectIconPreview)
            .padding(.horizontal, NomaSpacing.xl)
            .accessibilityIdentifier("project-icon-preview")
            .accessibilityHidden(true)
            .accessibilityRepresentation { EmptyView() }
    }
}

struct ProjectColorPicker: View {
    @Binding var selectedColorIndex: Int

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: NomaSpacing.xl) {
                ForEach(ProjectIconPickerOption.colors.indices, id: \.self) { index in
                    ProjectColorOptionButton(
                        index: index,
                        isSelected: index == selectedColorIndex
                    ) {
                        selectedColorIndex = index
                    }
                }
            }
            .padding(.vertical, NomaSpacing.sm)
        }
        .safeAreaPadding(.horizontal, NomaSpacing.xl)
        .scrollIndicators(.hidden)
    }
}

private struct ProjectColorOptionButton: View {
    let index: Int
    let isSelected: Bool
    let action: () -> Void

    private var color: Color {
        ProjectIconPickerOption.colors[index]
    }

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                Circle().fill(color)

                if isSelected {
                    Circle()
                        .stroke(color, lineWidth: ProjectIconPickerSheetLayout.selectedColorBorderWidth)
                        .padding(-NomaSpacing.xs)
                }
            }
            .frame(
                width: ProjectIconPickerSheetLayout.colorOptionSize,
                height: ProjectIconPickerSheetLayout.colorOptionSize
            )
            .frame(width: NomaSize.projectControl, height: NomaSize.projectControl)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(Text(ProjectIconPickerSheetCopy.colorAccessibilityLabel(for: index)))
        .accessibilityValue(
            isSelected
                ? Text(LocalizedStringKey(ProjectIconPickerSheetCopy.selectedAccessibilityValueKey))
                : Text("")
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct ProjectIconGrid: View {
    let columns: [GridItem]
    @Binding var selectedSymbol: String
    let selectedColor: Color

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: NomaSpacing.xl) {
                ForEach(ProjectIconPickerOption.icons) { option in
                    ProjectIconOptionButton(
                        option: option,
                        isSelected: option.symbolName == selectedSymbol,
                        selectedColor: selectedColor
                    ) {
                        selectedSymbol = option.symbolName
                    }
                }
            }
            .padding(.bottom, NomaSpacing.sm)
            .padding(.horizontal, NomaSpacing.xl)
        }
        .safeAreaPadding(.top, NomaSpacing.sm)
        .scrollIndicators(.hidden)
    }
}

private struct ProjectIconOptionButton: View {
    let option: ProjectIconOption
    let isSelected: Bool
    let selectedColor: Color
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: option.symbolName)
                .font(.title2.weight(.bold))
                .foregroundStyle(isSelected ? selectedColor : .textPrimary)
                .frame(width: NomaSize.projectControl, height: NomaSize.projectControl)
                .accessibilityHidden(true)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityRepresentation {
            Button(action: action) {
                Text(LocalizedStringKey(option.accessibilityLabelKey))
            }
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }
}
