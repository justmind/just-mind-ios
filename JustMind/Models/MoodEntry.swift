import Foundation
import SwiftData

/// A journal entry: free-form text the client writes (often the thing they
/// want to bring to their next session), the prompt that was showing when
/// they wrote it, and a timestamp.
///
/// Naming note: this type is still called `MoodEntry` because that's the
/// SwiftData entity name in the on-device store. Renaming the class would be
/// a destructive schema migration, so the internal name stays while the UI
/// presents it purely as a journal entry. The `score` and `tags` fields are
/// vestigial (the app no longer shows a mood emoji or tags) but are retained
/// as stored properties so existing stores keep opening without a migration.
@Model
final class MoodEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    /// Vestigial — retained for schema compatibility. Always saved as 3.
    var score: Int
    var body: String
    /// Vestigial — retained for schema compatibility. Always empty now.
    var tagsRaw: String
    var prompt: String

    init(score: Int = 3, body: String = "", tags: [String] = [], prompt: String = "", timestamp: Date = .now) {
        self.id = UUID()
        self.timestamp = timestamp
        self.score = score
        self.body = body
        self.tagsRaw = tags.joined(separator: "|")
        self.prompt = prompt
    }

    var tags: [String] {
        get { tagsRaw.isEmpty ? [] : tagsRaw.split(separator: "|").map(String.init) }
        set { tagsRaw = newValue.joined(separator: "|") }
    }
}
