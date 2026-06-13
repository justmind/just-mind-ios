import SwiftUI

/// Supportive (not alarming) sheet shown when a Wellbeing Check-In total is
/// very low (≤ 10). Sage green is used only on the primary action. No red, no
/// warning icons. (Change 3.)
struct LowScoreSupportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var safariItem: SafariSheetItem?

    private let portalURL = URL(string: "https://justmind.intakeq.com/portal")!

    var body: some View {
        VStack(spacing: JMSpacing.xl) {
            Spacer(minLength: JMSpacing.xl)

            Image(systemName: "heart.circle")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(JMColor.primary)

            VStack(spacing: JMSpacing.m) {
                Text("We want you to feel supported")
                    .font(JMFont.title)
                    .jmDisplayTracking()
                    .foregroundStyle(JMColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Your scores today suggest you may be going through a really hard time. You're not alone in this. If you're in crisis or need to talk to someone right now, support is available.")
                    .font(JMFont.body)
                    .foregroundStyle(JMColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, JMSpacing.l)

            Spacer(minLength: JMSpacing.l)

            VStack(spacing: JMSpacing.m) {
                Button {
                    safariItem = SafariSheetItem(url: portalURL)
                } label: {
                    Text("Contact My Therapist")
                }
                .buttonStyle(.jmPrimary)

                Button {
                    if let url = URL(string: "tel://988") { openURL(url) }
                } label: {
                    Text("Crisis Support Line")
                }
                .buttonStyle(.jmOutline)

                Button {
                    dismiss()
                } label: {
                    Text("I'm okay, continue")
                }
                .buttonStyle(.jmGhost)
            }
            .padding(.horizontal, JMSpacing.l)
            .padding(.bottom, JMSpacing.xl)
        }
        .frame(maxWidth: .infinity)
        .background(JMColor.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(item: $safariItem) { SafariView(url: $0.url) }
    }
}
