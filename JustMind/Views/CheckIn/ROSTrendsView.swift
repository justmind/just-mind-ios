import SwiftUI
import SwiftData
import Charts

/// Trend analysis over 30 / 90 / 180-day windows for the RŌS instrument.
/// Surfaces average total, change vs prior comparable window, time spent
/// above clinical cutoff, count of meaningful shifts, and per-subscale averages.
struct ROSTrendsView: View {
    enum Window: Int, CaseIterable, Identifiable {
        case d30 = 30
        case d90 = 90
        case d180 = 180
        var id: Int { rawValue }
        var label: String { "\(rawValue)d" }
        var fullLabel: String {
            switch self {
            case .d30:  return "30 days"
            case .d90:  return "90 days"
            case .d180: return "180 days"
            }
        }
    }

    @Query(sort: \ROSEntry.timestamp, order: .reverse) private var entries: [ROSEntry]
    @State private var window: Window = .d30

    private var allAsc: [ROSEntry] { Array(entries.reversed()) }

    private var windowed: [ROSEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -window.rawValue, to: .now) ?? .now
        return allAsc.filter { $0.timestamp >= cutoff }
    }

    private var prior: [ROSEntry] {
        let now = Date.now
        let upper = Calendar.current.date(byAdding: .day, value: -window.rawValue, to: now) ?? now
        let lower = Calendar.current.date(byAdding: .day, value: -window.rawValue * 2, to: now) ?? now
        return allAsc.filter { $0.timestamp >= lower && $0.timestamp < upper }
    }

    private var currentAvg: Double? { Self.avgTotal(windowed) }
    private var priorAvg: Double? { Self.avgTotal(prior) }

    private var delta: Double? {
        guard let c = currentAvg, let p = priorAvg else { return nil }
        return c - p
    }

    private var aboveCutoffShare: Double? {
        guard !windowed.isEmpty else { return nil }
        let above = windowed.filter { $0.total >= ROSEntry.clinicalCutoffAdult }.count
        return Double(above) / Double(windowed.count)
    }

    private var rciCount: Int {
        var count = 0
        var prev: Double? = nil
        for e in windowed {
            if let p = prev, abs(e.total - p) >= ROSEntry.reliableChangeIndex {
                count += 1
            }
            prev = e.total
        }
        return count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: JMSpacing.xl) {
            windowPicker

            if windowed.count < 2 {
                EmptyStateCard(
                    icon: "chart.xyaxis.line",
                    text: windowed.isEmpty
                        ? "No RŌS entries in this window. Trends appear after a couple of check-ins."
                        : "One entry in this window. A second entry unlocks the trend."
                )
            } else {
                summaryNumbers
                trendChart
                subscaleBreakdown
                notes
            }
        }
    }

    // MARK: Sections

    private var windowPicker: some View {
        Picker("Window", selection: $window) {
            ForEach(Window.allCases) { w in
                Text(w.fullLabel).tag(w)
            }
        }
        .pickerStyle(.segmented)
    }

    private var summaryNumbers: some View {
        VStack(alignment: .leading, spacing: JMSpacing.l) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Average total")
                    .font(JMFont.footnote)
                    .foregroundStyle(JMColor.textSecondary)
                    .tracking(1)
                    .textCase(.uppercase)
                HStack(alignment: .firstTextBaseline, spacing: JMSpacing.m) {
                    Text(currentAvg.map { String(format: "%.1f", $0) } ?? "—")
                        .font(JMFont.heroNumber)
                        .jmDisplayTracking()
                        .foregroundStyle(JMColor.textPrimary)
                        .monospacedDigit()
                    Text("/ \(Int(ROSEntry.maxTotal))")
                        .font(JMFont.headline)
                        .foregroundStyle(JMColor.textSecondary)
                }
            }

            if let delta {
                deltaRow(delta: delta)
            } else if priorAvg == nil && !windowed.isEmpty {
                Text("Not enough prior data for a comparison yet.")
                    .font(JMFont.footnote)
                    .foregroundStyle(JMColor.textSecondary)
            }

            JMHairline()

            HStack(spacing: 0) {
                statBlock(
                    label: "Entries",
                    value: "\(windowed.count)"
                )
                Rectangle()
                    .fill(JMColor.divider)
                    .frame(width: JMHairline.width, height: 36)
                statBlock(
                    label: "Above cutoff",
                    value: aboveCutoffShare.map { String(format: "%.0f%%", $0 * 100) } ?? "—"
                )
                Rectangle()
                    .fill(JMColor.divider)
                    .frame(width: JMHairline.width, height: 36)
                statBlock(
                    label: "Notable shifts",
                    value: "\(rciCount)"
                )
            }
        }
        .padding(JMSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .jmQuietCardFlush()
    }

    private func deltaRow(delta: Double) -> some View {
        let positive = delta > 0
        let neutral = abs(delta) < 0.05
        let arrow = neutral ? "minus" : (positive ? "arrow.up" : "arrow.down")
        let tint = neutral ? JMColor.textSecondary : (positive ? JMColor.success : JMColor.warning)
        let text = neutral
            ? "Steady vs prior \(window.fullLabel)"
            : String(format: "%@%.1f vs prior %@", positive ? "+" : "", delta, window.fullLabel)
        return HStack(spacing: 6) {
            Image(systemName: arrow)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(JMFont.callout)
                .foregroundStyle(tint)
                .monospacedDigit()
        }
    }

    private func statBlock(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(JMFont.title)
                .foregroundStyle(JMColor.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(JMFont.caption)
                .foregroundStyle(JMColor.textSecondary)
                .tracking(0.5)
                .textCase(.uppercase)
        }
        .padding(.horizontal, JMSpacing.l)
        .padding(.vertical, JMSpacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One row per (entry × subscale). Charts uses these to draw four
    /// separate lines on a shared 0–10 axis with a color legend.
    private struct SubscalePoint: Identifiable {
        let id = UUID()
        let date: Date
        let subscale: String
        let value: Double
    }

    /// Display order matches the legend; same order the user sees on entry.
    private static let subscaleOrder = [
        "Individual", "Interpersonal", "Social / Role", "Overall"
    ]

    private var subscalePoints: [SubscalePoint] {
        var pts: [SubscalePoint] = []
        for e in windowed {
            pts.append(SubscalePoint(date: e.timestamp, subscale: "Individual",    value: e.individual))
            pts.append(SubscalePoint(date: e.timestamp, subscale: "Interpersonal", value: e.interpersonal))
            pts.append(SubscalePoint(date: e.timestamp, subscale: "Social / Role", value: e.social))
            pts.append(SubscalePoint(date: e.timestamp, subscale: "Overall",       value: e.overall))
        }
        return pts
    }

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: JMSpacing.s) {
            Text("Trend by question")
                .font(JMFont.footnote)
                .foregroundStyle(JMColor.textSecondary)
                .tracking(1)
                .textCase(.uppercase)
            Text("Each line traces one of the four RŌS questions on a 0–10 scale across the selected window.")
                .font(JMFont.caption)
                .foregroundStyle(JMColor.textSecondary)
                .lineSpacing(2)
                .padding(.bottom, JMSpacing.xs)

            Chart(subscalePoints) { p in
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Score", p.value),
                    series: .value("Subscale", p.subscale)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(by: .value("Subscale", p.subscale))
                .lineStyle(StrokeStyle(lineWidth: 1.75, lineCap: .round))

                PointMark(
                    x: .value("Date", p.date),
                    y: .value("Score", p.value)
                )
                .foregroundStyle(by: .value("Subscale", p.subscale))
                .symbolSize(30)
            }
            .chartYScale(domain: 0...10)
            .chartForegroundStyleScale([
                "Individual":     JMColor.primary,    // sage
                "Interpersonal":  JMColor.warning,    // amber
                "Social / Role":  JMColor.secondary,  // muted earth
                "Overall":        JMColor.textPrimary // near-black anchor
            ])
            .chartLegend(position: .bottom, alignment: .leading, spacing: JMSpacing.s)
            .frame(height: 240)
        }
        .padding(JMSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .jmQuietCardFlush()
    }

    private var subscaleBreakdown: some View {
        let avgs = subscaleAverages(windowed)
        return VStack(alignment: .leading, spacing: JMSpacing.m) {
            Text("Subscales")
                .font(JMFont.footnote)
                .foregroundStyle(JMColor.textSecondary)
                .tracking(1)
                .textCase(.uppercase)
            VStack(spacing: JMSpacing.m) {
                subscaleBar(label: "Individual",   value: avgs.individual)
                subscaleBar(label: "Interpersonal", value: avgs.interpersonal)
                subscaleBar(label: "Social / Role", value: avgs.social)
                subscaleBar(label: "Overall",       value: avgs.overall)
            }
        }
        .padding(JMSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .jmQuietCardFlush()
    }

    private func subscaleBar(label: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(JMFont.callout)
                    .foregroundStyle(JMColor.textPrimary)
                Spacer()
                Text(String(format: "%.1f", value))
                    .font(JMFont.callout)
                    .foregroundStyle(JMColor.textSecondary)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(JMColor.divider)
                        .frame(height: 4)
                    Capsule().fill(JMColor.primary)
                        .frame(width: max(2, geo.size.width * CGFloat(value / 10.0)), height: 4)
                }
            }
            .frame(height: 4)
        }
    }

    private var notes: some View {
        Text("Trends are computed locally from the entries on this device. The clinical cutoff (25) and Reliable Change Index (6) follow the published RŌS guidance for adults.")
            .font(JMFont.caption)
            .foregroundStyle(JMColor.textSecondary)
            .lineSpacing(2)
    }

    // MARK: Math

    private struct SubscaleAverages {
        var individual: Double = 0
        var interpersonal: Double = 0
        var social: Double = 0
        var overall: Double = 0
    }

    private func subscaleAverages(_ es: [ROSEntry]) -> SubscaleAverages {
        guard !es.isEmpty else { return SubscaleAverages() }
        let n = Double(es.count)
        var s = SubscaleAverages()
        for e in es {
            s.individual    += e.individual
            s.interpersonal += e.interpersonal
            s.social        += e.social
            s.overall       += e.overall
        }
        s.individual    /= n
        s.interpersonal /= n
        s.social        /= n
        s.overall       /= n
        return s
    }

    private static func avgTotal(_ es: [ROSEntry]) -> Double? {
        guard !es.isEmpty else { return nil }
        return es.map(\.total).reduce(0, +) / Double(es.count)
    }
}

