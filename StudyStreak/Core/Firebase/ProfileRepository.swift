import FirebaseFirestore
import Foundation

// Firestore references are thread-safe; this repository has no mutable state.
nonisolated final class ProfileRepository: @unchecked Sendable {
    private let database = Firestore.firestore()

    func fetch(uid: String) async throws -> UserProfile? {
        let snapshot = try await database.collection("users").document(uid).getDocument()
        guard snapshot.exists else { return nil }
        guard let data = snapshot.data(), let username = data["username"] as? String,
              UsernameRules.isValid(username) else { throw AccountError.incompleteProfile }
        return UserProfile(
            uid: uid, username: username,
            photoBase64: data["photoBase64"] as? String,
            setupCompleted: data["setupCompleted"] as? Bool ?? false
        )
    }

    func isUsernameAvailable(_ username: String, for uid: String) async throws -> Bool {
        let name = UsernameRules.canonical(username)
        guard UsernameRules.isValid(name) else { return false }
        let snapshot = try await database.collection("usernames").document(name).getDocument(source: .server)
        return !snapshot.exists || snapshot.data()?["uid"] as? String == uid
    }

    func reserveUsername(_ username: String, uid: String) async throws -> UserProfile {
        let name = UsernameRules.canonical(username)
        guard UsernameRules.isValid(name) else { throw AccountError.invalidUsername }
        let userRef = database.collection("users").document(uid)
        let nameRef = database.collection("usernames").document(name)

        _ = try await database.runTransaction { transaction, errorPointer -> Any? in
            do {
                let user = try transaction.getDocument(userRef)
                let claim = try transaction.getDocument(nameRef)
                let oldName = user.data()?["username"] as? String
                if claim.exists && claim.data()?["uid"] as? String != uid {
                    throw AccountError.usernameTaken
                }
                if user.data()?["setupCompleted"] as? Bool == true && oldName != name {
                    throw AccountError.invalidUsername
                }
                // Read every document before making any writes; transactions may retry.
                var oldClaimRef: DocumentReference?
                if let oldName, oldName != name {
                    let reference = userRef.firestore.collection("usernames").document(oldName)
                    let previous = try transaction.getDocument(reference)
                    if previous.data()?["uid"] as? String == uid { oldClaimRef = reference }
                }
                if !claim.exists {
                    transaction.setData(["uid": uid, "createdAt": FieldValue.serverTimestamp()], forDocument: nameRef)
                }
                var fields: [String: Any] = [
                    "uid": uid, "username": name, "updatedAt": FieldValue.serverTimestamp()
                ]
                if !user.exists {
                    fields["createdAt"] = FieldValue.serverTimestamp()
                    fields["setupCompleted"] = false
                }
                transaction.setData(fields, forDocument: userRef, merge: true)
                if let oldClaimRef { transaction.deleteDocument(oldClaimRef) }
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
        guard let profile = try await fetch(uid: uid) else { throw AccountError.incompleteProfile }
        return profile
    }

    func completeSetup(uid: String, photoData: Data?) async throws {
        if let photoData, photoData.count > 150 * 1024 { throw ProfilePhotoError.tooLarge }
        let userRef = database.collection("users").document(uid)
        let photo: Any
        if let photoData { photo = photoData.base64EncodedString() }
        else { photo = FieldValue.delete() }
        // Transactions fail offline rather than leaving setup waiting on a queued write.
        _ = try await database.runTransaction { transaction, errorPointer -> Any? in
            do {
                let user = try transaction.getDocument(userRef)
                guard user.exists, let name = user.data()?["username"] as? String,
                      UsernameRules.isValid(name) else { throw AccountError.incompleteProfile }
                transaction.updateData([
                    "photoBase64": photo, "setupCompleted": true,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: userRef)
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }
}
