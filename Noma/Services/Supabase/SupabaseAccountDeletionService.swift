import Foundation
import Supabase

enum AccountDeletionFailureStage: String, Decodable, Equatable {
    case configuration
    case authentication
    case refreshSessionRevocation = "refresh_session_revocation"
    case userDeletion = "user_deletion"
}

enum AccountDeletionError: LocalizedError, Equatable {
    case missingSession
    case remoteOutcomeUnknown(reason: String, localSessionCleanupFailure: String?)
    case serverFailure(
        stage: AccountDeletionFailureStage?,
        statusCode: Int,
        message: String,
        requestID: String?
    )
    case localCleanupFailed(message: String)
    case cleanupJournalFailure(
        remoteOutcome: AccountDeletionRemoteOutcome,
        error: AccountDeletionCleanupJournalError
    )

    var remoteOutcome: AccountDeletionRemoteOutcome {
        switch self {
        case .missingSession, .serverFailure:
            .notDeleted
        case .localCleanupFailed:
            .deleted
        case .remoteOutcomeUnknown:
            .unknown
        case let .cleanupJournalFailure(remoteOutcome, _):
            remoteOutcome
        }
    }

    var requiresPrivacyCleanup: Bool {
        remoteOutcome != .notDeleted
    }

    var localSessionCleanupFailed: Bool {
        switch self {
        case .localCleanupFailed:
            true
        case let .remoteOutcomeUnknown(_, localSessionCleanupFailure):
            localSessionCleanupFailure != nil
        case .missingSession, .serverFailure, .cleanupJournalFailure:
            false
        }
    }

    var requiresAuthenticationBlock: Bool {
        if localSessionCleanupFailed { return true }
        guard case let .cleanupJournalFailure(remoteOutcome, error) = self else {
            return false
        }
        return remoteOutcome != .notDeleted || error.indicatesStoredCleanupObligation
    }

    var errorDescription: String? {
        switch self {
        case .missingSession:
            "No active session was found."
        case let .remoteOutcomeUnknown(reason, localSessionCleanupFailure):
            if let localSessionCleanupFailure {
                "The server outcome could not be confirmed. The app attempted to clear the local session, but that cleanup failed: \(localSessionCleanupFailure). Local account cleanup remains pending, and the account may still exist on the server. [\(reason)]"
            } else {
                "The server outcome could not be confirmed. For privacy, the app signed out and attempted to remove local account data. The account may still exist on the server. [\(reason)]"
            }
        case let .serverFailure(_, statusCode, message, requestID):
            if let requestID {
                "Account deletion failed (\(statusCode)): \(message) [\(requestID)]"
            } else {
                "Account deletion failed (\(statusCode)): \(message)"
            }
        case let .localCleanupFailed(message):
            "The account was deleted, but this device could not finish signing out: \(message)"
        case let .cleanupJournalFailure(remoteOutcome, error):
            switch remoteOutcome {
            case .notDeleted:
                "Account deletion was not started because cleanup recovery could not be secured: \(error.localizedDescription)"
            case .deleted:
                "The account was deleted, but cleanup recovery could not be committed: \(error.localizedDescription)"
            case .unknown:
                "The server outcome could not be confirmed, and cleanup recovery could not be committed: \(error.localizedDescription)"
            }
        }
    }
}

nonisolated enum AccountDeletionRemoteOutcome: Equatable {
    case notDeleted
    case deleted
    case unknown
}

@MainActor
struct AccountDeletionTransport {
    let send: (URLRequest) async throws -> (Data, URLResponse)

    static let live = AccountDeletionTransport { request in
        try await URLSession.shared.data(for: request)
    }
}

@MainActor
struct AccountDeletionSessionCleaner {
    let clear: () async throws -> Void

    static func live(client: SupabaseClient) -> AccountDeletionSessionCleaner {
        AccountDeletionSessionCleaner {
            try await client.auth.signOut(scope: .local)
        }
    }
}

@MainActor
struct SupabaseAccountDeletionService {
    let configuration: SupabaseConfiguration
    let transport: AccountDeletionTransport
    let sessionCleaner: AccountDeletionSessionCleaner
    let cleanupJournal: AccountDeletionCleanupJournal

