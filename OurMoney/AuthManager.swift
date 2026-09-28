import Foundation
import Combine
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import UIKit

@MainActor
final class AuthManager: ObservableObject {
    enum State { case loading; case idle; case requiresName(uid: String); case requiresPairing(user: User, household: Household?, error: String?); case authenticated(user: User, household: Household, partner: User?); case error(String) }
    @Published private(set) var state: State = .loading
    private let service: FirestoreService
    private var userCancellable: AnyCancellable?
    private var householdCancellable: AnyCancellable?
    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        // Firebase must be configured before any Firestore reference is created;
        // Firestore.firestore() throws otherwise. Swift does not allow instance
        // method calls before stored properties are initialized, so configuration
        // runs as a static call first, then service creation.
        Self.configureFirebaseIfNeeded()
        self.service = FirestoreService()
        configureGoogle()
        attachAuthListener()
        if FirebaseApp.app() == nil {
            state = .error("Firebase iOS configuration is missing. Register com.ourmoney.app in Firebase and add GoogleService-Info.plist.")
        }
    }
    deinit { if let authHandle { Auth.auth().removeStateDidChangeListener(authHandle) } }

    private static func configureFirebaseIfNeeded() {
        guard FirebaseApp.app() == nil,
              Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return }
        FirebaseApp.configure()
    }

    private func configureGoogle() {
        if let clientID = FirebaseApp.app()?.options.clientID { GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID) }
    }
    private func attachAuthListener() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in Task { @MainActor in self?.handleAuthUser(user) } }
    }
    private func handleAuthUser(_ firebaseUser: FirebaseAuth.User?) {
        userCancellable?.cancel(); userCancellable = nil; householdCancellable?.cancel(); householdCancellable = nil
        guard let firebaseUser else { state = .idle; return }; state = .loading
        userCancellable = service.observeUser(uid: firebaseUser.uid) { [weak self] result in Task { @MainActor in guard let self else { return }; switch result { case .failure(let e): self.state = .error(e.localizedDescription); case .success(nil): self.state = .requiresName(uid: firebaseUser.uid); case .success(.some(let user)): self.routeUser(user) } } }
    }
    private func routeUser(_ user: User) {
        guard let householdId = user.householdId, !householdId.isEmpty else { state = .requiresPairing(user: user, household: nil, error: nil); return }
        householdCancellable = service.observeHousehold(id: householdId) { [weak self] result in Task { @MainActor in guard let self else { return }; switch result { case .failure(let e): self.state = .error(e.localizedDescription); case .success(nil): var updated = user; updated.householdId = nil; updated.connectedAt = nil; try? await self.service.setUser(updated); self.state = .requiresPairing(user: updated, household: nil, error: nil); case .success(let household): guard let household else { return }; if !household.members.contains(user.id) { var updated = user; updated.householdId = nil; updated.connectedAt = nil; try? await self.service.setUser(updated); self.state = .requiresPairing(user: updated, household: nil, error: nil) } else if household.members.count < 2 { self.state = .requiresPairing(user: user, household: household, error: nil) } else { var partner: User?; if let other = household.members.first(where: { $0 != user.id }) { partner = try? await self.service.getUser(uid: other) }; self.state = .authenticated(user: user, household: household, partner: partner) } } } }
    }

    func signInWithGoogle() async {
        state = .loading
        guard let root = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow })?.rootViewController }).first else { state = .error("Could not open Google sign-in."); return }
        do { let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: root); guard let idToken = result.user.idToken?.tokenString else { throw NSError(domain: "OurMoneyAuth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Google ID token missing"]) }; let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString); _ = try await Auth.auth().signIn(with: credential) } catch { state = .error(error.localizedDescription) }
    }
    func saveName(_ name: String, uid: String) async { let clean = name.trimmingCharacters(in: .whitespacesAndNewlines); guard !clean.isEmpty, let fb = Auth.auth().currentUser else { return }; do { try await service.setUser(User(id: uid, name: clean, email: fb.email ?? "")) } catch { state = .error(error.localizedDescription) } }
    func createHousehold(user: User) async { state = .loading; do { let code = String(Int.random(in: 100000...999999)); let household = Household(id: UUID().uuidString, code: code, members: [user.id]); try await service.createHousehold(household); var updated = user; updated.householdId = household.id; updated.connectedAt = nowMillis(); try await service.setUser(updated) } catch { state = .requiresPairing(user: user, household: nil, error: "Unable to connect. Check your internet connection and try again.") } }
    func joinHousehold(user: User, code rawCode: String) async { state = .loading; let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines); do { let qs = try await Firestore.firestore().collection("households").whereField("code", isEqualTo: code).getDocuments(); guard let doc = qs.documents.first, var household = try? FirestoreCodec.decode(Household.self, from: FirestoreCodec.dataForDocument(doc)) else { state = .requiresPairing(user: user, household: nil, error: "Invalid connection code."); return }; if household.members.count >= 2 && !household.members.contains(user.id) { state = .requiresPairing(user: user, household: nil, error: "This connection already has two members."); return }; household.members = Array(Set(household.members + [user.id])); try await service.updateHouseholdMembers(id: household.id, members: household.members); var updated = user; updated.householdId = household.id; updated.connectedAt = nowMillis(); try await service.setUser(updated) } catch { state = .requiresPairing(user: user, household: nil, error: "Unable to connect. Check your internet connection and try again.") } }
    func cancelPairing(user: User) async { state = .loading; do { let oldID = user.householdId; var updated = user; updated.householdId = nil; updated.connectedAt = nil; try await service.setUser(updated); if let oldID { try? await service.deleteHousehold(id: oldID) } } catch { state = .requiresPairing(user: user, household: nil, error: "Failed to cancel connection.") } }
    func signOut() { try? Auth.auth().signOut(); GIDSignIn.sharedInstance.signOut(); userCancellable?.cancel(); householdCancellable?.cancel(); state = .idle }
}
