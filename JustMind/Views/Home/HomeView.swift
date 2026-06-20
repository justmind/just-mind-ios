import SwiftUI
import SwiftData
import Charts

struct HomeView: View {
    @Environment(AppPreferences.self) private var prefs
    @Environment(\.modelContext) private var context
    @Binding var selectedTab: RootTab
    @Binding var checkInSection: CheckInSection
    @State private var safariItem: SafariSheetItem?
    @State private var showSessionPrep: Bool = false
    @State private var cardsAppeared: [Bool] = []
    @State private var allianceScore: Double = 5.0
    @State private var allianceDismissed: Bool = false

    private let portalURL = URL(string: "https://justmind.intakeq.com/portal")!

    @Query(sort: \MoodEntry.timestamp, order: .reverse) private var moods: [MoodEntry]
    @Query(sort: \SessionAllianceEntry.date, order: .reverse) private var allianceEntries: [SessionAllianceEntry]
    @Query(sort: \ROSEntry.timestamp, order: .reverse) private var wciEntries: [ROSEntry]

    private static let allianceHandledKey = "ros_alliance_handled_appointment"

    private var todayMood: MoodEntry? {
        moods.first(where: { Calendar.current.isDateInToday($0.timestamp) })
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        let stem: String
        switch h {
        case 5..<12: stem = "Good morning"
        case 12..<17: stem = "Good afternoon"
        case 17..<22: stem = "Good evening"
        default: stem = "Hello"
        }
        let raw = prefs.preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = raw.capitalized
        return name.isEmpty ? stem : "\(stem),\n\(name)."
    }

    /// All home cards in render order. Used by the staggered entry animation
    /// so each row fades up sequentially regardless of conditional inclusion.
    private var cards: [(id: String, view: AnyView)] {
        var items: [(id: String, view: AnyView)] = []
        if showAllianceCard {
            items.append(("alliance", AnyView(allianceInputCard)))
        }
        items.append(("mood", AnyView(moodSummaryCard)))
        // Show the next appointment whenever one is entered and still upcoming.
        if let appt = prefs.nextAppointment, appt.timeIntervalSinceNow > 0 {
            items.append(("appointment", AnyView(appointmentCard(date: appt))))
        }
        items.append(("quickActions", AnyView(quickActions)))
        if wciEntries.count >= 2 {
            items.append(("wciTrend", AnyView(wciTrendCard)))
        }
        if allianceEntries.count >= 2 {
            items.append(("allianceTrend", AnyView(allianceSparkline)))
        }
        return items
    }

    // MARK: Wellbeing trend snapshot

