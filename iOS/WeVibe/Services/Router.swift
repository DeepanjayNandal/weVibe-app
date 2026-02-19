import Foundation
import SwiftUI
import Observation


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
    func navigateSurveyStep1() {
        path.append(Route.surveyStep1)
    }
    func navigateSurveyStep2() {
        path.append(Route.surveyStep2)
    }
    func navigateSurveyStep3() {
        path.append(Route.surveyStep3)
    }
    func navigateSurveyStep4() {
        path.append(Route.surveyStep4)
    }
    func navigateSurveyStep5() {
        path.append(Route.surveyStep5)
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
    case surveyStep1
    case surveyStep2
    case surveyStep3
    case surveyStep4
    case surveyStep5
}
