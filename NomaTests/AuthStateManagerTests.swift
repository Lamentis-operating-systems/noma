@testable import Noma
import Foundation
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
        let lifecycle = AuthSessionLifecycleSpy()
        let authClient = AuthClientSpy(
            initialSnapshot: AuthSessionSnapshot(
                state: .refreshingExpiredLocalSession,
                userID: "stored-user"
            )
        )
        let authState = AuthStateManager(
            authClient: authClient,
            appleSignInProvider: StubAppleSignInProvider(),
            sessionLifecycle: lifecycle
        )
        authState.phase = .signedOut

        authState.start()
        await allowAuthObserverToRun()

        XCTAssertEqual(authState.phase, .signedIn)
        XCTAssertEqual(authState.storageUserID, "stored-user")
        XCTAssertEqual(authClient.currentSessionSnapshotCallCount, 1)
        XCTAssertEqual(authClient.authStateSnapshotsCallCount, 1)
        XCTAssertEqual(lifecycle.activationCallCount, 1)
        XCTAssertEqual(lifecycle.clearCallCount, 0)
    }

    @MainActor
    func testAuthStateManagerAppliesRefreshAfterExpiredStoredSession() async {
        let authClient = AuthClientSpy(
            initialSnapshot: AuthSessionSnapshot(state: .refreshingExpiredLocalSession),
            streamSnapshots: [AuthSessionSnapshot(state: .authenticated)]
        )
        let authState = AuthStateManager(
            authClient: authClient,
            appleSignInProvider: StubAppleSignInProvider()
        )

        authState.start()
        await allowAuthObserverToRun()

        XCTAssertEqual(authState.phase, .signedIn)
        XCTAssertEqual(authClient.currentSessionSnapshotCallCount, 1)
        XCTAssertEqual(authClient.authStateSnapshotsCallCount, 1)
    }

    @MainActor
    func testSignInWithAppleAppliesReturnedSessionSnapshotImmediately() async {
        let lifecycle = AuthSessionLifecycleSpy()
        let authClient = AuthClientSpy(
            signInSnapshot: AuthSessionSnapshot(isSignedIn: true, userID: "signed-in-user")
        )
        let authState = AuthStateManager(
            authClient: authClient,
            appleSignInProvider: StubAppleSignInProvider(),
            sessionLifecycle: lifecycle
        )
        authState.phase = .signedOut

        await authState.signInWithAppleFlow()

        XCTAssertEqual(authState.phase, .signedIn)
        XCTAssertEqual(authState.storageUserID, "signed-in-user")
        XCTAssertFalse(authState.isSigningIn)
        XCTAssertEqual(authClient.signInWithAppleCalls.count, 1)
        XCTAssertEqual(authClient.signInWithAppleCalls.first?.idToken, "identity-token")
        XCTAssertEqual(authClient.signInWithAppleCalls.first?.nonce, "nonce")
        XCTAssertEqual(lifecycle.activationCallCount, 1)
    }

    @MainActor
    func testSignInWithAppleReportsFailureAndClearsLoading() async {
        let authClient = AuthClientSpy(signInError: TestAuthError.signInRejected)
        let authState = AuthStateManager(
            authClient: authClient,
            appleSignInProvider: StubAppleSignInProvider()
        )
        authState.phase = .signedOut

        await authState.signInWithAppleFlow()

        XCTAssertEqual(authState.phase, .signedOut)
        XCTAssertEqual(authState.errorMessage, TestAuthError.signInRejected.localizedDescription)
        XCTAssertFalse(authState.isSigningIn)
        XCTAssertEqual(authClient.signInWithAppleCalls.count, 1)
    }

    @MainActor
    func testCleanupBlockStopsAnAlreadyStartedAppleSignInBeforeAuthRequest() async {
        let appleSignInProvider = SuspendedAppleSignInProvider()
        let authClient = AuthClientSpy()
        let authState = AuthStateManager(
            authClient: authClient,
            appleSignInProvider: appleSignInProvider
        )
        authState.phase = .signedOut

        let signInTask = Task { await authState.signInWithAppleFlow() }
        for _ in 0..<20 where !appleSignInProvider.isWaitingForResume {
            await Task.yield()
        }
        XCTAssertTrue(appleSignInProvider.isWaitingForResume)
        XCTAssertTrue(authState.isSigningIn)

        authState.blockAuthenticationForPendingAccountDeletionCleanup()
        appleSignInProvider.resume()
        await signInTask.value

        XCTAssertTrue(authState.isAccountDeletionRecoveryBlocked)
        XCTAssertEqual(authState.phase, .signedOut)
        XCTAssertFalse(authState.isSigningIn)
        XCTAssertTrue(authClient.signInWithAppleCalls.isEmpty)
    }

    @MainActor
    func testSignOutAppliesSignedOutSnapshot() async {
        let lifecycle = AuthSessionLifecycleSpy()
        let authClient = AuthClientSpy(initialSnapshot: AuthSessionSnapshot(isSignedIn: true))
        let authState = AuthStateManager(
            authClient: authClient,
            appleSignInProvider: StubAppleSignInProvider(),
            sessionLifecycle: lifecycle
        )
        authState.phase = .signedIn

        await authState.signOutFlow()

        XCTAssertEqual(authState.phase, .signedOut)
        XCTAssertNil(authState.storageUserID)
        XCTAssertNil(authState.errorMessage)
        XCTAssertEqual(lifecycle.clearCallCount, 1)
        XCTAssertEqual(authClient.signOutCallCount, 1)
    }

    @MainActor
    func testSignOutIsBlockedInUIAndActionPathDuringAccountDeletion() async {
        let authClient = AuthClientSpy(initialSnapshot: AuthSessionSnapshot(isSignedIn: true))
        let authState = AuthStateManager(
            authClient: authClient,
            appleSignInProvider: StubAppleSignInProvider()
        )
        authState.phase = .signedIn
        authState.storageUserID = "signed-in-user"
        authState.isDeletingAccount = true

        await authState.signOutFlow()

        XCTAssertFalse(HomeMenuActionAvailability.allowsSignOut(isDeletingAccount: true))
        XCTAssertTrue(HomeMenuActionAvailability.allowsSignOut(isDeletingAccount: false))
        XCTAssertEqual(authClient.signOutCallCount, 0)
        XCTAssertEqual(authState.phase, .signedIn)
        XCTAssertEqual(authState.storageUserID, "signed-in-user")
    }

    @MainActor
    func testDeleteAccountAppliesSignedOutSnapshot() async {
        let lifecycle = AuthSessionLifecycleSpy()
        let authClient = AuthClientSpy(
            initialSnapshot: AuthSessionSnapshot(isSignedIn: true, userID: "signed-in-user")
        )
        let authState = AuthStateManager(
            authClient: authClient,
            appleSignInProvider: StubAppleSignInProvider(),
            sessionLifecycle: lifecycle
        )
        authState.phase = .signedIn
        authState.storageUserID = "signed-in-user"

        let result = await authState.deleteAccountFlow()

        XCTAssertEqual(result, .deleted)
        XCTAssertEqual(authState.phase, .signedOut)
        XCTAssertNil(authState.storageUserID)
        XCTAssertNil(authState.errorMessage)
        XCTAssertFalse(authState.isDeletingAccount)
        XCTAssertEqual(lifecycle.clearCallCount, 1)
        XCTAssertEqual(authClient.deleteAccountCallCount, 1)
    }

    @MainActor
    func testDeleteAccountReportsFailureAndKeepsSignedInState() async {
        let authClient = AuthClientSpy(deleteAccountError: TestAuthError.deleteRejected)
        let authState = AuthStateManager(
            authClient: authClient,
            appleSignInProvider: StubAppleSignInProvider()
        )
        authState.phase = .signedIn
        authState.storageUserID = "signed-in-user"

        let result = await authState.deleteAccountFlow()

        XCTAssertEqual(result, .failed)
        XCTAssertEqual(authState.phase, .signedIn)
        XCTAssertEqual(authState.storageUserID, "signed-in-user")
        XCTAssertEqual(authState.errorMessage, TestAuthError.deleteRejected.localizedDescription)
        XCTAssertFalse(authState.isDeletingAccount)
        XCTAssertEqual(authClient.deleteAccountCallCount, 1)
    }

    @MainActor
    func testLiveSessionCleanupFailureStopsObserverAndBlocksAppleSignIn() async {
        let authClient = AuthClientSpy(
            deleteAccountError: AccountDeletionError.localCleanupFailed(message: "Cleanup failed"),
            keepsAuthStateStreamOpen: true
        )
        let authState = AuthStateManager(
            authClient: authClient,
            appleSignInProvider: StubAppleSignInProvider()
        )
        authState.start()
        await allowAuthObserverToRun()
        let observerTask = authState.authObserverTask
        authState.phase = .signedIn
        authState.storageUserID = "deleted-user"

        let result = await authState.deleteAccountFlow()

        XCTAssertEqual(result, .remoteDeletedLocalSessionCleanupFailed)
        XCTAssertEqual(authState.phase, .signedOut)
        XCTAssertNil(authState.storageUserID)
        XCTAssertNotNil(authState.errorMessage)
        XCTAssertFalse(authState.isDeletingAccount)
        XCTAssertTrue(authState.isAccountDeletionRecoveryBlocked)
        XCTAssertFalse(authState.hasStarted)
        XCTAssertNil(authState.authObserverTask)
        XCTAssertTrue(observerTask?.isCancelled == true)
        XCTAssertEqual(authClient.deleteAccountCallCount, 1)

        authState.start()
        XCTAssertFalse(authState.hasStarted)
        XCTAssertNil(authState.authObserverTask)

        await authState.signInWithAppleFlow()
        XCTAssertFalse(authState.isSigningIn)
        XCTAssertTrue(authClient.signInWithAppleCalls.isEmpty)
    }

    @MainActor
    func testDeleteAccountUnknownRemoteOutcomeSignsOutAndPreservesDurableWarning() async {
        let lifecycle = AuthSessionLifecycleSpy()
        let authClient = AuthClientSpy(
            deleteAccountError: AccountDeletionError.remoteOutcomeUnknown(
                reason: "Connection lost after request transmission",
                localSessionCleanupFailure: nil
            )
        )
        let authState = AuthStateManager(
            authClient: authClient,
            appleSignInProvider: StubAppleSignInProvider(),
            sessionLifecycle: lifecycle
        )
        authState.phase = .signedIn
        authState.storageUserID = "possibly-deleted-user"

        let result = await authState.deleteAccountFlow()

        XCTAssertEqual(result, .remoteOutcomeUnknown)
        XCTAssertEqual(authState.phase, .signedOut)
        XCTAssertNil(authState.storageUserID)
        XCTAssertTrue(authState.errorMessage?.contains("could not be confirmed") == true)
        XCTAssertEqual(lifecycle.clearCallCount, 1)
        XCTAssertEqual(authClient.deleteAccountCallCount, 1)
    }

    @MainActor
    func testCoordinatorDeletesAppDataWhenRemoteDeleteOutlivesLocalSessionCleanup() async {
        let suiteName = "NomaTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated user defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let userID = "deleted-user"
        let storageKey = DailyTaskGroupStorage.storageKey(forUserID: userID)
        let cleanupJournal = AccountDeletionCleanupJournal(userDefaults: defaults)
        cleanupJournal.armCleanupRequest(forUserID: userID)
        cleanupJournal.recordRemoteOutcome(.deletionConfirmed, forUserID: userID)
        let dailyTaskGroups = DailyTaskGroupStore(userDefaults: defaults, userID: userID)
        dailyTaskGroups.setReminders(
            [CreateReminder(text: "Private task")],
            forDayID: dailyTaskGroups.todayID()
        )
        XCTAssertNotNil(defaults.data(forKey: storageKey))

        let authClient = AuthClientSpy(
            deleteAccountError: AccountDeletionError.localCleanupFailed(message: "Cleanup failed")
        )
        let authState = AuthStateManager(
            authClient: authClient,
            appleSignInProvider: StubAppleSignInProvider()
        )
        authState.phase = .signedIn
        authState.storageUserID = userID

        let result = await AccountDeletionCoordinator.deleteAccount(
            authState: authState,
            dailyTaskGroups: dailyTaskGroups,
            cleanupJournal: cleanupJournal
        )

        XCTAssertEqual(result.authResult, .remoteDeletedLocalSessionCleanupFailed)
        XCTAssertNil(result.localDataDeletionError)
        XCTAssertFalse(result.completedCleanly)
        XCTAssertNil(defaults.data(forKey: storageKey))
        XCTAssertEqual(
            cleanupJournal.pendingCleanup,
            AccountDeletionCleanupJournalEntry(
                userID: userID,
                remoteState: .deletionConfirmed,
                requiresLocalSessionCleanup: true,
                requiresTaskDataCleanup: false
            )
        )
        XCTAssertTrue(dailyTaskGroups.groups.isEmpty)
    }

    @MainActor
    func testCoordinatorDeletesAppDataWhenRemoteOutcomeIsUnknown() async {
        let suiteName = "NomaTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated user defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let userID = "possibly-deleted-user"
        let storageKey = DailyTaskGroupStorage.storageKey(forUserID: userID)
        let cleanupJournal = AccountDeletionCleanupJournal(userDefaults: defaults)
        cleanupJournal.armCleanupRequest(forUserID: userID)
        cleanupJournal.recordRemoteOutcome(.outcomeUnknown, forUserID: userID)
        cleanupJournal.markLocalSessionCleanupCompleted(forUserID: userID)
        let dailyTaskGroups = DailyTaskGroupStore(userDefaults: defaults, userID: userID)
        dailyTaskGroups.setReminders(
            [CreateReminder(text: "Private task")],
            forDayID: dailyTaskGroups.todayID()
        )
        XCTAssertNotNil(defaults.data(forKey: storageKey))

        let authState = AuthStateManager(
            authClient: AuthClientSpy(
                deleteAccountError: AccountDeletionError.remoteOutcomeUnknown(
                    reason: "Connection lost after request transmission",
                    localSessionCleanupFailure: nil
                )
            ),
            appleSignInProvider: StubAppleSignInProvider()
        )
        authState.phase = .signedIn
        authState.storageUserID = userID

        let result = await AccountDeletionCoordinator.deleteAccount(
            authState: authState,
            dailyTaskGroups: dailyTaskGroups,
            cleanupJournal: cleanupJournal
        )

        XCTAssertEqual(result.authResult, .remoteOutcomeUnknown)
        XCTAssertNil(result.localDataDeletionError)
        XCTAssertFalse(result.completedCleanly)
        XCTAssertNil(defaults.data(forKey: storageKey))
        XCTAssertNil(cleanupJournal.pendingUserID)
        XCTAssertTrue(dailyTaskGroups.groups.isEmpty)
        XCTAssertNotNil(authState.errorMessage)
    }

    @MainActor
    func testCoordinatorPreservesUnknownRemoteWarningWhenLocalDataDeletionAlsoFails() async {
        let suiteName = "NomaTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated user defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let userID = "possibly-deleted-user"
        let cleanupJournal = AccountDeletionCleanupJournal(userDefaults: defaults)
        cleanupJournal.armCleanupRequest(forUserID: userID)
        cleanupJournal.recordRemoteOutcome(.outcomeUnknown, forUserID: userID)
        cleanupJournal.markLocalSessionCleanupCompleted(forUserID: userID)
        let remoteError = AccountDeletionError.remoteOutcomeUnknown(
            reason: "Connection lost after request transmission",
            localSessionCleanupFailure: nil
        )
        let dailyTaskGroups = DailyTaskGroupStore(
            userID: userID,
            persistenceFactory: { _ in
                DailyTaskGroupStorage(dataStore: DeleteFailingDailyTaskGroupDataStore())
            }
        )
        let authState = AuthStateManager(
            authClient: AuthClientSpy(deleteAccountError: remoteError),
            appleSignInProvider: StubAppleSignInProvider()
        )
        authState.phase = .signedIn
        authState.storageUserID = userID

        let result = await AccountDeletionCoordinator.deleteAccount(
            authState: authState,
            dailyTaskGroups: dailyTaskGroups,
            cleanupJournal: cleanupJournal
        )

        let errorMessage = try? XCTUnwrap(authState.errorMessage)
        XCTAssertEqual(result.authResult, .remoteOutcomeUnknown)
        XCTAssertEqual(result.localDataDeletionError, .deleteFailed)
        XCTAssertFalse(result.completedCleanly)
        XCTAssertEqual(cleanupJournal.pendingUserID, userID)
        XCTAssertEqual(cleanupJournal.pendingCleanup?.requiresLocalSessionCleanup, false)
        XCTAssertEqual(cleanupJournal.pendingCleanup?.requiresTaskDataCleanup, true)
        XCTAssertTrue(errorMessage?.hasPrefix(remoteError.localizedDescription) == true)
        XCTAssertTrue(
            errorMessage?.contains(
                String(localized: "auth.delete-account.additional-local-data-cleanup-error")
            ) == true
        )
        XCTAssertFalse(errorMessage?.contains("The account was deleted") == true)
    }

    @MainActor
    func testCoordinatorDoesNotReportCleanCompletionWhenAppDataDeletionFails() async {
        let suiteName = "NomaTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated user defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let userID = "deleted-user"
        let cleanupJournal = AccountDeletionCleanupJournal(userDefaults: defaults)
        cleanupJournal.armCleanupRequest(forUserID: userID)
        cleanupJournal.recordRemoteOutcome(.deletionConfirmed, forUserID: userID)
        cleanupJournal.markLocalSessionCleanupCompleted(forUserID: userID)
        let dailyTaskGroups = DailyTaskGroupStore(
            userID: userID,
            persistenceFactory: { _ in
                DailyTaskGroupStorage(dataStore: DeleteFailingDailyTaskGroupDataStore())
            }
        )
        let authState = AuthStateManager(
            authClient: AuthClientSpy(),
            appleSignInProvider: StubAppleSignInProvider()
        )
        authState.phase = .signedIn
        authState.storageUserID = userID

        let result = await AccountDeletionCoordinator.deleteAccount(
            authState: authState,
            dailyTaskGroups: dailyTaskGroups,
            cleanupJournal: cleanupJournal
        )

        XCTAssertEqual(result.authResult, .deleted)
        XCTAssertEqual(result.localDataDeletionError, .deleteFailed)
        XCTAssertFalse(result.completedCleanly)
        XCTAssertEqual(
            result.errorMessage(combining: nil),
            String(localized: "auth.delete-account.local-data-cleanup-error")
        )
        XCTAssertEqual(authState.errorMessage, result.errorMessage(combining: nil))
        XCTAssertEqual(dailyTaskGroups.persistenceError, .deleteFailed)
        XCTAssertEqual(cleanupJournal.pendingUserID, userID)
        XCTAssertEqual(cleanupJournal.pendingCleanup?.requiresLocalSessionCleanup, false)
        XCTAssertEqual(cleanupJournal.pendingCleanup?.requiresTaskDataCleanup, true)
    }

    @MainActor
    func testPendingLocalCleanupJournalRecoversAndClearsAfterRelaunch() async {
        let suiteName = "NomaTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated user defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let userID = "interrupted-deletion-user"
        let storageKey = DailyTaskGroupStorage.storageKey(forUserID: userID)
        let cleanupJournal = AccountDeletionCleanupJournal(userDefaults: defaults)
        let accountStore = DailyTaskGroupStore(userDefaults: defaults, userID: userID)
        accountStore.setReminders(
            [CreateReminder(text: "Private task")],
            forDayID: accountStore.todayID()
        )
        cleanupJournal.armCleanupRequest(forUserID: userID)
        XCTAssertNotNil(defaults.data(forKey: storageKey))

        let launchStore = DailyTaskGroupStore(userDefaults: defaults)
        let authClient = AuthClientSpy()
        let authState = AuthStateManager(
            authClient: authClient,
            appleSignInProvider: StubAppleSignInProvider()
        )
        let result = await AccountDeletionCoordinator.recoverPendingLocalCleanup(
            authState: authState,
            dailyTaskGroups: launchStore,
            cleanupJournal: cleanupJournal
        )

        XCTAssertEqual(result, .recovered)
        XCTAssertEqual(authClient.pendingAccountDeletionCleanupCallCount, 1)
        XCTAssertNil(defaults.data(forKey: storageKey))
        XCTAssertNil(cleanupJournal.pendingUserID)

        let repeatedResult = await AccountDeletionCoordinator.recoverPendingLocalCleanup(
            authState: authState,
            dailyTaskGroups: launchStore,
            cleanupJournal: cleanupJournal
        )
        XCTAssertEqual(repeatedResult, .nothingPending)
        XCTAssertEqual(authClient.pendingAccountDeletionCleanupCallCount, 1)
    }

    @MainActor
    func testLegacyCleanupMarkerConservativelyRetriesSessionAndTaskCleanup() async {
        let suiteName = "NomaTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated user defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let userID = "legacy-cleanup-user"
        defaults.set(userID, forKey: AccountDeletionCleanupJournal.storageKey)
        let cleanupJournal = AccountDeletionCleanupJournal(userDefaults: defaults)
        let authClient = AuthClientSpy()
        let authState = AuthStateManager(
            authClient: authClient,
            appleSignInProvider: StubAppleSignInProvider()
        )
        XCTAssertEqual(
            cleanupJournal.pendingCleanup,
            AccountDeletionCleanupJournalEntry(
                userID: userID,
                remoteState: .outcomeUnknown
            )
        )

        let result = await AccountDeletionCoordinator.recoverPendingLocalCleanup(
            authState: authState,
            dailyTaskGroups: DailyTaskGroupStore(userDefaults: defaults),
            cleanupJournal: cleanupJournal
        )

        XCTAssertEqual(result, .recovered)
        XCTAssertEqual(authClient.pendingAccountDeletionCleanupCallCount, 1)
        XCTAssertNil(cleanupJournal.pendingCleanup)
    }

    @MainActor
    func testPendingLocalCleanupJournalSurvivesFailedRelaunchRecovery() async {
        let suiteName = "NomaTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated user defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let userID = "interrupted-deletion-user"
        let cleanupJournal = AccountDeletionCleanupJournal(userDefaults: defaults)
        cleanupJournal.armCleanupRequest(forUserID: userID)
        let launchStore = DailyTaskGroupStore(
            persistenceFactory: { _ in
                DailyTaskGroupStorage(dataStore: DeleteFailingDailyTaskGroupDataStore())
            }
        )
        let authClient = AuthClientSpy()
        let authState = AuthStateManager(
            authClient: authClient,
            appleSignInProvider: StubAppleSignInProvider()
        )

        let result = await AccountDeletionCoordinator.recoverPendingLocalCleanup(
            authState: authState,
            dailyTaskGroups: launchStore,
            cleanupJournal: cleanupJournal
        )

        XCTAssertEqual(
            result,
            .failed(localSessionCleanupFailure: nil, taskDataCleanupFailure: .deleteFailed)
        )
        XCTAssertEqual(authClient.pendingAccountDeletionCleanupCallCount, 1)
        XCTAssertEqual(cleanupJournal.pendingUserID, userID)
        XCTAssertEqual(cleanupJournal.pendingCleanup?.requiresLocalSessionCleanup, false)
        XCTAssertEqual(cleanupJournal.pendingCleanup?.requiresTaskDataCleanup, true)
    }

    @MainActor
    func testPendingSessionCleanupRetriesWithoutRepeatingCompletedTaskCleanup() async {
        let suiteName = "NomaTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated user defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let userID = "session-retry-user"
        let cleanupJournal = AccountDeletionCleanupJournal(userDefaults: defaults)
        cleanupJournal.armCleanupRequest(forUserID: userID)
        cleanupJournal.recordRemoteOutcome(.outcomeUnknown, forUserID: userID)

        let authClient = AuthClientSpy(
            pendingAccountDeletionCleanupError: TestAuthError.pendingCleanupRejected
        )
        let authState = AuthStateManager(
            authClient: authClient,
            appleSignInProvider: StubAppleSignInProvider()
        )
        let dailyTaskGroups = DailyTaskGroupStore(userDefaults: defaults)

        let firstResult = await AccountDeletionCoordinator.recoverPendingLocalCleanup(
            authState: authState,
            dailyTaskGroups: dailyTaskGroups,
            cleanupJournal: cleanupJournal
        )

        XCTAssertEqual(
            firstResult,
            .failed(
                localSessionCleanupFailure: TestAuthError.pendingCleanupRejected.localizedDescription,
                taskDataCleanupFailure: nil
            )
        )
        XCTAssertEqual(authClient.pendingAccountDeletionCleanupCallCount, 1)
        XCTAssertEqual(
            cleanupJournal.pendingCleanup,
            AccountDeletionCleanupJournalEntry(
                userID: userID,
                remoteState: .outcomeUnknown,
                requiresLocalSessionCleanup: true,
                requiresTaskDataCleanup: false
            )
        )

        authClient.pendingAccountDeletionCleanupError = nil
        let secondResult = await AccountDeletionCoordinator.recoverPendingLocalCleanup(
            authState: authState,
            dailyTaskGroups: dailyTaskGroups,
            cleanupJournal: cleanupJournal
        )

        XCTAssertEqual(secondResult, .recovered)
        XCTAssertEqual(authClient.pendingAccountDeletionCleanupCallCount, 2)
        XCTAssertNil(cleanupJournal.pendingCleanup)
    }

    @MainActor
    func testStartupBlocksAuthWhenTaskCleanupRemainsPending() async {
        let suiteName = "NomaTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated user defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let userID = "task-cleanup-blocked-user"
        let cleanupJournal = AccountDeletionCleanupJournal(userDefaults: defaults)
        cleanupJournal.armCleanupRequest(forUserID: userID)
        cleanupJournal.recordRemoteOutcome(.deletionConfirmed, forUserID: userID)
        cleanupJournal.markLocalSessionCleanupCompleted(forUserID: userID)
        let authClient = AuthClientSpy()
        let authState = AuthStateManager(
            authClient: authClient,
            appleSignInProvider: StubAppleSignInProvider()
        )
        let dailyTaskGroups = DailyTaskGroupStore(
            persistenceFactory: { _ in
                DailyTaskGroupStorage(dataStore: DeleteFailingDailyTaskGroupDataStore())
            }
        )

        await authState.startAfterRecoveringPendingAccountDeletion(
            dailyTaskGroups: dailyTaskGroups,
            cleanupJournal: cleanupJournal
        )

        XCTAssertTrue(authState.isAccountDeletionRecoveryBlocked)
        XCTAssertFalse(authState.hasStarted)
        XCTAssertEqual(authState.phase, .signedOut)
        XCTAssertEqual(authClient.pendingAccountDeletionCleanupCallCount, 0)
        XCTAssertEqual(authClient.currentSessionSnapshotCallCount, 0)
        XCTAssertEqual(cleanupJournal.pendingUserID, userID)
        XCTAssertEqual(cleanupJournal.pendingCleanup?.requiresTaskDataCleanup, true)

        await authState.signInWithAppleFlow()
        XCTAssertTrue(authClient.signInWithAppleCalls.isEmpty)
    }

    @MainActor
    func testStartupTreatsCorruptAndFutureCleanupJournalsAsBlocking() async {
        let futureJournal = Data(
            #"{"schemaVersion":99,"userID":"future-user","remoteState":"requestInFlight","requiresLocalSessionCleanup":true,"requiresTaskDataCleanup":true}"#.utf8
        )
        let cases: [(data: Data, error: AccountDeletionCleanupJournalError)] = [
            (Data("not-json".utf8), .malformedStoredJournal),
            (futureJournal, .unsupportedSchemaVersion(99))
        ]

        for testCase in cases {
            let suiteName = "NomaTests-\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                return XCTFail("Could not create isolated user defaults")
            }
            defer { defaults.removePersistentDomain(forName: suiteName) }
            defaults.set(testCase.data, forKey: AccountDeletionCleanupJournal.storageKey)

            let cleanupJournal = AccountDeletionCleanupJournal(userDefaults: defaults)
            let authClient = AuthClientSpy()
            let authState = AuthStateManager(
                authClient: authClient,
                appleSignInProvider: StubAppleSignInProvider()
            )

            await authState.startAfterRecoveringPendingAccountDeletion(
                dailyTaskGroups: DailyTaskGroupStore(userDefaults: defaults),
                cleanupJournal: cleanupJournal
            )

            XCTAssertEqual(cleanupJournal.state, .invalid(testCase.error))
            XCTAssertEqual(
                defaults.data(forKey: AccountDeletionCleanupJournal.storageKey),
                testCase.data
            )
            XCTAssertTrue(authState.isAccountDeletionRecoveryBlocked)
            XCTAssertFalse(authState.hasStarted)
            XCTAssertEqual(authState.phase, .signedOut)
            XCTAssertEqual(authClient.currentSessionSnapshotCallCount, 0)
            XCTAssertEqual(authClient.authStateSnapshotsCallCount, 0)

            await authState.signInWithAppleFlow()
            XCTAssertTrue(authClient.signInWithAppleCalls.isEmpty)
        }
    }

    @MainActor
    func testStartupTreatsEmptyLegacyCleanupJournalAsBlocking() async {
        let suiteName = "NomaTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated user defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("", forKey: AccountDeletionCleanupJournal.storageKey)

        let cleanupJournal = AccountDeletionCleanupJournal(userDefaults: defaults)
        let authClient = AuthClientSpy()
        let authState = AuthStateManager(
            authClient: authClient,
            appleSignInProvider: StubAppleSignInProvider()
        )

        await authState.startAfterRecoveringPendingAccountDeletion(
            dailyTaskGroups: DailyTaskGroupStore(userDefaults: defaults),
            cleanupJournal: cleanupJournal
        )

        XCTAssertEqual(cleanupJournal.state, .invalid(.malformedStoredJournal))
        XCTAssertEqual(
            defaults.string(forKey: AccountDeletionCleanupJournal.storageKey),
            ""
        )
        XCTAssertTrue(authState.isAccountDeletionRecoveryBlocked)
        XCTAssertFalse(authState.hasStarted)
        XCTAssertEqual(authClient.currentSessionSnapshotCallCount, 0)
    }

    @MainActor
    func testStartupBlocksAuthAndAppleSignInUntilPendingSessionCleanupRecovers() async {
        let suiteName = "NomaTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Could not create isolated user defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let userID = "blocked-launch-user"
        let cleanupJournal = AccountDeletionCleanupJournal(userDefaults: defaults)
        cleanupJournal.armCleanupRequest(forUserID: userID)
        cleanupJournal.recordRemoteOutcome(.deletionConfirmed, forUserID: userID)

        let authClient = AuthClientSpy(
            pendingAccountDeletionCleanupError: TestAuthError.pendingCleanupRejected
        )
        let authState = AuthStateManager(
            authClient: authClient,
            appleSignInProvider: StubAppleSignInProvider()
        )
        let dailyTaskGroups = DailyTaskGroupStore(userDefaults: defaults)
        let pendingCleanupMessage = String(
            localized: "auth.delete-account.pending-local-data-cleanup-error"
        )

        await authState.startAfterRecoveringPendingAccountDeletion(
            dailyTaskGroups: dailyTaskGroups,
            cleanupJournal: cleanupJournal
        )

        XCTAssertTrue(authState.isAccountDeletionRecoveryBlocked)
        XCTAssertFalse(authState.hasStarted)
        XCTAssertEqual(authState.phase, .signedOut)
        XCTAssertEqual(authState.errorMessage, pendingCleanupMessage)
        XCTAssertEqual(authClient.currentSessionSnapshotCallCount, 0)
        XCTAssertEqual(authClient.authStateSnapshotsCallCount, 0)

        await authState.signInWithAppleFlow()
        XCTAssertFalse(authState.isSigningIn)
        XCTAssertTrue(authClient.signInWithAppleCalls.isEmpty)

        authClient.pendingAccountDeletionCleanupError = nil
        await authState.startAfterRecoveringPendingAccountDeletion(
            dailyTaskGroups: dailyTaskGroups,
            cleanupJournal: cleanupJournal
        )
        await allowAuthObserverToRun()

        XCTAssertFalse(authState.isAccountDeletionRecoveryBlocked)
        XCTAssertTrue(authState.hasStarted)
        XCTAssertEqual(authState.phase, .signedOut)
        XCTAssertNil(authState.errorMessage)
        XCTAssertNil(cleanupJournal.pendingCleanup)
        XCTAssertEqual(authClient.pendingAccountDeletionCleanupCallCount, 2)
        XCTAssertEqual(authClient.currentSessionSnapshotCallCount, 1)
        XCTAssertEqual(authClient.authStateSnapshotsCallCount, 1)
    }
}

