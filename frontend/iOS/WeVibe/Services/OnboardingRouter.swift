import SwiftUI
import Observation

enum OnboardingRoute: Hashable {
    case step1
    case step2
    case step3
    case step4
    case step5
}

@Observable
final class OnboardingRouter {
    var path = NavigationPath()

    func navigate(to route: OnboardingRoute) {
        path.append(route)
    }

    // Used for "back" buttons on survey steps.
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}
