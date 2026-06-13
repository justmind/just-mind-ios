import SwiftUI

struct ROSResultsView: View {
    let individual: Double
    let interpersonal: Double
    let social: Double
    let overall: Double
    let previousTotal: Double?
    /// Receives the optional reflection note (nil if skipped). (Change 2.)
    let onDone: (String?) -> Void
    let onDiscard: () -> Void

    @State private var showCrisis: Bool = false
    @State private var reflectionNote: String = ""
    @State private var showLowScoreSupport: Bool = false

    private let reflectionLimit = 500
    private let lowScoreThreshold: Double = 10
    private static let safetyPromptKey = "ros_safety_prompt_last_shown"

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

            if !aboveCutoff {
                crisisPrompt
            }

            if let delta = rciDelta, abs(delta) >= ROSEntry.reliableChangeIndex {
                rciCard(delta: delta)
            }

            reflectionField

            disclaimer

            VStack(spacing: JMSpacing.m) {
                Button {
                    let trimmed = reflectionNote.trimmingCharacters(in: .whitespacesAndNewlines)
                    onDone(trimmed.isEmpty ? nil : trimmed)
                } label: { Text("Done") }
                    .buttonStyle(.jmPrimary)
                Button {
                    onDiscard()
                } label: { Text("Discard this entry") }
                    .buttonStyle(.jmGhost)
            }
        }
        .sheet(isPresented: $showCrisis) { CrisisResourcesView() }
        .sheet(isPresented: $showLowScoreSupport) { LowScoreSupportSheet() }
        .onAppear { maybeShowLowScoreSupport() }
    }

    /// Optional free-text reflection, shown below the score summary. (Change 2.)
    private var reflectionField: some View {
        VStack(alignment: .leading, spacing: JMSpacing.s) {
            Text("Your note (optional)")
                .font(JMFont.sectionLabel)
                .foregroundStyle(JMColor.textSecondary)
                .tracking(0.96)
                .textCase(.uppercase)
            Text("What's been most on your mind this week?")
                .font(JMFont.bodyEmph)
                .foregroundStyle(JMColor.textPrimary)
            TextEditor(text: $reflectionNote)
                .font(JMFont.body)
                .lineSpacing(3)
                .scrollContentBackground(.hidden)
                .frame(height: 110)
                .overlay(alignment: .topLeading) {
                    if reflectionNote.isEmpty {
                        Text("You don't have to have it all figured out. Just write what comes up.")
                            .font(JMFont.body)
                            .foregroundStyle(JMColor.textSecondary.opacity(0.55))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .onChange(of: reflectionNote) { _, newValue in
                    if newValue.count > reflectionLimit {
                        reflectionNote = String(newValue.prefix(reflectionLimit))
                    }
                }
            HStack {
                Spacer()
                Text("\(reflectionNote.count)/\(reflectionLimit)")
                    .font(JMFont.caption)
                    .foregroundStyle(JMColor.textSecondary.opacity(0.7))
                    .monospacedDigit()
            }
        }
        .padding(JMSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(JMColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: JMRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: JMRadius.card, style: .continuous)
                .strokeBorder(JMColor.divider, lineWidth: JMHairline.width)
        )
    }

    /// Present the supportive sheet once per calendar day when the total is
    /// very low. (Change 3.)
    private func maybeShowLowScoreSupport() {
        guard total <= lowScoreThreshold else { return }
        let d = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: .now)
        if let last = d.object(forKey: Self.safetyPromptKey) as? Date,
           Calendar.current.isDate(last, inSameDayAs: today) {
            return // already shown today
        }
        d.set(today, forKey: Self.safetyPromptKey)
        // Slight delay so it doesn't fight the results screen's entrance.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            showLowScoreSupport = true
        }
    }

    /// Gentle, non-alarmist offer of crisis resources when the score is below
    /// the clinical cutoff. Not a diagnosis — just makes help one tap away.
    private var crisisPrompt: some View {
        Button {
            showCrisis = true
        } label: {
            HStack(spacing: JMSpacing.m) {
                Image(systemName: "lifepreserver")
                    .font(.system(size: 16))
                    .foregroundStyle(JMColor.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Need support right now?")
                        .font(JMFont.bodyEmph)
                        .foregroundStyle(JMColor.textPrimary)
                    Text("Crisis lines are open 24/7 — call or text")
                        .font(JMFont.caption)
                        .foregroundStyle(JMColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(JMColor.textSecondary.opacity(0.7))
            }
            .padding(JMSpacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(JMColor.warning.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: JMRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: JMRadius.card, style: .continuous)
                    .strokeBorder(JMColor.warning.opacity(0.25), lineWidth: JMHairline.width)
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens crisis support resources")
    }

    private var scoreBreakdown: some View {
        VStack(spacing: 0) {
            row("How I'm feeling inside", individual)
            JMHairline()
            row("My close relationships", interpersonal)
            JMHairline()
            row("Work, school & daily life", social)
            JMHairline()
            row("Life in general", overall)
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
        Text("The Wellbeing Check-In is based on the RŌS, a validated clinical instrument developed by Seidel et al. (2016). This in-app version is for personal reflection only and does not replace clinical assessment. Share your results with your therapist.")
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
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
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
            .padding(.horizontal, JMSpacing.l)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Wellbeing Check-In total score")
        .accessibilityValue(String(format: "%.1f out of %d. Clinical cutoff is %d.", total, Int(max), Int(cutoff)))
    }
}
