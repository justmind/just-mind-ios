import SwiftUI
import SwiftData
import Charts

struct ROSHistoryView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case log = "Log"
        case trends = "Trends"
        var id: String { rawValue }
    }

    let initialMode: Mode

    init(initialMode: Mode = .log) {
        self.initialMode = initialMode
        _mode = State(initialValue: initialMode)
    }

    @Environment(AppPreferences.self) private var prefs
    @Environment(\.modelContext) private var context
    @Query(sort: \ROSEntry.timestamp, order: .reverse) private var entries: [ROSEntry]
    @State private var mode: Mode
    @State private var shareItem: ShareItem?
    @State private var pendingDelete: ROSEntry?

    private var orderedAsc: [ROSEntry] { Array(entries.reversed()) }

    private var rciAnnotations: [ROSEntry] {
        var out: [ROSEntry] = []
        var prev: Double? = nil
        for e in orderedAsc {
            if let p = prev, abs(e.total - p) >= ROSEntry.reliableChangeIndex {
                out.append(e)
            }
            prev = e.total
        }
        return out
    }

    var body: some View {
        if entries.isEmpty {
            EmptyStateCard(
                icon: "chart.xyaxis.line",
                text: "You haven't completed a Wellbeing Check-In yet. Your first entry creates a baseline so you can track your progress over time."
            )
        } else {
            VStack(alignment: .leading, spacing: JMSpacing.l) {
                Text("History")
                    .font(JMFont.largeTitle)
                    .jmDisplayTracking()
                    .foregroundStyle(JMColor.textPrimary)

                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.segmented)

                shareButton

                switch mode {
                case .log:
                    chart
                    list
                case .trends:
                    ROSTrendsView()
                }
            }
            .sheet(item: $shareItem) { ShareSheet(items: [$0.url]) }
            .confirmationDialog(
                "Delete this entry?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { confirmDelete() }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("This permanently removes the Wellbeing Check-In from this device.")
            }
        }
    }

    private func confirmDelete() {
        if let entry = pendingDelete {
            context.delete(entry)
            try? context.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        pendingDelete = nil
    }

    private var shareButton: some View {
        Button {
            if let url = WCIPDFExporter.makePDF(
                entries: entries,
                clientName: prefs.preferredName.capitalized
            ) {
                shareItem = ShareItem(url: url)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .regular))
                Text("Share with my therapist (PDF)")
            }
        }
        .buttonStyle(.jmGhost)
        .accessibilityHint("Creates a PDF of your Wellbeing Check-In history to email or share")
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: JMSpacing.s) {
            Text("Total over time")
                .font(JMFont.footnote)
                .foregroundStyle(JMColor.textSecondary)
                .tracking(1)
                .textCase(.uppercase)
            Chart {
                RuleMark(y: .value("Cutoff", ROSEntry.clinicalCutoffAdult))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(JMColor.warning.opacity(0.6))
                    .annotation(position: .topTrailing, alignment: .trailing) {
                        Text("Cutoff")
                            .font(JMFont.caption)
                            .foregroundStyle(JMColor.warning)
                    }
                ForEach(orderedAsc) { e in
                    LineMark(
                        x: .value("Date", e.timestamp),
                        y: .value("Total", e.total)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(JMColor.primary)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    PointMark(
                        x: .value("Date", e.timestamp),
                        y: .value("Total", e.total)
                    )
                    .foregroundStyle(JMColor.primary)
                    .symbolSize(36)
                }
                ForEach(rciAnnotations) { e in
                    PointMark(
                        x: .value("Date", e.timestamp),
                        y: .value("Total", e.total)
                    )
                    .foregroundStyle(JMColor.warning)
                    .symbolSize(120)
                    .annotation(position: .top, alignment: .center) {
                        Text("Δ")
                            .font(JMFont.caption)
                            .foregroundStyle(JMColor.warning)
                    }
                }
            }
            .chartYScale(domain: 0...ROSEntry.maxTotal)
            .frame(height: 220)
        }
        .padding(JMSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .jmQuietCardFlush()
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { idx, e in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(formatted(e.timestamp))
                            .font(JMFont.caption)
                            .foregroundStyle(JMColor.textSecondary)
                            .tracking(0.5)
                            .textCase(.uppercase)
                        Spacer()
                        Text(String(format: "%.1f", e.total))
                            .font(JMFont.headline)
                            .foregroundStyle(JMColor.textPrimary)
                            .monospacedDigit()
                    }
                    Text(String(
                        format: "Ind %.1f · IP %.1f · Soc %.1f · Overall %.1f",
                        e.individual, e.interpersonal, e.social, e.overall
                    ))
                    .font(JMFont.caption)
                    .foregroundStyle(JMColor.textSecondary)
                }
                .padding(.horizontal, JMSpacing.l)
                .padding(.vertical, JMSpacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .contextMenu {
                    Button(role: .destructive) {
                        pendingDelete = e
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                if idx < entries.count - 1 {
                    JMHairline()
                }
            }
        }
        .jmQuietCardFlush()
    }

    private func formatted(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy · h:mm a"
        return f.string(from: d)
    }
}
