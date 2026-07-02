@testable import Resources
import VaporTesting
import Testing
import Fluent

@Suite("App Tests with DB", .serialized)
struct AppTests {
    @Test("Test Ping Route")
    func helloWorld() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "ping", afterResponse: { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "Pong")
            })
        }
    }
}
