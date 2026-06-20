import SwiftUI

struct OnboardingView: View {
    @Environment(AppPreferences.self) private var prefs
    @State private var page: Int = 0
    @State private var draftName: String = ""
    @State private var selectedTopics: Set<String> = []
    @FocusState private var nameFocused: Bool

    private let pageCount = 4

    var body: some View {
        ZStack {
            JMColor.background.ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcomeCard.tag(0)
                    featuresCard.tag(1)
                    topicsCard.tag(2)
                    nameCard.tag(3)
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
            // Same green JM mark as the splash / Home, centered (the headline
            // VStack is leading-aligned, so the logo is centered explicitly).
            Image("LogoSquareMark")
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .center)
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

    private var topicsCard: some View {
        VStack(alignment: .leading, spacing: JMSpacing.l) {
            Spacer()
            Text("What's on\nyour mind?")
                .font(JMFont.display)
                .jmDisplayTracking()
                .foregroundStyle(JMColor.textPrimary)
                .lineSpacing(2)
            Text("Pick a few topics and we'll bring the most relevant Just Mind articles to you. You can change this anytime.")
                .font(JMFont.body)
                .foregroundStyle(JMColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            FlowChips(
                topics: BlogService.curatedTagSlugs.map(\.label),
                selected: $selectedTopics
            )
            .padding(.top, JMSpacing.s)

            Spacer()
            Button(selectedTopics.isEmpty ? "Skip for now" : "Continue") {
                withAnimation { page = 3 }
            }
            .buttonStyle(.jmPrimary)
        }
        .padding(.horizontal, JMSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                prefs.preferredBlogTopics = BlogService.curatedTagSlugs
                    .map(\.label)
                    .filter { selectedTopics.contains($0) } // preserve curated order
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
            ForEach(0..<pageCount, id: \.self) { i in
                Capsule()
                    .fill(i == page ? JMColor.textPrimary : JMColor.divider)
                    .frame(width: i == page ? 18 : 6, height: 6)
                    .animation(.easeInOut(duration: 0.2), value: page)
            }
        }
    }
}

/// A wrapping row of selectable topic chips.
private struct FlowChips: View {
    let topics: [String]
    @Binding var selected: Set<String>

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 10, alignment: .leading)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(topics, id: \.self) { topic in
                let isOn = selected.contains(topic)
                Button {
                    if isOn { selected.remove(topic) } else { selected.insert(topic) }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text(topic)
                        .font(JMFont.callout)
                        .foregroundStyle(isOn ? .white : JMColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isOn ? JMColor.primary : Color.clear)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(isOn ? Color.clear : JMColor.divider, lineWidth: JMHairline.width)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isSelected] : [])
            }
        }
    }
}
