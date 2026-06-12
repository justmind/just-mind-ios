import SwiftUI

enum CheckInSection: String, CaseIterable, Identifiable {
    case journal = "Journal"
    case ros = "RŌS"
    var id: String { rawValue }

    /// Backwards-compat alias for callers that still reference `.mood`.
    static var mood: CheckInSection { .journal }
}

struct CheckInView: View {
    @Binding var section: CheckInSection

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $section) {
                    ForEach(CheckInSection.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, JMSpacing.l)
                .padding(.vertical, JMSpacing.m)

                ZStack {
                    // Cross-fade between segments — sliding feels like
                    // navigation; cross-fade reads as a perspective shift.
                    switch section {
                    case .journal:
                        JournalView()
                            .transition(.opacity)
                    case .ros:
                        ROSView()
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.20), value: section)
            }
            .background(JMColor.background.ignoresSafeArea())
            .navigationTitle("Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .jmPrivacySensitive()
        }
    }
}
