import Foundation
import SwiftData

@Model
final class ROSEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var individual: Double
    var interpersonal: Double
    var social: Double
    var overall: Double
    /// Optional free-text reflection captured on the results screen. Nil if
    /// the user skipped it. (Change 2.)
    var reflectionNote: String?

    init(
        individual: Double,
        interpersonal: Double,
        social: Double,
        overall: Double,
        reflectionNote: String? = nil,
        timestamp: Date = .now
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.individual = individual
        self.interpersonal = interpersonal
        self.social = social
        self.overall = overall
        self.reflectionNote = reflectionNote
    }

    var total: Double { individual + interpersonal + social + overall }

    static let clinicalCutoffAdult: Double = 25
    static let reliableChangeIndex: Double = 6
    static let maxTotal: Double = 40
    /// Normed community-sample midpoint from the RŌS validation study, used as
    /// a reference line on the trend chart. (Change 6.)
    static let communityAverage: Double = 25
}

struct ROSItem: Identifiable, Equatable {
    enum Key: String, CaseIterable, Identifiable {
        case individual, interpersonal, social, overall
        var id: String { rawValue }

        /// Original clinical domain name. Preserved for VoiceOver hints,
        /// chart axis/legend labels, and data export so historical data stays
        /// comparable even though the on-screen titles are now warmer. (Change 1.)
        var clinicalName: String {
            switch self {
            case .individual:    return "Individual"
            case .interpersonal: return "Interpersonal"
            case .social:        return "Social"
            case .overall:       return "Overall"
            }
        }
    }
    let key: Key
    /// Warm, accessible primary label shown on screen.
    let title: String
    let prompt: String
    let leftLabel: String
    let rightLabel: String
    var id: Key { key }

    var clinicalName: String { key.clinicalName }

    static let all: [ROSItem] = [
        ROSItem(
            key: .individual,
            title: "How I'm feeling inside",
            prompt: "How am I doing personally — my sense of well-being and any symptoms I'm experiencing.",
            leftLabel: "Not well at all",
            rightLabel: "Going very well"
        ),
        ROSItem(
            key: .interpersonal,
            title: "My close relationships",
            prompt: "How things are going in my close relationships.",
            leftLabel: "Very difficult",
            rightLabel: "Going very well"
        ),
        ROSItem(
            key: .social,
            title: "Work, school & daily life",
            prompt: "How I'm doing at work, school, or in other important life roles.",
            leftLabel: "Very difficult",
            rightLabel: "Going very well"
        ),
        ROSItem(
            key: .overall,
            title: "Life in general",
            prompt: "How things are going overall in my life.",
            leftLabel: "Very bad",
            rightLabel: "Very good"
        )
    ]
}