private func allowAuthObserverToRun() async {
    await Task.yield()
    try? await Task.sleep(nanoseconds: 1_000_000)
}

@MainActor
private final class AuthSessionLifecycleSpy: AuthSessionLifecycle {
    private(set) var activationCallCount = 0
    private(set) var clearCallCount = 0

    func activateAuthenticatedSession() {
        activationCallCount += 1
    }

    func clearAfterAuthenticationEnds() {
        clearCallCount += 1
    }
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

@MainActor
private final class SuspendedAppleSignInProvider: AppleSignInProviding {
    private var continuation: CheckedContinuation<AppleSignInCredential, Never>?

    var isWaitingForResume: Bool { continuation != nil }

    func requestCredential() async throws -> AppleSignInCredential {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resume() {
        continuation?.resume(returning: AppleSignInCredential(
            identityToken: "identity-token",
            nonce: "nonce",
            fullName: nil
        ))
        continuation = nil
    }
}

@MainActor
private final class AuthClientSpy: AuthClient {
    let initialSnapshot: AuthSessionSnapshot
    let streamSnapshots: [AuthSessionSnapshot]
    let signInSnapshot: AuthSessionSnapshot
    let signInError: Error?
    let signOutError: Error?
    let deleteAccountError: Error?
    let keepsAuthStateStreamOpen: Bool
    var pendingAccountDeletionCleanupError: Error?
    private var authStateContinuation: AsyncStream<AuthSessionSnapshot>.Continuation?

