import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppPreferences.self) private var prefs
    @Environment(\.modelContext) private var context
    @Binding var selectedTab: RootTab
    @Binding var checkInSection: CheckInSection
    @State private var safariItem: SafariSheetItem?
    @State private var showSessionPrep: Bool = false
    @State private var cardsAppeared: [Bool] = []
    @State private var displayedQuote: String = QuoteService.quoteForToday()

    @Query(sort: \MoodEntry.timestamp, order: .reverse) private var moods: [MoodEntry]

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
        items.append(("mood", AnyView(moodSummaryCard)))
        items.append(("quickActions", AnyView(quickActions)))
        if let appt = prefs.nextAppointment, appt.timeIntervalSinceNow > 0,
           appt.timeIntervalSinceNow < 72 * 3600 {
            items.append(("appointment", AnyView(appointmentCard(date: appt))))
        }
        items.append(("quote", AnyView(quoteCard)))
        return items
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
        idx < cardsAppeared.count ? cardsAppeared[idx] : false
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
                    HStack {
                        Text("Write today's entry")
                            .font(JMFont.bodyEmph)
                            .foregroundStyle(JMColor.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(JMColor.textSecondary)
                    }
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
            quickActionRow(systemImage: "pencil.line", title: "Write today's entry") {
                selectedTab = .checkIn; checkInSection = .journal
            }
            JMHairline()
            quickActionRow(systemImage: "list.bullet", title: "Complete RŌS") {
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
    /// Sits flush on the background. Sage leaf, italic body, slow fades.
    private var quoteCard: some View {
        VStack(alignment: .leading, spacing: JMSpacing.s) {
            Image(systemName: "leaf")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(JMColor.primary.opacity(0.55)) // muted sage
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
