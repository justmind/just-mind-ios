import SwiftUI
import SwiftData

/// History of journal entries — a clean date-grouped list. No chart, no
/// filter strip. Entries expand inline on tap to show the full body and
/// the prompt the user was writing against.
struct JournalHistoryView: View {
    enum Window: String, CaseIterable, Identifiable {
        case sevenDay = "7 days"
        case thirtyDay = "30 days"
        case ninetyDay = "90 days"
        case all = "All"
        var id: String { rawValue }
        var days: Int? {
            switch self {
            case .sevenDay: return 7
            case .thirtyDay: return 30
            case .ninetyDay: return 90
            case .all: return nil
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Environment(AppPreferences.self) private var prefs
    @Query(sort: \MoodEntry.timestamp, order: .reverse) private var allEntries: [MoodEntry]
    @State private var window: Window = .thirtyDay
    @State private var expanded: Set<UUID> = []
    @State private var editingEntry: MoodEntry?
    @State private var pendingDelete: MoodEntry?
    @State private var shareItem: ShareItem?

    private var windowed: [MoodEntry] {
        guard let days = window.days else { return allEntries }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        return allEntries.filter { $0.timestamp >= cutoff }
    }

    /// Groups entries by calendar day, newest day first. Each value is
    /// already sorted newest-first within the day (because allEntries is
    /// queried .reverse).
    private var grouped: [(date: Date, entries: [MoodEntry])] {
        let cal = Calendar.current
        let buckets = Dictionary(grouping: windowed) { cal.startOfDay(for: $0.timestamp) }
        return buckets.keys.sorted(by: >).map { day in
            (date: day, entries: buckets[day] ?? [])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: JMSpacing.l) {
            Picker("Window", selection: $window) {
                ForEach(Window.allCases) { w in Text(w.rawValue).tag(w) }
            }
            .pickerStyle(.segmented)

            if allEntries.isEmpty {
                EmptyStateCard(
                    icon: "leaf",
                    text: "No entries yet. Start today — it only takes a minute."
                )
            } else if windowed.isEmpty {
                EmptyStateCard(
                    icon: "calendar",
                    text: "No entries in this window. Try a longer range."
                )
            } else {
                weeklyDigestButton
                ForEach(grouped, id: \.date) { day in
                    daySection(date: day.date, entries: day.entries)
                }
            }
        }
        .sheet(item: $editingEntry) { JournalEntryEditorSheet(entry: $0) }
        .sheet(item: $shareItem) { ShareSheet(items: [$0.url], cleanupURLs: [$0.url]) }
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
            Text("This permanently removes the entry from this device.")
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

    private var weeklyDigestButton: some View {
        Button {
            if let url = JournalDigestPDFExporter.makeWeeklyDigest(
                entries: allEntries,
                clientName: prefs.preferredName.capitalized
            ) {
                shareItem = ShareItem(url: url)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 14))
                Text("Share weekly digest with my therapist")
            }
        }
        .buttonStyle(.jmGhost)
        .accessibilityHint("Creates a PDF of the last 7 days of check-ins to email or share")
    }

    // MARK: Day section

    private func daySection(date: Date, entries: [MoodEntry]) -> some View {
        VStack(alignment: .leading, spacing: JMSpacing.s) {
            Text(formattedDay(date))
                .font(JMFont.sectionLabel)
                .foregroundStyle(JMColor.textSecondary)
                .tracking(0.96)
                .textCase(.uppercase)
            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                    JournalEntryRow(
                        entry: entry,
                        isOpen: expanded.contains(entry.id),
                        onToggle: {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                if expanded.contains(entry.id) { expanded.remove(entry.id) }
                                else { expanded.insert(entry.id) }
                            }
                        },
                        onEdit: { editingEntry = entry },
                        onDelete: { pendingDelete = entry }
                    )
                    if idx < entries.count - 1 {
                        JMHairline()
                    }
                }
            }
            .jmQuietCardFlush()
        }
    }

    private func formattedDay(_ d: Date) -> String {
        let f = DateFormatter()
        if Calendar.current.isDateInToday(d) {
            return "TODAY · \(longDate(d))"
        } else if Calendar.current.isDateInYesterday(d) {
            return "YESTERDAY · \(longDate(d))"
        }
        f.dateFormat = "EEEE · MMM d"
        return f.string(from: d).uppercased()
    }

    private func longDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: d).uppercased()
    }
}

struct EmptyStateCard: View {
    let icon: String
    let text: String
    var body: some View {
        VStack(spacing: JMSpacing.m) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(JMColor.textSecondary.opacity(0.7))
            Text(text)
                .font(JMFont.body)
                .foregroundStyle(JMColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, JMSpacing.xl)
        .padding(.horizontal, JMSpacing.l)
        .frame(maxWidth: .infinity)
        .jmQuietCard()
    }
}
