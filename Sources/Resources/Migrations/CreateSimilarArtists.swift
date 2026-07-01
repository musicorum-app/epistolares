import Fluent

struct CreateSimilarArtists: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("similar_artists")
            .id()
            .field("artist_id", .uuid, .required, .references("artists", "id"))
            .field("similar_artist_id", .uuid, .required, .references("artists", "id"))
            .unique(on: "artist_id", "similar_artist_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("similar_artists").delete()
    }
}
