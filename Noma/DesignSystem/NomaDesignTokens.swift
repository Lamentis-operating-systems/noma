import SwiftUI

enum NomaMetric {
    typealias Value = CGFloat
}

enum NomaSpacing {
    static let none: NomaMetric.Value = 0
    static let xs: NomaMetric.Value = 4
    static let sm: NomaMetric.Value = 8
    static let md: NomaMetric.Value = 12
    static let lg: NomaMetric.Value = 16
    static let xl: NomaMetric.Value = 24
    static let xxl: NomaMetric.Value = 32
}

enum NomaOffset {
    static let keyboardAccessoryOverlap: NomaMetric.Value = -20
}

enum NomaSize {
    static let scrollDismissSentinel: NomaMetric.Value = 1
    static let sendButton: NomaMetric.Value = 34
    static let taskDeleteSwipeThreshold: NomaMetric.Value = 72
    static let radioCheckboxOuter: NomaMetric.Value = 16
    static let radioCheckboxInner: NomaMetric.Value = 12
    static let radioCheckboxBorder: NomaMetric.Value = 1.5
    static let radioCheckboxFirstLineOffset: NomaMetric.Value = 1
    static let taskFirstLineIconOffset: NomaMetric.Value = radioCheckboxFirstLineOffset + scrollDismissSentinel
    static let projectControl: NomaMetric.Value = 40
    static let projectColorOption: NomaMetric.Value = NomaSize.projectControl - NomaSpacing.xs
    static let projectColorSelectionBorder: NomaMetric.Value = NomaSpacing.xs
    static let projectIconPreview: NomaMetric.Value = 72
    static let taskPreview: NomaMetric.Value = 320
    static let taskMetadataIconColumn: NomaMetric.Value = NomaSpacing.xl
}

enum NomaRadius {
    static let composer: NomaMetric.Value = 25
    static let taskPreview: NomaMetric.Value = NomaSpacing.md
    static let projectControl: NomaMetric.Value = NomaSize.projectControl / 2
}

enum NomaTiming {
    static let controlFeedback = 0.2
    static let taskSwipeRelease = 0.26
}

enum NomaOpacity {
    static let disabledControlBackground = 0.18
}

enum NomaLimit {
    static let projectTitleCharacters = 50
}

enum NomaScale {
    static let pressedControl: CGFloat = 0.96
    static let hintIcon: CGFloat = 1.5
    static let taskDeleteSwipeDamping: CGFloat = NomaSpacing.xl / NomaSpacing.xxl
    static let taskSwipeHorizontalDominance: CGFloat = 1.5
    static let datePickerSheetFraction: CGFloat =
        (NomaSpacing.xl + (NomaSpacing.xs / NomaSpacing.sm * NomaSpacing.xs)) / NomaSize.projectControl
}

enum NomaGradient {
    static let proTierText = LinearGradient(
        colors: [Color.orange, Color.pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension ShapeStyle where Self == Color {
    static var textPrimary: Color { Color.primary }
    static var textSecondary: Color { Color.secondary }
    static var primaryBackground: Color { Color(.systemBackground) }
    static var controlActive: Color { Color(.label) }
    static var controlError: Color { Color(.systemRed) }
    static var controlSuccess: Color { Color(.systemGreen) }
    static var secondaryBackground: Color { Color(.secondarySystemBackground) }
}
