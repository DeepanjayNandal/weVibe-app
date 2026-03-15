import SwiftUI
import Observation

enum SpeedDatingRoute: Hashable {
    case rules
    case tests
    case joinQueue
//    case findingMatch
//    case matchResult
}

@Observable
final class SpeedDatingRouter {
    var path = NavigationPath()

    func navigate(to route: SpeedDatingRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}