/// Compact at-a-glance trends card surfaced on the RŌS intro screen.
/// Shows the 30-day average, delta vs prior 30 days, and a sparkline of
/// the most recent totals. Tapping it (handled by the parent button)
/// routes into the full Trends view.
struct ROSTrendsSnapshot: View {
    let entries: [ROSEntry]

    private var ascending: [ROSEntry] {
        // `entries` arrives newest-first from the parent's @Query.
        Array(entries.reversed())
    }

    private var window30: [ROSEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        return ascending.filter { $0.timestamp >= cutoff }
    }

    private var prior30: [ROSEntry] {
        let now = Date.now
        let upper = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let lower = Calendar.current.date(byAdding: .day, value: -60, to: now) ?? now
        return ascending.filter { $0.timestamp >= lower && $0.timestamp < upper }
    }

    /// Falls back to all entries if the 30-day window is empty — better
    /// to show *something* than a blank card on sparse usage.
    private var sampleForAvg: [ROSEntry] {
        window30.isEmpty ? ascending : window30
    }

    private var avg: Double? {
        guard !sampleForAvg.isEmpty else { return nil }
        return sampleForAvg.map(\.total).reduce(0, +) / Double(sampleForAvg.count)
    }

    private var delta: Double? {
        guard let a = avg, !prior30.isEmpty, !window30.isEmpty else { return nil }
        let p = prior30.map(\.total).reduce(0, +) / Double(prior30.count)
        return a - p
    }

