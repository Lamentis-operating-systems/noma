import Foundation

enum AccountDeletionCleanupRemoteState: String, Codable, Equatable {
    case requestInFlight
    case deletionConfirmed
    case outcomeUnknown
}

struct AccountDeletionCleanupJournalEntry: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let userID: String
    var remoteState: AccountDeletionCleanupRemoteState
    var requiresLocalSessionCleanup: Bool
    var requiresTaskDataCleanup: Bool

    init(
        userID: String,
        remoteState: AccountDeletionCleanupRemoteState = .requestInFlight,
        requiresLocalSessionCleanup: Bool = true,
        requiresTaskDataCleanup: Bool = true
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.userID = userID
        self.remoteState = remoteState
        self.requiresLocalSessionCleanup = requiresLocalSessionCleanup
        self.requiresTaskDataCleanup = requiresTaskDataCleanup
    }
}

enum AccountDeletionCleanupJournalError: LocalizedError, Equatable {
    case pendingCleanupConflict(existingUserID: String, requestedUserID: String)
    case missingPendingCleanup(userID: String)
    case malformedStoredJournal
    case unsupportedSchemaVersion(Int)
    case encodingFailed
    case persistenceFailed

    var errorDescription: String? {
        switch self {
        case let .pendingCleanupConflict(existingUserID, requestedUserID):
            "Account cleanup for \(existingUserID) is still pending; cleanup for \(requestedUserID) was not started."
        case let .missingPendingCleanup(userID):
            "The pending account-cleanup journal for \(userID) is missing."
        case .malformedStoredJournal:
            "The pending account-cleanup journal could not be read."
        case let .unsupportedSchemaVersion(version):
            "The pending account-cleanup journal uses unsupported schema version \(version)."
        case .encodingFailed:
            "The pending account-cleanup journal could not be encoded."
        case .persistenceFailed:
            "The pending account-cleanup journal could not be committed to storage."
        }
    }

    var indicatesStoredCleanupObligation: Bool {
        switch self {
        case .pendingCleanupConflict, .malformedStoredJournal, .unsupportedSchemaVersion:
            true
        case .missingPendingCleanup, .encodingFailed, .persistenceFailed:
            false
        }
    }
}

enum AccountDeletionCleanupJournalState: Equatable {
    case none
    case pending(AccountDeletionCleanupJournalEntry)
    case invalid(AccountDeletionCleanupJournalError)

    var pendingCleanup: AccountDeletionCleanupJournalEntry? {
        guard case let .pending(entry) = self else { return nil }
        return entry
    }

    var requiresAuthenticationBlock: Bool {
        switch self {
        case .none:
            false
        case .pending, .invalid:
            true
        }
    }
}

@MainActor
struct AccountDeletionCleanupJournalStorage {
    let read: () -> Any?
    let commit: (Data?) -> Bool

    static func userDefaults(_ userDefaults: UserDefaults) -> Self {
        AccountDeletionCleanupJournalStorage(
            read: {
                userDefaults.object(forKey: AccountDeletionCleanupJournal.storageKey)
            },
            commit: { data in
                if let data {
                    userDefaults.set(data, forKey: AccountDeletionCleanupJournal.storageKey)
                } else {
                    userDefaults.removeObject(forKey: AccountDeletionCleanupJournal.storageKey)
                }
                return userDefaults.synchronize()
            }
        )
    }
}

@MainActor
struct AccountDeletionCleanupJournal {
    nonisolated static let storageKey = "noma.account-deletion.pending-local-cleanup-user-id"

    private let storage: AccountDeletionCleanupJournalStorage

    static var standard: AccountDeletionCleanupJournal {
        AccountDeletionCleanupJournal(userDefaults: .standard)
    }

    init(userDefaults: UserDefaults) {
        storage = .userDefaults(userDefaults)
    }

    init(storage: AccountDeletionCleanupJournalStorage) {
        self.storage = storage
    }

