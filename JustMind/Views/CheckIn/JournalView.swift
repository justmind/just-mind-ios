import SwiftUI
import SwiftData

/// The daily micro-journal: three short prompts — what went well, what was a
/// challenge, and what to try differently. One entry per day (editable), with a
/// quiet list of past days below. Everything stays on-device.
struct JournalView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MoodEntry.timestamp, order: .reverse) private var entries: [MoodEntry]

    @State private var wentWell: String = ""
    @State private var challenge: String = ""
    @State private var tryDifferently: String = ""
    @State private var phase: SavePhase = .editing
    @State private var didLoadToday: Bool = false
    @State private var showFullHistory: Bool = false
    @State private var showCrisis: Bool = false
    @State private var editingEntry: MoodEntry?
    @State private var pendingDelete: MoodEntry?
    @State private var expandedEntries: Set<UUID> = []
    @FocusState private var focused: FieldID?

    private enum FieldID { case wins, challenge, experiment }
    private enum SavePhase: Equatable { case editing, confirmation }

    private var todaysEntry: MoodEntry? {
        entries.first(where: { Calendar.current.isDateInToday($0.timestamp) })
    }

    private var recentEntries: [MoodEntry] {
        Array(entries.filter { $0.hasContent }.prefix(5))
    }

    private var canSave: Bool {
        [wentWell, challenge, tryDifferently].contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
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
            .animation(.easeInOut(duration: 0.3), value: phase)
        }
        .toolbar {
            if phase == .editing {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .tint(JMColor.primary)
                        .font(JMFont.bodyEmph)
                        .disabled(!canSave)
                }
            }
        }
        .onAppear {
            if !didLoadToday { loadToday(); didLoadToday = true }
        }
        .sheet(item: $editingEntry) { JournalEntryEditorSheet(entry: $0) }
        .sheet(isPresented: $showCrisis) { CrisisResourcesView() }
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
                        Button("Done") { showFullHistory = false }.tint(JMColor.primary)
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete this entry?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { confirmDelete() }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("This permanently removes the entry from this device.")
        }
    }

    // MARK: Editing state

    private var editingState: some View {
        VStack(alignment: .leading, spacing: JMSpacing.xl) {
            header

            promptField(
                label: "What went well?",
                placeholder: "A win, a moment of ease, something you're glad about.",
                text: $wentWell,
                field: .wins
            )
            promptField(
                label: "What was a challenge?",
                placeholder: "Something that felt hard or got in the way.",
                text: $challenge,
                field: .challenge
            )
            promptField(
                label: "What could you try differently next time?",
                placeholder: "A small experiment for the days ahead.",
                text: $tryDifferently,
                field: .experiment
            )

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
            Text(todaysEntry == nil ? "Today's check-in" : "Today's check-in — saved")
                .font(JMFont.title)
                .jmDisplayTracking()
                .foregroundStyle(JMColor.textPrimary)
        }
        .padding(.top, JMSpacing.s)
    }

    private func promptField(label: String, placeholder: String, text: Binding<String>, field: FieldID) -> some View {
        VStack(alignment: .leading, spacing: JMSpacing.s) {
            Text(label)
                .font(JMFont.bodyEmph)
                .foregroundStyle(JMColor.textPrimary)
            TextEditor(text: text)
                .font(JMFont.body)
                .lineSpacing(3)
                .scrollContentBackground(.hidden)
                .focused($focused, equals: field)
                .frame(height: 96)
                .scrollIndicators(.visible)
                .padding(.horizontal, JMSpacing.m)
                .padding(.vertical, JMSpacing.s)
                .background(JMColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: JMRadius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: JMRadius.card, style: .continuous)
                        .strokeBorder(JMColor.divider, lineWidth: JMHairline.width)
                )
                .overlay(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(JMFont.callout)
                            .foregroundStyle(JMColor.textSecondary.opacity(0.55))
                            .padding(.top, JMSpacing.s + 8)
                            .padding(.leading, JMSpacing.m + 5)
                            .allowsHitTesting(false)
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
                if !recentEntries.isEmpty {
                    Button {
                        showFullHistory = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Open history")
                            Image(systemName: "arrow.right").font(.system(size: 11, weight: .light))
                        }
                        .font(JMFont.caption)
                        .foregroundStyle(JMColor.primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if recentEntries.isEmpty {
                Text("Your past check-ins will appear here.")
                    .font(JMFont.callout)
                    .foregroundStyle(JMColor.textSecondary.opacity(0.75))
                    .italic()
                    .padding(.vertical, JMSpacing.s)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentEntries.enumerated()), id: \.element.id) { idx, entry in
                        JournalEntryRow(
                            entry: entry,
                            isOpen: expandedEntries.contains(entry.id),
                            onToggle: { toggleExpanded(entry.id) },
                            onEdit: { editingEntry = entry },
                            onDelete: { pendingDelete = entry }
                        )
                        if idx < recentEntries.count - 1 { JMHairline() }
                    }
                }
                .jmQuietCardFlush()
            }
        }
    }

    // MARK: Confirmation state

    private var confirmationState: some View {
        VStack(spacing: JMSpacing.xl) {
            Spacer().frame(height: JMSpacing.xxxl)
            Image(systemName: "checkmark")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(JMColor.success)
                .frame(width: 60, height: 60)
                .overlay(Circle().strokeBorder(JMColor.success.opacity(0.4), lineWidth: 1))
            VStack(spacing: JMSpacing.s) {
                Text("Saved")
                    .font(JMFont.title)
                    .jmDisplayTracking()
                    .foregroundStyle(JMColor.textPrimary)
                Text("Today's check-in is recorded — only on this device.")
                    .font(JMFont.callout)
                    .foregroundStyle(JMColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            VStack(spacing: JMSpacing.m) {
                Button("Done") { phase = .editing }
                    .buttonStyle(.jmPrimary)
                Button("View full history") {
                    phase = .editing
                    showFullHistory = true
                }
                .buttonStyle(.jmGhost)
            }
            .padding(.horizontal, JMSpacing.l)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Actions

    private func loadToday() {
        guard let entry = todaysEntry else { return }
        wentWell = entry.wentWell
        challenge = entry.challenge
        tryDifferently = entry.tryDifferently
        // Migrate a legacy single-body entry into the first prompt so it's editable.
        if !entry.isThreePart, !entry.body.isEmpty {
            wentWell = entry.body
        }
    }

    private func save() {
        focused = nil
        let w = wentWell.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = challenge.trimmingCharacters(in: .whitespacesAndNewlines)
        let t = tryDifferently.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !(w.isEmpty && c.isEmpty && t.isEmpty) else { return }

        if let entry = todaysEntry {
            entry.wentWell = w
            entry.challenge = c
            entry.tryDifferently = t
            entry.body = "" // superseded by the three-part fields
        } else {
            let entry = MoodEntry(wentWell: w, challenge: c, tryDifferently: t)
            context.insert(entry)
        }
        try? context.save()
        wentWell = w; challenge = c; tryDifferently = t

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Local, gentle safety check — offer resources, never block or accuse.
        if JournalCrisisScan.isTriggered(in: w, c, t) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showCrisis = true }
        }

        phase = .confirmation
    }

    private func toggleExpanded(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.22)) {
            if expandedEntries.contains(id) { expandedEntries.remove(id) } else { expandedEntries.insert(id) }
        }
    }

    private func confirmDelete() {
        if let entry = pendingDelete {
            let wasToday = Calendar.current.isDateInToday(entry.timestamp)
            context.delete(entry)
            try? context.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if wasToday { wentWell = ""; challenge = ""; tryDifferently = "" }
        }
        pendingDelete = nil
    }

    private var formattedToday: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: .now)
    }
}
