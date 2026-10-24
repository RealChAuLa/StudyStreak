import FirebaseFirestore
import Foundation
import Observation

@MainActor
@Observable
final class LeaderboardModel {
    let userID: String
    let visibility: LeaderboardVisibilityModel
    private(set) var isLoading = true
    private(set) var connectionError: String?
    private(set) var failedParts: Set<String> = []
    private var peers: [String: Peer] = [:]
    private var ownSummary: StudySummary?

    @ObservationIgnored private var friends: FriendsRepository?
    @ObservationIgnored private var repository: LeaderboardRepository?
    @ObservationIgnored private var connectionListener: ListenerRegistration?
    @ObservationIgnored private var ownListener: ListenerRegistration?
    @ObservationIgnored private var profileListeners: [String: ListenerRegistration] = [:]
    @ObservationIgnored private var visibilityListeners: [String: ListenerRegistration] = [:]
    @ObservationIgnored private var summaryListeners: [String: ListenerRegistration] = [:]
    @ObservationIgnored private var peerTokens: [String: UUID] = [:]
    @ObservationIgnored private var summaryTokens: [String: UUID] = [:]
    @ObservationIgnored private var generation = UUID()

    private struct Peer {
        var profile: FriendProfile?
        var isVisible: Bool?
        var summary: StudySummary?
    }

    init(userID: String) {
        self.userID = userID
        visibility = LeaderboardVisibilityModel(userID: userID)
    }

    var friendCount: Int { peers.count }
    var visibleFriendCount: Int { peers.values.filter { $0.isVisible == true }.count }
    var isLoadingFriends: Bool {
        peers.contains { id, peer in
            !failedParts.contains("\(id):profile") && !failedParts.contains("\(id):visibility")
                && (peer.profile == nil || peer.isVisible == nil)
        }
    }

    func entries(ownProfile: UserProfile, period: LeaderboardPeriod, now: Date) -> [LeaderboardEntry] {
        let own = FriendProfile(id: ownProfile.uid, username: ownProfile.username,
                                displayName: ownProfile.displayName, photoBase64: ownProfile.photoBase64)
        var entries = [LeaderboardEntry(
            profile: own, seconds: ownSummary?.seconds(for: period, now: now),
            streak: ownSummary?.currentStreak(now: now), isCurrentUser: true,
            isPrivate: !visibility.isLoaded || !visibility.isVisible
        )]
        for peer in peers.values where peer.isVisible == true {
            guard let profile = peer.profile else { continue }
            entries.append(LeaderboardEntry(
                profile: profile, seconds: peer.summary?.seconds(for: period, now: now),
                streak: peer.summary?.currentStreak(now: now), isCurrentUser: false, isPrivate: false
            ))
        }
        return LeaderboardEntry.ranked(entries)
    }

    func start() {
        stop()
        guard !userID.isEmpty else { return }
        let friends = FriendsRepository()
        let repository = LeaderboardRepository()
        self.friends = friends
        self.repository = repository
        visibility.start()
        isLoading = true
        connectionError = nil
        let current = generation
        ownListener = repository.observeSummary(userID: userID) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self, self.generation == current else { return }
                switch result {
                case .success(let summary):
                    self.ownSummary = summary
                    self.failedParts.remove("own:summary")
                case .failure:
                    self.ownSummary = nil
                    self.failedParts.insert("own:summary")
                }
            }
        }
        connectionListener = friends.observeConnections(for: userID) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self, self.generation == current else { return }
                self.isLoading = false
                switch result {
                case .success(let connections):
                    self.connectionError = nil
                    let ids = Set(connections.filter { $0.status == .accepted }
                        .map { $0.otherUserID(for: self.userID) })
                    self.updatePeers(ids, generation: current)
                case .failure(let error):
                    self.connectionError = FriendsError.message(for: error)
                    self.updatePeers([], generation: current)
                }
            }
        }
    }

    func stop() {
        generation = UUID()
        connectionListener?.remove()
        connectionListener = nil
        ownListener?.remove()
        ownListener = nil
        for id in Array(peers.keys) { removePeer(id) }
        ownSummary = nil
        failedParts.removeAll()
        visibility.stop()
        friends = nil
        repository = nil
    }

    private func updatePeers(_ ids: Set<String>, generation current: UUID) {
        for id in Array(peers.keys) where !ids.contains(id) { removePeer(id) }
        guard let friends, let repository else { return }
        for id in ids where peers[id] == nil {
            peers[id] = Peer()
            let token = UUID()
            peerTokens[id] = token
            profileListeners[id] = friends.observeProfile(userID: id) { [weak self] result in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == current, self.peerTokens[id] == token else { return }
                    switch result {
                    case .success(let profile):
                        self.peers[id]?.profile = profile
                        if profile == nil { self.failedParts.insert("\(id):profile") }
                        else { self.failedParts.remove("\(id):profile") }
                    case .failure:
                        self.peers[id]?.profile = nil
                        self.failedParts.insert("\(id):profile")
                    }
                }
            }
            visibilityListeners[id] = repository.observeVisibility(userID: id) { [weak self] result in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == current, self.peerTokens[id] == token else { return }
                    switch result {
                    case .success(let isVisible):
                        self.peers[id]?.isVisible = isVisible
                        self.failedParts.remove("\(id):visibility")
                        if isVisible { self.observeSummary(id, generation: current) }
                        else { self.removeSummary(id) }
                    case .failure:
                        self.peers[id]?.isVisible = nil
                        self.removeSummary(id)
                        self.failedParts.insert("\(id):visibility")
                    }
                }
            }
        }
    }

    private func observeSummary(_ id: String, generation current: UUID) {
        guard summaryListeners[id] == nil, let repository else { return }
        let token = UUID()
        summaryTokens[id] = token
        summaryListeners[id] = repository.observeSummary(userID: id) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self, self.generation == current, self.summaryTokens[id] == token,
                      self.peers[id]?.isVisible == true else { return }
                switch result {
                case .success(let summary):
                    self.peers[id]?.summary = summary
                    self.failedParts.remove("\(id):summary")
                case .failure:
                    self.peers[id]?.summary = nil
                    self.failedParts.insert("\(id):summary")
                }
            }
        }
    }

    private func removeSummary(_ id: String) {
        summaryTokens.removeValue(forKey: id)
        summaryListeners.removeValue(forKey: id)?.remove()
        peers[id]?.summary = nil
        failedParts.remove("\(id):summary")
    }

    private func removePeer(_ id: String) {
        peerTokens.removeValue(forKey: id)
        profileListeners.removeValue(forKey: id)?.remove()
        visibilityListeners.removeValue(forKey: id)?.remove()
        removeSummary(id)
        peers.removeValue(forKey: id)
        failedParts.remove("\(id):profile")
        failedParts.remove("\(id):visibility")
    }
}
