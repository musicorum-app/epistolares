import Fluent

struct CreateArtist: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("artists")
            .id()
            .field("name", .string, .required)
            .field("aliases", .array(of: .string), .required)
            .field("mbid", .string)
            .field("url", .string, .required)
            .field("summary", .string)
            .field("biography", .string)
            .field("biography_license", .string)
            .field("formed_date", .datetime)
            .field("external_id", .string, .required)
            .field("listeners", .int, .required)
            .field("scrobbles", .int, .required)
            .field("cover_id", .uuid, .required, .references("covers", "id"))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "name")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("artists").delete()
    }
}
