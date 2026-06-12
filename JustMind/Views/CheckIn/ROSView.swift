import SwiftUI
import SwiftData

enum ROSStage: Equatable {
    case intro
    case item(Int)
    case results(individual: Double, interpersonal: Double, social: Double, overall: Double)
    case history(initialMode: ROSHistoryView.Mode)
}

struct ROSView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ROSEntry.timestamp, order: .reverse) private var entries: [ROSEntry]

    @State private var stage: ROSStage = .intro
    @State private var values: [ROSItem.Key: Double] = [
        .individual: 5.0, .interpersonal: 5.0, .social: 5.0, .overall: 5.0
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: JMSpacing.l) {
                switch stage {
                case .intro:
                    intro
                case .item(let idx):
                    itemView(idx: idx)
                case .results(let i, let ip, let s, let o):
                    ROSResultsView(
                        individual: i, interpersonal: ip, social: s, overall: o,
                        previous: entries.first,
                        onSave: { save(individual: i, interpersonal: ip, social: s, overall: o) },
                        onDone: { reset() }
                    )
                case .history(let mode):
                    ROSHistoryView(initialMode: mode)
                }
            }
            .padding(.horizontal, JMSpacing.l)
            .padding(.bottom, JMSpacing.xxl)
            .padding(.top, JMSpacing.s)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: JMSpacing.xl) {
            VStack(alignment: .leading, spacing: JMSpacing.s) {
                Text("RŌS")
                    .font(JMFont.footnote)
                    .foregroundStyle(JMColor.textSecondary)
                    .tracking(2)
                    .textCase(.uppercase)
                Text("Four questions.\nAbout a minute.")
                    .font(JMFont.display)
                    .jmDisplayTracking()
                    .foregroundStyle(JMColor.textPrimary)
                    .lineSpacing(2)
            }

            // Surface a snapshot inline whenever the user has any prior
            // entry — they shouldn't have to dig into History to see their
            // own data. With one entry it shows "Last entry" + tap-to-view;
            // with two or more it shows a trend with delta and sparkline.
            if !entries.isEmpty {
                trendsPreview
            }

            VStack(spacing: 0) {
                ForEach(Array(ROSItem.all.enumerated()), id: \.element.id) { idx, item in
                    HStack(alignment: .firstTextBaseline, spacing: JMSpacing.l) {
                        Text(String(format: "%02d", idx + 1))
                            .font(JMFont.callout)
                            .foregroundStyle(JMColor.textSecondary)
                            .monospacedDigit()
                            .frame(width: 28, alignment: .leading)
                        Text(item.title)
                            .font(JMFont.body)
                            .foregroundStyle(JMColor.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, JMSpacing.l)
                    .padding(.vertical, JMSpacing.m)
                    if idx < ROSItem.all.count - 1 {
                        JMHairline()
                    }
                }
            }
            .jmQuietCardFlush()

            Button("Begin") {
                values = [.individual: 5.0, .interpersonal: 5.0, .social: 5.0, .overall: 5.0]
                withAnimation { stage = .item(0) }
            }
            .buttonStyle(.jmPrimary)

            Button {
                withAnimation { stage = .history(initialMode: .log) }
            } label: {
                HStack(spacing: 6) {
                    Text(entries.count >= 2 ? "View full history" : "View history")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .light))
                }
            }
            .buttonStyle(.jmGhost)
        }
    }

    /// Compact snapshot shown on the intro when prior entries exist.
    /// Single entry → routes to History › Log so the user sees their record.
    /// Two or more   → routes to History › Trends for the full trend view.
    private var trendsPreview: some View {
        Button {
            let target: ROSHistoryView.Mode = entries.count >= 2 ? .trends : .log
            withAnimation { stage = .history(initialMode: target) }
        } label: {
            ROSTrendsSnapshot(entries: Array(entries))
        }
        .buttonStyle(.plain)
    }

    private func itemView(idx: Int) -> some View {
        let items = ROSItem.all
        let item = items[idx]
        let valueBinding = Binding<Double>(
            get: { values[item.key] ?? 5.0 },
            set: { values[item.key] = $0 }
        )
        return VStack(alignment: .leading, spacing: JMSpacing.l) {
            HStack {
                Text("\(String(format: "%02d", idx + 1)) / \(String(format: "%02d", items.count))")
                    .font(JMFont.footnote)
                    .foregroundStyle(JMColor.textSecondary)
                    .tracking(1)
                    .monospacedDigit()
                Spacer()
                Button("Cancel") { withAnimation { reset() } }
                    .font(JMFont.callout)
                    .foregroundStyle(JMColor.textSecondary)
            }
            ProgressView(value: Double(idx + 1), total: Double(items.count))
                .tint(JMColor.primary)

            Text(item.title)
                .font(JMFont.title)
                .jmDisplayTracking()
                .foregroundStyle(JMColor.textPrimary)
                .padding(.top, JMSpacing.s)
            Text(item.prompt)
                .font(JMFont.body)
                .foregroundStyle(JMColor.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            VASSlider(
                value: valueBinding,
                leftLabel: item.leftLabel,
                rightLabel: item.rightLabel
            )
            .padding(.top, JMSpacing.l)
            .padding(JMSpacing.l)
            .frame(maxWidth: .infinity)
            .jmQuietCardFlush()

            HStack(spacing: JMSpacing.m) {
                if idx > 0 {
                    Button {
                        withAnimation { stage = .item(idx - 1) }
                    } label: {
                        Text("Back")
                    }
                    .buttonStyle(.jmOutline)
                }
                Button {
                    if idx + 1 < items.count {
                        withAnimation { stage = .item(idx + 1) }
                    } else {
                        let i = values[.individual] ?? 5
                        let ip = values[.interpersonal] ?? 5
                        let s = values[.social] ?? 5
                        let o = values[.overall] ?? 5
                        withAnimation { stage = .results(individual: i, interpersonal: ip, social: s, overall: o) }
                    }
                } label: {
                    Text(idx + 1 == items.count ? "See Results" : "Next")
                }
                .buttonStyle(.jmPrimary)
            }
        }
    }

    private func save(individual: Double, interpersonal: Double, social: Double, overall: Double) {
        let entry = ROSEntry(individual: individual, interpersonal: interpersonal, social: social, overall: overall)
        context.insert(entry)
        try? context.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func reset() {
        stage = .intro
    }
}
