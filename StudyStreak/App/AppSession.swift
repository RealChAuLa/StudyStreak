import FirebaseAuth
import FirebaseCore
import Foundation
import Observation

@MainActor
@Observable
final class AppSession {
    enum Phase: Equatable {
        case loading, signedOut, accountSetup, home, profileError, notConfigured
    }

    private(set) var phase: Phase = .loading
    private(set) var profile: UserProfile?
    private(set) var uid: String?
    private(set) var profileErrorMessage = ""
    var preferredAuthenticationMode: AuthenticationMode = .signUp

    @ObservationIgnored private var authentication: AuthenticationService?
    @ObservationIgnored private var profiles: ProfileRepository?
    @ObservationIgnored private var authListener: AuthStateDidChangeListenerHandle?
    @ObservationIgnored private var profileTask: Task<Void, Never>?

    init() {
        guard FirebaseApp.app() != nil else {
            phase = .notConfigured
            return
        }
        let service = AuthenticationService()
        authentication = service
        profiles = ProfileRepository()
        authListener = service.auth.addStateDidChangeListener { [weak self] _, user in
            let uid = user?.uid
            Task { @MainActor [weak self] in self?.loadProfile(for: uid) }
        }
    }

    func authenticate(email: String, password: String, mode: AuthenticationMode) async throws {
        guard let authentication else { throw AccountError.notConfigured }
        if mode == .signUp {
            try await authentication.signUp(email: email, password: password)
        } else {
            try await authentication.signIn(email: email, password: password)
        }
    }

    func signInWithGoogle() async throws {
        guard let authentication else { throw AccountError.notConfigured }
        try await authentication.signInWithGoogle()
    }

    func resetPassword(email: String) async throws {
        guard let authentication else { throw AccountError.notConfigured }
        try await authentication.sendPasswordReset(email: email)
    }

    func signOut() throws {
        guard let authentication else { throw AccountError.notConfigured }
        try authentication.signOut()
        profileTask?.cancel()
        preferredAuthenticationMode = .signIn
        uid = nil
        profile = nil
        phase = .signedOut
    }

    func retryProfile() { loadProfile(for: uid) }

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        guard let uid, let profiles else { throw AccountError.signedOut }
        return try await profiles.isUsernameAvailable(username, for: uid)
    }

    func reserveUsername(_ username: String) async throws {
        guard let userID = uid, let profiles else { throw AccountError.signedOut }
        let saved = try await profiles.reserveUsername(username, uid: userID)
        guard uid == userID else { throw AccountError.signedOut }
        profile = saved
    }

    func completeSetup(photoData: Data?) async throws {
        guard let userID = uid, let current = profile, let profiles else { throw AccountError.signedOut }
        try await profiles.completeSetup(uid: userID, photoData: photoData)
        guard uid == userID else { throw AccountError.signedOut }
        profile = UserProfile(
            uid: userID, username: current.username, displayName: current.displayName,
            photoBase64: photoData?.base64EncodedString(), setupCompleted: true
        )
        phase = .home
    }

    func updateProfile(for userID: String, username: String, displayName: String, photoData: Data?) async throws {
        guard uid == userID, let profiles else { throw AccountError.signedOut }
        let saved = try await profiles.updateProfile(uid: userID, username: username,
                                                     displayName: displayName, photoData: photoData)
        guard uid == userID else { throw AccountError.signedOut }
        profile = saved
    }

    func refreshProfile() async throws {
        guard let userID = uid, let profiles else { throw AccountError.signedOut }
        let previous = profile
        guard let saved = try await profiles.fetch(uid: userID, fromServer: true) else { throw AccountError.incompleteProfile }
        try Task.checkCancellation()
        guard uid == userID else { throw AccountError.signedOut }
        // A slow refresh must not replace a profile that was just saved locally.
        guard profile == previous else { return }
        profile = saved
    }

    private func loadProfile(for userID: String?) {
        profileTask?.cancel()
        uid = userID
        profile = nil
        guard let userID, let profiles else {
            phase = .signedOut
            return
        }
        phase = .loading
        profileTask = Task { [weak self] in
            do {
                let saved = try await profiles.fetch(uid: userID)
                guard !Task.isCancelled, let self, self.uid == userID else { return }
                self.profile = saved
                self.phase = saved?.setupCompleted == true ? .home : .accountSetup
            } catch {
                guard !Task.isCancelled, let self, self.uid == userID else { return }
                self.profileErrorMessage = AccountError.message(for: error)
                self.phase = .profileError
            }
        }
    }
}
