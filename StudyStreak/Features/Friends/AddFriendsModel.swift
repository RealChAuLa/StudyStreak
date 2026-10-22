import FirebaseFirestore
import Foundation
import Observation

@MainActor
@Observable
final class AddFriendsModel {
    let userID: String
    var query = ""
    var actionError: String?
    private(set) var results: [FriendProfile] = []
    private(set) var connections: [FriendConnection] = []
    private(set) var profiles: [String: FriendProfile] = [:]
    private(set) var isSearching = false
    private(set) var hasSearched = false
    private(set) var searchError: String?
    private(set) var requestError: String?
    private(set) var directoryError: String?
    private(set) var isLoadingRequests = true
    private(set) var isReady = false
    private(set) var busyUserIDs: Set<String> = []
    private(set) var failedProfileIDs: Set<String> = []

    @ObservationIgnored private let repository = FriendsRepository()
    @ObservationIgnored private var connectionListener: ListenerRegistration?
    @ObservationIgnored private var profileListeners: [String: ListenerRegistration] = [:]
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var searchGeneration = UUID()

    init(userID: String) { self.userID = userID }

    var incoming: [FriendConnection] {
        connections.filter { $0.status == .pending && $0.recipientID == userID }
    }

    var outgoing: [FriendConnection] {
        connections.filter { $0.status == .pending && $0.senderID == userID }
    }

    func connection(with otherID: String) -> FriendConnection? {
        connections.first { $0.otherUserID(for: userID) == otherID }
    }

    func start() async {
        stop()
        let current = generation
        requestError = nil
        directoryError = nil
        isLoadingRequests = true
        connectionListener = repository.observeConnections(for: userID) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self, self.generation == current else { return }
                self.isLoadingRequests = false
                switch result {
                case .success(let connections):
                    self.connections = connections
                    self.requestError = nil
                    self.observePendingProfiles(generation: current)
                case .failure(let error):
                    self.requestError = FriendsError.message(for: error)
                }
            }
        }
        do {
            // This also makes an account created by an older build searchable.
            try await ProfileRepository().synchronizeFriendProfile(uid: userID)
            try Task.checkCancellation()
            guard generation == current else { return }
            isReady = true
        } catch {
            guard !Task.isCancelled, generation == current else { return }
            directoryError = FriendsError.message(for: error)
        }
    }

    func stop() {
        generation = UUID()
        searchGeneration = UUID()
        connectionListener?.remove()
        connectionListener = nil
        profileListeners.values.forEach { $0.remove() }
        profileListeners.removeAll()
        failedProfileIDs.removeAll()
        isReady = false
    }

    func clearSearch() {
        searchGeneration = UUID()
        results = []
        searchError = nil
        hasSearched = false
        isSearching = false
    }

    func search() async {
        clearSearch()
        let prefix = FriendSearch.normalized(query)
        guard FriendSearch.isValidPrefix(prefix) else { return }
        let currentSearch = searchGeneration
        let current = generation
        isSearching = true
        do {
            try await Task.sleep(for: .milliseconds(350))
            let found = try await repository.search(usernamePrefix: prefix, excluding: userID)
            try Task.checkCancellation()
            guard generation == current, searchGeneration == currentSearch,
                  prefix == FriendSearch.normalized(query) else { return }
            results = found
            isSearching = false
            hasSearched = true
        } catch {
            guard !Task.isCancelled, generation == current, searchGeneration == currentSearch else { return }
            isSearching = false
            searchError = FriendsError.message(for: error)
        }
    }

    func perform(_ action: FriendAction, otherID: String) async {
        guard isReady, !busyUserIDs.contains(otherID) else { return }
        let current = generation
        busyUserIDs.insert(otherID)
        defer { busyUserIDs.remove(otherID) }
        do {
            if action == .send {
                try await repository.sendRequest(from: userID, to: otherID)
            } else {
                guard let connection = connection(with: otherID) else { throw FriendsError.requestChanged }
                try await repository.respond(to: connection, as: userID, action: action)
            }
        } catch {
            guard generation == current, !Task.isCancelled else { return }
            actionError = FriendsError.message(for: error)
        }
    }

    private func observePendingProfiles(generation current: UUID) {
        let needed = Set((incoming + outgoing).map { $0.otherUserID(for: userID) })
        for id in Array(profileListeners.keys) where !needed.contains(id) {
            profileListeners.removeValue(forKey: id)?.remove()
            profiles.removeValue(forKey: id)
            failedProfileIDs.remove(id)
        }
        for id in needed where profileListeners[id] == nil {
            profileListeners[id] = repository.observeProfile(userID: id) { [weak self] result in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == current,
                          self.profileListeners[id] != nil else { return }
                    switch result {
                    case .success(let profile):
                        self.profiles[id] = profile
                        if profile == nil { self.failedProfileIDs.insert(id) }
                        else { self.failedProfileIDs.remove(id) }
                    case .failure:
                        self.failedProfileIDs.insert(id)
                    }
                }
            }
        }
    }
}
