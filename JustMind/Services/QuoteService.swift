import Foundation

enum QuoteService {
    /// 30 short, clinically-warm grounding lines. No toxic positivity.
    static let quotes: [String] = [
        "Progress isn't always visible. Show up anyway.",
        "You don't have to have it all figured out today.",
        "Slow is steady. Steady is enough.",
        "Feelings aren't facts, but they are signals worth listening to.",
        "Rest is part of the work, not separate from it.",
        "You can hold two true things at once.",
        "Your healing doesn't have to be linear to be real.",
        "It's okay to need what you need.",
        "Naming a feeling is half the work.",
        "Boundaries are how you stay in the room.",
        "Small repairs matter. Reach out if it feels right.",
        "Hard days don't undo the work you've done.",
        "Let yourself be a beginner at this.",
        "You're allowed to take up space here.",
        "Curiosity, not judgment — about yourself, too.",
        "Tend to the part of you that's tired.",
        "You can be a work in progress and still be whole.",
        "Try one small kind thing for yourself today.",
        "What you noticed is information. Stay with it.",
        "Healing rarely looks the way we expect it to.",
        "You don't have to perform okay-ness here.",
        "Your nervous system has been doing its best.",
        "Some days, getting through is the win.",
        "It's not weakness to ask for help. It's wisdom.",
        "Self-compassion isn't earned. It's practiced.",
        "You're allowed to change your mind.",
        "What you're feeling has a reason. It might not be the obvious one.",
        "Soften where you can. Hold firm where it matters.",
        "Coming back to yourself is the work."
    ]

    static func quoteForToday(_ date: Date = .now) -> String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = Calendar.current.component(.year, from: date)
        let idx = (day + year) % quotes.count
        return quotes[idx]
    }
}
