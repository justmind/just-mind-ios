import Foundation

/// Daily-rotating writing prompts shown above the journal entry field.
/// The prompt is a suggestion, not a requirement — the user can ignore it.
enum JournalPrompts {
    static let prompts: [String] = [
        "What's actually on your mind right now?",
        "Where in your body is today showing up?",
        "What would you say if no one were going to read this?",
        "Name one thing you're carrying. Just naming it is enough.",
        "What did you almost say today, but didn't?",
        "Who or what made today feel a little easier?",
        "When thinking about recent events, what went well and what was a challenge?",
        "What did you need today that you didn't get?",
        "What did you give yourself today?",
        "What's one thing you'd like to bring to your next session?",
        "What were you doing when you felt most like yourself today?",
        "What's the loop your mind keeps coming back to?",
        "What's gone well this week and what's been a challenge?",
        "What part of today felt heavier than it needed to?"
    ]

    static func promptForToday(_ date: Date = .now) -> String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = Calendar.current.component(.year, from: date)
        return prompts[(day &+ year) % prompts.count]
    }
}
