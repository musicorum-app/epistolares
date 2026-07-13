@testable import Epistolares
import VaporTesting
import Testing
import Fluent

extension AppTests {
    @Test("GET /track/info works without a username")
    func trackInfoWorksWithoutUsername() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            app.lastFM = mock
            await mock.setArtist(.fixture(name: "Kelela"), forName: "Kelela")
            await mock.setTrack(.fixture(name: "All the Way Down"), forArtist: "Kelela", name: "All the Way Down")

            try await app.testing().test(.GET, "track/info?track=All%20the%20Way%20Down&artist=Kelela", afterResponse: { res async in
                #expect(res.status == .ok)
            })
        }
    }

    @Test("GET /artist/info works without a username")
    func artistInfoWorksWithoutUsername() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            app.lastFM = mock
            await mock.setArtist(.fixture(name: "Kelela"), forName: "Kelela")

            try await app.testing().test(.GET, "artist/info?name=Kelela", afterResponse: { res async in
                #expect(res.status == .ok)
            })
        }
    }

    @Test("GET /album/info resolves by name and artist, without a username")
    func albumInfoResolvesByNameAndArtist() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            app.lastFM = mock
            await mock.setArtist(.fixture(name: "Kelela"), forName: "Kelela")
            await mock.setAlbum(.fixture(name: "Hallucinogen", artist: "Kelela"), forArtist: "Kelela", name: "Hallucinogen")

            try await app.testing().test(.GET, "album/info?name=Hallucinogen&artist=Kelela", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(AlbumInfoResponseDTO.self)
                #expect(body.name == "Hallucinogen")
                #expect(body.artist == "Kelela")
            })
        }
    }

    @Test("GET /album/info resolves by id")
    func albumInfoResolvesByID() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            await mock.setArtist(.fixture(name: "Kelela"), forName: "Kelela")
            await mock.setAlbum(.fixture(name: "Hallucinogen", artist: "Kelela"), forArtist: "Kelela", name: "Hallucinogen")

            let artist = try await LastFMSync.syncArtist(name: "Kelela", username: nil, db: app.db, lastFM: mock)
            let album = try await LastFMSync.syncAlbum(name: "Hallucinogen", artist: artist.artist, username: nil, db: app.db, lastFM: mock)
            let albumID = try album.album.requireID()

            app.lastFM = mock
            try await app.testing().test(.GET, "album/info?id=\(albumID)", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(AlbumInfoResponseDTO.self)
                #expect(body.id == albumID)
            })
        }
    }

    @Test("GET /album/info rejects a request with neither id nor name+artist")
    func albumInfoRejectsMissingParams() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            app.lastFM = mock

            try await app.testing().test(.GET, "album/info", afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }
}
