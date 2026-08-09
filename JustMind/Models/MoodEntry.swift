import Foundation
import SwiftData

/// A daily journal entry. The client answers three short prompts —
/// what went well, what was a challenge, and what they'd try differently —
/// stored entirely on-device.
///
/// Naming note: this type is still called `MoodEntry` because that's the
/// SwiftData entity name in the on-device store. Renaming the class would be
/// a destructive schema migration, so the internal name stays while the UI
/// presents it as a journal entry. `score`, `tags`, and the single `body`
/// field are legacy: earlier versions stored one free-text `body`. They're
/// retained so existing on-device entries keep opening. New entries populate
/// the three-part fields below; display code falls back to `body` for old ones.
@Model
final class MoodEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    /// Legacy — kept for schema compatibility. Always saved as 3.
    var score: Int
    /// Legacy single free-text field (pre-3-prompt entries).
    var body: String
    /// Legacy — kept for schema compatibility. Always empty now.
    var tagsRaw: String
    var prompt: String

    /// Three-part daily reflection (added in the micro-journal update).
    var wentWell: String = ""
    var challenge: String = ""
    var tryDifferently: String = ""

    init(
        score: Int = 3,
        body: String = "",
        tags: [String] = [],
        prompt: String = "",
        wentWell: String = "",
        challenge: String = "",
        tryDifferently: String = "",
        timestamp: Date = .now
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.score = score
        self.body = body
        self.tagsRaw = tags.joined(separator: "|")
        self.prompt = prompt
        self.wentWell = wentWell
        self.challenge = challenge
        self.tryDifferently = tryDifferently
    }

    var tags: [String] {
        get { tagsRaw.isEmpty ? [] : tagsRaw.split(separator: "|").map(String.init) }
        set { tagsRaw = newValue.joined(separator: "|") }
    }

    /// True when this entry uses the three-part format (vs. a legacy body).
    var isThreePart: Bool {
        !wentWell.isEmpty || !challenge.isEmpty || !tryDifferently.isEmpty
    }

    /// Whether the entry has any content at all.
    var hasContent: Bool {
        isThreePart || !body.isEmpty
    }

    /// A short one-line preview for cards (Home TODAY card, history rows).
    var previewText: String {
        if isThreePart {
            if !wentWell.isEmpty { return wentWell }
            if !challenge.isEmpty { return challenge }
            return tryDifferently
        }
        return body
    }

    /// Sections to render for a three-part entry, skipping empty ones.
    var sections: [(label: String, text: String)] {
        var out: [(String, String)] = []
        if !wentWell.isEmpty { out.append(("What went well", wentWell)) }
        if !challenge.isEmpty { out.append(("A challenge", challenge)) }
        if !tryDifferently.isEmpty { out.append(("To try next time", tryDifferently)) }
        return out
    }
}