    var state: AccountDeletionCleanupJournalState {
        guard let storedValue = storage.read() else { return .none }

        if let legacyUserID = storedValue as? String {
            guard !legacyUserID.isEmpty else {
                return .invalid(.malformedStoredJournal)
            }
            return .pending(AccountDeletionCleanupJournalEntry(
                userID: legacyUserID,
                remoteState: .outcomeUnknown,
                requiresLocalSessionCleanup: true,
                requiresTaskDataCleanup: true
            ))
        }

        guard let data = storedValue as? Data,
              let header = try? JSONDecoder().decode(JournalHeader.self, from: data)
        else { return .invalid(.malformedStoredJournal) }
        guard header.schemaVersion == AccountDeletionCleanupJournalEntry.currentSchemaVersion else {
            return .invalid(.unsupportedSchemaVersion(header.schemaVersion))
        }
        guard let entry = try? JSONDecoder().decode(AccountDeletionCleanupJournalEntry.self, from: data),
              !entry.userID.isEmpty,
              entry.requiresLocalSessionCleanup || entry.requiresTaskDataCleanup
        else { return .invalid(.malformedStoredJournal) }
        return .pending(entry)
    }

    var pendingCleanup: AccountDeletionCleanupJournalEntry? { state.pendingCleanup }
    var pendingUserID: String? { pendingCleanup?.userID }

    @discardableResult
    func armCleanupRequest(
        forUserID userID: String
    ) -> Result<Void, AccountDeletionCleanupJournalError> {
        switch state {
        case .none:
            persist(AccountDeletionCleanupJournalEntry(userID: userID))
        case let .pending(entry):
            .failure(.pendingCleanupConflict(
                existingUserID: entry.userID,
                requestedUserID: userID
            ))
        case let .invalid(error):
            .failure(error)
        }
    }

    @discardableResult
    func ensureCleanupIsArmed(
        forUserID userID: String
    ) -> Result<Void, AccountDeletionCleanupJournalError> {
        switch state {
        case .none:
            persist(AccountDeletionCleanupJournalEntry(
                userID: userID,
                remoteState: .outcomeUnknown
            ))
        case let .pending(entry) where entry.userID == userID:
            .success(())
        case let .pending(entry):
            .failure(.pendingCleanupConflict(
                existingUserID: entry.userID,
                requestedUserID: userID
            ))
        case let .invalid(error):
            .failure(error)
        }
    }

    @discardableResult
    func recordRemoteOutcome(
        _ remoteState: AccountDeletionCleanupRemoteState,
        forUserID userID: String
    ) -> Result<Void, AccountDeletionCleanupJournalError> {
        updateEntry(forUserID: userID) { $0.remoteState = remoteState }
    }

    @discardableResult
    func disarmCleanupAfterDefiniteRemoteFailure(
        forUserID userID: String
    ) -> Result<Void, AccountDeletionCleanupJournalError> {
        switch state {
        case .none:
            return .success(())
        case let .pending(entry) where entry.userID == userID:
            return removeEntry()
        case let .pending(entry):
            return .failure(.pendingCleanupConflict(
                existingUserID: entry.userID,
                requestedUserID: userID
            ))
        case let .invalid(error):
            return .failure(error)
        }
    }

    @discardableResult
    func markLocalSessionCleanupCompleted(
        forUserID userID: String
    ) -> Result<Void, AccountDeletionCleanupJournalError> {
        updateEntry(forUserID: userID) { $0.requiresLocalSessionCleanup = false }
    }

    @discardableResult
    func markTaskDataCleanupCompleted(
        forUserID userID: String
    ) -> Result<Void, AccountDeletionCleanupJournalError> {
        updateEntry(forUserID: userID) { $0.requiresTaskDataCleanup = false }
    }

    private func updateEntry(
        forUserID userID: String,
        update: (inout AccountDeletionCleanupJournalEntry) -> Void
    ) -> Result<Void, AccountDeletionCleanupJournalError> {
        let entry: AccountDeletionCleanupJournalEntry
        switch state {
        case .none:
            return .failure(.missingPendingCleanup(userID: userID))
        case let .pending(pendingEntry) where pendingEntry.userID == userID:
            entry = pendingEntry
        case let .pending(pendingEntry):
            return .failure(.pendingCleanupConflict(
                existingUserID: pendingEntry.userID,
                requestedUserID: userID
            ))
        case let .invalid(error):
            return .failure(error)
        }

        var updatedEntry = entry
        update(&updatedEntry)
        return persist(updatedEntry)
    }

