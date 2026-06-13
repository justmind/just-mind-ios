import SwiftUI
import Combine

/// Brief cold-launch splash: the Just Mind logo, three dots that fill in
/// progression, and a "loading" label so the launch reads as intentional —
/// not a frozen or buggy screen.
struct LaunchSplashView: View {
    var body: some View {
        ZStack {
            JMColor.background.ignoresSafeArea()
            VStack(spacing: JMSpacing.l) {
                Image("LogoMark")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 160, maxHeight: 52)
                    .foregroundStyle(JMColor.textPrimary)
                    .padding(.bottom, JMSpacing.s)

                ProgressDots()

                Text("Loading")
                    .font(JMFont.caption)
                    .foregroundStyle(JMColor.textSecondary)
                    .tracking(2)
                    .textCase(.uppercase)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Just Mind, loading")
    }
}

/// Three sage dots that fill one-by-one (●, ●●, ●●●) and reset, giving a clear
/// sense of forward motion rather than a single static or pulsing indicator.
private struct ProgressDots: View {
    @State private var count = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(JMColor.primary)
                    .frame(width: 9, height: 9)
                    .opacity(i < count ? 1.0 : 0.22)
                    .scaleEffect(i < count ? 1.0 : 0.75)
                    .animation(.easeInOut(duration: 0.22), value: count)
            }
        }
        .onReceive(timer) { _ in
            // 0 → 1 → 2 → 3 → 0 …  (empty, one, two, three, reset)
            count = (count + 1) % 4
        }
    }
}
