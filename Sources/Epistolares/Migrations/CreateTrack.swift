import Fluent
import FluentSQL

struct CreateTrack: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("tracks")
            .id()
            .field("name", .string, .required)
            .field("mbid", .string)
            .field("url", .string, .required)
            .field("duration", .int, .required)
            .field("rank", .int, .required)
            .field("listeners", .int, .required)
            .field("scrobbles", .int, .required)
            .field("artist_id", .uuid, .required, .references("artists", "id"))
            .field("album_id", .uuid, .required, .references("albums", "id"))
            .field("cover_id", .uuid, .required, .references("covers", "id"))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()

        // Not unique bc two tracks can legitimately share a name within the same album/artist
        if let sql = database as? any SQLDatabase {
            try await sql.raw("CREATE INDEX tracks_album_id_name_idx ON tracks (album_id, name)").run()
            try await sql.raw("CREATE INDEX tracks_artist_id_name_idx ON tracks (artist_id, name)").run()
        }
    }

    func revert(on database: any Database) async throws {
        try await database.schema("tracks").delete()
    }
}
