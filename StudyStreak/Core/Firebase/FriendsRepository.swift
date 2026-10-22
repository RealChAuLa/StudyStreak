import FirebaseFirestore
import Foundation

// Like ProfileRepository, this owns only thread-safe Firestore references.
nonisolated final class FriendsRepository: @unchecked Sendable {
    private let database = Firestore.firestore()

    func search(usernamePrefix: String, excluding userID: String) async throws -> [FriendProfile] {
        guard FriendSearch.isValidPrefix(usernamePrefix) else { return [] }
        let snapshot = try await database.collection("friendProfiles")
            .order(by: "username")
            .start(at: [usernamePrefix])
            .end(at: [usernamePrefix + "\u{f8ff}"])
            .limit(to: 20)
            .getDocuments(source: .server)
        return snapshot.documents.compactMap { Self.profile($0) }.filter { $0.id != userID }
    }

    func observeConnections(for userID: String,
                            onChange: @escaping @Sendable (Result<[FriendConnection], Error>) -> Void) -> ListenerRegistration {
        database.collection("friendships").whereField("memberIDs", arrayContains: userID)
            .addSnapshotListener { snapshot, error in
                if let error { onChange(.failure(error)); return }
                guard let snapshot else { return }
                let connections = snapshot.documents.compactMap { Self.connection($0) }
                    .sorted { $0.createdAt > $1.createdAt }
                onChange(.success(connections))
            }
    }

    func observeProfile(userID: String,
                        onChange: @escaping @Sendable (Result<FriendProfile?, Error>) -> Void) -> ListenerRegistration {
        database.collection("friendProfiles").document(userID).addSnapshotListener { snapshot, error in
            if let error { onChange(.failure(error)); return }
            onChange(.success(snapshot.flatMap(Self.profile)))
        }
    }

    func sendRequest(from userID: String, to otherID: String) async throws {
        guard userID != otherID else { throw FriendsError.selfRequest }
        let requestRef = database.collection("friendships").document("\(userID):\(otherID)")
        let reverseRef = database.collection("friendships").document("\(otherID):\(userID)")
        let targetRef = database.collection("friendProfiles").document(otherID)

        _ = try await database.runTransaction { transaction, errorPointer -> Any? in
            do {
                let outgoing = try transaction.getDocument(requestRef)
                let incoming = try transaction.getDocument(reverseRef)
                let target = try transaction.getDocument(targetRef)
                guard target.exists else { throw FriendsError.profileUnavailable }
                // Both directions are read before writing. Concurrent/crossed requests
                // retry against the existing record instead of creating a second one.
                guard !outgoing.exists && !incoming.exists else { return nil }
                transaction.setData([
                    "senderID": userID, "recipientID": otherID,
                    "memberIDs": [userID, otherID], "status": "pending",
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: requestRef)
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }

    func respond(to connection: FriendConnection, as userID: String, action: FriendAction) async throws {
        let reference = database.collection("friendships").document(connection.id)
        _ = try await database.runTransaction { transaction, errorPointer -> Any? in
            do {
                let snapshot = try transaction.getDocument(reference)
                guard let current = Self.connection(snapshot), current.status == .pending else {
                    throw FriendsError.requestChanged
                }
                switch action {
                case .accept, .decline:
                    guard current.recipientID == userID else { throw FriendsError.requestChanged }
                case .cancel:
                    guard current.senderID == userID else { throw FriendsError.requestChanged }
                case .send:
                    throw FriendsError.requestChanged
                }
                if action == .accept {
                    transaction.updateData([
                        "status": "accepted", "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: reference)
                } else {
                    transaction.deleteDocument(reference)
                }
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }

    private static func profile(_ snapshot: DocumentSnapshot) -> FriendProfile? {
        guard let data = snapshot.data(), let username = data["username"] as? String,
              UsernameRules.isValid(username), data["uid"] as? String == snapshot.documentID else { return nil }
        return FriendProfile(id: snapshot.documentID, username: username,
                             displayName: DisplayNameRules.resolved(data["displayName"] as? String ?? "", username: username),
                             photoBase64: data["photoBase64"] as? String)
    }

    private static func connection(_ snapshot: DocumentSnapshot) -> FriendConnection? {
        guard let data = snapshot.data(), let sender = data["senderID"] as? String,
              let recipient = data["recipientID"] as? String,
              let statusValue = data["status"] as? String,
              let status = FriendConnection.Status(rawValue: statusValue) else { return nil }
        return FriendConnection(id: snapshot.documentID, senderID: sender, recipientID: recipient,
                                status: status, createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast)
    }
}

nonisolated enum FriendsError: LocalizedError {
    case selfRequest, profileUnavailable, requestChanged

    var errorDescription: String? {
        switch self {
        case .selfRequest: "That’s your own account. Search for a friend’s username."
        case .profileUnavailable: "This profile isn’t available right now. Try searching again."
        case .requestChanged: "This request has already changed. Check the updated requests and try again."
        }
    }

    static func message(for error: Error) -> String {
        let value = error as NSError
        guard value.domain == FirestoreErrorDomain else { return error.localizedDescription }
        switch FirestoreErrorCode.Code(rawValue: value.code) {
        case .unavailable, .deadlineExceeded:
            return "Couldn’t connect. Check your internet connection and try again."
        case .permissionDenied:
            return "Friends aren’t available right now. Please try again later."
        case .unauthenticated:
            return "Please sign in again to continue."
        default:
            return "Couldn’t update friends. Please try again."
        }
    }
}
