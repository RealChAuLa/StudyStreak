import SwiftUI

struct MainTabView: View {
    let displayName: String
    let userID: String
    @Environment(StudyRuntime.self) private var runtime

    var body: some View {
        Group {
            if let tracker = runtime.tracker, tracker.ownerID == userID {
                tabs.environment(tracker)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.background)
            }
        }
        .task(id: userID) { runtime.activate(userID) }
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
