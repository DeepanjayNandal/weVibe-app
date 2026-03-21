import SwiftUI
import Observation

enum ChatRoute: Hashable {
    case activeChat(matchId: String)
}

@Observable
final class ChatRouter {
    var path = NavigationPath()

    func navigate(to route: ChatRoute) {
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
