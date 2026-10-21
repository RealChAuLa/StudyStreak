import SwiftUI

nonisolated private struct StudyUserIDKey: EnvironmentKey {
    static let defaultValue = ""
}

extension EnvironmentValues {
    var studyUserID: String {
        get { self[StudyUserIDKey.self] }
        set { self[StudyUserIDKey.self] = newValue }
    }
}