    /// Sparkline samples — last 12 entries (chronological).
    private var sparkline: [ROSEntry] {
        Array(ascending.suffix(12))
    }

    private var hasMultipleEntries: Bool { ascending.count >= 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: JMSpacing.s) {
            HStack {
                Text(hasMultipleEntries ? "Your trend" : "Last entry")
                    .font(JMFont.sectionLabel)
                    .foregroundStyle(JMColor.textSecondary)
                    .tracking(0.96)
                    .textCase(.uppercase)
                Spacer()
                HStack(spacing: 4) {
                    Text(hasMultipleEntries ? "Open trends" : "View")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .light))
                }
                .font(JMFont.caption)
                .foregroundStyle(JMColor.primary)
            }

            HStack(alignment: .firstTextBaseline, spacing: JMSpacing.m) {
                Text(avg.map { String(format: "%.1f", $0) } ?? "—")
                    .font(JMFont.display)
                    .jmDisplayTracking()
                    .foregroundStyle(JMColor.textPrimary)
                    .monospacedDigit()
                Text("/ \(Int(ROSEntry.maxTotal))")
                    .font(JMFont.callout)
                    .foregroundStyle(JMColor.textSecondary)
                Spacer()
                if sparkline.count >= 2 {
                    Sparkline(values: sparkline.map(\.total),
                              max: ROSEntry.maxTotal)
                        .frame(width: 96, height: 32)
                }
            }

            HStack(spacing: 12) {
                if let d = delta {
                    deltaPill(d)
                }
                Text(footerLabel)
                    .font(JMFont.caption)
                    .foregroundStyle(JMColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .jmQuietCard()
    }

    private var footerLabel: String {
        if hasMultipleEntries {
            return "\(window30.count) \(window30.count == 1 ? "entry" : "entries") · last 30 days"
        }
        if let last = ascending.last {
            let f = DateFormatter()
            if Calendar.current.isDateInToday(last.timestamp) {
                f.dateFormat = "'Taken today, 'h:mm a"
            } else if Calendar.current.isDateInYesterday(last.timestamp) {
                f.dateFormat = "'Taken yesterday'"
            } else {
                f.dateFormat = "'Taken' MMM d"
            }
            return f.string(from: last.timestamp)
        }
        return ""
    }

    private func deltaPill(_ d: Double) -> some View {
        let neutral = abs(d) < 0.05
        let positive = d > 0
        let arrow = neutral ? "minus" : (positive ? "arrow.up" : "arrow.down")
        let tint = neutral ? JMColor.textSecondary : (positive ? JMColor.success : JMColor.warning)
        let text = neutral
            ? "Steady"
            : String(format: "%@%.1f", positive ? "+" : "", d)
        return HStack(spacing: 4) {
            Image(systemName: arrow)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(JMFont.caption)
                .foregroundStyle(tint)
                .monospacedDigit()
        }
    }
}

/// Tiny line chart drawn manually — fewer pixels than a `Chart` view,
/// no axes, no markers. Just the shape.
private struct Sparkline: View {
    let values: [Double]
    let max: Double

    var body: some View {
        GeometryReader { geo in
            Path { path in
                guard values.count > 1 else { return }
                let stepX = geo.size.width / CGFloat(values.count - 1)
                for (i, v) in values.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = geo.size.height * (1 - CGFloat(v / max))
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(JMColor.primary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}
