@testable import Resources
import Testing
import Fluent

extension AppTests {
    @Test("syncArtist creates a new artist from a mock Last.fm response")
    func syncArtistCreatesNewArtist() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            await mock.setArtist(.fixture(name: "Kelela", listeners: 648_122, playcount: 39_692_947), forName: "Kelela")

            let synced = try await LastFMSync.syncArtist(name: "Kelela", username: nil, db: app.db, lastFM: mock)

            #expect(synced.artist.name == "Kelela")
            #expect(synced.artist.listeners == 648_122)
            #expect(synced.artist.scrobbles == 39_692_947)

            let stored = try await Artist.query(on: app.db).filter(\.$name == "Kelela").first()
            #expect(stored != nil)
        }
    }

    @Test("syncArtist reuses a fresh cached row without calling Last.fm again")
    func syncArtistUsesCacheWhenFresh() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            await mock.setArtist(.fixture(name: "Kelela"), forName: "Kelela")

            _ = try await LastFMSync.syncArtist(name: "Kelela", username: nil, db: app.db, lastFM: mock)
            let callsAfterFirst = await mock.calls.count

            _ = try await LastFMSync.syncArtist(name: "Kelela", username: nil, db: app.db, lastFM: mock)
            let callsAfterSecond = await mock.calls.count

            #expect(callsAfterFirst == 1)
            #expect(callsAfterSecond == 1, "second call within the TTL window should not hit Last.fm again")
        }
    }

    @Test("syncArtist records an alias when autocorrect changes the name")
    func syncArtistRecordsAlias() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            // Simulate Last.fm's autocorrect: we search "kelela" (lowercase typo), it corrects to "Kelela".
            await mock.setArtist(.fixture(name: "Kelela"), forName: "kelela")

            let synced = try await LastFMSync.syncArtist(name: "kelela", username: nil, db: app.db, lastFM: mock)

            #expect(synced.artist.name == "Kelela")
            #expect(synced.artist.aliases == ["kelela"])
        }
    }

    @Test("syncArtist strips the Last.fm read-more link from bio fields")
    func syncArtistStripsBioLink() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            let bio = "Real bio content. <a href=\"https://www.last.fm/music/Kelela\">Read more on Last.fm</a>. User-contributed text is available under the Creative Commons By-SA License; additional terms may apply."
            await mock.setArtist(.fixture(name: "Kelela", bioSummary: bio, bioContent: bio), forName: "Kelela")

            let synced = try await LastFMSync.syncArtist(name: "Kelela", username: nil, db: app.db, lastFM: mock)

            #expect(synced.artist.summary == "Real bio content.")
            #expect(synced.artist.biography == "Real bio content.")
        }
    }

    @Test("syncArtist upserts the requesting user's scrobble count")
    func syncArtistUpsertsUserScrobbles() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            await mock.setArtist(.fixture(name: "Kelela", userplaycount: 909), forName: "Kelela")

            let synced = try await LastFMSync.syncArtist(name: "Kelela", username: "rj", db: app.db, lastFM: mock)

            #expect(synced.scrobbles?.playCount == 909)
        }
    }

    @Test("syncAlbum caches the album's tracklist as bare name+rank entries")
    func syncAlbumCachesTracklist() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            await mock.setArtist(.fixture(name: "Kelela"), forName: "Kelela")
            await mock.setAlbum(
                .fixture(name: "Hallucinogen", artist: "Kelela", tracks: [
                    ("A Message", 1), ("Gomenasai", 2), ("All the Way Down", 3),
                ]),
                forArtist: "Kelela", name: "Hallucinogen"
            )

            let artist = try await LastFMSync.syncArtist(name: "Kelela", username: nil, db: app.db, lastFM: mock)
            let album = try await LastFMSync.syncAlbum(name: "Hallucinogen", artist: artist.artist, username: nil, db: app.db, lastFM: mock)

            let albumID = try album.album.requireID()
            let tracks = try await Track.query(on: app.db).filter(\.$album.$id == albumID).sort(\.$rank).all()
            #expect(tracks.map(\.name) == ["A Message", "Gomenasai", "All the Way Down"])
            #expect(tracks.map(\.rank) == [1, 2, 3])
        }
    }

    @Test("syncTrack does not persist a track-album association that was only discovered, not requested")
    func syncTrackDoesNotPersistGuessedAlbum() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            await mock.setArtist(.fixture(name: "Some Artist"), forName: "Some Artist")
            await mock.setAlbum(.fixture(name: "Some Album", artist: "Some Artist", tracks: []), forArtist: "Some Artist", name: "Some Album")
            await mock.setTrack(.fixture(name: "Some Track", listeners: 42), forArtist: "Some Artist", name: "Some Track")

            let artist = try await LastFMSync.syncArtist(name: "Some Artist", username: nil, db: app.db, lastFM: mock)
            let album = try await LastFMSync.syncAlbum(name: "Some Album", artist: artist.artist, username: nil, db: app.db, lastFM: mock)

            let synced = try await LastFMSync.syncTrack(
                name: "Some Track",
                artist: artist.artist,
                album: album.album,
                username: nil,
                db: app.db,
                lastFM: mock,
                persistAlbumAssociation: false
            )

            #expect(synced.track.listeners == 42, "the response should still reflect fresh Last.fm data")

            let stored = try await Track.query(on: app.db).filter(\.$name == "Some Track").first()
            #expect(stored == nil, "no row should have been written for an unconfirmed album guess")
        }
    }

    @Test("syncTrack does persist when the album association was explicitly requested")
    func syncTrackPersistsExplicitAlbum() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            await mock.setArtist(.fixture(name: "Some Artist"), forName: "Some Artist")
            await mock.setAlbum(.fixture(name: "Some Album", artist: "Some Artist", tracks: []), forArtist: "Some Artist", name: "Some Album")
            await mock.setTrack(.fixture(name: "Some Track"), forArtist: "Some Artist", name: "Some Track")

            let artist = try await LastFMSync.syncArtist(name: "Some Artist", username: nil, db: app.db, lastFM: mock)
            let album = try await LastFMSync.syncAlbum(name: "Some Album", artist: artist.artist, username: nil, db: app.db, lastFM: mock)

            _ = try await LastFMSync.syncTrack(
                name: "Some Track",
                artist: artist.artist,
                album: album.album,
                username: nil,
                db: app.db,
                lastFM: mock,
                persistAlbumAssociation: true
            )

            let stored = try await Track.query(on: app.db).filter(\.$name == "Some Track").first()
            #expect(stored != nil)
            #expect(try stored?.$album.id == album.album.requireID())
        }
    }

    @Test("TrackInfoResolver discovers the album when none is supplied")
    func resolverDiscoversAlbum() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            await mock.setArtist(.fixture(name: "Kelela"), forName: "Kelela")
            await mock.setTrack(
                .fixture(name: "All the Way Down", albumTitle: "Hallucinogen", albumArtist: "Kelela"),
                forArtist: "Kelela", name: "All the Way Down"
            )
            await mock.setAlbum(
                .fixture(name: "Hallucinogen", artist: "Kelela", tracks: [("All the Way Down", 1)]),
                forArtist: "Kelela", name: "Hallucinogen"
            )

            let result = try await TrackInfoResolver.resolve(
                track: "All the Way Down", album: nil, artist: "Kelela", username: LastFMSync.serviceUsername,
                db: app.db, lastFM: mock
            )

            #expect(result.album?.name == "Hallucinogen")
            #expect(result.track.name == "All the Way Down")
        }
    }

    @Test("syncTrack does not steal a same-named track from a different album when persisting explicitly")
    func syncTrackDoesNotReassignTrackAcrossAlbums() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            await mock.setArtist(.fixture(name: "Some Artist"), forName: "Some Artist")
            await mock.setAlbum(.fixture(name: "Album A", artist: "Some Artist", tracks: [("Intro", 1)]), forArtist: "Some Artist", name: "Album A")
            await mock.setAlbum(.fixture(name: "Album B", artist: "Some Artist", tracks: [("Intro", 1)]), forArtist: "Some Artist", name: "Album B")
            await mock.setTrack(.fixture(name: "Intro"), forArtist: "Some Artist", name: "Intro")

            let artist = try await LastFMSync.syncArtist(name: "Some Artist", username: nil, db: app.db, lastFM: mock)
            let albumA = try await LastFMSync.syncAlbum(name: "Album A", artist: artist.artist, username: nil, db: app.db, lastFM: mock)
            let albumB = try await LastFMSync.syncAlbum(name: "Album B", artist: artist.artist, username: nil, db: app.db, lastFM: mock)

            // Album A's own tracklist sync already created its "Intro" row (per syncAlbumCachesTracklist).
            // Explicitly resolving Album B's "Intro" must create a second row, not repoint Album A's.
            _ = try await LastFMSync.syncTrack(
                name: "Intro", artist: artist.artist, album: albumB.album, username: nil,
                db: app.db, lastFM: mock, persistAlbumAssociation: true
            )

            let introRows = try await Track.query(on: app.db).filter(\.$name == "Intro").all()
            #expect(introRows.count == 2, "each album should keep its own \"Intro\" row")

            let albumAID = try albumA.album.requireID()
            let albumBID = try albumB.album.requireID()
            let introAlbumIDs = Set(introRows.map { $0.$album.id })
            #expect(introAlbumIDs == [albumAID, albumBID], "neither album should have lost its \"Intro\" track")
        }
    }

    @Test("syncSimilarArtists does not create a scrobble row for the service account")
    func syncSimilarArtistsDoesNotTrackServiceAccountScrobbles() async throws {
        try await withTestApp { app in
            let mock = MockLastFMClient()
            await mock.setArtist(
                .fixture(name: "Kelela", similar: [
                    LFMArtist.SimilarArtist(name: "Rochelle Jordan", url: "https://www.last.fm/music/Rochelle+Jordan", image: nil),
                ]),
                forName: "Kelela"
            )
            await mock.setArtist(.fixture(name: "Rochelle Jordan", userplaycount: 500), forName: "Rochelle Jordan")

            _ = try await LastFMSync.syncArtist(name: "Kelela", username: nil, db: app.db, lastFM: mock)

            let similarArtist = try await Artist.query(on: app.db).filter(\.$name == "Rochelle Jordan").first()
            #expect(similarArtist != nil)

            let scrobbleRows = try await UserScrobbles.query(forUsername: LastFMSync.serviceUsername, on: app.db).all()
            #expect(scrobbleRows.isEmpty, "discovering a similar artist must not record scrobbles for the service account")
        }
    }
}
