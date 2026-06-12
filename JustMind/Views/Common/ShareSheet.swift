import SwiftUI
import UIKit

/// Thin wrapper over UIActivityViewController so a generated file (e.g. the
/// WCI PDF) can be shared via Mail, Messages, AirDrop, Files, etc. The user
/// chooses the destination — nothing is sent automatically.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Identifiable wrapper so a file URL can drive a `.sheet(item:)`.
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}
