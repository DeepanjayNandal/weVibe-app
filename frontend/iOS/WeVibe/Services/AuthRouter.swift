import SwiftUI
import Observation

enum AuthRoute: Hashable {
    case login
    case register
    case forgotPassword
}

@Observable
final class AuthRouter {
    var path = NavigationPath()

    func navigate(to route: AuthRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeLast(path.count)
    }
}
