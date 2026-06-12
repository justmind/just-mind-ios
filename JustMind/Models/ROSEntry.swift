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

    init(individual: Double, interpersonal: Double, social: Double, overall: Double, timestamp: Date = .now) {
        self.id = UUID()
        self.timestamp = timestamp
        self.individual = individual
        self.interpersonal = interpersonal
        self.social = social
        self.overall = overall
    }

    var total: Double { individual + interpersonal + social + overall }

    static let clinicalCutoffAdult: Double = 25
    static let reliableChangeIndex: Double = 6
    static let maxTotal: Double = 40
}

struct ROSItem: Identifiable, Equatable {
    enum Key: String, CaseIterable, Identifiable {
        case individual, interpersonal, social, overall
        var id: String { rawValue }
    }
    let key: Key
    let title: String
    let prompt: String
    let leftLabel: String
    let rightLabel: String
    var id: Key { key }

    static let all: [ROSItem] = [
        ROSItem(
            key: .individual,
            title: "Individual Well-Being",
            prompt: "How am I doing personally — my sense of well-being and any symptoms I'm experiencing.",
            leftLabel: "Not well at all",
            rightLabel: "Going very well"
        ),
        ROSItem(
            key: .interpersonal,
            title: "Interpersonal Well-Being",
            prompt: "How things are going in my close relationships.",
            leftLabel: "Very difficult",
            rightLabel: "Going very well"
        ),
        ROSItem(
            key: .social,
            title: "Social / Role Functioning",
            prompt: "How I'm doing at work, school, or in other important life roles.",
            leftLabel: "Very difficult",
            rightLabel: "Going very well"
        ),
        ROSItem(
            key: .overall,
            title: "Overall Well-Being",
            prompt: "How things are going overall in my life.",
            leftLabel: "Very bad",
            rightLabel: "Very good"
        )
    ]
}
