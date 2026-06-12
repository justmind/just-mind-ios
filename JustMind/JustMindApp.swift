import SwiftUI
import SwiftData

@main
struct JustMindApp: App {
    @State private var preferences = AppPreferences()

    var sharedModelContainer: ModelContainer = {
        // Versioned schema + migration plan so future model changes can carry
        // existing on-device data forward instead of crashing on launch.
        // See MigrationPlan.swift.
        let schema = Schema(versionedSchema: SchemaV1.self)
        // Local-only persistence: explicitly NOT using CloudKit.
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: JustMindMigrationPlan.self,
                configurations: config
            )
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
