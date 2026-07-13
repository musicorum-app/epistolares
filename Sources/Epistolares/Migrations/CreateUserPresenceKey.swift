import Fluent

struct CreateUserPresenceKey: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("user_presence_keys")
            .id()
            .field("username", .string, .required)
            .field("push_key", .string, .required)
            .field("created_at", .datetime)
            .unique(on: "username")
            .unique(on: "push_key")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("user_presence_keys").delete()
    }
}
