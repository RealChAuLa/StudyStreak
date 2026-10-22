import Observation
import SwiftData

@MainActor
@Observable
final class LocalPersistence {
    private(set) var container: ModelContainer?

    init() { load() }

    func load() {
        do {
            // A named store avoids reusing Xcode's old sample Item store.
            let configuration = ModelConfiguration("StudyStreakLocal", cloudKitDatabase: .none)
            container = try ModelContainer(for: StudySubject.self, StudyZone.self, configurations: configuration)
        } catch {
            // Keep the existing store intact and let the user retry opening it.
            container = nil
        }
    }
}
