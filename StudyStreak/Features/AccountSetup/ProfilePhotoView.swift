import AVFoundation
import Foundation
import PhotosUI
import SwiftUI
import UIKit

struct ProfilePhotoView: View {
    let profile: UserProfile
    @Environment(AppSession.self) private var session
    @State private var selectedItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var isShowingLibrary = false
    @State private var isShowingCamera = false
    @State private var isShowingPhotoOptions = false
    @State private var isProcessing = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var needsCameraSettings = false

    private var isBusy: Bool { isProcessing || isSaving }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Add a profile photo")
                        .font(AppTypography.largeTitle)
                        .foregroundStyle(AppColors.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("Make your study circle feel a little closer.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondary)
                }

                Button { isShowingPhotoOptions = true } label: {
                    ProfileAvatar(initial: profile.initial, photoData: photoData)
                        .overlay(alignment: .bottomTrailing) {
                            Image("SetupCamera")
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(AppColors.onPrimary)
                                .frame(width: 23, height: 23)
                                .frame(width: 44, height: 44)
                                .background(AppColors.primary, in: Circle())
                                .offset(x: 2, y: 2)
                        }
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .accessibilityLabel(photoData == nil ? "Add profile photo" : "Change profile photo")
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                .padding(.bottom, 40)

                VStack(spacing: 12) {
                    PhotoActionButton(title: "Choose Photo", isTinted: true) { isShowingLibrary = true }
                    PhotoActionButton(title: "Take Photo", isTinted: false, action: takePhoto)
                    if isProcessing {
                        ProgressView("Preparing photo…")
                            .font(AppTypography.subheadline)
                            .tint(AppColors.primary)
                            .padding(.top, 8)
                    }
                }
                .disabled(isBusy)
            }
            .padding(.horizontal, 24)
            .padding(.top, 64)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppColors.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                PrimaryButton(title: isSaving ? "Saving…" : "Continue") { save(photo: photoData) }
                Button("Skip for now") { save(photo: nil) }
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.primary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(.plain)
            }
            .disabled(isBusy)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .background(AppColors.background)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarRole(.editor)
        .navigationBarBackButtonHidden(isSaving)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("A familiar face").font(AppTypography.headline).foregroundStyle(AppColors.text)
            }
        }
        .photosPicker(isPresented: $isShowingLibrary, selection: $selectedItem, matching: .images, preferredItemEncoding: .current)
        .task(id: selectedItem) {
            guard let selectedItem else { return }
            isProcessing = true
            defer { if !Task.isCancelled { isProcessing = false } }
            do {
                guard let data = try await selectedItem.loadTransferable(type: Data.self) else {
                    throw ProfilePhotoError.unsupported
                }
                try Task.checkCancellation()
                try await preparePhoto(data)
            } catch is CancellationError { }
            catch { errorMessage = error.localizedDescription }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker { data in
                isShowingCamera = false
                guard let data else { return }
                isProcessing = true
                Task {
                    defer { isProcessing = false }
                    do { try await preparePhoto(data) }
                    catch { errorMessage = error.localizedDescription }
                }
            }
            .ignoresSafeArea()
        }
        .confirmationDialog("Profile photo", isPresented: $isShowingPhotoOptions, titleVisibility: .visible) {
            Button("Choose Photo") { isShowingLibrary = true }
            Button("Take Photo", action: takePhoto)
            if photoData != nil {
                Button("Remove Photo", role: .destructive) { photoData = nil; selectedItem = nil }
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Couldn’t continue", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil; needsCameraSettings = false } })) {
            if needsCameraSettings {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            }
            Button("OK", role: .cancel) { }
        } message: { Text(errorMessage ?? "Please try again.") }
        .onAppear { if photoData == nil { photoData = profile.photoData } }
    }

    private func preparePhoto(_ data: Data) async throws {
        let compressed = try await Task.detached(priority: .userInitiated) {
            try ProfilePhotoProcessor.compress(data)
        }.value
        try Task.checkCancellation()
        photoData = compressed
    }

    private func takePhoto() {
        guard !isBusy else { return }
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = "A camera isn’t available on this device. You can choose a photo instead."
            return
        }
        Task {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                isShowingCamera = true
            case .notDetermined:
                if await AVCaptureDevice.requestAccess(for: .video) { isShowingCamera = true }
                else { cameraPermissionDenied() }
            default: cameraPermissionDenied()
            }
        }
    }

    private func cameraPermissionDenied() {
        needsCameraSettings = true
        errorMessage = "Allow camera access in Settings to take a profile photo, or choose a photo from your library."
    }

    private func save(photo: Data?) {
        guard !isBusy else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            do { try await session.completeSetup(photoData: photo) }
            catch { errorMessage = AccountError.message(for: error) }
        }
    }
}

#Preview("07 · Profile photo") {
    NavigationStack {
        ProfilePhotoView(profile: UserProfile(uid: "preview", username: "devinda.studies", photoBase64: nil, setupCompleted: false))
    }
    .environment(AppSession())
}

#Preview("Profile photo · Dark") {
    NavigationStack {
        ProfilePhotoView(profile: UserProfile(uid: "preview", username: "devinda.studies", photoBase64: nil, setupCompleted: false))
    }
    .environment(AppSession())
    .preferredColorScheme(.dark)
}

private struct PhotoActionButton: View {
    let title: String
    let isTinted: Bool
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(isTinted ? AppColors.tint : AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
                .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .opacity(isEnabled ? 1 : 0.5)
        .buttonStyle(.plain)
    }
}
