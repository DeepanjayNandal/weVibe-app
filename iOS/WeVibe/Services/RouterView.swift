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
                    }
                }
        }
        .environment(router)
    }
}
