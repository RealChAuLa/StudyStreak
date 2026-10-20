import Foundation

nonisolated struct UserProfile: Equatable, Sendable {
    let uid: String
    let username: String
    let photoBase64: String?
    let setupCompleted: Bool

    var initial: String { String(username.prefix(1)).uppercased() }

    var photoData: Data? {
        guard let photoBase64, photoBase64.utf8.count <= 204_800 else { return nil }
        return Data(base64Encoded: photoBase64)
    }
}

nonisolated enum UsernameRules {
    static func canonical(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isValid(_ value: String) -> Bool {
        canonical(value).range(of: #"^[a-z0-9._]{3,20}$"#, options: .regularExpression) != nil
    }
}
