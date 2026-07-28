import SwiftUI

enum HintViewLayout {
    static let horizontalPadding = NomaSpacing.xl
}

struct HintView: View {
    let systemImage: String?
    let title: LocalizedStringKey?
    let subtitle: LocalizedStringKey?

    init(
        systemImage: String? = nil,
        title: LocalizedStringKey? = nil,
        subtitle: LocalizedStringKey? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: 0) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title.weight(.bold))
                    .scaleEffect(NomaScale.hintIcon)
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity)
            }

            if let title {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, systemImage == nil ? 0 : NomaSpacing.xxl)
            }

            if let subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, title == nil ? 0 : NomaSpacing.sm)
            }
        }
        .padding(.horizontal, HintViewLayout.horizontalPadding)
        .frame(maxWidth: .infinity)
    }
}
