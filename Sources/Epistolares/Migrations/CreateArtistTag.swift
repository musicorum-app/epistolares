import Fluent

struct CreateArtistTag: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("artist_tags")
            .id()
            .field("artist_id", .uuid, .required, .references("artists", "id"))
            .field("tag_id", .uuid, .required, .references("tags", "id"))
            .unique(on: "artist_id", "tag_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("artist_tags").delete()
    }
}
