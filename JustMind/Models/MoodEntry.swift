import Foundation
import SwiftData

/// A single journal entry: how the user is feeling (emoji), what they wrote
/// about it (body), tags, the writing prompt active when they wrote, and a
/// timestamp. The "mood" data and the "journal" data live as one row — the
/// journal IS the place where moods are noted.
@Model
final class MoodEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var score: Int
    var body: String
    var tagsRaw: String
    var prompt: String

    init(score: Int, body: String = "", tags: [String] = [], prompt: String = "", timestamp: Date = .now) {
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

    var emoji: String { Self.emoji(for: score) }

    var wordCount: Int {
        body.split { !$0.isLetter && !$0.isNumber && $0 != "'" }.count
    }

    static func emoji(for score: Int) -> String {
        switch score {
        case 1: return "😔"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "😊"
        default: return "😐"
        }
    }

    static func label(for score: Int) -> String {
        switch score {
        case 1: return "Very Low"
        case 2: return "Low"
        case 3: return "Neutral"
        case 4: return "Good"
        case 5: return "Great"
        default: return "Neutral"
        }
    }

    static let availableTags: [String] = [
        "Anxious", "Tired", "Hopeful", "Grateful", "Overwhelmed",
        "Calm", "Distracted", "Irritable", "Energized", "Sad"
    ]
}
