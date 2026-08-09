import SwiftUI
import SwiftData

/// Edits an existing journal entry's three parts. The entry is a SwiftData
/// `@Model` (reference type), so we mutate it directly and save. Legacy
/// single-body entries are migrated into the first prompt on first edit.
struct JournalEntryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let entry: MoodEntry

    @State private var wentWell: String = ""
    @State private var challenge: String = ""
    @State private var tryDifferently: String = ""
    @FocusState private var focused: Bool

    private var canSave: Bool {
        [wentWell, challenge, tryDifferently].contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: JMSpacing.l) {
                    field(label: "What went well?", text: $wentWell, autofocus: true)
                    field(label: "What was a challenge?", text: $challenge)
                    field(label: "What could you try differently next time?", text: $tryDifferently)
                }
                .padding(JMSpacing.l)
            }
            .background(JMColor.background.ignoresSafeArea())
            .navigationTitle("Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.tint(JMColor.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .tint(JMColor.primary)
                        .font(JMFont.bodyEmph)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                wentWell = entry.wentWell
                challenge = entry.challenge
                tryDifferently = entry.tryDifferently
                if !entry.isThreePart, !entry.body.isEmpty {
                    wentWell = entry.body
                }
            }
        }
    }

    private func field(label: String, text: Binding<String>, autofocus: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: JMSpacing.s) {
            Text(label)
                .font(JMFont.bodyEmph)
                .foregroundStyle(JMColor.textPrimary)
            TextEditor(text: text)
                .font(JMFont.body)
                .lineSpacing(3)
                .scrollContentBackground(.hidden)
                .frame(height: 100)
                .padding(.horizontal, JMSpacing.m)
                .padding(.vertical, JMSpacing.s)
                .background(JMColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: JMRadius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: JMRadius.card, style: .continuous)
                        .strokeBorder(JMColor.divider, lineWidth: JMHairline.width)
                )
                .focused($focused)
                .onAppear { if autofocus { focused = true } }
        }
    }

    private func save() {
        entry.wentWell = wentWell.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.challenge = challenge.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.tryDifferently = tryDifferently.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.body = "" // superseded by the three-part fields
        try? context.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dismiss()
    }
}
