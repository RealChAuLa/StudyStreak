import SwiftUI

struct AccountSetupView: View {
    @Environment(AppSession.self) private var session
    @State private var path: [Step] = []
    @State private var hasRestoredStep = false

    var body: some View {
        NavigationStack(path: $path) {
            UsernameView { path.append(.photo) }
                .navigationDestination(for: Step.self) { _ in
                    if let profile = session.profile { ProfilePhotoView(profile: profile) }
                }
        }
        .tint(AppColors.primary)
        .task {
            guard !hasRestoredStep else { return }
            hasRestoredStep = true
            if session.profile != nil { path = [.photo] }
        }
    }

    private enum Step: Hashable { case photo }
}
