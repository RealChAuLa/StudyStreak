import Foundation
import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(AppSession.self) private var session
    @Environment(StudySessionTracker.self) private var tracker
    @State private var errorMessage: String?
    @State private var errorTitle = "Couldn’t load profile"
    @State private var isEditingProfile = false
    @State private var isDeletingAccount = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            ProfileContent(
                profile: session.profile,
                allTimeSeconds: tracker.loadError == nil ? tracker.totalSeconds(at: context.date) : nil,
                onSignOut: {
                    do {
                        try session.signOut()
                    } catch {
                        errorTitle = "Couldn’t log out"
                        errorMessage = AccountError.message(for: error)
                    }
                },
                onEditProfile: { isEditingProfile = true },
                onDeleteAccount: { isDeletingAccount = true }
            )
        }
        .task(id: session.uid) {
            // Refresh photos from the server while retaining the cached profile offline.
            guard session.uid != nil else { return }
            try? await session.refreshProfile()
        }
        .refreshable {
            tracker.reload()
            do { try await session.refreshProfile() }
            catch { errorTitle = "Couldn’t refresh profile"; errorMessage = AccountError.message(for: error) }
        }
        .sheet(isPresented: $isEditingProfile) {
            if let profile = session.profile {
                EditProfileView(profile: profile)
                    .presentationDetents([.height(660), .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(24)
            }
        }
        .sheet(isPresented: $isDeletingAccount) {
            DeleteAccountView()
        }
        .alert(errorTitle, isPresented: Binding(
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
    var allTimeSeconds: TimeInterval? = 0
    let onSignOut: () -> Void
    var onEditProfile: () -> Void = { }
    var onDeleteAccount: (() -> Void)? = nil
    @Environment(\.studyUserID) private var ownerID
    @State private var routineRevision = UUID()
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system.rawValue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                identityCard

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
                    LeaderboardVisibilityRow(ownerID: ownerID).id(ownerID)
                }
                .profileCard()

                sectionTitle("Your routine")
                ProfileRoutineSection(ownerID: ownerID).id("\(ownerID)-\(routineRevision)")

                sectionTitle("Preferences")
                VStack(spacing: 0) {
                    NavigationLink {
                        AppearanceView(displayName: profile?.displayName ?? "Your profile")
                    } label: {
                        settingsRow("Appearance", icon: "ProfileSun", value: (AppAppearance(rawValue: appearance) ?? .system).title)
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(AppColors.border)
                    Button(action: onEditProfile) {
                        settingsRow("Edit Profile", icon: "ProfilePerson")
                    }
                    .buttonStyle(.plain)
                    .disabled(profile == nil)
                }
                .profileCard()

                sectionTitle("Your data")
                ProfileBackupSection(ownerID: ownerID) { routineRevision = UUID() }
                    .id(ownerID)

                Button(role: .destructive, action: onSignOut) {
                    Text("Sign Out")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.danger)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(AppColors.warm, in: RoundedRectangle(cornerRadius: 16))
                        .contentShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                Button(role: .destructive) { onDeleteAccount?() } label: {
                    Text("Delete Account").font(AppTypography.headline)
                        .foregroundStyle(AppColors.danger)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain).disabled(profile == nil || onDeleteAccount == nil)

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
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Profile")
    }

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ProfileAvatar(initial: profile?.initial ?? "?", photoData: profile?.photoData, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile?.displayName ?? "Your profile")
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
            }
            Divider().overlay(AppColors.border)
            HStack(spacing: 16) {
                Text(allTimeSeconds.map(StudyTime.duration) ?? "Unavailable")
                    .font(AppTypography.title2)
                    .foregroundStyle(AppColors.text)
                Spacer(minLength: 0)
                Text("all-time focus")
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppColors.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(allTimeSeconds.map { "\(StudyTime.duration($0)) of all-time focus" }
                                ?? "Couldn’t load all-time focus")
        }
        .profileCard()
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(AppTypography.caption.weight(.semibold))
            .foregroundStyle(AppColors.secondary)
            .accessibilityAddTraits(.isHeader)
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
