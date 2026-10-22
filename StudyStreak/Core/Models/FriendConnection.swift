import Foundation

nonisolated struct FriendProfile: Identifiable, Equatable, Sendable {
    let id: String
    let username: String
    let displayName: String
    let photoBase64: String?

    var initial: String { String(username.prefix(1)).uppercased() }
    var photoData: Data? {
        guard let photoBase64, photoBase64.utf8.count <= 204_800 else { return nil }
        return Data(base64Encoded: photoBase64)
    }
}

// An accepted request is the lasting friendship, ready for the future leaderboard.
nonisolated struct FriendConnection: Identifiable, Equatable, Sendable {
    enum Status: String, Equatable, Sendable { case pending, accepted }

    let id: String
    let senderID: String
    let recipientID: String
    let status: Status
    let createdAt: Date

    func otherUserID(for userID: String) -> String {
        senderID == userID ? recipientID : senderID
    }
}

nonisolated enum FriendAction: Equatable, Sendable { case send, accept, decline, cancel }

nonisolated enum FriendSearch {
    static func normalized(_ value: String) -> String {
        var name = UsernameRules.canonical(value)
        if name.hasPrefix("@") { name.removeFirst() }
        return name
    }

    static func isValidPrefix(_ value: String) -> Bool {
        value.range(of: #"^[a-z0-9._]{2,20}$"#, options: .regularExpression) != nil
    }
}
