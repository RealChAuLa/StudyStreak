import SwiftUI

struct MainTabView: View {
    let displayName: String
    let userID: String
    @Environment(StudyRuntime.self) private var runtime
    @State private var selectedTab: StudyTab = .home
    @State private var homePath = NavigationPath()

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
        .onChange(of: runtime.homeNavigationRequest) { _, _ in
            selectedTab = .home
            homePath = NavigationPath()
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: StudyTab.home) {
                NavigationStack(path: $homePath) { HomeView(displayName: displayName) }
            }
            Tab("Zones", systemImage: "mappin.circle", value: StudyTab.zones) {
                NavigationStack { ZonesView() }
            }
            Tab("Stats", systemImage: "chart.bar", value: StudyTab.stats) {
                NavigationStack { StatsView() }
            }
            Tab("Friends", systemImage: "person.2", value: StudyTab.friends) {
                NavigationStack { FriendsView() }
            }
            Tab("Profile", systemImage: "person.crop.circle", value: StudyTab.profile) {
                NavigationStack { ProfileView() }
            }
        }
        .id(runtime.homeNavigationRequest)
        .tint(AppColors.primary)
        .environment(\.studyUserID, userID)
    }
}

private enum StudyTab: Hashable { case home, zones, stats, friends, profile }
