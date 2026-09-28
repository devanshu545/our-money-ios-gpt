import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct OurMoneyApp: App {
    @StateObject private var auth = AuthManager()
    var body: some Scene {
        WindowGroup {
            RootView(auth: auth)
                .preferredColorScheme(.dark)
                .tint(AppTheme.primary)
                .onOpenURL { url in GIDSignIn.sharedInstance.handle(url) }
        }
    }
}

struct RootView: View {
    @ObservedObject var auth: AuthManager
    @State private var showSplash = true
    var body: some View {
        Group {
            if showSplash { SplashView() }
            else {
                switch auth.state {
                case .loading: SplashView()
                case .idle: GoogleSignInView(auth: auth)
                case .requiresName(let uid): NameInputView(auth: auth, uid: uid)
                case .requiresPairing(let user, let household, let error): PairingView(auth: auth, user: user, household: household, error: error)
                case .authenticated(let user, let household, let partner): MainRootView(user: user, household: household, partner: partner)
                case .error(let message): ErrorView(message: message)
                }
            }
        }
        .task { try? await Task.sleep(for: .seconds(1.5)); withAnimation { showSplash = false } }
    }
}
