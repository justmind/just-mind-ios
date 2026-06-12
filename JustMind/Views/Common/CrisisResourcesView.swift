import SwiftUI

/// Always-available crisis resources. Surfaced from My Care and from a
/// below-cutoff WCI result. Every action uses the device's native dialer /
/// Messages — nothing is logged or transmitted by Just Mind.
///
/// This screen is intentionally plain and fast to scan: in a hard moment, a
/// person should be one tap from help, not reading copy.
struct CrisisResourcesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: JMSpacing.l) {
                    Text("If you're in crisis or thinking about harming yourself, you don't have to handle it alone. Reach out — any time, day or night.")
                        .font(JMFont.body)
                        .foregroundStyle(JMColor.textPrimary)
                        .lineSpacing(3)
                        .padding(.top, JMSpacing.s)

                    VStack(spacing: 0) {
                        resourceRow(
                            title: "988 Suicide & Crisis Lifeline",
                            subtitle: "Call or text · 24/7 · free & confidential",
                            actionLabel: "Call 988",
                            systemImage: "phone.fill",
                            url: URL(string: "tel://988")
                        )
                        JMHairline()
                        resourceRow(
                            title: "Text the 988 Lifeline",
                            subtitle: "Text if you'd rather not talk",
                            actionLabel: "Text 988",
                            systemImage: "message.fill",
                            url: URL(string: "sms:988")
                        )
                        JMHairline()
                        resourceRow(
                            title: "Crisis Text Line",
                            subtitle: "Text HOME to 741741",
                            actionLabel: "Text 741741",
                            systemImage: "message.fill",
                            url: URL(string: "sms:741741&body=HOME")
                        )
                        JMHairline()
                        resourceRow(
                            title: "The Trevor Project",
                            subtitle: "For LGBTQ+ young people · 24/7",
                            actionLabel: "Call",
                            systemImage: "phone.fill",
                            url: URL(string: "tel://18664887386")
                        )
                        JMHairline()
                        resourceRow(
                            title: "Emergency services",
                            subtitle: "If you or someone else is in immediate danger",
                            actionLabel: "Call 911",
                            systemImage: "cross.case.fill",
                            url: URL(string: "tel://911"),
                            emphasized: true
                        )
                    }
                    .jmQuietCardFlush()

                    Text("Just Mind isn't a crisis service and can't monitor what you write here. These lines are staffed by trained counselors and are independent of your therapist.")
                        .font(JMFont.caption)
                        .foregroundStyle(JMColor.textSecondary)
                        .lineSpacing(2)
                        .padding(.horizontal, JMSpacing.s)
                }
                .padding(.horizontal, JMSpacing.l)
                .padding(.bottom, JMSpacing.xxl)
            }
            .background(JMColor.background.ignoresSafeArea())
            .navigationTitle("Get help now")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .tint(JMColor.primary)
                }
            }
        }
    }

    private func resourceRow(
        title: String,
        subtitle: String,
        actionLabel: String,
        systemImage: String,
        url: URL?,
        emphasized: Bool = false
    ) -> some View {
        Button {
            if let url { openURL(url) }
        } label: {
            HStack(spacing: JMSpacing.l) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(JMFont.bodyEmph)
                        .foregroundStyle(JMColor.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(JMFont.caption)
                        .foregroundStyle(JMColor.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                    Text(actionLabel)
                        .font(JMFont.footnote)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(emphasized ? JMColor.warning : JMColor.primary)
                .clipShape(Capsule())
                .fixedSize()
            }
            .padding(.horizontal, JMSpacing.l)
            .padding(.vertical, JMSpacing.l)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle).")
        .accessibilityHint(actionLabel)
    }
}
