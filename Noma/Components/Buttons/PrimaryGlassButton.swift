import SwiftUI

enum PrimaryGlassButtonWidth: Equatable {
    case intrinsic
    case fullWidth
}

struct PrimaryGlassButtonState: Equatable {
    let isDisabled: Bool
    let isLoading: Bool

    var allowsInteraction: Bool { !isDisabled && !isLoading }
    var showsProgress: Bool { isLoading }
}

struct PrimaryGlassButton: View {
    private let title: Text
    private let systemImage: String?
    private let width: PrimaryGlassButtonWidth
    private let state: PrimaryGlassButtonState
    private let action: () -> Void

    init(
        title: LocalizedStringKey,
        systemImage: String? = nil,
        width: PrimaryGlassButtonWidth = .intrinsic,
        isDisabled: Bool = false,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = Text(title)
        self.systemImage = systemImage
        self.width = width
        self.state = PrimaryGlassButtonState(isDisabled: isDisabled, isLoading: isLoading)
        self.action = action
    }

    init(
        verbatimTitle: String,
        systemImage: String? = nil,
        width: PrimaryGlassButtonWidth = .intrinsic,
        isDisabled: Bool = false,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = Text(verbatim: verbatimTitle)
        self.systemImage = systemImage
        self.width = width
        self.state = PrimaryGlassButtonState(isDisabled: isDisabled, isLoading: isLoading)
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                label
                    .hidden()
                    .accessibilityHidden(true)

                if state.showsProgress {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.primaryBackground)
                        .transition(.blurReplace)
                } else {
                    label
                        .transition(.blurReplace)
                }
            }
            .font(.headline)
            .foregroundStyle(.primaryBackground)
            .frame(maxWidth: width == .fullWidth ? .infinity : nil)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, NomaSpacing.md)
            .padding(.horizontal, NomaSpacing.md)
            .animation(.smooth(duration: NomaTiming.controlFeedback), value: state)
        }
        .disabled(!state.allowsInteraction)
        .tint(.primary)
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var label: some View {
        HStack(spacing: NomaSpacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
            }

            title
        }
    }
}

#Preview("Glass actions") {
    VStack(spacing: NomaSpacing.xl) {
        PrimaryGlassButton(title: "create.button.title", systemImage: "square.and.pencil") {}
        PrimaryGlassButton(title: "create.project.create-button", width: .fullWidth) {}
        PrimaryGlassButton(
            title: "create.project.save-button",
            width: .fullWidth,
            isDisabled: true
        ) {}
        PrimaryGlassButton(
            title: "create.project.save-button",
            width: .fullWidth,
            isLoading: true
        ) {}
    }
    .padding(NomaSpacing.xxl)
}
