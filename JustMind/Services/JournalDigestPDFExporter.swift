import Foundation
import UIKit

/// Compiles a client's last 7 days of three-part journal check-ins into a
/// shareable PDF for their therapist's pre-session review.
///
/// Note: this is an on-device *compilation* — the entries are laid out as-is,
/// grouped by prompt. It deliberately does NOT send anything to a server or an
/// LLM, so no journal content ever leaves the device except via the share
/// action the client explicitly takes. The PDF is written to a temp file and
/// deleted after sharing.
enum JournalDigestPDFExporter {
    private static let pageSize = CGSize(width: 612, height: 792) // US Letter
    private static let margin: CGFloat = 50

    static func makeWeeklyDigest(entries: [MoodEntry], clientName: String) -> URL? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let windowStart = cal.date(byAdding: .day, value: -6, to: today) ?? today
        let windowEnd = cal.date(byAdding: .day, value: 1, to: today) ?? today

        let week = entries
            .filter { $0.timestamp >= windowStart && $0.timestamp < windowEnd && $0.hasContent }
            .sorted { $0.timestamp < $1.timestamp }
        let loggedDays = Set(week.map { cal.startOfDay(for: $0.timestamp) }).count

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Weekly-Check-In-Digest.pdf")

        do {
            try renderer.writePDF(to: url) { ctx in
                var c = Layout(margin: margin, pageSize: pageSize, context: ctx)
                c.beginPage()

                c.draw(text: "Weekly Check-In Digest", font: .systemFont(ofSize: 22, weight: .semibold))
                c.draw(text: "For \(clientName.isEmpty ? "a Just Mind client" : clientName)",
                       font: .systemFont(ofSize: 13), color: .darkGray)
                c.draw(text: "\(shortDate(windowStart)) – \(shortDate(today))",
                       font: .systemFont(ofSize: 11), color: .gray)
                c.space(8)
                c.draw(text: "Logged \(loggedDays) of 7 days",
                       font: .systemFont(ofSize: 12, weight: .medium))
                c.space(14)
                c.rule()

                if week.isEmpty {
                    c.space(10)
                    c.draw(text: "No check-ins were recorded this week.",
                           font: .systemFont(ofSize: 12), color: .gray)
                } else {
                    section(&c, title: "What went well", items: week.compactMap { entry in
                        entry.wentWell.isEmpty ? nil : (dayLabel(entry.timestamp), entry.wentWell)
                    })
                    section(&c, title: "Challenges", items: week.compactMap { entry in
                        entry.challenge.isEmpty ? nil : (dayLabel(entry.timestamp), entry.challenge)
                    })
                    section(&c, title: "To try differently", items: week.compactMap { entry in
                        entry.tryDifferently.isEmpty ? nil : (dayLabel(entry.timestamp), entry.tryDifferently)
                    })
                }

                c.space(16)
                c.rule()
                c.draw(
                    text: "Compiled on-device from this client's daily check-ins, for discussion in session. Not a clinical assessment. All journal data is stored solely on the client's device.",
                    font: .systemFont(ofSize: 9),
                    color: .gray
                )
            }
            return url
        } catch {
            return nil
        }
    }

    private static func section(_ c: inout Layout, title: String, items: [(String, String)]) {
        guard !items.isEmpty else { return }
        c.space(12)
        c.draw(text: title.uppercased(), font: .systemFont(ofSize: 11, weight: .semibold), color: .darkGray)
        c.space(4)
        for (day, text) in items {
            if c.needsNewPage(rowHeight: 40) { c.beginPage() }
            c.draw(text: day, font: .systemFont(ofSize: 10, weight: .semibold), color: .gray)
            c.draw(text: text, font: .systemFont(ofSize: 12), color: .black)
            c.space(6)
        }
    }

    private static func shortDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f.string(from: d)
    }

    private static func dayLabel(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"; return f.string(from: d)
    }
}

/// Minimal top-down text layout over a PDF context.
private struct Layout {
    let margin: CGFloat
    let pageSize: CGSize
    let context: UIGraphicsPDFRendererContext
    private var y: CGFloat = 0

    init(margin: CGFloat, pageSize: CGSize, context: UIGraphicsPDFRendererContext) {
        self.margin = margin
        self.pageSize = pageSize
        self.context = context
    }

    private var contentWidth: CGFloat { pageSize.width - margin * 2 }
    private var maxY: CGFloat { pageSize.height - margin }

    mutating func beginPage() {
        context.beginPage()
        y = margin
    }

    mutating func space(_ h: CGFloat) { y += h }

    func needsNewPage(rowHeight: CGFloat) -> Bool { y + rowHeight > maxY }

    mutating func draw(text: String, font: UIFont, color: UIColor = .black) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let bounding = (text as NSString).boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs, context: nil
        )
        if y + bounding.height > maxY { beginPage() }
        (text as NSString).draw(
            with: CGRect(x: margin, y: y, width: contentWidth, height: bounding.height),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs, context: nil
        )
        y += bounding.height + 4
    }

    mutating func rule() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: pageSize.width - margin, y: y))
        UIColor(white: 0.85, alpha: 1).setStroke()
        path.lineWidth = 0.5
        path.stroke()
        y += 6
    }
}
