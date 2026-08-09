import SwiftUI

/// A single journal-entry row: shows the day, a preview when collapsed, and the
/// three-part reflection when expanded. Falls back to the legacy single-body
/// text for entries made before the three-prompt format. Long-press to edit or
/// delete.
struct JournalEntryRow: View {
    let entry: MoodEntry
    let isOpen: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: JMSpacing.s) {
                HStack(alignment: .top, spacing: JMSpacing.m) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(formattedDate(entry.timestamp))
                            .font(JMFont.caption)
                            .foregroundStyle(JMColor.textSecondary)
                            .tracking(0.5)
                            .textCase(.uppercase)

                        if isOpen {
                            expandedBody
                        } else {
                            Text(entry.previewText.isEmpty ? "(empty)" : entry.previewText)
                                .font(JMFont.body)
                                .foregroundStyle(entry.previewText.isEmpty ? JMColor.textSecondary.opacity(0.6) : JMColor.textPrimary)
                                .lineLimit(2)
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
            }
            .padding(.horizontal, JMSpacing.l)
            .padding(.vertical, JMSpacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
        }
    }

    @ViewBuilder
    private var expandedBody: some View {
        if entry.isThreePart {
            VStack(alignment: .leading, spacing: JMSpacing.m) {
                ForEach(Array(entry.sections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.label)
                            .font(JMFont.caption)
                            .foregroundStyle(JMColor.textSecondary)
                            .tracking(0.5)
                            .textCase(.uppercase)
                        Text(section.text)
                            .font(JMFont.body)
                            .foregroundStyle(JMColor.textPrimary)
                            .lineSpacing(3)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(.top, JMSpacing.xs)
        } else {
            Text(entry.body.isEmpty ? "(empty)" : entry.body)
                .font(JMFont.body)
                .foregroundStyle(entry.body.isEmpty ? JMColor.textSecondary.opacity(0.6) : JMColor.textPrimary)
                .lineSpacing(3)
                .multilineTextAlignment(.leading)
        }
    }

    private func formattedDate(_ d: Date) -> String {
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
