import SwiftUI
import UIKit

enum HapticFeedbackClass: Equatable {
    case createTaskSubmit
    case taskSwipeDeleteThreshold
}

struct HapticFeedbackService {
    private let playHandler: (HapticFeedbackClass) -> Void

    init(_ playHandler: @escaping (HapticFeedbackClass) -> Void) {
        self.playHandler = playHandler
    }

    func play(_ feedback: HapticFeedbackClass) {
        playHandler(feedback)
    }

    static let live = HapticFeedbackService { feedback in
        switch feedback {
        case .createTaskSubmit, .taskSwipeDeleteThreshold:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }

    static let noop = HapticFeedbackService { _ in }
}

private struct HapticFeedbackServiceKey: EnvironmentKey {
    static let defaultValue = HapticFeedbackService.live
}

extension EnvironmentValues {
    var hapticFeedback: HapticFeedbackService {
        get { self[HapticFeedbackServiceKey.self] }
        set { self[HapticFeedbackServiceKey.self] = newValue }
    }
}
