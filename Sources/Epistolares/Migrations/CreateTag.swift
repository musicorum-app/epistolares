import Fluent

struct CreateTag: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("tags")
            .id()
            .field("name", .string, .required)
            .field("url", .string, .required)
            .unique(on: "name")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("tags").delete()
    }
}
