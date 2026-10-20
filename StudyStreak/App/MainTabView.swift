import SwiftUI

struct MainTabView: View {
    let username: String

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                NavigationStack { HomeView(username: username) }
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
    }
}
