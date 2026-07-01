@testable import Resources
import VaporTesting
import Fluent

/// Named to avoid colliding with VaporTesting's own `withApp(_:)`, which doesn't call `configure`.
func withTestApp(_ test: (Application) async throws -> ()) async throws {
    let app = try await Application.make(.testing)
    do {
        try await configure(app)
        try await app.autoMigrate()
        try await test(app)
        try await app.autoRevert()
    } catch {
        try? await app.autoRevert()
        try await app.asyncShutdown()
        throw error
    }
    try await app.asyncShutdown()
}
