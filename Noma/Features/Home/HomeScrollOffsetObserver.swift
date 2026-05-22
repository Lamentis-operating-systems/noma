import SwiftUI
import UIKit

struct HomeScrollOffsetObserver: UIViewRepresentable {
    let onOffsetChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onOffsetChange: onOffsetChange)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        context.coordinator.attachWhenReady(from: view)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.onOffsetChange = onOffsetChange
        context.coordinator.attachWhenReady(from: view)
    }

    final class Coordinator {
        var onOffsetChange: (CGFloat) -> Void
        private weak var observedScrollView: UIScrollView?
        private var observation: NSKeyValueObservation?
        private var attachAttempts = 0

        init(onOffsetChange: @escaping (CGFloat) -> Void) {
            self.onOffsetChange = onOffsetChange
        }

        func attachWhenReady(from view: UIView) {
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view else { return }
                self.attach(to: view.enclosingScrollView, from: view)
            }
        }

        private func attach(to scrollView: UIScrollView?, from view: UIView) {
            guard let scrollView else {
                retryAttach(from: view)
                return
            }
            guard observedScrollView !== scrollView else { return }

            observation = nil
            observedScrollView = scrollView
            attachAttempts = 0
            onOffsetChange(normalizedScrollOffset(for: scrollView))
            observation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
                self?.onOffsetChange(self?.normalizedScrollOffset(for: scrollView) ?? scrollView.contentOffset.y)
            }
        }

        private func retryAttach(from view: UIView) {
            guard attachAttempts < HomeScrollOffsetObserverLayout.maxAttachAttempts else { return }
            attachAttempts += 1

            DispatchQueue.main.asyncAfter(deadline: .now() + HomeScrollOffsetObserverLayout.retryDelay) { [weak self, weak view] in
                guard let self, let view else { return }
                self.attach(to: view.enclosingScrollView, from: view)
            }
        }

        private func normalizedScrollOffset(for scrollView: UIScrollView) -> CGFloat {
            scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        }
    }
}

enum HomeScrollOffsetObserverLayout {
    static let maxAttachAttempts = 8
    static let retryDelay = DispatchTimeInterval.milliseconds(20)
}

private extension UIView {
    var enclosingScrollView: UIScrollView? {
        if let scrollView = superview as? UIScrollView { return scrollView }
        return superview?.enclosingScrollView
    }
}
