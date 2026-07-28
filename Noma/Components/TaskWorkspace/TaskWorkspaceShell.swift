import SwiftUI

enum TaskWorkspaceLayout {
    static let collapsedEdgePadding = NomaSpacing.xxl
    static let focusedEdgePadding = NomaSpacing.md
    static let focusedKeyboardSpacing = NomaOffset.keyboardAccessoryOverlap

    static func composerWidth(containerWidth: CGFloat, isKeyboardPresented: Bool) -> CGFloat {
        let edgePadding = isKeyboardPresented ? focusedEdgePadding : collapsedEdgePadding
        let width = max(0, containerWidth - (edgePadding * 2))
        return width.isFinite ? width : 0
    }

    static func composerBottomPadding(isKeyboardPresented: Bool, safeAreaBottom: CGFloat) -> CGFloat {
        let padding = isKeyboardPresented
            ? focusedEdgePadding
            : max(0, collapsedEdgePadding - safeAreaBottom)
        return padding.isFinite ? padding : 0
    }

    static func composerSpacing(isKeyboardPresented: Bool) -> CGFloat {
        max(0, isKeyboardPresented ? focusedKeyboardSpacing : 0)
    }
}

enum TaskWorkspaceKeyboardPolicy {
    static func resolvedPresentationState(
        currentState: Bool,
        keyboardWillBePresented: Bool,
        isModalPresented: Bool
    ) -> Bool {
        isModalPresented ? currentState : keyboardWillBePresented
    }
}

struct TaskWorkspaceShell<Content: View, Composer: View>: View {
    @Binding private var isKeyboardPresented: Bool
    private let isModalPresented: Bool
    private let isInputFocused: FocusState<Bool>.Binding
    private let onKeyboardPresented: () -> Void
    private let content: Content
    private let composer: Composer

    init(
        isKeyboardPresented: Binding<Bool>,
        isModalPresented: Bool,
        isInputFocused: FocusState<Bool>.Binding,
        onKeyboardPresented: @escaping () -> Void,
        @ViewBuilder content: () -> Content,
        @ViewBuilder composer: () -> Composer
    ) {
        _isKeyboardPresented = isKeyboardPresented
        self.isModalPresented = isModalPresented
        self.isInputFocused = isInputFocused
        self.onKeyboardPresented = onKeyboardPresented
        self.content = content()
        self.composer = composer()
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle()
                    .fill(.primaryBackground)
                    .ignoresSafeArea(.container)

                content
            }
            .safeAreaBar(
                edge: .bottom,
                spacing: TaskWorkspaceLayout.composerSpacing(isKeyboardPresented: isKeyboardPresented)
            ) {
                composer
                    .frame(
                        width: TaskWorkspaceLayout.composerWidth(
                            containerWidth: proxy.size.width,
                            isKeyboardPresented: isKeyboardPresented
                        ),
                        alignment: .leading
                    )
                    .padding(
                        .bottom,
                        TaskWorkspaceLayout.composerBottomPadding(
                            isKeyboardPresented: isKeyboardPresented,
                            safeAreaBottom: proxy.safeAreaInsets.bottom
                        )
                    )
            }
        }
        .background { NavigationKeyboardDismissObserver(isInputFocused: isInputFocused) }
        .ignoresSafeArea(.keyboard, edges: isModalPresented ? .bottom : [])
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            let nextState = TaskWorkspaceKeyboardPolicy.resolvedPresentationState(
                currentState: isKeyboardPresented,
                keyboardWillBePresented: true,
                isModalPresented: isModalPresented
            )
            guard nextState != isKeyboardPresented else { return }
            isKeyboardPresented = nextState
            onKeyboardPresented()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardPresented = TaskWorkspaceKeyboardPolicy.resolvedPresentationState(
                currentState: isKeyboardPresented,
                keyboardWillBePresented: false,
                isModalPresented: isModalPresented
            )
        }
    }
}