    private func persist(
        _ entry: AccountDeletionCleanupJournalEntry
    ) -> Result<Void, AccountDeletionCleanupJournalError> {
        guard entry.requiresLocalSessionCleanup || entry.requiresTaskDataCleanup else {
            return removeEntry()
        }

        guard let data = try? JSONEncoder().encode(entry) else {
            return .failure(.encodingFailed)
        }
        return storage.commit(data) ? .success(()) : .failure(.persistenceFailed)
    }

    private func removeEntry() -> Result<Void, AccountDeletionCleanupJournalError> {
        storage.commit(nil) ? .success(()) : .failure(.persistenceFailed)
    }
}

private struct JournalHeader: Decodable {
    let schemaVersion: Int
}

enum AccountDeletionLocalCleanupRecoveryResult: Equatable {
    case nothingPending
    case recovered
    case failed(
        localSessionCleanupFailure: String?,
        taskDataCleanupFailure: DailyTaskGroupPersistenceError?
    )
    case journalFailure(AccountDeletionCleanupJournalError)

    var requiresAuthenticationBlock: Bool {
        switch self {
        case .nothingPending, .recovered:
            false
        case .failed, .journalFailure:
            true
        }
    }
}

@MainActor
enum AccountDeletionCoordinator {
    static func deleteAccount(
        authState: AuthStateManager,
        dailyTaskGroups: DailyTaskGroupStore
    ) async -> AccountDeletionCoordinatorResult {
        await deleteAccount(
            authState: authState,
            dailyTaskGroups: dailyTaskGroups,
            cleanupJournal: .standard
        )
    }

    static func deleteAccount(
        authState: AuthStateManager,
        dailyTaskGroups: DailyTaskGroupStore,
        cleanupJournal: AccountDeletionCleanupJournal
    ) async -> AccountDeletionCoordinatorResult {
        guard !authState.isDeletingAccount else {
            let hasPendingCleanup = cleanupJournal.state.requiresAuthenticationBlock
            if hasPendingCleanup {
                authState.blockAuthenticationForPendingAccountDeletionCleanup()
            }
            return AccountDeletionCoordinatorResult(
                authResult: .failed,
                localDataDeletionError: nil,
                cleanupJournalError: nil,
                hasPendingCleanup: hasPendingCleanup
            )
        }
        guard let userID = authState.storageUserID else {
            authState.errorMessage = String(
                localized: "auth.delete-account.missing-local-data-scope-error"
            )
            let hasPendingCleanup = cleanupJournal.state.requiresAuthenticationBlock
            if hasPendingCleanup {
                authState.blockAuthenticationForPendingAccountDeletionCleanup()
            }
            return AccountDeletionCoordinatorResult(
                authResult: .failed,
                localDataDeletionError: nil,
                cleanupJournalError: nil,
                hasPendingCleanup: hasPendingCleanup
            )
        }

        let authResult = await authState.deleteAccountFlow()
        var localDataDeletionError: DailyTaskGroupPersistenceError?
        var cleanupJournalError: AccountDeletionCleanupJournalError?

        if authResult.requiresPrivacyCleanup {
            // The live deletion service arms this before clearing the local auth
            // session. This fallback keeps alternate AuthClient implementations
            // privacy-safe without resetting a completed session-cleanup step.
            if case let .failure(error) = cleanupJournal.ensureCleanupIsArmed(forUserID: userID) {
                cleanupJournalError = error
            }

            switch dailyTaskGroups.deleteLocalData(forUserID: userID) {
            case .success:
                if case let .failure(error) = cleanupJournal.markTaskDataCleanupCompleted(
                    forUserID: userID
                ) {
                    cleanupJournalError = cleanupJournalError ?? error
                }
            case let .failure(error):
                localDataDeletionError = error
            }
        }

        let hasPendingCleanup = cleanupJournal.state.requiresAuthenticationBlock
        let result = AccountDeletionCoordinatorResult(
            authResult: authResult,
            localDataDeletionError: localDataDeletionError,
            cleanupJournalError: cleanupJournalError,
            hasPendingCleanup: hasPendingCleanup
        )
        if hasPendingCleanup {
            authState.blockAuthenticationForPendingAccountDeletionCleanup()
        }
        if localDataDeletionError != nil || cleanupJournalError != nil || hasPendingCleanup {
            authState.errorMessage = result.errorMessage(combining: authState.errorMessage)
        }
        return result
    }

