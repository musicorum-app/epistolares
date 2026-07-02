@testable import Resources
import VaporTesting
import Testing
import Fluent
import Logging

extension AppTests {
    @Test("getCharts resolves a top-artists chart and syncs each entry")
    func chartsResolvesTopArtists() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            await mock.setValidUsername("blueslimee")
            await mock.setTopArtists(
                .fixture(entries: [("Kelela", 1, 500), ("Rochelle Jordan", 2, 300)], page: 1, totalPages: 1, total: 2),
                username: "blueslimee", period: "overall", limit: 50, page: 1
            )
            await mock.setArtist(.fixture(name: "Kelela", listeners: 648_122), forName: "Kelela")
            await mock.setArtist(.fixture(name: "Rochelle Jordan"), forName: "Rochelle Jordan")

            let response = try await ChartsResolver.resolve(
                type: .artist, username: "blueslimee", period: .overall, limit: 50, page: 1,
                db: app.db, lastFM: mock, logger: Logger(label: "test")
            )

            #expect(response.items.count == 2)
            #expect(response.items[0].name == "Kelela")
            #expect(response.items[0].playCount == 500)
            #expect(response.items[0].artist == nil)
            #expect(response.total == 2)

            let stored = try await Artist.query(on: app.db).filter(\.$name == "Kelela").first()
            #expect(stored != nil, "an artist chart entry with no existing local row should get synced (created)")
            #expect(response.items[0].id == stored?.id)
        }
    }

    @Test("getCharts resolves a top-albums chart, syncing artist then album")
    func chartsResolvesTopAlbums() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            await mock.setValidUsername("blueslimee")
            await mock.setTopAlbums(
                .fixture(entries: [("Hallucinogen", "Kelela", 1, 200)], page: 1, totalPages: 1, total: 1),
                username: "blueslimee", period: "overall", limit: 50, page: 1
            )
            await mock.setArtist(.fixture(name: "Kelela"), forName: "Kelela")
            await mock.setAlbum(.fixture(name: "Hallucinogen", artist: "Kelela"), forArtist: "Kelela", name: "Hallucinogen")

            let response = try await ChartsResolver.resolve(
                type: .album, username: "blueslimee", period: .overall, limit: 50, page: 1,
                db: app.db, lastFM: mock, logger: Logger(label: "test")
            )

            #expect(response.items.count == 1)
            #expect(response.items[0].name == "Hallucinogen")
            #expect(response.items[0].artist == "Kelela")

            let stored = try await Album.query(on: app.db).filter(\.$name == "Hallucinogen").first()
            #expect(stored != nil)
            #expect(response.items[0].id == stored?.id)
        }
    }

    @Test("getCharts resolves a top-tracks chart, syncing artist then track")
    func chartsResolvesTopTracks() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            await mock.setValidUsername("blueslimee")
            await mock.setTopTracks(
                .fixture(entries: [("All the Way Down", "Kelela", 1, 150)], page: 1, totalPages: 1, total: 1),
                username: "blueslimee", period: "overall", limit: 50, page: 1
            )
            await mock.setArtist(.fixture(name: "Kelela"), forName: "Kelela")
            // A top-tracks entry carries no album name, so it's resolved the same way as any
            // track lookup with no supplied album: the track's own `album` field (from Last.fm's
            // track.getInfo) is used to discover and sync the album.
            await mock.setTrack(
                .fixture(name: "All the Way Down", albumTitle: "Hallucinogen", albumArtist: "Kelela"),
                forArtist: "Kelela", name: "All the Way Down"
            )
            await mock.setAlbum(
                .fixture(name: "Hallucinogen", artist: "Kelela", tracks: [("All the Way Down", 1)]),
                forArtist: "Kelela", name: "Hallucinogen"
            )

            let response = try await ChartsResolver.resolve(
                type: .track, username: "blueslimee", period: .overall, limit: 50, page: 1,
                db: app.db, lastFM: mock, logger: Logger(label: "test")
            )

            #expect(response.items.count == 1)
            #expect(response.items[0].name == "All the Way Down")
            #expect(response.items[0].artist == "Kelela")
            // The album's own tracklist sync (syncAlbum) already created this row when the album
            // was synced, so it does have a real, stable id -- even though syncTrack itself
            // wouldn't have persisted a discovered (not explicitly requested) album association.
            let stored = try await Track.query(on: app.db).filter(\.$name == "All the Way Down").first()
            #expect(stored != nil)
            #expect(response.items[0].id == stored?.id)
        }
    }

    @Test("getCharts caches the shaped response, skipping a second Last.fm chart call")
    func chartsCachesResponse() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            // Distinct limit from other tests in this suite: the response cache is a process-wide
            // singleton (by design, shared across requests), so a colliding cache key here would
            // pick up a hit left over from another test.
            await mock.setValidUsername("blueslimee")
            await mock.setTopArtists(
                .fixture(entries: [("Kelela", 1, 500)], page: 1, totalPages: 1, total: 1),
                username: "blueslimee", period: "overall", limit: 23, page: 1
            )
            await mock.setArtist(.fixture(name: "Kelela"), forName: "Kelela")

            _ = try await ChartsResolver.resolve(type: .artist, username: "blueslimee", period: .overall, limit: 23, page: 1, db: app.db, lastFM: mock, logger: Logger(label: "test"))
            let callsAfterFirst = await mock.calls.filter { $0.hasPrefix("topArtists") }.count

            _ = try await ChartsResolver.resolve(type: .artist, username: "blueslimee", period: .overall, limit: 23, page: 1, db: app.db, lastFM: mock, logger: Logger(label: "test"))
            let callsAfterSecond = await mock.calls.filter { $0.hasPrefix("topArtists") }.count

            #expect(callsAfterFirst == 1)
            #expect(callsAfterSecond == 1, "an identical chart request within the 10-minute cache window should not hit Last.fm again")
        }
    }

    @Test("getCharts/all resolves top artists, albums, and tracks in one call")
    func chartsResolvesAll() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            await mock.setValidUsername("blueslimee")
            await mock.setTopArtists(.fixture(entries: [("Kelela", 1, 500)], page: 1, totalPages: 1, total: 1), username: "blueslimee", period: "overall", limit: 10, page: 1)
            await mock.setTopAlbums(.fixture(entries: [("Hallucinogen", "Kelela", 1, 200)], page: 1, totalPages: 1, total: 1), username: "blueslimee", period: "overall", limit: 10, page: 1)
            await mock.setTopTracks(.fixture(entries: [("All the Way Down", "Kelela", 1, 150)], page: 1, totalPages: 1, total: 1), username: "blueslimee", period: "overall", limit: 10, page: 1)
            await mock.setArtist(.fixture(name: "Kelela"), forName: "Kelela")
            await mock.setAlbum(.fixture(name: "Hallucinogen", artist: "Kelela"), forArtist: "Kelela", name: "Hallucinogen")
            await mock.setTrack(.fixture(name: "All the Way Down"), forArtist: "Kelela", name: "All the Way Down")

            let response = try await ChartsResolver.resolveAll(username: "blueslimee", period: .overall, limit: 10, db: app.db, lastFM: mock, logger: Logger(label: "test"))

            #expect(response.artists.items.map(\.name) == ["Kelela"])
            #expect(response.albums.items.map(\.name) == ["Hallucinogen"])
            #expect(response.tracks.items.map(\.name) == ["All the Way Down"])
        }
    }

    @Test("GET /user/charts resolves over HTTP, decoding query params and clamping limit/page")
    func chartsHTTPHappyPath() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            app.lastFM = mock
            await mock.setValidUsername("blueslimee")
            // limit=0 should clamp up to 1, so the mock only needs a fixture for limit=1.
            await mock.setTopArtists(.fixture(entries: [("Kelela", 1, 500)], page: 1, totalPages: 1, total: 1), username: "blueslimee", period: "overall", limit: 1, page: 1)
            await mock.setArtist(.fixture(name: "Kelela"), forName: "Kelela")

            try await app.testing().test(.GET, "user/charts?username=blueslimee&type=artist&period=overall&limit=0&page=0", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(ChartsResponseDTO.self)
                #expect(body.items.map(\.name) == ["Kelela"])
                #expect(body.page == 1)
            })
        }
    }

    @Test("GET /user/charts/all resolves over HTTP")
    func chartsAllHTTPHappyPath() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            app.lastFM = mock
            // Distinct limit from other tests in this suite: the response cache is a process-wide
            // singleton (by design), so a colliding cache key here would pick up a hit left over
            // from another test.
            await mock.setValidUsername("blueslimee")
            await mock.setTopArtists(.fixture(entries: [("Kelela", 1, 500)], page: 1, totalPages: 1, total: 1), username: "blueslimee", period: "overall", limit: 33, page: 1)
            await mock.setTopAlbums(.fixture(entries: [("Hallucinogen", "Kelela", 1, 200)], page: 1, totalPages: 1, total: 1), username: "blueslimee", period: "overall", limit: 33, page: 1)
            await mock.setTopTracks(.fixture(entries: [("All the Way Down", "Kelela", 1, 150)], page: 1, totalPages: 1, total: 1), username: "blueslimee", period: "overall", limit: 33, page: 1)
            await mock.setArtist(.fixture(name: "Kelela"), forName: "Kelela")
            await mock.setAlbum(.fixture(name: "Hallucinogen", artist: "Kelela"), forArtist: "Kelela", name: "Hallucinogen")
            await mock.setTrack(.fixture(name: "All the Way Down"), forArtist: "Kelela", name: "All the Way Down")

            try await app.testing().test(.GET, "user/charts/all?username=blueslimee&period=overall&limit=33", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let body = try res.content.decode(ChartsAllResponseDTO.self)
                #expect(body.artists.items.map(\.name) == ["Kelela"])
                #expect(body.albums.items.map(\.name) == ["Hallucinogen"])
                #expect(body.tracks.items.map(\.name) == ["All the Way Down"])
            })
        }
    }

    @Test("GET /user/charts/all rejects an invalid username")
    func chartsAllRejectsInvalidUsername() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            app.lastFM = mock

            try await app.testing().test(.GET, "user/charts/all?username=nobody&period=overall", afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }

    @Test("GET /user/charts rejects an invalid username")
    func chartsRejectsInvalidUsername() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            app.lastFM = mock

            try await app.testing().test(.GET, "user/charts?username=nobody&type=artist&period=overall", afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }
}
