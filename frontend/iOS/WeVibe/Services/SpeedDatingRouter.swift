import SwiftUI
import Observation

enum SpeedDatingRoute: Hashable {
//    case main
    case rules
    case q1
//    case q2
//    case q3
//    case q4
//    case q5
//    case q6
}

@Observable
final class SpeedDatingRouter {
    var path = NavigationPath()

    func navigate(to route: SpeedDatingRoute) {
        path.append(route)
    }

    // Used for "back" buttons on survey steps.
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}

