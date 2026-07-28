import SwiftUI

struct CloseToolbarButton: ToolbarContent {
    let accessibilityLabelKey: LocalizedStringKey
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: action) {
                Image(systemName: "xmark")
            }
            .accessibilityLabel(Text(accessibilityLabelKey))
            .accessibilityIdentifier("close-toolbar-button")
        }
    }
}
