import Foundation

extension AuthStateManager {
    func startAfterRecoveringPendingAccountDeletion(
        dailyTaskGroups: DailyTaskGroupStore,
        cleanupJournal: AccountDeletionCleanupJournal? = nil
    ) async {
        guard !hasStarted else { return }

        let pendingCleanupMessage = String(
            localized: "auth.delete-account.pending-local-data-cleanup-error"
        )
        let recoveryResult = await AccountDeletionCoordinator.recoverPendingLocalCleanup(
            authState: self,
            dailyTaskGroups: dailyTaskGroups,
            cleanupJournal: cleanupJournal ?? .standard
        )

        if recoveryResult.requiresAuthenticationBlock {
            errorMessage = pendingCleanupMessage
        } else if errorMessage == pendingCleanupMessage {
            errorMessage = nil
        }

        guard !recoveryResult.requiresAuthenticationBlock else {
            blockAuthenticationForPendingAccountDeletionCleanup()
            return
        }

        isAccountDeletionRecoveryBlocked = false
        start()
    }

    func start() {
        guard !hasStarted, !isAccountDeletionRecoveryBlocked else { return }
        hasStarted = true

        authObserverTask = Task { [authClient] in
            let initialSnapshot = await authClient.currentSessionSnapshot()
            guard !Task.isCancelled, !isAccountDeletionRecoveryBlocked else { return }
            apply(initialSnapshot)

            for await snapshot in authClient.authStateSnapshots() {
                guard !Task.isCancelled, !isAccountDeletionRecoveryBlocked else { return }
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
        guard !isDeletingAccount else { return }
        errorMessage = nil
        do {
            try await authClient.signOut()
            apply(AuthSessionSnapshot(isSignedIn: false))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAccount() { Task { _ = await deleteAccountFlow() } }

    func clearLocalSessionForPendingAccountDeletion() async throws {
        try await authClient.clearLocalSessionForPendingAccountDeletion()
        apply(AuthSessionSnapshot(isSignedIn: false))
    }

    func blockAuthenticationForPendingAccountDeletionCleanup() {
        isAccountDeletionRecoveryBlocked = true
        authObserverTask?.cancel()
        authObserverTask = nil
        hasStarted = false
        apply(AuthSessionSnapshot(isSignedIn: false))
    }

    @discardableResult
    func deleteAccountFlow() async -> AccountDeletionFlowResult {
        guard beginDeleteAccount() else { return .failed }
        defer { isDeletingAccount = false }

        do {
            try await authClient.deleteAccount()
            apply(AuthSessionSnapshot(isSignedIn: false))
            return .deleted
        } catch {
            if let deletionError = error as? AccountDeletionError {
                if deletionError.requiresAuthenticationBlock {
                    blockAuthenticationForPendingAccountDeletionCleanup()
                } else if deletionError.requiresPrivacyCleanup {
                    apply(AuthSessionSnapshot(isSignedIn: false))
                }
                errorMessage = error.localizedDescription
                guard deletionError.requiresPrivacyCleanup else { return .failed }
                return deletionError.remoteOutcome == .unknown
                    ? .remoteOutcomeUnknown
                    : .remoteDeletedLocalSessionCleanupFailed
            }
            errorMessage = error.localizedDescription
            return .failed
        }
    }

    private func beginSignInWithApple() -> Bool {
        guard !isSigningIn, !isAccountDeletionRecoveryBlocked else { return false }
        errorMessage = nil
        isSigningIn = true
        return true
    }

    private func beginDeleteAccount() -> Bool {
        guard !isDeletingAccount else { return false }
        errorMessage = nil
        isDeletingAccount = true
        return true
    }

    private func completeSignInWithAppleFlow() async {
        defer { isSigningIn = false }

        do {
            let credential = try await appleSignInProvider.requestCredential()
            guard !isAccountDeletionRecoveryBlocked else { return }
            let snapshot = try await authClient.signInWithApple(
                idToken: credential.identityToken,
                nonce: credential.nonce
            )
            guard !isAccountDeletionRecoveryBlocked else {
                try? await authClient.clearLocalSessionForPendingAccountDeletion()
                return
            }
            apply(snapshot)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ snapshot: AuthSessionSnapshot) {
        phase = snapshot.rootPhase
        storageUserID = snapshot.storageUserID

        switch snapshot.state {
        case .missing:
            sessionLifecycle?.clearAfterAuthenticationEnds()
        case .authenticated, .refreshingExpiredLocalSession:
            sessionLifecycle?.activateAuthenticatedSession()
        }
    }
}
