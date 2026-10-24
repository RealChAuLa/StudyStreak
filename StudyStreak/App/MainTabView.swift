import Foundation
import SwiftData
import SwiftUI

struct MainTabView: View {
    let displayName: String
    let userID: String
    @Environment(AppSession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var tracker: StudySessionTracker?

    var body: some View {
        Group {
            if let tracker {
                tabs.environment(tracker)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.background)
            }
        }
        .task(id: userID) {
            if tracker?.ownerID != userID {
                tracker = StudySessionTracker(container: modelContext.container, ownerID: userID)
            }
            if let tracker {
                // Keep the current tracker alive through account-loading transitions.
                session.prepareForSignOut = { try tracker.pause() }
                tracker.requestSync()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                tracker?.refreshSettings()
                tracker?.requestSync()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            tracker?.refreshSettings()
        }
        .onDisappear {
            // Also handle authentication ending outside the app's Sign Out button.
            if session.uid != userID { try? tracker?.pause() }
        }
    }

    private var tabs: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                NavigationStack { HomeView(displayName: displayName) }
            }
            Tab("Zones", systemImage: "mappin.circle") {
                NavigationStack { ZonesView() }
            }
            Tab("Stats", systemImage: "chart.bar") {
                NavigationStack { StatsView() }
            }
            Tab("Friends", systemImage: "person.2") {
                NavigationStack { FriendsView() }
            }
            Tab("Profile", systemImage: "person.crop.circle") {
                NavigationStack { ProfileView() }
            }
        }
        .tint(AppColors.primary)
        .environment(\.studyUserID, userID)
    }
}
