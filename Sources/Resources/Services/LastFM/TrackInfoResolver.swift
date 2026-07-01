import Fluent

struct TrackInfoResult {
    let track: Track
    let trackScrobbles: UserScrobbles?
    let album: Album?
    let albumScrobbles: UserScrobbles?
    let artist: Artist
    let artistScrobbles: UserScrobbles?
}

enum TrackInfoResolver {
    static func resolve(
        track: String,
        album: String?,
        artist: String,
        username: String,
        db: any Database,
        lastFM: any LastFMClientProtocol
    ) async throws -> TrackInfoResult {
        let albumWasExplicit = album != nil
        let cleanTrack = LastFMNameCleaner.cleanTrackName(track)

        let syncedArtist = try await LastFMSync.syncArtist(name: artist, username: username, db: db, lastFM: lastFM)

        var syncedAlbum: LastFMSync.SyncedAlbum?
        var matchedTrackName = cleanTrack

        if let album {
            // "X" and "X - EP"/"X - Single" can be genuinely distinct releases on Last.fm (not just
            // decorated names for the same album), so try the caller's exact string first and only
            // fall back to the cleaned name if that lookup fails.
            do {
                syncedAlbum = try await LastFMSync.syncAlbum(name: album, artist: syncedArtist.artist, username: username, db: db, lastFM: lastFM)
            } catch LastFMError.notFound {
                let cleanedAlbum = LastFMNameCleaner.cleanAlbumName(album)
                if cleanedAlbum != album {
                    syncedAlbum = try await LastFMSync.syncAlbum(name: cleanedAlbum, artist: syncedArtist.artist, username: username, db: db, lastFM: lastFM)
                } else {
                    throw LastFMError.notFound
                }
            }
        } else if let discovered = try await discoverAlbumName(cleanTrack: cleanTrack, originalTrack: track, artist: artist, lastFM: lastFM) {
            syncedAlbum = try await LastFMSync.syncAlbum(name: discovered.album, artist: syncedArtist.artist, username: username, db: db, lastFM: lastFM)
            matchedTrackName = discovered.trackName
        }

        if let albumResult = syncedAlbum {
            let albumID = try albumResult.album.requireID()
            let tracks = try await Track.query(on: db).filter(\.$album.$id == albumID).all()
            let cleanTrackLower = cleanTrack.lowercased()

            if let exact = tracks.first(where: { LastFMNameCleaner.cleanTrackName($0.name).lowercased() == cleanTrackLower }) {
                matchedTrackName = exact.name
            } else if let prefixed = tracks.first(where: { LastFMNameCleaner.cleanTrackName($0.name).lowercased().hasPrefix(cleanTrackLower) }) {
                matchedTrackName = prefixed.name
            }
        }

        let syncedTrack = try await LastFMSync.syncTrack(
            name: matchedTrackName,
            artist: syncedArtist.artist,
            album: syncedAlbum?.album,
            username: username,
            db: db,
            lastFM: lastFM,
            persistAlbumAssociation: albumWasExplicit
        )

        return TrackInfoResult(
            track: syncedTrack.track,
            trackScrobbles: syncedTrack.scrobbles,
            album: syncedAlbum?.album,
            albumScrobbles: syncedAlbum?.scrobbles,
            artist: syncedArtist.artist,
            artistScrobbles: syncedArtist.scrobbles
        )
    }

    /// Returns the album title along with whichever of `cleanTrack`/`originalTrack` actually
    /// resolved it, so callers don't retry with a name that's already known to not exist.
    private static func discoverAlbumName(cleanTrack: String, originalTrack: String, artist: String, lastFM: any LastFMClientProtocol) async throws -> (trackName: String, album: String)? {
        var info: LFMTrack?
        var resolvedName = cleanTrack
        do {
            info = try await lastFM.trackInfo(name: cleanTrack, artist: artist, username: LastFMSync.serviceUsername)
        } catch LastFMError.notFound {
            info = nil
        }

        if info?.album == nil {
            do {
                info = try await lastFM.trackInfo(name: originalTrack, artist: artist, username: LastFMSync.serviceUsername)
                if info?.album != nil { resolvedName = originalTrack }
            } catch LastFMError.notFound {
                info = nil
            }
        }

        guard let albumTitle = info?.album?.title else { return nil }
        return (resolvedName, albumTitle)
    }
}
