import SwiftUI

extension View {
    /// Marks a view as containing private user content. Today this calls SwiftUI's
    /// `privacySensitive()` (which redacts in Live Activities, AirPlay mirroring, and
    /// supported system surfaces). The app switcher snapshot is additionally
    /// blurred at the root via `RootView.swift` (scene-phase aware).
    func jmPrivacySensitive() -> some View {
        self.privacySensitive(true)
    }
}