    static func recoverPendingLocalCleanup(
        authState: AuthStateManager,
        dailyTaskGroups: DailyTaskGroupStore
    ) async -> AccountDeletionLocalCleanupRecoveryResult {
        await recoverPendingLocalCleanup(
            authState: authState,
            dailyTaskGroups: dailyTaskGroups,
            cleanupJournal: .standard
        )
    }

    static func recoverPendingLocalCleanup(
        authState: AuthStateManager,
        dailyTaskGroups: DailyTaskGroupStore,
        cleanupJournal: AccountDeletionCleanupJournal
    ) async -> AccountDeletionLocalCleanupRecoveryResult {
        let pendingCleanup: AccountDeletionCleanupJournalEntry
        switch cleanupJournal.state {
        case .none:
            return .nothingPending
        case let .pending(entry):
            pendingCleanup = entry
        case let .invalid(error):
            return .journalFailure(error)
        }

        let userID = pendingCleanup.userID
        var localSessionCleanupFailure: String?
        var taskDataCleanupFailure: DailyTaskGroupPersistenceError?
        var cleanupJournalFailure: AccountDeletionCleanupJournalError?

        if pendingCleanup.requiresLocalSessionCleanup {
            do {
                try await authState.clearLocalSessionForPendingAccountDeletion()
                if case let .failure(error) = cleanupJournal.markLocalSessionCleanupCompleted(
                    forUserID: userID
                ) {
                    cleanupJournalFailure = error
                }
            } catch {
                localSessionCleanupFailure = error.localizedDescription
            }
        }

        if pendingCleanup.requiresTaskDataCleanup {
            switch dailyTaskGroups.deleteLocalData(forUserID: userID) {
            case .success:
                if case let .failure(error) = cleanupJournal.markTaskDataCleanupCompleted(
                    forUserID: userID
                ) {
                    cleanupJournalFailure = cleanupJournalFailure ?? error
                }
            case let .failure(error):
                taskDataCleanupFailure = error
            }
        }

        if let cleanupJournalFailure {
            return .journalFailure(cleanupJournalFailure)
        }

        switch cleanupJournal.state {
        case .none:
            return .recovered
        case let .invalid(error):
            return .journalFailure(error)
        case .pending:
            return .failed(
                localSessionCleanupFailure: localSessionCleanupFailure,
                taskDataCleanupFailure: taskDataCleanupFailure
            )
        }
    }
}

struct AccountDeletionCoordinatorResult: Equatable {
    let authResult: AccountDeletionFlowResult
    let localDataDeletionError: DailyTaskGroupPersistenceError?
    let cleanupJournalError: AccountDeletionCleanupJournalError?
    let hasPendingCleanup: Bool

    var completedCleanly: Bool {
        authResult.completedCleanly
            && localDataDeletionError == nil
            && cleanupJournalError == nil
            && !hasPendingCleanup
    }

    func errorMessage(combining authErrorMessage: String?) -> String? {
        if localDataDeletionError == nil,
           cleanupJournalError == nil,
           !hasPendingCleanup {
            return nil
        }

        if localDataDeletionError != nil, authResult == .deleted {
            return String(localized: "auth.delete-account.local-data-cleanup-error")
        }

        let localCleanupMessage = localDataDeletionError == nil
            ? nil
            : String(localized: "auth.delete-account.additional-local-data-cleanup-error")
        let pendingCleanupMessage = cleanupJournalError != nil || hasPendingCleanup
            ? String(localized: "auth.delete-account.pending-local-data-cleanup-error")
            : nil
        return [authErrorMessage, localCleanupMessage, pendingCleanupMessage]
            .compactMap { $0 }
            .reduce(into: [String]()) { messages, message in
                if !messages.contains(message) {
                    messages.append(message)
                }
            }
            .joined(separator: " ")
    }
}
