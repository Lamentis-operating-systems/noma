@testable import Noma
import XCTest

final class AuthStateManagerTests: XCTestCase {
    @MainActor
    func testAuthSessionSnapshotMapsToRootPhases() {
        XCTAssertEqual(AuthSessionSnapshot(isSignedIn: false).rootPhase, .signedOut)
        XCTAssertEqual(AuthSessionSnapshot(isSignedIn: true).rootPhase, .signedIn)
        XCTAssertEqual(AuthSessionSnapshot(state: .refreshingExpiredLocalSession).rootPhase, .signedIn)
        XCTAssertEqual(AuthSessionSnapshot(isSignedIn: true, userID: "user-1").storageUserID, "user-1")
        XCTAssertNil(AuthSessionSnapshot(isSignedIn: false, userID: "user-1").storageUserID)
        XCTAssertEqual(
            AuthSessionSnapshot(state: .refreshingExpiredLocalSession, userID: "user-1").storageUserID,
            "user-1"
        )
    }

    @MainActor
    func testAuthStateManagerKeepsExpiredStoredSessionSignedInAtStartup() async {
        let authState = AuthStateManager(
            authClient: StartupAuthClient(
                initialSnapshot: AuthSessionSnapshot(state: .refreshingExpiredLocalSession, userID: "stored-user"),
                streamSnapshots: []
            ),
            appleSignInProvider: StubAppleSignInProvider()
        )
        authState.phase = .signedOut

        authState.start()
        await allowAuthObserverToRun()

        XCTAssertEqual(authState.phase, .signedIn)
        XCTAssertEqual(authState.storageUserID, "stored-user")
    }

    @MainActor
    func testAuthStateManagerAppliesRefreshAfterExpiredStoredSession() async {
        let authState = AuthStateManager(
            authClient: StartupAuthClient(
                initialSnapshot: AuthSessionSnapshot(state: .refreshingExpiredLocalSession),
                streamSnapshots: [AuthSessionSnapshot(state: .authenticated)]
            ),
            appleSignInProvider: StubAppleSignInProvider()
        )

        authState.start()
        await allowAuthObserverToRun()

        XCTAssertEqual(authState.phase, .signedIn)
    }

    @MainActor
    func testSignInWithAppleAppliesReturnedSessionSnapshotImmediately() async {
        let authState = AuthStateManager(
            authClient: SignInSucceedsAuthClient(),
            appleSignInProvider: StubAppleSignInProvider()
        )
        authState.phase = .signedOut

        await authState.signInWithAppleFlow()

        XCTAssertEqual(authState.phase, .signedIn)
        XCTAssertEqual(authState.storageUserID, "signed-in-user")
        XCTAssertFalse(authState.isSigningIn)
    }

    @MainActor
    func testSignInWithAppleReportsFailureAndClearsLoading() async {
        let authState = AuthStateManager(
            authClient: SignInFailsAuthClient(),
            appleSignInProvider: StubAppleSignInProvider()
        )
        authState.phase = .signedOut

        await authState.signInWithAppleFlow()

        XCTAssertEqual(authState.phase, .signedOut)
        XCTAssertEqual(authState.errorMessage, TestAuthError.signInRejected.localizedDescription)
        XCTAssertFalse(authState.isSigningIn)
    }

    @MainActor
    func testSignOutAppliesSignedOutSnapshot() async {
        let authState = AuthStateManager(
            authClient: SignOutSucceedsAuthClient(),
            appleSignInProvider: StubAppleSignInProvider()
        )
        authState.phase = .signedIn

        await authState.signOutFlow()

        XCTAssertEqual(authState.phase, .signedOut)
        XCTAssertNil(authState.storageUserID)
        XCTAssertNil(authState.errorMessage)
    }
}

private func allowAuthObserverToRun() async {
    await Task.yield()
    try? await Task.sleep(nanoseconds: 1_000_000)
}

private struct StubAppleSignInProvider: AppleSignInProviding {
    func requestCredential() async throws -> AppleSignInCredential {
        AppleSignInCredential(
            identityToken: "identity-token",
            nonce: "nonce",
            fullName: nil
        )
    }
}

private struct StartupAuthClient: AuthClient {
    let initialSnapshot: AuthSessionSnapshot
    let streamSnapshots: [AuthSessionSnapshot]

    func currentSessionSnapshot() async -> AuthSessionSnapshot {
        initialSnapshot
    }

    func authStateSnapshots() -> AsyncStream<AuthSessionSnapshot> {
        AsyncStream { continuation in
            for snapshot in streamSnapshots {
                continuation.yield(snapshot)
            }
            continuation.finish()
        }
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSessionSnapshot {
        AuthSessionSnapshot(state: .authenticated)
    }

    func signOut() async throws {}
}

private struct SignInSucceedsAuthClient: AuthClient {
    func currentSessionSnapshot() async -> AuthSessionSnapshot {
        AuthSessionSnapshot(isSignedIn: false)
    }

    func authStateSnapshots() -> AsyncStream<AuthSessionSnapshot> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSessionSnapshot {
        AuthSessionSnapshot(isSignedIn: true, userID: "signed-in-user")
    }

    func signOut() async throws {}
}

private struct SignInFailsAuthClient: AuthClient {
    func currentSessionSnapshot() async -> AuthSessionSnapshot {
        AuthSessionSnapshot(isSignedIn: false)
    }

    func authStateSnapshots() -> AsyncStream<AuthSessionSnapshot> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSessionSnapshot {
        throw TestAuthError.signInRejected
    }

    func signOut() async throws {}
}

private struct SignOutSucceedsAuthClient: AuthClient {
    func currentSessionSnapshot() async -> AuthSessionSnapshot {
        AuthSessionSnapshot(isSignedIn: true)
    }

    func authStateSnapshots() -> AsyncStream<AuthSessionSnapshot> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSessionSnapshot {
        AuthSessionSnapshot(isSignedIn: true)
    }

    func signOut() async throws {}
}

private enum TestAuthError: LocalizedError {
    case signInRejected

    var errorDescription: String? {
        "Sign in rejected"
    }
}
