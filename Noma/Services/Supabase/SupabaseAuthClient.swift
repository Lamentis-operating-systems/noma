import Foundation
import Supabase

@MainActor
protocol AuthClient {
    func currentSessionSnapshot() async -> AuthSessionSnapshot
    func authStateSnapshots() -> AsyncStream<AuthSessionSnapshot>
    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSessionSnapshot
    func signOut() async throws
    func deleteAccount() async throws
    func clearLocalSessionForPendingAccountDeletion() async throws
}

struct SupabaseAuthClient: AuthClient {
    let client: SupabaseClient
    let configuration: SupabaseConfiguration
    private let accountDeletionService: SupabaseAccountDeletionService

    init(
        client: SupabaseClient,
        configuration: SupabaseConfiguration,
        accountDeletionTransport: AccountDeletionTransport? = nil,
        localSessionCleaner: AccountDeletionSessionCleaner? = nil,
        accountDeletionCleanupJournal: AccountDeletionCleanupJournal? = nil
    ) {
        self.client = client
        self.configuration = configuration
        self.accountDeletionService = SupabaseAccountDeletionService(
            configuration: configuration,
            transport: accountDeletionTransport ?? .live,
            sessionCleaner: localSessionCleaner ?? .live(client: client),
            cleanupJournal: accountDeletionCleanupJournal ?? .standard
        )
    }

    func currentSessionSnapshot() async -> AuthSessionSnapshot {
        AuthSessionSnapshot(session: client.auth.currentSession)
    }

    func authStateSnapshots() -> AsyncStream<AuthSessionSnapshot> {
        AsyncStream { continuation in
            let producerTask = Task { @MainActor [client] in
                defer { continuation.finish() }
                for await (event, session) in client.auth.authStateChanges {
                    guard !Task.isCancelled else { return }
                    continuation.yield(AuthSessionSnapshot(event: event, session: session))
                }
            }
            continuation.onTermination = { @Sendable _ in
                producerTask.cancel()
            }
        }
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSessionSnapshot {
        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        return AuthSessionSnapshot(session: session)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func deleteAccount() async throws {
        guard let session = client.auth.currentSession else {
            throw AccountDeletionError.missingSession
        }
        try await accountDeletionService.deleteAccount(
            accessToken: session.accessToken,
            userID: session.user.id.uuidString
        )
    }

    func clearLocalSessionForPendingAccountDeletion() async throws {
        try await accountDeletionService.clearLocalSessionForPendingAccountDeletion()
    }
}

struct UnconfiguredAuthClient: AuthClient {
    let error: Error

    func currentSessionSnapshot() async -> AuthSessionSnapshot {
        AuthSessionSnapshot(isSignedIn: false)
    }

    func authStateSnapshots() -> AsyncStream<AuthSessionSnapshot> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSessionSnapshot {
        throw error
    }

    func signOut() async throws {
        throw error
    }

    func deleteAccount() async throws {
        throw error
    }

    func clearLocalSessionForPendingAccountDeletion() async throws {
        throw error
    }
}

private extension AuthSessionSnapshot {
    init(session: Session?) {
        guard let session else {
            self.init(state: .missing)
            return
        }

        self.init(
            state: session.isExpired ? .refreshingExpiredLocalSession : .authenticated,
            userID: session.user.id.uuidString
        )
    }

    init(event: AuthChangeEvent, session: Session?) {
        switch event {
        case .initialSession:
            self.init(session: session)
        case .signedIn, .tokenRefreshed, .userUpdated, .mfaChallengeVerified, .passwordRecovery:
            self.init(session: session)
        case .signedOut, .userDeleted:
            self.init(state: .missing)
        }
    }
}
