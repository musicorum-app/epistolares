import Fluent

struct CreateCover: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("covers")
            .id()
            .field("source", .string, .required)
            .field("external_id", .string, .required)
            .unique(on: "source", "external_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("covers").delete()
    }
}
