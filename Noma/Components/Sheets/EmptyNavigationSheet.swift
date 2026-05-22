import SwiftUI

struct EmptyNavigationSheet: View {
    let titleKey: String
    let closeAccessibilityLabelKey: LocalizedStringKey
    let close: () -> Void

    var body: some View {
        NavigationStack {
            Rectangle()
                .fill(.primaryBackground)
                .ignoresSafeArea(.container)
                .navigationTitle(LocalizedStringKey(titleKey))
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    CloseToolbarButton(
                        accessibilityLabelKey: closeAccessibilityLabelKey,
                        action: close
                    )
                }
        }
    }
}
