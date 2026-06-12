import SwiftUI
import SwiftData

@main
struct JustMindApp: App {
    @State private var preferences = AppPreferences()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MoodEntry.self,
            ROSEntry.self,
            CachedPost.self
        ])
        // Local-only persistence: explicitly NOT using CloudKit.
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create SwiftData container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(preferences)
                .preferredColorScheme(nil) // adaptive
        }
        .modelContainer(sharedModelContainer)
    }
}
