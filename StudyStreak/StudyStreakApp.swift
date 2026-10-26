import FirebaseCore
import GoogleSignIn
import SwiftData
import SwiftUI
import UIKit

@main
struct StudyStreakApp: App {
    @UIApplicationDelegateAdaptor(StudyAppDelegate.self) private var appDelegate
    @State private var session: AppSession
    @State private var persistence: LocalPersistence
    @State private var runtime = StudyRuntime.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system.rawValue

    init() {
        if FirebaseApp.app() == nil,
           let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: path) {
            FirebaseApp.configure(options: options)
        }
        let persistence = LocalPersistence()
        let session = AppSession()
        _persistence = State(initialValue: persistence)
        _session = State(initialValue: session)
        // Region delivery must work before the authenticated SwiftUI screens appear,
        // including a system launch in the background for a location event.
        if let container = persistence.container {
            StudyRuntime.shared.configure(container: container, account: session)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = persistence.container {
                    ContentView()
                        .environment(session)
                        .environment(runtime)
                        .modelContainer(container)
                        .onAppear { runtime.configure(container: container, account: session) }
                } else {
                    ContentUnavailableView {
                        Label("Couldn’t open your study data", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text("Your saved data hasn’t been removed. Please try again.")
                    } actions: {
                        Button("Try Again") { persistence.load() }
                    }
                }
            }
            .preferredColorScheme((AppAppearance(rawValue: appearance) ?? .system).colorScheme)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { runtime.refresh() }
                else if phase == .background { runtime.publishWidgetProgress(forceReload: true) }
            }
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
                runtime.refreshCatalog()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.backgroundRefreshStatusDidChangeNotification)) { _ in
                runtime.refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                runtime.refresh()
                runtime.publishWidgetProgress(forceReload: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                runtime.tracker?.refreshSettings()
            }
            .onOpenURL { url in
                if StudyWidgetConfiguration.opensHome(url) { runtime.openHome() }
                else { _ = GIDSignIn.sharedInstance.handle(url) }
            }
        }
    }
}
