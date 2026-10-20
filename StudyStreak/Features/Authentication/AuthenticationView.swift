import SwiftUI

struct AuthenticationView: View {
    let onReplaySetup: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mode: AuthenticationMode

    init(initialMode: AuthenticationMode = .signUp, onReplaySetup: (() -> Void)? = nil) {
        self.onReplaySetup = onReplaySetup
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        ZStack {
            AuthenticationScreen(mode: mode, onReplaySetup: onReplaySetup) {
                mode = mode.other
            }
            .id(mode)
            .transition(.opacity)
        }
        .background(AppColors.background.ignoresSafeArea())
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: mode)
    }
}

#Preview("05a · Sign up") {
    AuthenticationView()
}

#Preview("05b · Sign in") {
    AuthenticationView(initialMode: .signIn)
}

#Preview("Sign up · Dark") {
    AuthenticationView()
        .preferredColorScheme(.dark)
}

#Preview("Sign in · Dark") {
    AuthenticationView(initialMode: .signIn)
        .preferredColorScheme(.dark)
}

#Preview("Authentication · Large text") {
    AuthenticationView()
        .environment(\.dynamicTypeSize, .accessibility3)
}
