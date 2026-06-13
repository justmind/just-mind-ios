import SwiftUI

enum RootTab: Hashable {
    case home, checkIn, blog, myCare
}

struct RootView: View {
    @Environment(AppPreferences.self) private var prefs
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab: RootTab = .home
    @State private var checkInSection: CheckInSection = .mood
    @State private var locked: Bool = false
    @State private var didInitialAuth: Bool = false
    // Guards against the FaceID system sheet (which briefly backgrounds the
    // app) re-triggering the lock / a second prompt while we're mid-auth.
    @State private var isAuthenticating: Bool = false
    @State private var showSplash: Bool = true

    var body: some View {
        ZStack {
            if !prefs.onboardingComplete {
                OnboardingView()
                    .transition(.opacity)
            } else {
                tabView
                    .transition(.opacity)
            }

            if shouldShowLock {
                LockOverlay(onUnlock: { Task { await unlock() } })
                    .transition(.opacity)
            }

            // Always redact sensitive content from the app-switcher snapshot
            // and any over-the-shoulder glance when the app isn't frontmost —
            // independent of whether biometric lock is enabled.
            if scenePhase != .active && prefs.onboardingComplete {
                PrivacyCover()
            }

            // Cold-launch splash sits above everything until it fades out.
            if showSplash {
                LaunchSplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: prefs.onboardingComplete)
        .animation(.easeInOut(duration: 0.2), value: locked)
        .onChange(of: scenePhase) { _, phase in
            handleScene(phase)
        }
        // Deep-link from the weekly check-in notification → WCI section.
        .onReceive(NotificationCenter.default.publisher(for: .jmOpenWCI)) { _ in
            selectedTab = .checkIn
            checkInSection = .ros
        }
        .task {
            // Cover content beneath the splash if the app will lock, so the
            // unlock prompt doesn't flash content while the splash fades.
            if prefs.appLockEnabled { locked = true }
            try? await Task.sleep(for: .seconds(1.3))
            withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }

            // Run biometrics on cold launch after the splash, if enabled.
            if prefs.appLockEnabled, !didInitialAuth {
                await unlock()
            }
            didInitialAuth = true

            // Keep the weekly check-in nudge current with the latest data.
            await CheckInReminders.refreshSchedule()
        }
    }

    private var shouldShowLock: Bool {
        prefs.appLockEnabled && locked && prefs.onboardingComplete
    }

    private var tabView: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab, checkInSection: $checkInSection)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(RootTab.home)

            CheckInView(section: $checkInSection)
                .tabItem { Label("Check-In", systemImage: "checkmark.circle.fill") }
                .tag(RootTab.checkIn)

            BlogView()
                .tabItem { Label("Blog", systemImage: "newspaper.fill") }
                .tag(RootTab.blog)

            MyCareView()
                .tabItem { Label("My Care", systemImage: "heart.fill") }
                .tag(RootTab.myCare)
        }
        .tint(JMColor.primary)
    }

    private func handleScene(_ phase: ScenePhase) {
        switch phase {
        case .background, .inactive:
            // Lock as soon as we leave the foreground if the user opted in.
            // Skip while authenticating — the FaceID sheet itself backgrounds us.
            if prefs.appLockEnabled, didInitialAuth, !isAuthenticating {
                locked = true
            }
        case .active:
            // Coming back to the foreground while locked: prompt automatically
            // so the user doesn't have to tap "Unlock" every time.
            if prefs.appLockEnabled, locked, didInitialAuth, !isAuthenticating {
                Task { await unlock() }
            }
        @unknown default:
            break
        }
    }

    private func unlock() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        let result = await BiometricsService.authenticate(reason: "Unlock Just Mind")
        switch result {
        case .success:
            locked = false
        case .unavailable:
            // If biometrics/passcode are unavailable, don't trap the user out.
            prefs.appLockEnabled = false
            locked = false
        case .cancelled, .failure:
            locked = true
        }
    }
}

/// Branded blur shown whenever the app leaves the foreground, so journal and
/// Wellbeing Check-In content never appears in the multitasking snapshot.
private struct PrivacyCover: View {
    var body: some View {
        ZStack {
            JMColor.background.ignoresSafeArea()
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            Image("LogoSquareMark")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .opacity(0.9)
        }
        .accessibilityHidden(true)
    }
}

private struct LockOverlay: View {
    let onUnlock: () -> Void
    var body: some View {
        ZStack {
            JMColor.background.ignoresSafeArea()
            // Material blur also serves as the app-switcher snapshot redaction.
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            VStack(spacing: JMSpacing.xl) {
                // The lockup already includes "Just Mind"; show it alone
                // and drop the redundant title text below.
                Image("LogoMark")
                    .resizable().scaledToFit()
                    .frame(maxWidth: 200, maxHeight: 72)
                    .foregroundStyle(JMColor.textPrimary)
                Text("Locked")
                    .font(JMFont.footnote)
                    .foregroundStyle(JMColor.textSecondary)
                    .tracking(1)
                    .textCase(.uppercase)
                Button {
                    onUnlock()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "faceid")
                            .font(.system(size: 16, weight: .light))
                        Text("Unlock")
                    }
                }
                .buttonStyle(.jmPrimary)
                .frame(maxWidth: 240)
                Text("Use Face ID, Touch ID, or your passcode")
                    .font(JMFont.caption)
                    .foregroundStyle(JMColor.textSecondary)
            }
            .padding(JMSpacing.xl)
        }
    }
}
