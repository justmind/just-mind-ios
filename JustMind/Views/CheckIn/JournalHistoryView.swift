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
    @Query(sort: \MoodEntry.timestamp, order: .reverse) private var allEntries: [MoodEntry]
    @State private var window: Window = .thirtyDay
    @State private var expanded: Set<UUID> = []
    @State private var editingEntry: MoodEntry?
    @State private var pendingDelete: MoodEntry?

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
                ForEach(grouped, id: \.date) { day in
                    daySection(date: day.date, entries: day.entries)
                }
            }
        }
        .sheet(item: $editingEntry) { JournalEntryEditorSheet(entry: $0) }
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
                    entryRow(entry: entry)
                    if idx < entries.count - 1 {
                        JMHairline()
                    }
                }
            }
            .jmQuietCardFlush()
        }
    }

    private func entryRow(entry: MoodEntry) -> some View {
        let isOpen = expanded.contains(entry.id)
        return Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                if isOpen { expanded.remove(entry.id) } else { expanded.insert(entry.id) }
            }
        } label: {
            VStack(alignment: .leading, spacing: JMSpacing.s) {
                HStack(alignment: .top, spacing: JMSpacing.m) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formattedTime(entry.timestamp))
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
                            Text(entry.body)
                                .font(JMFont.body)
                                .foregroundStyle(JMColor.textPrimary)
                                .lineLimit(isOpen ? nil : 3)
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
                if isOpen, !entry.prompt.isEmpty {
                    Text(entry.prompt)
                        .font(JMFont.footnote)
                        .foregroundStyle(JMColor.textSecondary)
                        .italic()
                        .lineSpacing(2)
                        .padding(.top, JMSpacing.xs)
                }
            }
            .padding(.horizontal, JMSpacing.l)
            .padding(.vertical, JMSpacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                editingEntry = entry
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                pendingDelete = entry
            } label: {
                Label("Delete", systemImage: "trash")
            }
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

    private func formattedTime(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: d)
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