    private(set) var currentSessionSnapshotCallCount = 0
    private(set) var authStateSnapshotsCallCount = 0
    private(set) var signInWithAppleCalls: [(idToken: String, nonce: String)] = []
    private(set) var signOutCallCount = 0
    private(set) var deleteAccountCallCount = 0
    private(set) var pendingAccountDeletionCleanupCallCount = 0

    init(
        initialSnapshot: AuthSessionSnapshot? = nil,
        streamSnapshots: [AuthSessionSnapshot] = [],
        signInSnapshot: AuthSessionSnapshot? = nil,
        signInError: Error? = nil,
        signOutError: Error? = nil,
        deleteAccountError: Error? = nil,
        pendingAccountDeletionCleanupError: Error? = nil,
        keepsAuthStateStreamOpen: Bool = false
    ) {
        self.initialSnapshot = initialSnapshot ?? AuthSessionSnapshot(isSignedIn: false)
        self.streamSnapshots = streamSnapshots
        self.signInSnapshot = signInSnapshot ?? AuthSessionSnapshot(isSignedIn: true)
        self.signInError = signInError
        self.signOutError = signOutError
        self.deleteAccountError = deleteAccountError
        self.pendingAccountDeletionCleanupError = pendingAccountDeletionCleanupError
        self.keepsAuthStateStreamOpen = keepsAuthStateStreamOpen
    }

