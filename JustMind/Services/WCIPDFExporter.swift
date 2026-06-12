import Foundation
import UIKit

/// Renders a client's Wellbeing Check-In (WCI) history into a shareable PDF —
/// intended to be emailed/handed to a therapist. Only WCI data is included;
/// journal entries are never exported.
///
/// The PDF is written to a temp file and returned as a URL so the iOS share
/// sheet attaches it with a meaningful filename. Nothing leaves the device
/// except via the share action the user explicitly takes.
enum WCIPDFExporter {
    /// US Letter.
    private static let pageSize = CGSize(width: 612, height: 792)
    private static let margin: CGFloat = 50

    static func makePDF(entries: [ROSEntry], clientName: String) -> URL? {
        // Newest first for display.
        let sorted = entries.sorted { $0.timestamp > $1.timestamp }
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Wellbeing-Check-In-Summary.pdf")

        do {
            try renderer.writePDF(to: url) { ctx in
                var cursor = Layout(margin: margin, pageSize: pageSize, context: ctx)
                cursor.beginPage()

                cursor.draw(text: "Wellbeing Check-In", font: .systemFont(ofSize: 22, weight: .semibold))
                cursor.draw(text: "Summary for \(clientName.isEmpty ? "a Just Mind client" : clientName)",
                            font: .systemFont(ofSize: 13, weight: .regular), color: .darkGray)
                cursor.draw(text: "Generated \(longDate(.now))",
                            font: .systemFont(ofSize: 11, weight: .regular), color: .gray)
                cursor.space(10)

                // Summary line
                if let latest = sorted.first {
                    let avg = sorted.map(\.total).reduce(0, +) / Double(sorted.count)
                    cursor.draw(text: "Latest total: \(fmt(latest.total)) of 40   ·   Average: \(fmt(avg))   ·   Entries: \(sorted.count)",
                                font: .systemFont(ofSize: 12, weight: .medium))
                    cursor.draw(text: "Clinical cutoff for adults: 25. Reliable Change Index: 6 points.",
                                font: .systemFont(ofSize: 10, weight: .regular), color: .gray)
                }
                cursor.space(16)

                // Table header
                cursor.drawRow(
                    columns: ["Date", "Total", "Indiv", "Interp", "Social", "Overall"],
                    font: .systemFont(ofSize: 11, weight: .semibold),
                    color: .black
                )
                cursor.rule()

                // Rows
                var prevTotal: Double? = nil
                // Iterate oldest→newest for the "change" column to read naturally,
                // but display newest first; compute change vs the chronologically
                // previous entry.
                let chronological = sorted.reversed()
                var changeByID: [UUID: Double] = [:]
                for e in chronological {
                    if let p = prevTotal { changeByID[e.id] = e.total - p }
                    prevTotal = e.total
                }

                for e in sorted {
                    if cursor.needsNewPage(rowHeight: 20) {
                        cursor.beginPage()
                        cursor.drawRow(
                            columns: ["Date", "Total", "Indiv", "Interp", "Social", "Overall"],
                            font: .systemFont(ofSize: 11, weight: .semibold),
                            color: .black
                        )
                        cursor.rule()
                    }
                    cursor.drawRow(
                        columns: [
                            shortDate(e.timestamp),
                            fmt(e.total),
                            fmt(e.individual),
                            fmt(e.interpersonal),
                            fmt(e.social),
                            fmt(e.overall)
                        ],
                        font: .systemFont(ofSize: 11, weight: .regular),
                        color: e.total < ROSEntry.clinicalCutoffAdult ? .systemBrown : .black
                    )
                }

                cursor.space(20)
                cursor.rule()
                cursor.draw(
                    text: "The Wellbeing Check-In is based on the RŌS, a validated clinical instrument developed by Seidel et al. (2016). This summary is for personal reflection and clinical discussion only and does not replace clinical assessment. All data is stored solely on the client's device.",
                    font: .systemFont(ofSize: 9, weight: .regular),
                    color: .gray
                )
            }
            return url
        } catch {
            return nil
        }
    }

    // MARK: Formatting helpers

    private static func fmt(_ v: Double) -> String { String(format: "%.1f", v) }

    private static func shortDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy  h:mm a"
        return f.string(from: d)
    }

    private static func longDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        return f.string(from: d)
    }
}

/// Minimal top-down text layout helper over a PDF context.
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

    func needsNewPage(rowHeight: CGFloat) -> Bool {
        y + rowHeight > maxY
    }

    mutating func draw(text: String, font: UIFont, color: UIColor = .black) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let bounding = (text as NSString).boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs,
            context: nil
        )
        (text as NSString).draw(
            with: CGRect(x: margin, y: y, width: contentWidth, height: bounding.height),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs,
            context: nil
        )
        y += bounding.height + 4
    }

    mutating func drawRow(columns: [String], font: UIFont, color: UIColor) {
        // Column layout: first column (date) is wide, the rest are narrow numbers.
        let dateWidth = contentWidth * 0.34
        let numWidth = (contentWidth - dateWidth) / CGFloat(max(1, columns.count - 1))
        var x = margin
        let rowHeight: CGFloat = 18
        for (i, col) in columns.enumerated() {
            let w = i == 0 ? dateWidth : numWidth
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            (col as NSString).draw(
                in: CGRect(x: x, y: y, width: w, height: rowHeight),
                withAttributes: attrs
            )
            x += w
        }
        y += rowHeight
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
