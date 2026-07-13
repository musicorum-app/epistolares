import Fluent
import struct Foundation.UUID
import Foundation

final class UserPresenceKey: Model, @unchecked Sendable {
    static let schema = "user_presence_keys"

    @ID(key: .id)
    var id: UUID?

    /// The Last.fm username, always stored lowercased
    @Field(key: "username")
    private var _username: String
    var username: String {
        get { _username }
        set { _username = newValue.lowercased() }
    }

    @Field(key: "push_key")
    var pushKey: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() { }

    init(id: UUID? = nil, username: String, pushKey: String) {
        self.id = id
        self._username = username.lowercased()
        self.pushKey = pushKey
    }

    static func query(forUsername username: String, on database: any Database) -> QueryBuilder<UserPresenceKey> {
        UserPresenceKey.query(on: database).filter(\.$_username == username.lowercased())
    }

    static func getOrCreate(username: String, on db: any Database) async throws -> UserPresenceKey {
        if let existing = try await query(forUsername: username, on: db).first() {
            return existing
        }

        let key = UserPresenceKey(username: username, pushKey: generatePushKey())
        do {
            try await key.save(on: db)
            return key
        } catch {
            // Lost a create race against another request for the same username.
            if let existing = try await query(forUsername: username, on: db).first() {
                return existing
            }
            throw error
        }
    }

    private static func generatePushKey() -> String {
        (0..<32).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
    }
}
