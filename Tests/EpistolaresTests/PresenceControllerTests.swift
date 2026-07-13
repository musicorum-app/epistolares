@testable import Epistolares
import VaporTesting
import Testing
import Fluent
import NIOHTTP1

extension AppTests {
    @Test("POST /user/presence/register verifies the session key and returns a stable pushKey")
    func presenceRegisterIsIdempotent() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            await mock.setSession("valid-sk", username: "lyricalsoul")
            app.lastFM = mock

            var pushKey: String?
            try await app.testing().test(.POST, "user/presence/register", beforeRequest: { req async throws in
                try req.content.encode(PresenceRegisterRequest(sessionKey: "valid-sk"))
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(PresenceRegisterResponse.self)
                #expect(body.username == "lyricalsoul")
                pushKey = body.pushKey
            })

            // Second registration (e.g. from the other device) must converge on the same key.
            try await app.testing().test(.POST, "user/presence/register", beforeRequest: { req async throws in
                try req.content.encode(PresenceRegisterRequest(sessionKey: "valid-sk"))
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(PresenceRegisterResponse.self)
                #expect(body.pushKey == pushKey)
            })
        }
    }

    @Test("POST /user/presence/register rejects a session key Last.fm doesn't recognize")
    func presenceRegisterRejectsInvalidSessionKey() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            app.lastFM = mock

            try await app.testing().test(.POST, "user/presence/register", beforeRequest: { req async throws in
                try req.content.encode(PresenceRegisterRequest(sessionKey: "bogus"))
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test("Push then GET round-trips presence state, and GET 404s once nothing has been pushed")
    func presencePushAndGetRoundTrip() async throws {
        try await withTestApp { app in
            let key = try await UserPresenceKey.getOrCreate(username: "lyricalsoul", on: app.db)
            let auth: HTTPHeaders = ["Authorization": "Bearer \(key.pushKey)"]

            try await app.testing().test(.GET, "user/presence/lyricalsoul", headers: auth, afterResponse: { res async in
                #expect(res.status == .notFound)
            })

            let info = PresenceInfoDTO(title: "Track", artist: "Artist", album: nil, durationSeconds: 200, elapsedTimeSeconds: 10, isPlaying: true, coverURL: nil)
            let state = PresenceStateDTO(device: "ios", info: info, updatedAt: .init())

            try await app.testing().test(.POST, "user/presence/lyricalsoul", headers: auth, beforeRequest: { req async throws in
                try req.content.encode(state)
            }, afterResponse: { res async in
                #expect(res.status == .noContent)
            })

            try await app.testing().test(.GET, "user/presence/lyricalsoul", headers: auth, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(PresenceStateDTO.self)
                #expect(body.device == "ios")
                #expect(body.info?.title == "Track")
            })
        }
    }

    @Test("POST and GET /user/presence/{username} reject a missing or mismatched pushKey")
    func presencePushAndGetRejectBadToken() async throws {
        try await withTestApp { app in
            _ = try await UserPresenceKey.getOrCreate(username: "lyricalsoul", on: app.db)
            let state = PresenceStateDTO(device: "ios", info: nil, updatedAt: .init())

            try await app.testing().test(.POST, "user/presence/lyricalsoul", beforeRequest: { req async throws in
                try req.content.encode(state)
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })

            try await app.testing().test(.POST, "user/presence/lyricalsoul", headers: ["Authorization": "Bearer wrong-key"], beforeRequest: { req async throws in
                try req.content.encode(state)
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })

            try await app.testing().test(.GET, "user/presence/lyricalsoul", afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })

            try await app.testing().test(.GET, "user/presence/lyricalsoul", headers: ["Authorization": "Bearer wrong-key"], afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }
}
