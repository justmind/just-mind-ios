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
    @State private var displayedQuote: String = QuoteService.quoteForToday()
    @State private var allianceScore: Double = 5.0
    @State private var allianceDismissed: Bool = false
    @State private var featuredPost: BlogPost?
    @State private var didLoadFeatured: Bool = false

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
        items.append(("quickActions", AnyView(quickActions)))
        if wciEntries.count >= 2 {
            items.append(("wciTrend", AnyView(wciTrendCard)))
        }
        if allianceEntries.count >= 2 {
            items.append(("allianceTrend", AnyView(allianceSparkline)))
        }
        if let appt = prefs.nextAppointment, appt.timeIntervalSinceNow > 0,
           appt.timeIntervalSinceNow < 72 * 3600 {
            items.append(("appointment", AnyView(appointmentCard(date: appt))))
        }
        if let post = featuredPost {
            items.append(("featuredBlog", AnyView(featuredBlogCard(post))))
        }
        items.append(("quote", AnyView(quoteCard)))
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

    private func featuredBlogCard(_ post: BlogPost) -> some View {
        Button {
            if let url = URL(string: post.url) {
                safariItem = SafariSheetItem(url: url)
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                if let urlStr = post.imageURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        case .empty: Rectangle().fill(JMColor.divider).overlay(ProgressView())
                        default: Rectangle().fill(JMColor.divider)
                        }
                    }
                    .frame(height: 150)
                    .clipped()
                }
                VStack(alignment: .leading, spacing: JMSpacing.s) {
                    Text(prefs.preferredBlogTopics.isEmpty ? "From the Just Mind blog" : "For you · from the Just Mind blog")
                        .font(JMFont.sectionLabel)
                        .foregroundStyle(JMColor.textSecondary)
                        .tracking(0.96)
                        .textCase(.uppercase)
                    Text(post.title)
                        .font(JMFont.blogTitle)
                        .foregroundStyle(JMColor.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    if !post.excerpt.isEmpty {
                        Text(post.excerpt)
                            .font(JMFont.callout)
                            .foregroundStyle(JMColor.textSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                }
                .padding(JMSpacing.l)
            }
            .background(JMColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: JMRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: JMRadius.card, style: .continuous)
                    .strokeBorder(JMColor.divider, lineWidth: JMHairline.width)
            )
        }
        .buttonStyle(.plain)
    }

    private func loadFeaturedPost() async {
        guard !didLoadFeatured else { return }
        didLoadFeatured = true
        let post = await BlogService.shared.featuredPost(forTopicLabels: prefs.preferredBlogTopics)
        await MainActor.run { featuredPost = post }
    }

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
            .task { await loadFeaturedPost() }
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
        VStack(spacing: 0) {
            // "Write today's entry" lives on the TODAY card above, so it's not
            // repeated here.
            quickActionRow(systemImage: "list.bullet", title: "Complete WCI") {
                selectedTab = .checkIn; checkInSection = .ros
            }
            JMHairline()
            quickActionRow(systemImage: "message", title: "Message my therapist") {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                safariItem = SafariSheetItem(url: URL(string: "https://justmind.intakeq.com/portal")!)
            }
        }
        .jmQuietCardFlush()
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

    /// Quote card: a moment of stillness. No card chrome, no border, no shadow.
    /// Sits flush on the background. Italic body, slow fades.
    private var quoteCard: some View {
        VStack(alignment: .leading, spacing: JMSpacing.s) {
            Text(displayedQuote)
                .font(.system(size: 16, weight: .regular).italic())
                .foregroundStyle(JMColor.textPrimary)
                .lineSpacing(16 * 0.6) // ~line-height 1.6 for 16pt
                .fixedSize(horizontal: false, vertical: true)
                .id(displayedQuote)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.6), value: displayedQuote)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, JMSpacing.cardV)
        .padding(.horizontal, 0) // flush with background, no border
        .onAppear {
            // Refresh the quote (with a slow fade) when the view shows up.
            let next = QuoteService.quoteForToday()
            if next != displayedQuote {
                withAnimation { displayedQuote = next }
            }
        }
    }

    private func appointmentCard(date: Date) -> some View {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d 'at' h:mm a"
        return VStack(alignment: .leading, spacing: JMSpacing.s) {
            Text("Next session")
                .font(JMFont.sectionLabel)
                .foregroundStyle(JMColor.textSecondary)
                .tracking(0.96)
                .textCase(.uppercase)
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
