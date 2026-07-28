@testable import Noma
import Foundation
import XCTest

@MainActor
final class SupabaseAccountDeletionTests: XCTestCase {
    private let configuration = SupabaseConfiguration(
        projectURL: URL(string: "https://project-ref.supabase.co")!,
        publishableKey: "publishable-key"
    )

    func testSuccessfulDeletionRequiresExplicitServerOutcomeBeforeLocalCleanup() async throws {
        let recorder = DeletionRecorder()
        let service = makeService(
            responseStatus: 200,
            responseBody: #"{"deleted":true,"refresh_sessions_revoked":true,"access_tokens_remain_valid_until_expiry":true,"request_id":"request-1"}"#,
            recorder: recorder
        )

        try await service.deleteAccount(accessToken: "access-token", userID: "user-1")

        XCTAssertEqual(recorder.cleanupCount, 1)
        XCTAssertEqual(
            recorder.journalEntryObservedAtTransport,
            AccountDeletionCleanupJournalEntry(userID: "user-1")
        )
        XCTAssertEqual(
            recorder.journalEntryObservedAtSessionCleanup,
            AccountDeletionCleanupJournalEntry(
                userID: "user-1",
                remoteState: .deletionConfirmed
            )
        )
        XCTAssertEqual(
            recorder.cleanupJournal.pendingCleanup,
            AccountDeletionCleanupJournalEntry(
                userID: "user-1",
                remoteState: .deletionConfirmed,
                requiresLocalSessionCleanup: false,
                requiresTaskDataCleanup: true
            )
        )
        XCTAssertEqual(recorder.request?.httpMethod, "POST")
        XCTAssertEqual(recorder.request?.value(forHTTPHeaderField: "apikey"), "publishable-key")
        XCTAssertEqual(
            recorder.request?.value(forHTTPHeaderField: "Authorization"),
            "Bearer access-token"
        )
        XCTAssertEqual(
            recorder.request?.url?.absoluteString,
            "https://project-ref.supabase.co/functions/v1/delete-account"
        )
    }

