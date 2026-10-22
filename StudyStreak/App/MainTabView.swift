import SwiftUI

struct MainTabView: View {
    let displayName: String
    let userID: String

    var body: some View {
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
