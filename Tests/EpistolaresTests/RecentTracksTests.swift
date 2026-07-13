@testable import Epistolares
import VaporTesting
import Testing
import Fluent
import Logging

extension AppTests {
    @Test("getRecentTracks resolves each entry through the same sync path as track/info")
    func recentTracksResolvesEntries() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            await mock.setValidUsername("blueslimee")
            await mock.setRecentTracks(
                .fixture(entries: [
                    (name: "1 Thing", artist: "Amerie", album: "Touch", uts: nil, nowPlaying: true),
                    (name: "Toxic", artist: "Britney Spears", album: "In the Zone", uts: 1_782_953_390, nowPlaying: false),
                ], page: 1, totalPages: 1, total: 2),
                username: "blueslimee", limit: 50, page: 1
            )
            await mock.setArtist(.fixture(name: "Amerie"), forName: "Amerie")
            await mock.setAlbum(.fixture(name: "Touch", artist: "Amerie", tracks: [("1 Thing", 1)]), forArtist: "Amerie", name: "Touch")
            await mock.setTrack(.fixture(name: "1 Thing", albumTitle: "Touch", albumArtist: "Amerie"), forArtist: "Amerie", name: "1 Thing")

            await mock.setArtist(.fixture(name: "Britney Spears"), forName: "Britney Spears")
            await mock.setAlbum(.fixture(name: "In the Zone", artist: "Britney Spears", tracks: [("Toxic", 1)]), forArtist: "Britney Spears", name: "In the Zone")
            await mock.setTrack(.fixture(name: "Toxic", userloved: true), forArtist: "Britney Spears", name: "Toxic")

            let response = try await RecentTracksResolver.resolve(username: "blueslimee", limit: 50, page: 1, db: app.db, lastFM: mock, logger: Logger(label: "test"))

            #expect(response.items.count == 2)

            let nowPlayingItem = response.items[0]
            #expect(nowPlayingItem.track.name == "1 Thing")
            #expect(nowPlayingItem.artist.name == "Amerie")
            #expect(nowPlayingItem.album?.name == "Touch")
            #expect(nowPlayingItem.nowPlaying == true)
            #expect(nowPlayingItem.playedAt == nil)

            let playedItem = response.items[1]
            #expect(playedItem.track.name == "Toxic")
            #expect(playedItem.nowPlaying == false)
            #expect(playedItem.playedAt == Date(timeIntervalSince1970: 1_782_953_390))
            #expect(playedItem.track.userScrobbles.loved == true, "loved should come through non-optionally since username is always given here")
            #expect(playedItem.artist.userScrobbles.playCount >= 0, "artist/album userScrobbles are never optional on this endpoint")
        }
    }

    @Test("getRecentTracks treats an empty album #text as no album")
    func recentTracksTreatsEmptyAlbumAsNil() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            await mock.setValidUsername("blueslimee")
            await mock.setRecentTracks(
                .fixture(entries: [
                    (name: "Some Track", artist: "Some Artist", album: nil, uts: 1_782_953_390, nowPlaying: false),
                ], page: 1, totalPages: 1, total: 1),
                username: "blueslimee", limit: 50, page: 1
            )
            await mock.setArtist(.fixture(name: "Some Artist"), forName: "Some Artist")
            await mock.setTrack(.fixture(name: "Some Track"), forArtist: "Some Artist", name: "Some Track")

            let response = try await RecentTracksResolver.resolve(username: "blueslimee", limit: 50, page: 1, db: app.db, lastFM: mock, logger: Logger(label: "test"))

            #expect(response.items.count == 1)
            #expect(response.items[0].track.name == "Some Track")
        }
    }

    @Test("GET /user/recent-tracks rejects an invalid username")
    func recentTracksRejectsInvalidUsername() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            app.lastFM = mock

            try await app.testing().test(.GET, "user/recent-tracks?username=nobody", afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }
}