    private var wciTrendCard: some View {
        Button {
            selectedTab = .checkIn
            checkInSection = .ros
        } label: {
            ROSTrendsSnapshot(entries: Array(wciEntries))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens your Wellbeing Check-In trends")
    }

    // MARK: Featured blog article

    // MARK: Session alliance (Change 5)

    /// True only within 4 hours after the entered appointment time, and only
    /// if we haven't already handled (saved or skipped) this appointment.
    private var showAllianceCard: Bool {
        guard !allianceDismissed, let appt = prefs.nextAppointment else { return false }
        let now = Date()
        guard now >= appt, now <= appt.addingTimeInterval(4 * 3600) else { return false }
        if let handled = UserDefaults.standard.object(forKey: Self.allianceHandledKey) as? Date,
           abs(handled.timeIntervalSince(appt)) < 1 {
            return false
        }
        return true
    }

    private func markAllianceHandled() {
        if let appt = prefs.nextAppointment {
            UserDefaults.standard.set(appt, forKey: Self.allianceHandledKey)
        }
        allianceDismissed = true
    }

    private var allianceInputCard: some View {
        VStack(alignment: .leading, spacing: JMSpacing.m) {
            Text("Today's session")
                .font(JMFont.sectionLabel)
                .foregroundStyle(JMColor.textSecondary)
                .tracking(0.96)
                .textCase(.uppercase)
            Text("How did your session go?")
                .font(JMFont.headline)
                .foregroundStyle(JMColor.textPrimary)

            VASSlider(
                value: $allianceScore,
                leftLabel: "Didn't fit what I needed",
                rightLabel: "Fit perfectly",
                accessibilityHint: "Session fit, 0 to 10"
            )

            HStack(spacing: JMSpacing.m) {
                Button("Skip") {
                    withAnimation { markAllianceHandled() }
                }
                .buttonStyle(.jmGhost)
                Button("Save") {
                    let entry = SessionAllianceEntry(score: allianceScore)
                    context.insert(entry)
                    try? context.save()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation { markAllianceHandled() }
                }
                .buttonStyle(.jmPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .jmQuietCard()
    }

    private var allianceSparkline: some View {
        let recent = Array(allianceEntries.prefix(8)).reversed()
        return VStack(alignment: .leading, spacing: JMSpacing.s) {
            Text("Session fit over time")
                .font(JMFont.sectionLabel)
                .foregroundStyle(JMColor.textSecondary)
                .tracking(0.96)
                .textCase(.uppercase)
            Chart {
                ForEach(Array(recent.enumerated()), id: \.element.id) { _, e in
                    LineMark(
                        x: .value("Date", e.date),
                        y: .value("Fit", e.score)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(JMColor.primary)
                    .lineStyle(StrokeStyle(lineWidth: 1.75, lineCap: .round))
                    PointMark(
                        x: .value("Date", e.date),
                        y: .value("Fit", e.score)
                    )
                    .foregroundStyle(JMColor.primary)
                    .symbolSize(24)
                }
            }
            .chartYScale(domain: 0...10)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 56)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .jmQuietCard()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(greeting)
                        .font(JMFont.greeting)
                        .foregroundStyle(JMColor.textPrimary)
                        .lineSpacing(2)
                        .padding(.top, JMSpacing.s)
                        .padding(.bottom, JMSpacing.greetingTrailing)

                    VStack(alignment: .leading, spacing: JMSpacing.homeCardGap) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { idx, item in
                            item.view
                                .opacity(appearanceState(idx) ? 1 : 0)
                                .offset(y: appearanceState(idx) ? 0 : 4)
                        }
                    }
                }
                .padding(.horizontal, JMSpacing.l)
                .padding(.bottom, JMSpacing.xxl)
            }
            .background(JMColor.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // Mini home-screen icon: same artwork as AppIcon, clipped
                    // to a continuous-corner squircle to match what iOS shows
                    // on the home screen.
                    Image("LogoSquareMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .accessibilityLabel("Just Mind")
                }
            }
            .sheet(item: $safariItem) { SafariView(url: $0.url) }
            .sheet(isPresented: $showSessionPrep) { SessionPrepSheet() }
            .onAppear { animateEntry() }
        }
    }

    // MARK: Stagger animation

    private func appearanceState(_ idx: Int) -> Bool {
        // Cards added after the initial stagger (e.g. the alliance card or its
        // sparkline appearing mid-session) just show, rather than staying hidden.
        idx < cardsAppeared.count ? cardsAppeared[idx] : true
    }

    private func animateEntry() {
        let count = cards.count
        // Skip re-animating if already shown this session.
        if cardsAppeared.count == count, cardsAppeared.allSatisfy({ $0 }) { return }
        cardsAppeared = Array(repeating: false, count: count)
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.060) {
                withAnimation(.easeOut(duration: 0.28)) {
                    if i < cardsAppeared.count {
                        cardsAppeared[i] = true
                    }
                }
            }
        }
    }

    // MARK: Cards

    private var moodSummaryCard: some View {
        Button {
            selectedTab = .checkIn
            checkInSection = .journal
        } label: {
            VStack(alignment: .leading, spacing: JMSpacing.s) {
                Text("Today")
                    .font(JMFont.sectionLabel)
                    .foregroundStyle(JMColor.textSecondary)
                    .tracking(0.96)
                    .textCase(.uppercase)
                if let m = todayMood, !m.body.isEmpty {
                    Text(m.body)
                        .font(JMFont.body)
                        .foregroundStyle(JMColor.textPrimary)
                        .lineLimit(4)
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                } else {
                    // Show the actual daily prompt as an invitation, with a
                    // quiet secondary action beneath it.
                    Text(JournalPrompts.promptForToday())
                        .font(JMFont.headline)
                        .foregroundStyle(JMColor.textPrimary)
                        .lineLimit(3)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Text("Write today's entry")
                            .font(JMFont.callout)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .light))
                    }
                    .foregroundStyle(JMColor.primary)
                    .padding(.top, JMSpacing.xs)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .jmQuietCard()
        .jmPrivacySensitive()
        .accessibilityHint("Opens today's journal entry")
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: JMSpacing.s) {
            VStack(spacing: 0) {
                // "Write today's entry" lives on the TODAY card above, so it's
                // not repeated here.
                quickActionRow(systemImage: "list.bullet", title: "Complete WCI") {
                    selectedTab = .checkIn; checkInSection = .ros
                }
                JMHairline()
                quickActionRow(systemImage: "message", title: "Message my therapist") {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    safariItem = SafariSheetItem(url: portalURL)
                }
                JMHairline()
                quickActionRow(systemImage: "doc.text", title: "Invoices & billing") {
                    safariItem = SafariSheetItem(url: portalURL)
                }
                JMHairline()
                quickActionRow(systemImage: "creditcard", title: "Payment method") {
                    safariItem = SafariSheetItem(url: portalURL)
                }
            }
            .jmQuietCardFlush()

            Text("For scheduling questions, it's best to email your therapist directly.")
                .font(JMFont.caption)
                .foregroundStyle(JMColor.textSecondary)
                .padding(.horizontal, JMSpacing.xs)
        }
    }

    private func quickActionRow(systemImage: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: JMSpacing.l) {
                // Icon foreground neutralized — green is reserved for primary CTAs.
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(JMColor.textSecondary)
                    .frame(width: 24)
                Text(title)
                    .font(JMFont.bodyEmph) // 17/500 per spec
                    .foregroundStyle(JMColor.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(JMColor.textSecondary.opacity(0.7))
            }
            .padding(.horizontal, JMSpacing.l)
            .padding(.vertical, JMSpacing.cardV) // 20pt min per spec
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }


    private func appointmentCard(date: Date) -> some View {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d 'at' h:mm a"
        return VStack(alignment: .leading, spacing: JMSpacing.s) {
            HStack {
                Text("Next session")
                    .font(JMFont.sectionLabel)
                    .foregroundStyle(JMColor.textSecondary)
                    .tracking(0.96)
                    .textCase(.uppercase)
                Spacer()
                Text(relativeAppointment(date))
                    .font(JMFont.caption)
                    .foregroundStyle(JMColor.primary)
            }
            Text(f.string(from: date))
                .font(JMFont.title)
                .foregroundStyle(JMColor.textPrimary)
            Button {
                showSessionPrep = true
            } label: {
                HStack(spacing: 6) {
                    Text("Prepare for your session")
                        .font(JMFont.bodyEmph)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .light))
                }
                .foregroundStyle(JMColor.primary)
            }
            .buttonStyle(.plain)
            .padding(.top, JMSpacing.s)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .jmCard(elevated: true)
    }

    /// "Today" / "Tomorrow" / "In N days" for the appointment overline.
    private func relativeAppointment(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: date)).day ?? 0
        if days <= 7 { return "In \(days) days" }
        return ""
    }
}

private struct SessionPrepSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: JMSpacing.l) {
                Text("What do you want to bring up with your therapist today?")
                    .font(JMFont.title)
                    .jmDisplayTracking()
                    .foregroundStyle(JMColor.textPrimary)
                    .lineSpacing(2)
                Text("Not saved — just a place to think out loud.")
                    .font(JMFont.footnote)
                    .foregroundStyle(JMColor.textSecondary)
                JMHairline()
                TextEditor(text: $note)
                    .font(JMFont.body)
                    .lineSpacing(3)
                    .scrollContentBackground(.hidden)
                    .background(JMColor.background)
                    .frame(minHeight: 240)
                Spacer()
            }
            .padding(JMSpacing.l)
            .background(JMColor.background.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(JMColor.primary)
                }
            }
            .jmPrivacySensitive()
        }
    }
}
