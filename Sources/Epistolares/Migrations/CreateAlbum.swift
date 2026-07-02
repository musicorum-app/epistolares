import Fluent

struct CreateAlbum: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("albums")
            .id()
            .field("name", .string, .required)
            .field("mbid", .string)
            .field("url", .string, .required)
            .field("summary", .string)
            .field("biography", .string)
            .field("biography_license", .string)
            .field("published_date", .datetime)
            .field("listeners", .int, .required)
            .field("scrobbles", .int, .required)
            .field("artist_id", .uuid, .required, .references("artists", "id"))
            .field("cover_id", .uuid, .required, .references("covers", "id"))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "name", "artist_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("albums").delete()
    }
}
