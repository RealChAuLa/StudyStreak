import FirebaseFirestore
import Foundation
import Observation

@MainActor
@Observable
final class LeaderboardVisibilityModel {
    private(set) var isVisible = false
    private(set) var isLoaded = false
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    @ObservationIgnored private let userID: String
    @ObservationIgnored private var repository: LeaderboardRepository?
    @ObservationIgnored private var listener: ListenerRegistration?
    @ObservationIgnored private var generation = UUID()

    init(userID: String) { self.userID = userID }

    func start() {
        stop()
        guard !userID.isEmpty, userID != "preview" else { return }
        let repository = LeaderboardRepository()
        self.repository = repository
        let current = generation
        errorMessage = nil
        listener = repository.observeVisibility(userID: userID) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self, self.generation == current else { return }
                switch result {
                case .success(let value):
                    self.isVisible = value
                    self.isLoaded = true
                    self.errorMessage = nil
                case .failure(let error):
                    self.isLoaded = false
                    self.errorMessage = FriendsError.message(for: error)
                }
            }
        }
    }

    func stop() {
        generation = UUID()
        listener?.remove()
        listener = nil
        repository = nil
        isLoaded = false
        isSaving = false
    }

    func setVisible(_ value: Bool) async {
        guard isLoaded, !isSaving, value != isVisible, let repository else { return }
        let current = generation
        isSaving = true
        errorMessage = nil
        do {
            try await repository.setVisibility(userID: userID, isVisible: value)
            guard generation == current else { return }
            isVisible = value
            isSaving = false
        } catch {
            guard generation == current else { return }
            isSaving = false
            errorMessage = FriendsError.message(for: error)
        }
    }
}
