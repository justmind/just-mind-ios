import Foundation
import SwiftData

/// Versioned schema + migration plan.
///
/// Why this exists: SwiftData refuses to open a store whose on-disk schema
/// doesn't match the app's model definitions. Without a versioned schema and
/// migration plan, *any* future model change (a renamed property, a new field,
/// a dropped entity) crashes the app on launch for existing users and can lose
/// their data.
///
/// By pinning the current models as `SchemaV1` and routing the container
/// through `JustMindMigrationPlan`, future changes become a new versioned
/// schema (`SchemaV2`, …) plus a `MigrationStage` that describes how to carry
/// existing rows forward — instead of a hard crash.
///
/// `SchemaV1` must match the *current* live model definitions exactly, so that
/// existing stores open with no migration. When you next change a model:
///   1. Copy the current models into a frozen `SchemaV1` namespace (or keep
///      referencing the live types if the change is additive/lightweight).
///   2. Add `SchemaV2` with the new shape.
///   3. Append a `MigrationStage` (`.lightweight` or `.custom`) to `stages`.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [MoodEntry.self, ROSEntry.self, CachedPost.self]
    }
}

enum JustMindMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
