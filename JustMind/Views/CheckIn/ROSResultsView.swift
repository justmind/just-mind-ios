import SwiftUI

struct ROSResultsView: View {
    let individual: Double
    let interpersonal: Double
    let social: Double
    let overall: Double
    let previousTotal: Double?
    let onDone: () -> Void
    let onDiscard: () -> Void

    private var total: Double { individual + interpersonal + social + overall }

    private var rciDelta: Double? {
        guard let prev = previousTotal else { return nil }
        return total - prev
    }

    private var aboveCutoff: Bool { total >= ROSEntry.clinicalCutoffAdult }

    var body: some View {
        VStack(spacing: JMSpacing.xl) {
            // The entry is already saved by the time this screen appears.
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(JMColor.success)
                Text("Saved to your history")
                    .font(JMFont.footnote)
                    .foregroundStyle(JMColor.textSecondary)
                    .tracking(1)
                    .textCase(.uppercase)
            }

            ScoreArc(total: total)
                .frame(width: 240, height: 240)

            scoreBreakdown

            messageCard

            if let delta = rciDelta, abs(delta) >= ROSEntry.reliableChangeIndex {
                rciCard(delta: delta)
            }

            disclaimer

            VStack(spacing: JMSpacing.m) {
                Button {
                    onDone()
                } label: { Text("Done") }
                    .buttonStyle(.jmPrimary)
                Button {
                    onDiscard()
                } label: { Text("Discard this entry") }
                    .buttonStyle(.jmGhost)
            }
        }
    }

    private var scoreBreakdown: some View {
        VStack(spacing: 0) {
            row("Individual", individual)
            JMHairline()
            row("Interpersonal", interpersonal)
            JMHairline()
            row("Social / Role", social)
            JMHairline()
            row("Overall", overall)
        }
        .frame(maxWidth: .infinity)
        .jmQuietCardFlush()
    }

    private func row(_ label: String, _ value: Double) -> some View {
        HStack {
            Text(label)
                .font(JMFont.body)
                .foregroundStyle(JMColor.textPrimary)
            Spacer()
            Text(String(format: "%.1f", value))
                .font(JMFont.headline)
                .foregroundStyle(JMColor.textPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, JMSpacing.l)
        .padding(.vertical, JMSpacing.m)
    }

    private var messageCard: some View {
        let text: String = aboveCutoff
            ? "You're reporting a solid level of overall well-being. Keep going — your work is showing."
            : "Your score suggests you may be going through a difficult time. That's exactly what therapy is for. Consider sharing this with your therapist at your next session."
        return VStack(alignment: .leading, spacing: JMSpacing.s) {
            Text(aboveCutoff ? "Going well" : "A difficult stretch")
                .font(JMFont.caption)
                .foregroundStyle(aboveCutoff ? JMColor.success : JMColor.warning)
                .tracking(1.5)
                .textCase(.uppercase)
            Text(text)
                .font(JMFont.body)
                .foregroundStyle(JMColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding(JMSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .jmQuietCardFlush()
    }

    private func rciCard(delta: Double) -> some View {
        let direction = delta > 0 ? "+" : ""
        let formatted = String(format: "%@%.1f", direction, delta)
        return VStack(alignment: .leading, spacing: JMSpacing.s) {
            Text("Notable shift")
                .font(JMFont.caption)
                .foregroundStyle(JMColor.primary)
                .tracking(1.5)
                .textCase(.uppercase)
            Text("\(formatted) points since your last entry")
                .font(JMFont.headline)
                .foregroundStyle(JMColor.textPrimary)
                .monospacedDigit()
            Text("Your score has shifted meaningfully — worth bringing up with your therapist.")
                .font(JMFont.callout)
                .foregroundStyle(JMColor.textSecondary)
                .lineSpacing(2)
        }
        .padding(JMSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .jmQuietCardFlush()
    }

    private var disclaimer: some View {
        Text("The RŌS is a validated clinical instrument developed by Seidel et al. (2016). This in-app version is for personal reflection only and does not replace clinical assessment. Share your results with your therapist.")
            .font(JMFont.caption)
            .foregroundStyle(JMColor.textSecondary)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .padding(.horizontal, JMSpacing.s)
    }
}

struct ScoreArc: View {
    let total: Double
    var max: Double = ROSEntry.maxTotal
    var cutoff: Double = ROSEntry.clinicalCutoffAdult

    private var fraction: CGFloat {
        CGFloat(min(max, Swift.max(0, total)) / max)
    }

    private let arcStart: CGFloat = 0.07
    private let arcEnd: CGFloat = 0.93

    var body: some View {
        ZStack {
            Circle()
                .trim(from: arcStart, to: arcEnd)
                .stroke(JMColor.divider, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(90))

            Circle()
                .trim(from: arcStart, to: arcStart + (arcEnd - arcStart) * fraction)
                .stroke(JMColor.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(90))

            VStack(spacing: 4) {
                Text(String(format: "%.1f", total))
                    .font(JMFont.heroNumber)
                    .jmDisplayTracking()
                    .foregroundStyle(JMColor.textPrimary)
                    .monospacedDigit()
                Text("of \(Int(max))")
                    .font(JMFont.caption)
                    .foregroundStyle(JMColor.textSecondary)
                    .tracking(1)
                    .textCase(.uppercase)
                Text("cutoff \(Int(cutoff))")
                    .font(JMFont.caption)
                    .foregroundStyle(JMColor.warning)
                    .tracking(1)
                    .textCase(.uppercase)
            }
        }
    }
}
