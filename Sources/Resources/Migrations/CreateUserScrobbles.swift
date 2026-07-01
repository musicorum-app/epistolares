import Fluent
import FluentSQL

struct CreateUserScrobbles: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("user_scrobbles")
            .id()
            .field("username", .string, .required)
            .field("play_count", .int, .required)
            .field("loved", .bool)
            .field("artist_id", .uuid, .references("artists", "id"))
            .field("album_id", .uuid, .references("albums", "id"))
            .field("track_id", .uuid, .references("tracks", "id"))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()

        if let sql = database as? any SQLDatabase {
            try await sql.raw("CREATE INDEX user_scrobbles_username_artist_id_idx ON user_scrobbles (username, artist_id)").run()
            try await sql.raw("CREATE INDEX user_scrobbles_username_album_id_idx ON user_scrobbles (username, album_id)").run()
            try await sql.raw("CREATE INDEX user_scrobbles_username_track_id_idx ON user_scrobbles (username, track_id)").run()
        }
    }

    func revert(on database: any Database) async throws {
        try await database.schema("user_scrobbles").delete()
    }
}
