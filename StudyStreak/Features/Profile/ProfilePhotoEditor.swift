import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct ProfilePhotoEditor: View {
    let initial: String
    @Binding var photoData: Data?
    @Binding var isProcessing: Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var selectedItem: PhotosPickerItem?
    @State private var isShowingOptions = false
    @State private var isShowingLibrary = false
    @State private var isShowingCamera = false
    @State private var errorMessage: String?
    @State private var needsCameraSettings = false

    var body: some View {
        VStack(spacing: 8) {
            Button { isShowingOptions = true } label: {
                ProfileAvatar(initial: initial, photoData: photoData, size: 112)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change profile photo")
            Button("Change Photo") { isShowingOptions = true }
                .font(AppTypography.subheadline.weight(.medium))
                .foregroundStyle(AppColors.primary)
                .frame(minHeight: 44)
            if isProcessing { ProgressView("Preparing photo…").font(AppTypography.caption) }
        }
        .frame(maxWidth: .infinity)
        .disabled(isProcessing)
        .confirmationDialog("Profile photo", isPresented: $isShowingOptions, titleVisibility: .visible) {
            Button("Choose Photo") { isShowingLibrary = true }
            Button("Take Photo", action: takePhoto)
            if photoData != nil {
                Button("Remove Photo", role: .destructive) { photoData = nil; selectedItem = nil }
            }
            Button("Cancel", role: .cancel) { }
        }
        .photosPicker(isPresented: $isShowingLibrary, selection: $selectedItem,
                      matching: .images, preferredItemEncoding: .current)
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
        .alert("Couldn’t use photo", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil; needsCameraSettings = false } }
        )) {
            if needsCameraSettings {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            }
            Button("OK", role: .cancel) { }
        } message: { Text(errorMessage ?? "Please choose another photo.") }
    }

    private func preparePhoto(_ data: Data) async throws {
        let compressed = try await Task.detached(priority: .userInitiated) {
            try ProfilePhotoProcessor.compress(data)
        }.value
        try Task.checkCancellation()
        photoData = compressed
    }

    private func takePhoto() {
        guard isEnabled, !isProcessing else { return }
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = "A camera isn’t available on this device. You can choose a photo instead."
            return
        }
        Task {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: isShowingCamera = true
            case .notDetermined:
                if await AVCaptureDevice.requestAccess(for: .video) { isShowingCamera = true }
                else { cameraPermissionDenied() }
            default: cameraPermissionDenied()
            }
        }
    }

    private func cameraPermissionDenied() {
        needsCameraSettings = true
        errorMessage = "Allow camera access in Settings to take a profile photo, or choose one from your library."
    }
}
