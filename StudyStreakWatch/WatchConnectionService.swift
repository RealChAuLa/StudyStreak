import Foundation
@preconcurrency import WatchConnectivity

nonisolated enum WatchConnectionError: LocalizedError {
    case notReachable, invalidReply

    var errorDescription: String? {
        switch self {
        case .notReachable: "Connect your iPhone, then try again."
        case .invalidReply: "Couldn't read the iPhone's response. Please try again."
        }
    }
}

@MainActor
final class WatchConnectionService: NSObject, WCSessionDelegate {
    var onReady: (() -> Void)?
    var onUpdate: ((WatchSessionReply) -> Void)?
    var onDisconnect: (() -> Void)?
    private let session = WCSession.default

    var isReachable: Bool {
        session.activationState == .activated && session.isReachable
    }

    func activate() {
        guard session.delegate == nil else {
            if session.activationState == .activated { onReady?() }
            return
        }
        session.delegate = self
        session.activate()
    }

    func send(_ request: WatchSessionRequest,
              completion: @escaping (Result<WatchSessionReply, Error>) -> Void) {
        guard isReachable else {
            completion(.failure(WatchConnectionError.notReachable))
            return
        }
        do {
            let data = try JSONEncoder().encode(request)
            session.sendMessage([WatchSessionMessage.dataKey: data], replyHandler: { message in
                let reply = (message[WatchSessionMessage.dataKey] as? Data)
                    .flatMap { try? JSONDecoder().decode(WatchSessionReply.self, from: $0) }
                Task { @MainActor in
                    if let reply { completion(.success(reply)) }
                    else { completion(.failure(WatchConnectionError.invalidReply)) }
                }
            }, errorHandler: { error in
                Task { @MainActor in completion(.failure(error)) }
            })
        } catch {
            completion(.failure(error))
        }
    }

    private nonisolated func receive(_ message: [String: Any]) {
        guard let data = message[WatchSessionMessage.dataKey] as? Data,
              let reply = try? JSONDecoder().decode(WatchSessionReply.self, from: data) else { return }
        Task { @MainActor [weak self] in self?.onUpdate?(reply) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        receive(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receive(applicationContext)
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor [weak self] in
            if activationState == .activated { self?.onReady?() }
            else { self?.onDisconnect?() }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor [weak self] in
            if reachable { self?.onReady?() }
            else { self?.onDisconnect?() }
        }
    }
}

