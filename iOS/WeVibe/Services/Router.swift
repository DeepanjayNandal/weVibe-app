import Foundation
import Observation
import SwiftUI

@Observable
class Router {
    var path = NavigationPath()

    func navigateToLogin() {
        path.append(Route.login)
    }
    func navigateToRegister() {
        path.append(Route.register)
    }
    func navigateToConfirmScreen() {
        path.append(Route.confirm)
    }
    func navigateToBeginScreen() {
        path.append(Route.thankAndBegin)
    }
    func navigateToLoginViaGoole() {
        path.append(Route.loginViaGoogle)
    }
    func navigateToLoginViaApple() {
        path.append(Route.loginViaApple)
    }
    func popToRoot() {
        path.removeLast(path.count)
    }
}

enum Route: Hashable {
    case login
    case register
    case confirm
    case thankAndBegin
    case loginViaGoogle
    case loginViaApple
}
