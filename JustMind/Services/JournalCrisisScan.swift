import Foundation

/// On-device scan of journal text for language that may indicate the client is
/// in crisis. Runs entirely locally — nothing is transmitted or logged. A match
/// gently surfaces the app's existing crisis resources; it never blocks saving
/// and never accuses. Deliberately conservative to limit false alarms.
enum JournalCrisisScan {
    private static let pattern = #"(?i)\b(suicide|suicidal|self[-\s]?harm|kill(ing)? myself|take my own life|want to die|wanna die|end(ing)? my life|hurt(ing)? myself)\b"#

    static func isTriggered(in texts: String...) -> Bool {
        let combined = texts.joined(separator: "\n")
        return combined.range(of: pattern, options: .regularExpression) != nil
    }
}