    func deleteAccount(accessToken: String, userID: String) async throws {
        // Privacy-first crash policy: once the request can leave this process,
        // a kill may make its remote outcome unknowable. Persist that intent
        // before the first suspension; only a definite pre-delete response may
        // roll it back. This can remove local-only data after an interrupted
        // request that ultimately did not delete remotely, by design. The
        // storage commit is the in-process boundary; real kill/power-loss proof
        // remains an external integration concern.
        if case let .failure(error) = cleanupJournal.armCleanupRequest(forUserID: userID) {
            throw AccountDeletionError.cleanupJournalFailure(
                remoteOutcome: .notDeleted,
                error: error
            )
        }

        let remoteResult: RemoteAccountDeletionResult
        do {
            remoteResult = try await remoteDeletionResult(accessToken: accessToken)
        } catch let error as AccountDeletionError where error.remoteOutcome == .notDeleted {
            let disarmResult = cleanupJournal
                .disarmCleanupAfterDefiniteRemoteFailure(forUserID: userID)
            if case let .failure(journalError) = disarmResult {
                throw AccountDeletionError.cleanupJournalFailure(
                    remoteOutcome: .notDeleted,
                    error: journalError
                )
            }
            throw error
        }

        var cleanupJournalFailure: AccountDeletionCleanupJournalError?
        if case let .failure(error) = cleanupJournal.recordRemoteOutcome(
            remoteResult.cleanupRemoteState,
            forUserID: userID
        ) {
            cleanupJournalFailure = error
        }

        let localSessionCleanupFailure: String?
        do {
            try await sessionCleaner.clear()
            if case let .failure(error) = cleanupJournal.markLocalSessionCleanupCompleted(
                forUserID: userID
            ) {
                cleanupJournalFailure = cleanupJournalFailure ?? error
            }
            localSessionCleanupFailure = nil
        } catch {
            localSessionCleanupFailure = error.localizedDescription
        }

        switch remoteResult {
        case .deleted:
            if let localSessionCleanupFailure {
                throw AccountDeletionError.localCleanupFailed(message: localSessionCleanupFailure)
            }
            if let cleanupJournalFailure {
                throw AccountDeletionError.cleanupJournalFailure(
                    remoteOutcome: .deleted,
                    error: cleanupJournalFailure
                )
            }
        case let .unknown(reason):
            if localSessionCleanupFailure == nil, let cleanupJournalFailure {
                throw AccountDeletionError.cleanupJournalFailure(
                    remoteOutcome: .unknown,
                    error: cleanupJournalFailure
                )
            }
            throw AccountDeletionError.remoteOutcomeUnknown(
                reason: reason,
                localSessionCleanupFailure: localSessionCleanupFailure
            )
        }
    }

    func clearLocalSessionForPendingAccountDeletion() async throws {
        try await sessionCleaner.clear()
    }

    private func remoteDeletionResult(accessToken: String) async throws -> RemoteAccountDeletionResult {
        var request = URLRequest(
            url: SupabaseClientProvider.edgeFunctionURL(
                named: "delete-account",
                configuration: configuration
            )
        )
        request.httpMethod = "POST"
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch {
            return .unknown(
                reason: "Transport failed: \(error.localizedDescription)"
            )
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            return .unknown(reason: "The server returned a non-HTTP response")
        }

        let payload = try? JSONDecoder().decode(AccountDeletionResponse.self, from: data)

        if let payload, payload.deleted == false {
            if payload.stage == .userDeletion, httpResponse.statusCode == 502 {
                return .unknown(
                    reason: "The user-deletion request may have completed before its HTTP 502 response was lost"
                )
            }
            throw AccountDeletionError.serverFailure(
                stage: payload.stage,
                statusCode: httpResponse.statusCode,
                message: payload.message ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
                requestID: payload.requestID
            )
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let payload, Self.isPreDeletionStage(payload.stage) {
                throw AccountDeletionError.serverFailure(
                    stage: payload.stage,
                    statusCode: httpResponse.statusCode,
                    message: payload.message ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
                    requestID: payload.requestID
                )
            }

            if Self.isDefiniteGatewayRejection(httpResponse.statusCode) {
                throw AccountDeletionError.serverFailure(
                    stage: payload?.stage,
                    statusCode: httpResponse.statusCode,
                    message: payload?.message ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
                    requestID: payload?.requestID
                )
            }

            return .unknown(
                reason: "HTTP \(httpResponse.statusCode) did not confirm that the account was not deleted"
            )
        }

        guard payload?.deleted == true,
              payload?.refreshSessionsRevoked == true,
              payload?.accessTokensRemainValidUntilExpiry == true
        else {
            return .unknown(
                reason: "HTTP \(httpResponse.statusCode) did not include the complete deletion contract"
            )
        }

        return .deleted
    }

    private static func isDefiniteGatewayRejection(_ statusCode: Int) -> Bool {
        [401, 403, 404, 405].contains(statusCode)
    }

    private static func isPreDeletionStage(_ stage: AccountDeletionFailureStage?) -> Bool {
        switch stage {
        case .configuration, .authentication, .refreshSessionRevocation:
            true
        case .userDeletion, nil:
            false
        }
    }
}

private enum RemoteAccountDeletionResult {
    case deleted
    case unknown(reason: String)

    var cleanupRemoteState: AccountDeletionCleanupRemoteState {
        switch self {
        case .deleted:
            .deletionConfirmed
        case .unknown:
            .outcomeUnknown
        }
    }
}

private struct AccountDeletionResponse: Decodable {
    let deleted: Bool?
    let refreshSessionsRevoked: Bool?
    let accessTokensRemainValidUntilExpiry: Bool?
    let stage: AccountDeletionFailureStage?
    let message: String?
    let requestID: String?

    enum CodingKeys: String, CodingKey {
        case deleted
        case refreshSessionsRevoked = "refresh_sessions_revoked"
        case accessTokensRemainValidUntilExpiry = "access_tokens_remain_valid_until_expiry"
        case stage
        case message
        case requestID = "request_id"
    }
}