    func testRefreshSessionRevocationFailureDoesNotRunLocalCleanup() async {
        let recorder = DeletionRecorder()
        let service = makeService(
            responseStatus: 502,
            responseBody: #"{"code":"refresh_session_revocation_failed","message":"Refresh sessions could not be revoked","stage":"refresh_session_revocation","request_id":"request-2","refresh_sessions_revoked":false,"deleted":false,"access_tokens_remain_valid_until_expiry":true}"#,
            recorder: recorder
        )

        do {
            try await service.deleteAccount(accessToken: "access-token", userID: "user-1")
            XCTFail("Expected session revocation failure")
        } catch let error as AccountDeletionError {
            guard case let .serverFailure(stage, statusCode, _, requestID) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(stage, .refreshSessionRevocation)
            XCTAssertEqual(statusCode, 502)
            XCTAssertEqual(requestID, "request-2")
            XCTAssertEqual(error.remoteOutcome, .notDeleted)
            XCTAssertFalse(error.requiresPrivacyCleanup)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(recorder.cleanupCount, 0)
        XCTAssertNil(recorder.cleanupJournal.pendingCleanup)
    }

    func testLegacyPreDeletionFailuresWithoutDeletedFieldDoNotRunPrivacyCleanup() async {
        let failures: [(stage: AccountDeletionFailureStage, statusCode: Int)] = [
            (.configuration, 500),
            (.authentication, 502),
            (.refreshSessionRevocation, 502)
        ]

        for failure in failures {
            let recorder = DeletionRecorder()
            let service = makeService(
                responseStatus: failure.statusCode,
                responseBody: """
                {"message":"Pre-deletion failure","stage":"\(failure.stage.rawValue)","request_id":"legacy-request"}
                """,
                recorder: recorder
            )

            do {
                try await service.deleteAccount(accessToken: "access-token", userID: "user-1")
                XCTFail("Expected legacy \(failure.stage.rawValue) failure")
            } catch let error as AccountDeletionError {
                guard case let .serverFailure(stage, statusCode, _, requestID) = error else {
                    return XCTFail("Unexpected error: \(error)")
                }
                XCTAssertEqual(stage, failure.stage)
                XCTAssertEqual(statusCode, failure.statusCode)
                XCTAssertEqual(requestID, "legacy-request")
                XCTAssertEqual(error.remoteOutcome, .notDeleted)
                XCTAssertFalse(error.requiresPrivacyCleanup)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(recorder.cleanupCount, 0)
            XCTAssertNil(recorder.cleanupJournal.pendingCleanup)
        }
    }

    func testUserDeletionFailureDoesNotRunLocalCleanup() async {
        let recorder = DeletionRecorder()
        let service = makeService(
            responseStatus: 500,
            responseBody: #"{"code":"account_deletion_failed","message":"The account could not be deleted","stage":"user_deletion","request_id":"request-3","refresh_sessions_revoked":true,"deleted":false,"access_tokens_remain_valid_until_expiry":true}"#,
            recorder: recorder
        )

        do {
            try await service.deleteAccount(accessToken: "access-token", userID: "user-1")
            XCTFail("Expected account deletion failure")
        } catch let error as AccountDeletionError {
            guard case let .serverFailure(stage, statusCode, _, requestID) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(stage, .userDeletion)
            XCTAssertEqual(statusCode, 500)
            XCTAssertEqual(requestID, "request-3")
            XCTAssertEqual(error.remoteOutcome, .notDeleted)
            XCTAssertFalse(error.requiresPrivacyCleanup)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(recorder.cleanupCount, 0)
        XCTAssertNil(recorder.cleanupJournal.pendingCleanup)
    }

    func testLocalCleanupFailureReportsThatRemoteAccountWasDeleted() async {
        let recorder = DeletionRecorder()
        recorder.cleanupError = DeletionTestError.cleanupFailed
        let service = makeService(
            responseStatus: 200,
            responseBody: #"{"deleted":true,"refresh_sessions_revoked":true,"access_tokens_remain_valid_until_expiry":true,"request_id":"request-4"}"#,
            recorder: recorder
        )

        do {
            try await service.deleteAccount(accessToken: "access-token", userID: "user-1")
            XCTFail("Expected local cleanup failure")
        } catch let error as AccountDeletionError {
            guard case .localCleanupFailed = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(error.remoteOutcome, .deleted)
            XCTAssertTrue(error.requiresPrivacyCleanup)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(recorder.cleanupCount, 1)
        XCTAssertEqual(
            recorder.journalEntryObservedAtTransport,
            AccountDeletionCleanupJournalEntry(userID: "user-1")
        )
        XCTAssertEqual(
            recorder.journalEntryObservedAtSessionCleanup,
            AccountDeletionCleanupJournalEntry(
                userID: "user-1",
                remoteState: .deletionConfirmed
            )
        )
        XCTAssertEqual(
            recorder.cleanupJournal.pendingCleanup,
            AccountDeletionCleanupJournalEntry(
                userID: "user-1",
                remoteState: .deletionConfirmed
            )
        )
    }

    func testIncompleteSuccessContractIsUnknownAndRunsPrivacyCleanup() async {
        let recorder = DeletionRecorder()
        let service = makeService(
            responseStatus: 200,
            responseBody: #"{"deleted":true,"refresh_sessions_revoked":false,"access_tokens_remain_valid_until_expiry":true}"#,
            recorder: recorder
        )

        do {
            try await service.deleteAccount(accessToken: "access-token", userID: "user-1")
            XCTFail("Expected unknown remote outcome")
        } catch let error as AccountDeletionError {
            guard case .remoteOutcomeUnknown = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(error.remoteOutcome, .unknown)
            XCTAssertTrue(error.requiresPrivacyCleanup)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(recorder.cleanupCount, 1)
        XCTAssertEqual(
            recorder.journalEntryObservedAtTransport,
            AccountDeletionCleanupJournalEntry(userID: "user-1")
        )
        XCTAssertEqual(
            recorder.journalEntryObservedAtSessionCleanup,
            AccountDeletionCleanupJournalEntry(
                userID: "user-1",
                remoteState: .outcomeUnknown
            )
        )
        XCTAssertEqual(
            recorder.cleanupJournal.pendingCleanup,
            AccountDeletionCleanupJournalEntry(
                userID: "user-1",
                remoteState: .outcomeUnknown,
                requiresLocalSessionCleanup: false,
                requiresTaskDataCleanup: true
            )
        )
    }

    func testSuccessResponseMustDeclareAccessTokenExpiryBoundary() async {
        let recorder = DeletionRecorder()
        let service = makeService(
            responseStatus: 200,
            responseBody: #"{"deleted":true,"refresh_sessions_revoked":true}"#,
            recorder: recorder
        )

        do {
            try await service.deleteAccount(accessToken: "access-token", userID: "user-1")
            XCTFail("Expected unknown remote outcome")
        } catch let error as AccountDeletionError {
            guard case .remoteOutcomeUnknown = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(error.remoteOutcome, .unknown)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(recorder.cleanupCount, 1)
    }

    func testTransportLossAfterPossibleServerSuccessIsUnknownAndRunsPrivacyCleanup() async {
        let recorder = DeletionRecorder()
        let service = makeService(
            transport: AccountDeletionTransport { request in
                recorder.journalEntryObservedAtTransport = recorder.cleanupJournal.pendingCleanup
                recorder.request = request
                throw DeletionTestError.transportLostAfterRemoteSuccess
            },
            recorder: recorder
        )

        do {
            try await service.deleteAccount(accessToken: "access-token", userID: "user-1")
            XCTFail("Expected unknown remote outcome")
        } catch let error as AccountDeletionError {
            guard case let .remoteOutcomeUnknown(reason, cleanupFailure) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertTrue(reason.contains("Transport failed"))
            XCTAssertNil(cleanupFailure)
            XCTAssertEqual(error.remoteOutcome, .unknown)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(recorder.cleanupCount, 1)
        XCTAssertEqual(
            recorder.journalEntryObservedAtTransport,
            AccountDeletionCleanupJournalEntry(userID: "user-1")
        )
        XCTAssertEqual(
            recorder.journalEntryObservedAtSessionCleanup,
            AccountDeletionCleanupJournalEntry(
                userID: "user-1",
                remoteState: .outcomeUnknown
            )
        )
        XCTAssertEqual(
            recorder.cleanupJournal.pendingCleanup,
            AccountDeletionCleanupJournalEntry(
                userID: "user-1",
                remoteState: .outcomeUnknown,
                requiresLocalSessionCleanup: false,
                requiresTaskDataCleanup: true
            )
        )
    }

    func testNonHTTPResponseIsUnknownAndRunsPrivacyCleanup() async {
        let recorder = DeletionRecorder()
        let service = makeService(
            transport: AccountDeletionTransport { request in
                recorder.request = request
                return (
                    Data(),
                    URLResponse(
                        url: request.url!,
                        mimeType: nil,
                        expectedContentLength: 0,
                        textEncodingName: nil
                    )
                )
            },
            recorder: recorder
        )

        do {
            try await service.deleteAccount(accessToken: "access-token", userID: "user-1")
            XCTFail("Expected unknown remote outcome")
        } catch let error as AccountDeletionError {
            guard case .remoteOutcomeUnknown = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(recorder.cleanupCount, 1)
    }

    func testUnstructuredServerFailureIsUnknownAndRunsPrivacyCleanup() async {
        let recorder = DeletionRecorder()
        let service = makeService(
            responseStatus: 500,
            responseBody: "upstream disconnected",
            recorder: recorder
        )

        do {
            try await service.deleteAccount(accessToken: "access-token", userID: "user-1")
            XCTFail("Expected unknown remote outcome")
        } catch let error as AccountDeletionError {
            guard case .remoteOutcomeUnknown = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(recorder.cleanupCount, 1)
    }

    func testStructuredUnknownUserDeletionOutcomeRunsPrivacyCleanup() async {
        let recorder = DeletionRecorder()
        let service = makeService(
            responseStatus: 502,
            responseBody: #"{"code":"account_deletion_failed","message":"The delete request outcome is unknown","stage":"user_deletion","request_id":"request-unknown","refresh_sessions_revoked":true,"deleted":null,"access_tokens_remain_valid_until_expiry":true}"#,
            recorder: recorder
        )

        do {
            try await service.deleteAccount(accessToken: "access-token", userID: "user-1")
            XCTFail("Expected unknown remote outcome")
        } catch let error as AccountDeletionError {
            guard case .remoteOutcomeUnknown = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(error.remoteOutcome, .unknown)
            XCTAssertTrue(error.requiresPrivacyCleanup)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(recorder.cleanupCount, 1)
    }

    func testLegacyThrownUserDeletionFailureCannotClaimDefiniteNonDeletion() async {
        let recorder = DeletionRecorder()
        let service = makeService(
            responseStatus: 502,
            responseBody: #"{"code":"account_deletion_failed","message":"The account could not be deleted","stage":"user_deletion","request_id":"legacy-request","refresh_sessions_revoked":true,"deleted":false,"access_tokens_remain_valid_until_expiry":true}"#,
            recorder: recorder
        )

        do {
            try await service.deleteAccount(accessToken: "access-token", userID: "user-1")
            XCTFail("Expected unknown remote outcome")
        } catch let error as AccountDeletionError {
            guard case .remoteOutcomeUnknown = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(error.remoteOutcome, .unknown)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(recorder.cleanupCount, 1)
    }

    func testGatewayRejectionsAreDefiniteWithoutStructuredFunctionPayload() async {
        for statusCode in [401, 403, 404, 405] {
            let recorder = DeletionRecorder()
            let service = makeService(
                responseStatus: statusCode,
                responseBody: #"{"code":401,"message":"Invalid JWT"}"#,
                recorder: recorder
            )

            do {
                try await service.deleteAccount(accessToken: "access-token", userID: "user-1")
                XCTFail("Expected gateway rejection for HTTP \(statusCode)")
            } catch let error as AccountDeletionError {
                guard case let .serverFailure(_, actualStatusCode, message, _) = error else {
                    return XCTFail("Unexpected error for HTTP \(statusCode): \(error)")
                }
                XCTAssertEqual(actualStatusCode, statusCode)
                XCTAssertEqual(message, "Invalid JWT")
                XCTAssertEqual(error.remoteOutcome, .notDeleted)
                XCTAssertFalse(error.requiresPrivacyCleanup)
            } catch {
                XCTFail("Unexpected error for HTTP \(statusCode): \(error)")
            }

            XCTAssertEqual(recorder.cleanupCount, 0)
            XCTAssertNil(recorder.cleanupJournal.pendingCleanup)
        }
    }

    func testExistingCleanupForAnotherUserPreventsTransportWithoutOverwritingJournal() async {
        let recorder = DeletionRecorder()
        recorder.cleanupJournal.armCleanupRequest(forUserID: "user-a")
        let originalEntry = recorder.cleanupJournal.pendingCleanup
        let service = makeService(
            responseStatus: 200,
            responseBody: #"{"deleted":true,"refresh_sessions_revoked":true,"access_tokens_remain_valid_until_expiry":true}"#,
            recorder: recorder
        )

        do {
            try await service.deleteAccount(accessToken: "access-token", userID: "user-b")
            XCTFail("Expected pending-cleanup conflict")
        } catch let error as AccountDeletionError {
            guard case let .cleanupJournalFailure(remoteOutcome, journalError) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(remoteOutcome, .notDeleted)
            XCTAssertEqual(
                journalError,
                .pendingCleanupConflict(existingUserID: "user-a", requestedUserID: "user-b")
            )
            XCTAssertFalse(error.requiresPrivacyCleanup)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertNil(recorder.request)
        XCTAssertNil(recorder.journalEntryObservedAtTransport)
        XCTAssertEqual(recorder.cleanupCount, 0)
        XCTAssertEqual(recorder.cleanupJournal.pendingCleanup, originalEntry)
    }

    func testFailedInitialJournalCommitPreventsTransportAndSessionCleanup() async {
        var commitCount = 0
        var transportCount = 0
        var cleanupCount = 0
        let cleanupJournal = AccountDeletionCleanupJournal(
            storage: AccountDeletionCleanupJournalStorage(
                read: { nil },
                commit: { _ in
                    commitCount += 1
                    return false
                }
            )
        )
        let service = SupabaseAccountDeletionService(
            configuration: configuration,
            transport: AccountDeletionTransport { request in
                transportCount += 1
                return (
                    Data(),
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                )
            },
            sessionCleaner: AccountDeletionSessionCleaner {
                cleanupCount += 1
            },
            cleanupJournal: cleanupJournal
        )

        do {
            try await service.deleteAccount(accessToken: "access-token", userID: "user-1")
            XCTFail("Expected journal persistence failure")
        } catch let error as AccountDeletionError {
            guard case let .cleanupJournalFailure(remoteOutcome, journalError) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(remoteOutcome, .notDeleted)
            XCTAssertEqual(journalError, .persistenceFailed)
            XCTAssertFalse(error.requiresPrivacyCleanup)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(commitCount, 1)
        XCTAssertEqual(transportCount, 0)
        XCTAssertEqual(cleanupCount, 0)
    }

    func testUnknownOutcomeWithSessionCleanupFailureDoesNotClaimSuccessfulSignOut() async {
        let recorder = DeletionRecorder()
        recorder.cleanupError = DeletionTestError.cleanupFailed
        let service = makeService(
            transport: AccountDeletionTransport { _ in
                throw DeletionTestError.transportLostAfterRemoteSuccess
            },
            recorder: recorder
        )

        do {
            try await service.deleteAccount(accessToken: "access-token", userID: "user-1")
            XCTFail("Expected unknown remote outcome")
        } catch let error as AccountDeletionError {
            guard case let .remoteOutcomeUnknown(_, cleanupFailure) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(cleanupFailure, DeletionTestError.cleanupFailed.localizedDescription)
            XCTAssertTrue(error.localSessionCleanupFailed)
            XCTAssertTrue(error.localizedDescription.contains("attempted to clear the local session"))
            XCTAssertFalse(error.localizedDescription.contains("the app signed out"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(recorder.cleanupCount, 1)
        XCTAssertEqual(
            recorder.cleanupJournal.pendingCleanup,
            AccountDeletionCleanupJournalEntry(
                userID: "user-1",
                remoteState: .outcomeUnknown
            )
        )
    }

    private func makeService(
        responseStatus: Int,
        responseBody: String,
        recorder: DeletionRecorder
    ) -> SupabaseAccountDeletionService {
        makeService(
            transport: AccountDeletionTransport { request in
                recorder.request = request
                return (
                    Data(responseBody.utf8),
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: responseStatus,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                )
            },
            recorder: recorder
        )
    }

    private func makeService(
        transport: AccountDeletionTransport,
        recorder: DeletionRecorder
    ) -> SupabaseAccountDeletionService {
        SupabaseAccountDeletionService(
            configuration: configuration,
            transport: AccountDeletionTransport { request in
                recorder.journalEntryObservedAtTransport = recorder.cleanupJournal.pendingCleanup
                return try await transport.send(request)
            },
            sessionCleaner: AccountDeletionSessionCleaner {
                recorder.journalEntryObservedAtSessionCleanup = recorder.cleanupJournal.pendingCleanup
                recorder.cleanupCount += 1
                if let cleanupError = recorder.cleanupError {
                    throw cleanupError
                }
            },
            cleanupJournal: recorder.cleanupJournal
        )
    }
}

@MainActor
private final class DeletionRecorder {
    private let suiteName = "SupabaseAccountDeletionTests-\(UUID().uuidString)"
    private lazy var userDefaults = UserDefaults(suiteName: suiteName)!
    var request: URLRequest?
    var cleanupCount = 0
    var cleanupError: Error?
    var journalEntryObservedAtTransport: AccountDeletionCleanupJournalEntry?
    var journalEntryObservedAtSessionCleanup: AccountDeletionCleanupJournalEntry?

    lazy var cleanupJournal = AccountDeletionCleanupJournal(userDefaults: userDefaults)
}

private enum DeletionTestError: LocalizedError {
    case cleanupFailed
    case transportLostAfterRemoteSuccess

    var errorDescription: String? {
        switch self {
        case .cleanupFailed:
            "Cleanup failed"
        case .transportLostAfterRemoteSuccess:
            "Connection lost after request transmission"
        }
    }
}
