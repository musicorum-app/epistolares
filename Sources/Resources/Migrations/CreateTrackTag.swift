import Fluent

struct CreateTrackTag: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("track_tags")
            .id()
            .field("track_id", .uuid, .required, .references("tracks", "id"))
            .field("tag_id", .uuid, .required, .references("tags", "id"))
            .unique(on: "track_id", "tag_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("track_tags").delete()
    }
}
