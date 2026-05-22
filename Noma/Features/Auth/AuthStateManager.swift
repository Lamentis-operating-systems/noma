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
    let authClient: any AuthClient
    let appleSignInProvider: any AppleSignInProviding
    var authObserverTask: Task<Void, Never>?
    var hasStarted = false

    var phase: AuthRootPhase = .loading
    var storageUserID: String?
    var errorMessage: String?
    var isSigningIn = false
    var isDeletingAccount = false

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
}
