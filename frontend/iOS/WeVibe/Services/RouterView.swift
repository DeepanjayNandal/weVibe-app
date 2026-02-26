import Foundation
import SwiftUI

struct RouterView: View {

    @State private var router = Router()

    var body: some View {
        NavigationStack(path: $router.path) {
            SplashScreen()
                .navigationDestination(for: Route.self) {route in
                    switch route {
                    case .login:
                        LoginScreen()
                    case .loginViaApple:
                        LoginScreen()
                    case .register:
                        RegisterScreen()
                    case .loginViaGoogle:
                        LoginScreen()
                    case .confirm:
                        ConfirmScreen()
                    case .thankAndBegin:
                        ThankAndBegin()
                    case .surveyStep1:
                        SurveyStep1()
                    case .surveyStep2:
                        SurveyStep2()
                    case .surveyStep3:
                        SurveyStep3()
                    case .surveyStep4:
                        SurveyStep4()
                    case .surveyStep5:
                        SurveyStep5()
                    case .home:
                        HomeScreen()
                    }
                }
        }
        .environment(router)
    }
}
