import SwiftUI

@main
@MainActor
struct StudyStreakWatchApp: App {
    @StateObject private var model = WatchSessionViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchSessionView(model: model)
                .environment(\.colorScheme, .dark)
                .onAppear { model.connect() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.refresh() }
                }
        }
    }
}

