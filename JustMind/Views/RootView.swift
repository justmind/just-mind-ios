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
        }
        .animation(.easeInOut(duration: 0.25), value: prefs.onboardingComplete)
        .animation(.easeInOut(duration: 0.2), value: locked)
        .onChange(of: scenePhase) { _, phase in
            handleScene(phase)
        }
        .task {
            // Trigger biometrics on cold launch if enabled.
            if prefs.appLockEnabled, !didInitialAuth {
                locked = true
                await unlock()
            }
            didInitialAuth = true
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
            if prefs.appLockEnabled, didInitialAuth {
                locked = true
            }
        case .active:
            break
        @unknown default:
            break
        }
    }

    private func unlock() async {
        let result = await BiometricsService.authenticate(reason: "Unlock Just Mind")
        switch result {
        case .success:
            locked = false
        case .unavailable:
            // If biometrics broke, don't trap the user out — disable lock.
            prefs.appLockEnabled = false
            locked = false
        case .cancelled, .failure:
            locked = true
        }
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
                Text("Unlock to continue")
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
            }
            .padding(JMSpacing.xl)
        }
    }
}
