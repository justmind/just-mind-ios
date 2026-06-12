import SwiftUI
import SwiftData

/// Edits the body of an existing journal entry. The entry is a SwiftData
/// `@Model` (reference type), so we mutate it directly and save.
struct JournalEntryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let entry: MoodEntry

    @State private var draft: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: JMSpacing.s) {
                if !entry.prompt.isEmpty {
                    Text(entry.prompt)
                        .font(JMFont.footnote)
                        .foregroundStyle(JMColor.textSecondary)
                        .italic()
                        .lineSpacing(2)
                        .padding(.horizontal, JMSpacing.l)
                        .padding(.top, JMSpacing.m)
                }
                TextEditor(text: $draft)
                    .font(JMFont.body)
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .focused($focused)
                    .padding(.horizontal, JMSpacing.l)
            }
            .background(JMColor.background.ignoresSafeArea())
            .navigationTitle("Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .tint(JMColor.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .tint(JMColor.primary)
                        .font(JMFont.bodyEmph)
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                draft = entry.body
                focused = true
            }
        }
    }

    private func save() {
        entry.body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        try? context.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dismiss()
    }
}
