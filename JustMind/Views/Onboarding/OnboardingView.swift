import SwiftUI

struct OnboardingView: View {
    @Environment(AppPreferences.self) private var prefs
    @State private var page: Int = 0
    @State private var draftName: String = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            JMColor.background.ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcomeCard.tag(0)
                    featuresCard.tag(1)
                    nameCard.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .indexViewStyle(.page(backgroundDisplayMode: .never))

                pageDots
                    .padding(.bottom, JMSpacing.xl)
            }
        }
    }

    // MARK: Cards

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: JMSpacing.l) {
            Spacer()
            // Width-constrained: the tagline lockup is wider than tall.
            Image("LogoMark")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220, maxHeight: 80)
                .foregroundStyle(JMColor.textPrimary)
                .padding(.bottom, JMSpacing.s)
            Text("Your therapy,\nsupported between\nsessions.")
                .font(JMFont.display)
                .jmDisplayTracking()
                .foregroundStyle(JMColor.textPrimary)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
            Text("A private space to track how you're feeling and stay connected to your care.")
                .font(JMFont.body)
                .foregroundStyle(JMColor.textSecondary)
                .multilineTextAlignment(.leading)
            Spacer()
            Button("Continue") { withAnimation { page = 1 } }
                .buttonStyle(.jmPrimary)
        }
        .padding(.horizontal, JMSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var featuresCard: some View {
        VStack(alignment: .leading, spacing: JMSpacing.l) {
            Spacer()
            Text("A small toolkit\nfor showing up.")
                .font(JMFont.display)
                .jmDisplayTracking()
                .foregroundStyle(JMColor.textPrimary)
                .lineSpacing(2)

            VStack(alignment: .leading, spacing: 0) {
                featureRow(icon: "chart.line.uptrend.xyaxis", title: "Track your mood", subtitle: "A few seconds, once a day.")
                JMHairline()
                featureRow(icon: "list.bullet", title: "Complete your WCI", subtitle: "A short Wellbeing Check-In; trends over time.")
                JMHairline()
                featureRow(icon: "book.closed", title: "Journal your way through it", subtitle: "Long-form notes, kept private.")
                JMHairline()
                featureRow(icon: "lock.shield", title: "Stays on this device", subtitle: "Nothing syncs. Nothing is shared.")
            }
            Spacer()
            Button("Continue") { withAnimation { page = 2 } }
                .buttonStyle(.jmPrimary)
        }
        .padding(.horizontal, JMSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: JMSpacing.l) {
            // Onboarding icons neutralized — green is reserved for primary CTAs.
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(JMColor.textSecondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(JMFont.bodyEmph)
                    .foregroundStyle(JMColor.textPrimary)
                Text(subtitle)
                    .font(JMFont.footnote)
                    .foregroundStyle(JMColor.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, JMSpacing.m)
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: JMSpacing.l) {
            Spacer()
            Text("What should\nwe call you?")
                .font(JMFont.display)
                .jmDisplayTracking()
                .foregroundStyle(JMColor.textPrimary)
                .lineSpacing(2)

            VStack(alignment: .leading, spacing: JMSpacing.s) {
                TextField("First name", text: $draftName)
                    .textContentType(.givenName)
                    .autocorrectionDisabled(true)
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .font(JMFont.title)
                    .padding(.vertical, 14)
                JMHairline()
                Text("Your name is stored only on this device.")
                    .font(JMFont.footnote)
                    .foregroundStyle(JMColor.textSecondary)
            }
            Spacer()
            Button("Get Started") {
                let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                prefs.preferredName = trimmed.isEmpty ? "friend" : trimmed
                // Ask for notification permission here (after the name), not at
                // launch. If denied, the weekly nudge simply never schedules.
                Task {
                    await CheckInReminders.requestAuthorization()
                    await CheckInReminders.refreshSchedule()
                }
                prefs.onboardingComplete = true
            }
            .buttonStyle(.jmPrimary)
            .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal, JMSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { nameFocused = true }
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i == page ? JMColor.textPrimary : JMColor.divider)
                    .frame(width: i == page ? 18 : 6, height: 6)
                    .animation(.easeInOut(duration: 0.2), value: page)
            }
        }
    }
}
