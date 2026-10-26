import FirebaseFirestore
import Foundation

// Deletion uses authenticated transactions, which fail offline instead of queuing old writes.
nonisolated final class AccountDeletionRepository: @unchecked Sendable {
    private let database = Firestore.firestore()

    static func message(for error: Error) -> String {
        if error is AccountDeletionError { return error.localizedDescription }
        if (error as NSError).domain == "FIRAuthErrorDomain" { return AccountError.message(for: error) }
        return "Couldn’t finish deleting your account. Check your connection and try again."
    }

    func eraseCloudData(userID: String, fallbackUsername: String?) async throws {
        let user = database.collection("users").document(userID)
        let directory = database.collection("friendProfiles").document(userID)
        let preferences = database.collection("leaderboardPreferences").document(userID)
        let summary = database.collection("leaderboardStats").document(userID)
        // Profile, public mirror, username claim and study aggregate disappear atomically.
        _ = try await database.runTransaction { transaction, errorPointer -> Any? in
            do {
                let profile = try transaction.getDocument(user)
                let publicProfile = try transaction.getDocument(directory)
                let preference = try transaction.getDocument(preferences)
                let stats = try transaction.getDocument(summary)
                let name = profile.data()?["username"] as? String
                    ?? publicProfile.data()?["username"] as? String ?? fallbackUsername
                var nameToRemove: DocumentReference?
                if let name, UsernameRules.isValid(name) {
                    let reference = user.firestore.collection("usernames").document(name)
                    let claim = try transaction.getDocument(reference)
                    if claim.data()?["uid"] as? String == userID { nameToRemove = reference }
                    else if profile.exists { throw AccountDeletionError.cloudCleanup }
                }
                // All reads precede writes, including reads of documents already removed by a retry.
                if let nameToRemove { transaction.deleteDocument(nameToRemove) }
                if publicProfile.exists { transaction.deleteDocument(directory) }
                if preference.exists { transaction.deleteDocument(preferences) }
                if stats.exists { transaction.deleteDocument(summary) }
                if profile.exists { transaction.deleteDocument(user) }
                return nil
            } catch { errorPointer?.pointee = error as NSError; return nil }
        }
        // New requests require an existing public profile, so this final pass drains requests
        // that arrived just before the profile transaction without allowing new ones.
        try await eraseFriendships(userID: userID)
    }

    private func eraseFriendships(userID: String) async throws {
        let query = database.collection("friendships")
            .whereField("memberIDs", arrayContains: userID).limit(to: 10)
        while true {
            let page = try await query.getDocuments(source: .server)
            guard !page.documents.isEmpty else { break }
            let references = page.documents.map(\.reference)
            _ = try await database.runTransaction { transaction, errorPointer -> Any? in
                do {
                    let documents = try references.map { try transaction.getDocument($0) }
                    for document in documents where document.exists {
                        guard (document.data()?["memberIDs"] as? [String])?.contains(userID) == true else {
                            throw AccountDeletionError.accountChanged
                        }
                        transaction.deleteDocument(document.reference)
                    }
                    return nil
                } catch { errorPointer?.pointee = error as NSError; return nil }
            }
        }

    }
}
