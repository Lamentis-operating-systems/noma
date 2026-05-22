import Foundation
import Supabase

@MainActor
protocol AuthClient {
    func currentSessionSnapshot() async -> AuthSessionSnapshot
    func authStateSnapshots() -> AsyncStream<AuthSessionSnapshot>
    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSessionSnapshot
    func signOut() async throws
    func deleteAccount() async throws
}

enum AccountDeletionError: LocalizedError {
    case missingSession
    case failed(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingSession:
            "No active session was found."
        case let .failed(statusCode, message):
            "Account deletion failed (\(statusCode)): \(message)"
        }
    }
}

struct SupabaseAuthClient: AuthClient {
    let client: SupabaseClient
    let configuration: SupabaseConfiguration

    func currentSessionSnapshot() async -> AuthSessionSnapshot {
        AuthSessionSnapshot(session: client.auth.currentSession)
    }

    func authStateSnapshots() -> AsyncStream<AuthSessionSnapshot> {
        AsyncStream { continuation in
            Task {
                for await (event, session) in client.auth.authStateChanges {
                    continuation.yield(AuthSessionSnapshot(event: event, session: session))
                }
                continuation.finish()
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

        var request = URLRequest(
            url: SupabaseClientProvider.edgeFunctionURL(
                named: "delete-account",
                configuration: configuration
            )
        )
        request.httpMethod = "POST"
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AccountDeletionError.failed(statusCode: -1, message: "Invalid response")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw AccountDeletionError.failed(statusCode: httpResponse.statusCode, message: message)
        }

        try? await client.auth.signOut()
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

    func signOut() async throws {}

    func deleteAccount() async throws {
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