    func currentSessionSnapshot() async -> AuthSessionSnapshot {
        currentSessionSnapshotCallCount += 1
        return initialSnapshot
    }

    func authStateSnapshots() -> AsyncStream<AuthSessionSnapshot> {
        authStateSnapshotsCallCount += 1
        return AsyncStream { continuation in
            for snapshot in streamSnapshots {
                continuation.yield(snapshot)
            }
            if keepsAuthStateStreamOpen {
                authStateContinuation = continuation
            } else {
                continuation.finish()
            }
        }
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSessionSnapshot {
        signInWithAppleCalls.append((idToken, nonce))
        if let signInError { throw signInError }
        return signInSnapshot
    }

    func signOut() async throws {
        signOutCallCount += 1
        if let signOutError { throw signOutError }
    }

    func deleteAccount() async throws {
        deleteAccountCallCount += 1
        if let deleteAccountError { throw deleteAccountError }
    }

    func clearLocalSessionForPendingAccountDeletion() async throws {
        pendingAccountDeletionCleanupCallCount += 1
        if let pendingAccountDeletionCleanupError {
            throw pendingAccountDeletionCleanupError
        }
    }
}

private enum TestAuthError: LocalizedError {
    case signInRejected
    case deleteRejected
    case pendingCleanupRejected

    var errorDescription: String? {
        switch self {
        case .signInRejected:
            "Sign in rejected"
        case .deleteRejected:
            "Delete rejected"
        case .pendingCleanupRejected:
            "Pending cleanup rejected"
        }
    }
}

private struct DeleteFailingDailyTaskGroupDataStore: DailyTaskGroupDataStore {
    func read() throws -> Data? { nil }
    func write(_ data: Data) throws {}
    func delete() throws { throw DeleteFailingDataStoreError.rejected }
}

private enum DeleteFailingDataStoreError: Error {
    case rejected
}
