import Foundation
import Observation

enum AuthRootPhase: Equatable { case loading, signedOut, signedIn }

enum AuthSessionState: Equatable {
    case missing
    case authenticated
    case refreshingExpiredLocalSession
}

struct AuthSessionSnapshot: Equatable {
    let state: AuthSessionState
    let userID: String?

    init(state: AuthSessionState, userID: String? = nil) {
        self.state = state
        self.userID = userID
    }

    init(isSignedIn: Bool, userID: String? = nil) {
        self.init(state: isSignedIn ? .authenticated : .missing, userID: userID)
    }

    var isSignedIn: Bool { state != .missing }
    var storageUserID: String? { isSignedIn ? userID : nil }

    var rootPhase: AuthRootPhase {
        switch state {
        case .missing:
            .signedOut
        case .authenticated:
            .signedIn
        case .refreshingExpiredLocalSession:
            .signedIn
        }
    }
}

struct AppleSignInCredential: Equatable {
    let identityToken: String
    let nonce: String
    let fullName: PersonNameComponents?
}

@MainActor
protocol AppleSignInProviding { func requestCredential() async throws -> AppleSignInCredential }

@MainActor
@Observable
final class AuthStateManager {
    private let authClient: any AuthClient
    private let appleSignInProvider: any AppleSignInProviding
    private var authObserverTask: Task<Void, Never>?
    private var hasStarted = false

    var phase: AuthRootPhase = .loading
    var storageUserID: String?
    var errorMessage: String?
    var isSigningIn = false

    convenience init() {
        self.init(authClient: SupabaseClientProvider.makeAuthClient())
    }

    convenience init(authClient: any AuthClient) {
        self.init(authClient: authClient, appleSignInProvider: AppleSignInAuthenticator())
    }

    init(
        authClient: any AuthClient,
        appleSignInProvider: any AppleSignInProviding
    ) {
        self.authClient = authClient
        self.appleSignInProvider = appleSignInProvider
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        authObserverTask = Task { [authClient] in
            apply(await authClient.currentSessionSnapshot())

            for await snapshot in authClient.authStateSnapshots() {
                apply(snapshot)
            }
        }
    }

    func signInWithApple() {
        guard beginSignInWithApple() else { return }
        Task { await completeSignInWithAppleFlow() }
    }

    func signInWithAppleFlow() async {
        guard beginSignInWithApple() else { return }
        await completeSignInWithAppleFlow()
    }

    func signOut() { Task { await signOutFlow() } }

    func signOutFlow() async {
        errorMessage = nil
        do {
            try await authClient.signOut()
            apply(AuthSessionSnapshot(isSignedIn: false))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func beginSignInWithApple() -> Bool {
        guard !isSigningIn else { return false }
        errorMessage = nil
        isSigningIn = true
        return true
    }

    private func completeSignInWithAppleFlow() async {
        defer { isSigningIn = false }

        do {
            let credential = try await appleSignInProvider.requestCredential()
            let snapshot = try await authClient.signInWithApple(
                idToken: credential.identityToken,
                nonce: credential.nonce
            )
            apply(snapshot)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ snapshot: AuthSessionSnapshot) {
        phase = snapshot.rootPhase
        storageUserID = snapshot.storageUserID
    }
}
