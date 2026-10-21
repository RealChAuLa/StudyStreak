import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(AppSession.self) private var session
    @State private var errorMessage: String?

    var body: some View {
        ProfileContent(profile: session.profile) {
            do { try session.signOut() }
            catch { errorMessage = AccountError.message(for: error) }
        }
            .alert("Couldn’t log out", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
    }
}

private struct ProfileContent: View {
    let profile: UserProfile?
    let onSignOut: () -> Void
    @Environment(\.studyUserID) private var ownerID

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                identityCard

                sectionTitle("Your routine")
                VStack(spacing: 0) {
                    unavailableRow("Daily Goal", icon: "ProfileClock", value: "Not set")
                    Divider().overlay(AppColors.border)
                    unavailableRow("Notifications", icon: "ProfileBell")
                }
                .profileCard()

                sectionTitle("Your study world")
                VStack(alignment: .leading, spacing: 0) {
                    NavigationLink {
                        ZonesView()
                    } label: {
                        settingsRow("Study Zones", icon: "ProfileZone")
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(AppColors.border)
                    NavigationLink {
                        SubjectsView(ownerID: ownerID)
                    } label: {
                        settingsRow("Subjects", icon: "ProfileBook")
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(AppColors.border)
                    Toggle("Leaderboard visibility", isOn: .constant(false))
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.text)
                        .tint(AppColors.success)
                        .padding(.vertical, 12)
                        .disabled(true)
                        .accessibilityHint("Coming soon")
                    Text("Choose whether friends can see your weekly study time. Coming soon.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .profileCard()

                sectionTitle("Preferences")
                VStack(spacing: 0) {
                    unavailableRow("Appearance", icon: "ProfileSun", value: "System")
                    Divider().overlay(AppColors.border)
                    unavailableRow("Edit Profile", icon: "ProfilePerson")
                }
                .profileCard()

                Text("More profile settings are coming soon.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondary)

                Button(role: .destructive, action: onSignOut) {
                    Text("Sign Out")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.danger)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(AppColors.warm, in: RoundedRectangle(cornerRadius: 16))
                        .contentShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                Text("StudyStreak · A little focus, every day.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ProfileAvatar(initial: profile?.initial ?? "?", photoData: profile?.photoData, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile?.username ?? "Your profile")
                        .font(AppTypography.title2)
                        .foregroundStyle(AppColors.text)
                    if let profile {
                        Text("@\(profile.username)")
                            .font(AppTypography.subheadline)
                            .foregroundStyle(AppColors.secondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    // TODO: Present profile editing when that feature is implemented.
                } label: {
                    Image("ProfileEdit")
                        .resizable().scaledToFit().frame(width: 22, height: 22)
                        .foregroundStyle(AppColors.primary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(true)
                .accessibilityLabel("Edit profile")
                .accessibilityHint("Coming soon")
            }
            Divider().overlay(AppColors.border)
            HStack(spacing: 16) {
                // Session totals will be supplied by SwiftData in a later milestone.
                Text("—")
                    .font(AppTypography.title2)
                    .foregroundStyle(AppColors.text)
                Spacer(minLength: 0)
                Text("all-time focus")
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppColors.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("All-time focus is not available yet")
        }
        .profileCard()
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(AppTypography.caption.weight(.semibold))
            .foregroundStyle(AppColors.secondary)
            .accessibilityAddTraits(.isHeader)
    }

    private func unavailableRow(_ title: String, icon: String, value: String? = nil) -> some View {
        Button {
            // TODO: Connect this setting when its feature is implemented.
        } label: {
            settingsRow(title, icon: icon, value: value)
        }
        .buttonStyle(.plain)
        .disabled(true)
        .accessibilityHint("Coming soon")
    }

    private func settingsRow(_ title: String, icon: String, value: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(icon)
                .resizable().scaledToFit().frame(width: 22, height: 22)
                .foregroundStyle(AppColors.primary)
                .accessibilityHidden(true)
            Text(title)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let value {
                Text(value)
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppColors.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Image("ProfileChevron")
                .resizable().scaledToFit().frame(width: 16, height: 16)
                .foregroundStyle(AppColors.secondary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 48)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private extension View {
    func profileCard() -> some View {
        padding(16)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview("29 · Profile & settings") {
    NavigationStack {
        ProfileContent(profile: UserProfile(uid: "preview", username: "devinda.studies", photoBase64: nil, setupCompleted: true), onSignOut: {})
    }
    .tint(AppColors.primary)
    .environment(\.studyUserID, "preview")
    .modelContainer(for: StudySubject.self, inMemory: true)
}

#Preview("Profile · Dark") {
    NavigationStack {
        ProfileContent(profile: UserProfile(uid: "preview", username: "devinda.studies", photoBase64: nil, setupCompleted: true), onSignOut: {})
    }
    .tint(AppColors.primary)
    .environment(\.studyUserID, "preview")
    .modelContainer(for: StudySubject.self, inMemory: true)
    .preferredColorScheme(.dark)
}

#Preview("Profile · SE size", traits: .fixedLayout(width: 375, height: 667)) {
    NavigationStack {
        ProfileContent(profile: UserProfile(uid: "preview", username: "devinda.studies", photoBase64: nil, setupCompleted: true), onSignOut: {})
    }
    .tint(AppColors.primary)
    .environment(\.studyUserID, "preview")
    .modelContainer(for: StudySubject.self, inMemory: true)
}

#Preview("Profile · 17 Pro size", traits: .fixedLayout(width: 402, height: 874)) {
    NavigationStack {
        ProfileContent(profile: UserProfile(uid: "preview", username: "devinda.studies", photoBase64: nil, setupCompleted: true), onSignOut: {})
    }
    .tint(AppColors.primary)
    .environment(\.studyUserID, "preview")
    .modelContainer(for: StudySubject.self, inMemory: true)
}
