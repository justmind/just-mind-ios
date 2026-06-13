import SwiftUI

/// Brief cold-launch splash: the Just Mind logo with three pulsing dots.
/// Shown over the app for a moment on first appearance, then fades away.
struct LaunchSplashView: View {
    var body: some View {
        ZStack {
            JMColor.background.ignoresSafeArea()
            VStack(spacing: JMSpacing.xl) {
                Image("LogoMark")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220, maxHeight: 80)
                    .foregroundStyle(JMColor.textPrimary)
                LoadingDots()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Just Mind, loading")
    }
}

/// Three sage dots that pulse in sequence to signal loading.
private struct LoadingDots: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(JMColor.primary)
                    .frame(width: 8, height: 8)
                    .opacity(animating ? 1.0 : 0.3)
                    .scaleEffect(animating ? 1.0 : 0.7)
                    .animation(
                        .easeInOut(duration: 0.55)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.18),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}
