import Fluent

struct CreateAlbumTag: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("album_tags")
            .id()
            .field("album_id", .uuid, .required, .references("albums", "id"))
            .field("tag_id", .uuid, .required, .references("tags", "id"))
            .unique(on: "album_id", "tag_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("album_tags").delete()
    }
}
