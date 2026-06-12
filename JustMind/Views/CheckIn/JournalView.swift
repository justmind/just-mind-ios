import SwiftUI
import SwiftData

/// The journaling experience. Stripped to its essentials: today's prompt,
/// a comfortable writing surface, Save in the toolbar, and a quiet list of
/// past entries below so the user can scroll back through prior days at a
/// glance without leaving the screen.
struct JournalView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MoodEntry.timestamp, order: .reverse) private var entries: [MoodEntry]

    @State private var bodyText: String = ""
    @State private var phase: SavePhase = .editing
    @State private var prompt: String = JournalPrompts.promptForToday()
    @State private var expandedEntries: Set<UUID> = []
    @State private var showFullHistory: Bool = false
    @FocusState private var bodyFocused: Bool

    private enum SavePhase: Equatable {
        case editing
        case confirmation
    }

    /// Last 5 entries surfaced in the inline "Past entries" section.
    /// Anything more is reachable via the "View full history" link.
    private var recentEntries: [MoodEntry] {
        Array(entries.prefix(5))
    }

    var body: some View {
        ScrollView {
            ZStack {
                editingState
                    .opacity(phase == .editing ? 1 : 0)
                    .allowsHitTesting(phase == .editing)
                confirmationState
                    .opacity(phase == .confirmation ? 1 : 0)
                    .allowsHitTesting(phase == .confirmation)
            }
            .animation(.easeInOut(duration: 0.30), value: phase)
        }
        .toolbar {
            if phase == .editing {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .tint(JMColor.primary)
                        .font(JMFont.bodyEmph)
                        .disabled(trimmedBody.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showFullHistory) {
            NavigationStack {
                ScrollView {
                    JournalHistoryView()
                        .padding(.horizontal, JMSpacing.l)
                        .padding(.bottom, JMSpacing.xxl)
                }
                .background(JMColor.background.ignoresSafeArea())
                .navigationTitle("History")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showFullHistory = false }
                            .tint(JMColor.primary)
                    }
                }
            }
        }
    }

    // MARK: Editing state

    private var editingState: some View {
        VStack(alignment: .leading, spacing: JMSpacing.xl) {
            header
            entryField
            JMHairline().padding(.vertical, JMSpacing.s)
            pastEntries
        }
        .padding(.horizontal, JMSpacing.l)
        .padding(.bottom, JMSpacing.xxl)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: JMSpacing.s) {
            Text(formattedToday)
                .font(JMFont.sectionLabel)
                .foregroundStyle(JMColor.textSecondary)
                .tracking(0.96)
                .textCase(.uppercase)
            Text(prompt)
                .font(JMFont.title)
                .jmDisplayTracking()
                .foregroundStyle(JMColor.textPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, JMSpacing.s)
    }

    private var entryField: some View {
        VStack(alignment: .leading, spacing: JMSpacing.s) {
            // Fixed height + visible indicators: gives the editor a real
            // scroll region so longer entries scroll within the box (rather
            // than pushing past entries off the page) and the scroll bar
            // stays visible while there's overflow.
            TextEditor(text: $bodyText)
                .font(JMFont.body)
                .lineSpacing(4)
                .scrollContentBackground(.hidden)
                .background(JMColor.background)
                .focused($bodyFocused)
                .frame(height: 220)
                .scrollIndicators(.visible)
                .overlay(alignment: .topLeading) {
                    if bodyText.isEmpty {
                        Text("Write what you'd want to bring to your next session.")
                            .font(JMFont.body)
                            .foregroundStyle(JMColor.textSecondary.opacity(0.55))
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }
            JMHairline()
            HStack {
                Text(wordCountLabel)
                    .font(JMFont.caption)
                    .foregroundStyle(JMColor.textSecondary)
                    .monospacedDigit()
                Spacer()
                if bodyFocused {
                    Button("Done") { bodyFocused = false }
                        .font(JMFont.caption)
                        .foregroundStyle(JMColor.primary)
                }
            }
        }
    }

    private var pastEntries: some View {
        VStack(alignment: .leading, spacing: JMSpacing.m) {
            HStack {
                Text("Past entries")
                    .font(JMFont.sectionLabel)
                    .foregroundStyle(JMColor.textSecondary)
                    .tracking(0.96)
                    .textCase(.uppercase)
                Spacer()
                // Always offer a path into the full grouped-by-day history,
                // not just when there are more than 5 entries — long entries
                // push siblings off-screen even with only one or two saves.
                if !entries.isEmpty {
                    Button {
                        showFullHistory = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Open history")
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .light))
                        }
                        .font(JMFont.caption)
                        .foregroundStyle(JMColor.primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if recentEntries.isEmpty {
                Text("Your past notes will appear here.")
                    .font(JMFont.callout)
                    .foregroundStyle(JMColor.textSecondary.opacity(0.75))
                    .italic()
                    .padding(.vertical, JMSpacing.s)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentEntries.enumerated()), id: \.element.id) { idx, entry in
                        pastEntryRow(entry: entry)
                        if idx < recentEntries.count - 1 {
                            JMHairline()
                        }
                    }
                }
                .jmQuietCardFlush()
            }
        }
    }

    private func pastEntryRow(entry: MoodEntry) -> some View {
        let isOpen = expandedEntries.contains(entry.id)
        return Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                if isOpen { expandedEntries.remove(entry.id) }
                else { expandedEntries.insert(entry.id) }
            }
        } label: {
            VStack(alignment: .leading, spacing: JMSpacing.s) {
                HStack(alignment: .top, spacing: JMSpacing.l) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formattedRelative(entry.timestamp))
                            .font(JMFont.caption)
                            .foregroundStyle(JMColor.textSecondary)
                            .tracking(0.5)
                            .textCase(.uppercase)
                        if entry.body.isEmpty {
                            Text("(empty)")
                                .font(JMFont.callout)
                                .foregroundStyle(JMColor.textSecondary.opacity(0.6))
                                .italic()
                        } else {
                            // Capped inline expansion (≤8 lines) so a long
                            // entry doesn't push older entries off-screen.
                            // For full text, the user opens history.
                            Text(entry.body)
                                .font(JMFont.body)
                                .foregroundStyle(JMColor.textPrimary)
                                .lineLimit(isOpen ? 8 : 2)
                                .lineSpacing(3)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    Spacer()
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(JMColor.textSecondary.opacity(0.6))
                        .padding(.top, 6)
                }
                if isOpen {
                    if !entry.prompt.isEmpty {
                        Text(entry.prompt)
                            .font(JMFont.footnote)
                            .foregroundStyle(JMColor.textSecondary)
                            .italic()
                            .lineSpacing(2)
                            .padding(.top, JMSpacing.xs)
                    }
                    Button {
                        showFullHistory = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Read full entry in history")
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .light))
                        }
                        .font(JMFont.caption)
                        .foregroundStyle(JMColor.primary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, JMSpacing.xs)
                }
            }
            .padding(.horizontal, JMSpacing.l)
            .padding(.vertical, JMSpacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Confirmation state

    private var confirmationState: some View {
        VStack(spacing: JMSpacing.xl) {
            Spacer().frame(height: JMSpacing.xxxl)

            Image(systemName: "checkmark")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(JMColor.success)
                .frame(width: 60, height: 60)
                .overlay(
                    Circle().strokeBorder(JMColor.success.opacity(0.4), lineWidth: 1)
                )

            VStack(spacing: JMSpacing.s) {
                Text("Saved")
                    .font(JMFont.title)
                    .jmDisplayTracking()
                    .foregroundStyle(JMColor.textPrimary)
                Text("Your note is recorded — only on this device.")
                    .font(JMFont.callout)
                    .foregroundStyle(JMColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            VStack(spacing: JMSpacing.m) {
                Button("New Entry") {
                    resetForm()
                }
                .buttonStyle(.jmPrimary)
                Button {
                    resetForm()
                    showFullHistory = true
                } label: {
                    Text("View full history")
                }
                .buttonStyle(.jmGhost)
            }
            .padding(.horizontal, JMSpacing.l)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Helpers

    private var trimmedBody: String {
        bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var wordCountLabel: String {
        let count = bodyText.split { !$0.isLetter && !$0.isNumber && $0 != "'" }.count
        return "\(count) word\(count == 1 ? "" : "s")"
    }

    private func save() {
        guard !trimmedBody.isEmpty else { return }
        bodyFocused = false
        // score=3 is a placeholder kept for schema compatibility — the
        // emoji UI was removed. The field stays so we don't have to migrate.
        let entry = MoodEntry(
            score: 3,
            body: trimmedBody,
            tags: [],
            prompt: prompt
        )
        context.insert(entry)
        try? context.save()

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        phase = .confirmation
    }

    private func resetForm() {
        bodyText = ""
        prompt = JournalPrompts.promptForToday()
        phase = .editing
    }

    private var formattedToday: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: .now)
    }

    private func formattedRelative(_ d: Date) -> String {
        let f = DateFormatter()
        if Calendar.current.isDateInToday(d) {
            f.dateFormat = "'Today' · h:mm a"
        } else if Calendar.current.isDateInYesterday(d) {
            f.dateFormat = "'Yesterday' · h:mm a"
        } else {
            f.dateFormat = "EEE, MMM d"
        }
        return f.string(from: d)
    }
}
