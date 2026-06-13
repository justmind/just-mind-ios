import Foundation
import SwiftData

/// A single post-session "alliance" pulse: how well the most recent session fit
/// what the client needed (0–10). On-device only. (Change 5.)
@Model
final class SessionAllianceEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var score: Double

    init(score: Double, date: Date = .now) {
        self.id = UUID()
        self.date = date
        self.score = score
    }
}
