import FirebaseFirestore
import Foundation

nonisolated final class LeaderboardRepository: @unchecked Sendable {
    private let database = Firestore.firestore()

    // Preference reads are separate so a friend can observe an opt-in after opting out.
    // A missing preference is private; opening a screen never opts anyone in.
    func observeVisibility(userID: String,
                           onChange: @escaping @Sendable (Result<Bool, Error>) -> Void) -> ListenerRegistration {
        database.collection("leaderboardPreferences").document(userID).addSnapshotListener { snapshot, error in
            if let error { onChange(.failure(error)); return }
            guard let snapshot else { return }
            onChange(.success(snapshot.data()?["isVisible"] as? Bool ?? false))
        }
    }

    func setVisibility(userID: String, isVisible: Bool) async throws {
        let reference = database.collection("leaderboardPreferences").document(userID)
        // A transaction fails offline instead of silently queueing a privacy change.
        _ = try await database.runTransaction { transaction, errorPointer -> Any? in
            do {
                _ = try transaction.getDocument(reference)
                transaction.setData([
                    "uid": userID, "isVisible": isVisible,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: reference)
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }

    func observeSummary(userID: String,
                        onChange: @escaping @Sendable (Result<StudySummary?, Error>) -> Void) -> ListenerRegistration {
        database.collection("leaderboardStats").document(userID).addSnapshotListener { snapshot, error in
            if let error { onChange(.failure(error)); return }
            guard let snapshot else { return }
            guard snapshot.exists else { onChange(.success(nil)); return }
            guard let data = snapshot.data(), data["uid"] as? String == userID,
                  let weekID = data["weekID"] as? String,
                  let weekSeconds = data["weekSeconds"] as? Int,
                  let totalSeconds = data["totalSeconds"] as? Int,
                  let streak = data["streak"] as? Int,
                  let streakDay = data["streakDay"] as? String,
                  let timeZoneID = data["timeZoneID"] as? String else {
                onChange(.failure(LeaderboardError.invalidSummary)); return
            }
            let summary = StudySummary(weekID: weekID, weekSeconds: weekSeconds,
                                       totalSeconds: totalSeconds, streak: streak,
                                       streakDay: streakDay, timeZoneID: timeZoneID)
            guard summary.isValid else { onChange(.failure(LeaderboardError.invalidSummary)); return }
            onChange(.success(summary))
        }
    }

    // The session tracker supplies completed totals; views never increment them.
    // Replacing an aggregate is idempotent: retrying cannot count a session twice.
    func publish(_ summary: StudySummary, userID: String) async throws {
        guard summary.isValid else { throw LeaderboardError.invalidSummary }
        let reference = database.collection("leaderboardStats").document(userID)
        // Transactions fail offline. The session remains saved locally and can retry
        // instead of leaving an older aggregate queued behind a later account change.
        _ = try await database.runTransaction { transaction, errorPointer -> Any? in
            do {
                let existing = try transaction.getDocument(reference)
                if let data = existing.data(), let total = data["totalSeconds"] as? Int {
                    // Sessions are append-only here. A delayed writer must not lower a newer total.
                    if total > summary.totalSeconds { return nil }
                    if total == summary.totalSeconds, let week = data["weekID"] as? String,
                       week > summary.weekID { return nil }
                }
                transaction.setData([
                    "uid": userID, "weekID": summary.weekID, "weekSeconds": summary.weekSeconds,
                    "totalSeconds": summary.totalSeconds, "streak": summary.streak,
                    "streakDay": summary.streakDay, "timeZoneID": summary.timeZoneID,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: reference)
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }
}

nonisolated enum LeaderboardError: LocalizedError {
    case invalidSummary
    var errorDescription: String? { "Some study totals couldn’t be read. Please try again." }
}
