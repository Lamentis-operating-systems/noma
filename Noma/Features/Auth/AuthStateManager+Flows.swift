import Foundation

extension AuthStateManager {
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

    func deleteAccount() { Task { _ = await deleteAccountFlow() } }

    @discardableResult
    func deleteAccountFlow() async -> Bool {
        guard beginDeleteAccount() else { return false }
        defer { isDeletingAccount = false }

        do {
            try await authClient.deleteAccount()
            apply(AuthSessionSnapshot(isSignedIn: false))
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func beginSignInWithApple() -> Bool {
        guard !isSigningIn else { return false }
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
