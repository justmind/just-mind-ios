import SwiftUI
import UIKit

/// Thin wrapper over UIActivityViewController so a generated file (e.g. the
/// WCI PDF) can be shared via Mail, Messages, AirDrop, Files, etc. The user
/// chooses the destination — nothing is sent automatically.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    /// Temp files to delete once the share sheet finishes (shared or
    /// cancelled), so sensitive exports don't linger in the temp directory.
    var cleanupURLs: [URL] = []

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        let urls = cleanupURLs
        controller.completionWithItemsHandler = { _, _, _, _ in
            for url in urls {
                try? FileManager.default.removeItem(at: url)
            }
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Identifiable wrapper so a file URL can drive a `.sheet(item:)`.
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}
