import Fluent
import Foundation
import Vapor

enum LastFMSync {
    static let entityTTL: TimeInterval = 24 * 60 * 60
    static let scrobbleTTL: TimeInterval = 5 * 60

    /// Last.fm is going to change how this works in the future!
    static let serviceUsername = Environment.get("SYSTEM_USERNAME") ?? "rj"

    private static let ccLicense = "User-contributed text is available under the Creative Commons By-SA License; additional terms may apply."

    struct SyncedArtist {
        let artist: Artist
        let scrobbles: UserScrobbles?
    }

    struct SyncedAlbum {
        let album: Album
        let scrobbles: UserScrobbles?
    }

    struct SyncedTrack {
        let track: Track
        let scrobbles: UserScrobbles?
    }

    static func isStale(_ date: Date?, ttl: TimeInterval) -> Bool {
        guard let date else { return true }
        return Date().timeIntervalSince(date) > ttl
    }

    // MARK: - Diffing

    /// Tracks whether any field actually differs from Last.fm's canonical value, so a `save()`
    /// can be skipped entirely when a sync turns out to be a no-op.
    private struct FieldDiff<Model: AnyObject> {
        let model: Model
        var changed: Bool

        init(_ model: Model, isNew: Bool) {
            self.model = model
            self.changed = isNew
        }

        mutating func set<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<Model, Value>, _ newValue: Value) {
            if model[keyPath: keyPath] != newValue {
                model[keyPath: keyPath] = newValue
                changed = true
            }
        }

        mutating func markDirty() {
            changed = true
        }
    }

    // MARK: - Scrobble targets

    /// Which single entity a `UserScrobbles` row is for.
    private enum ScrobbleTarget {
        case artist(UUID)
        case album(UUID)
        case track(UUID)

        var ids: (artist: UUID?, album: UUID?, track: UUID?) {
            switch self {
            case .artist(let id): return (id, nil, nil)
            case .album(let id): return (nil, id, nil)
            case .track(let id): return (nil, nil, id)
            }
        }
    }

    private static func findUserScrobbles(username: String, target: ScrobbleTarget, db: any Database) async throws -> UserScrobbles? {
        let ids = target.ids
        var query = UserScrobbles.query(forUsername: username, on: db)
        query = ids.artist.map { query.filter(\.$artist.$id == $0) } ?? query.filter(\.$artist.$id == nil)
        query = ids.album.map { query.filter(\.$album.$id == $0) } ?? query.filter(\.$album.$id == nil)
        query = ids.track.map { query.filter(\.$track.$id == $0) } ?? query.filter(\.$track.$id == nil)
        return try await query.first()
    }

    private static func upsertScrobbles(
        existing: UserScrobbles?,
        username: String,
        playCount: Int,
        loved: Bool?,
        target: ScrobbleTarget,
        db: any Database
    ) async throws -> UserScrobbles {
        let ids = target.ids
        let record = existing ?? UserScrobbles(username: username, playCount: playCount, loved: loved, artistID: ids.artist, albumID: ids.album, trackID: ids.track)
        var changed = existing == nil
        if record.playCount != playCount { record.playCount = playCount; changed = true }
        if record.loved != loved { record.loved = loved; changed = true }
        if changed { try await record.save(on: db) }
        return record
    }

    // MARK: - Shared helpers

    private static func findOrCreateCover(externalID: String, db: any Database) async throws -> Cover {
        if let existing = try await Cover.query(on: db)
            .filter(\.$source == .lastfm)
            .filter(\.$externalID == externalID)
            .first() {
            return existing
        }
        let cover = Cover(source: .lastfm, externalID: externalID)
        try await cover.save(on: db)
        return cover
    }

    static func coverExternalID(from images: [LFMImage]?) -> String? {
        guard let urlString = images?.last(where: { !$0.text.isEmpty })?.text,
              let url = URL(string: urlString) else { return nil }
        return url.deletingPathExtension().lastPathComponent
    }

    /// Removes the appended "Read more on Last.fm" link (and, for bios, a trailing CC license notice)
    /// to summary/content text.
    static func stripReadMoreLink(_ text: String?) -> String? {
        guard let text else { return nil }
        guard let range = text.range(of: "<a href=\"https://www.last.fm/music/") else { return text }
        let trimmed = text[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func findOrCreateTag(name: String, url: String, db: any Database) async throws -> Tag {
        if let existing = try await Tag.query(on: db).filter(\.$name == name).first() {
            return existing
        }
        let tag = Tag(name: name, url: url)
        try await tag.save(on: db)
        return tag
    }

    /// Attaches any tags that aren't already attached.
    private static func syncTags(
        _ tags: [LFMTag]?,
        current: () async throws -> [Tag],
        attach: (Tag) async throws -> Void,
        db: any Database
    ) async throws {
        guard let tags, !tags.isEmpty else { return }
        let currentNames = Set(try await current().map { $0.name.lowercased() })
        for tagInfo in tags where !currentNames.contains(tagInfo.name.lowercased()) {
            let tag = try await findOrCreateTag(name: tagInfo.name, url: tagInfo.url, db: db)
            try await attach(tag)
        }
    }

    // TODO: syncTags and syncArtists: detach old artist and tags
    // TODO: swap for `aliases @> ARRAY[...]` filter ?
    static func findArtistByNameOrAlias(_ name: String, db: any Database) async throws -> Artist? {
        if let exact = try await Artist.query(on: db).filter(\.$name == name).first() {
            return exact
        }
        let all = try await Artist.query(on: db).all()
        return all.first { $0.aliases.contains { $0.lowercased() == name.lowercased() } }
    }

    /// Attaches any similar artists Last.fm reports that aren't already attached.
    private static func syncSimilarArtists(_ similar: [LFMArtist.SimilarArtist]?, artist: Artist, db: any Database, lastFM: any LastFMClientProtocol) async throws {
        guard let similar, !similar.isEmpty else { return }
        let artistID = try artist.requireID()
        let current = Set(try await artist.$similarArtists.get(reload: true, on: db).map { $0.name.lowercased() })

        for entry in similar where !current.contains(entry.name.lowercased()) {
            let synced = try await syncArtist(name: entry.name, username: serviceUsername, db: db, lastFM: lastFM, syncSimilar: false, trackScrobbles: false)
            let other = synced.artist
            if try other.requireID() != artistID {
                try await artist.$similarArtists.attach(other, on: db)
            }
        }
    }

    // MARK: - Artist

    /// - Parameter trackScrobbles: When `false`, `username` is only along for the ride to get a real
    ///   (non-placeholder) image out of Last.fm, without writing to `UserScrobbles`.
    static func syncArtist(name: String, username: String?, db: any Database, lastFM: any LastFMClientProtocol, syncSimilar: Bool = true, trackScrobbles: Bool = true) async throws -> SyncedArtist {
        let existing = try await findArtistByNameOrAlias(name, db: db)

        if let existing, !isStale(existing.updatedAt, ttl: entityTTL) {
            var scrobbles: UserScrobbles?
            if let username, trackScrobbles {
                scrobbles = try await findUserScrobbles(username: username, target: .artist(try existing.requireID()), db: db)
            }
            if username == nil || !trackScrobbles || !isStale(scrobbles?.updatedAt, ttl: scrobbleTTL) {
                return SyncedArtist(artist: existing, scrobbles: scrobbles)
            }
        }

        // Fetch both concurrently
        async let canonicalInfo = lastFM.artistInfo(name: name, username: serviceUsername)
        async let userInfo: LFMArtist? = {
            guard let username, trackScrobbles, username != serviceUsername else { return nil }
            return try await lastFM.artistInfo(name: name, username: username)
        }()

        let info = try await canonicalInfo
        let cover = try await findOrCreateCover(externalID: coverExternalID(from: info.image) ?? "", db: db)
        let coverID = try cover.requireID()

        let artist = existing ?? Artist(name: info.name, url: info.url, externalID: cover.externalID, listeners: 0, scrobbles: 0, coverID: coverID)
        var diff = FieldDiff(artist, isNew: existing == nil)

        diff.set(\.name, info.name)
        if info.name != name && !artist.aliases.contains(where: { $0.lowercased() == name.lowercased() }) {
            artist.aliases.append(name)
            diff.markDirty()
        }
        diff.set(\.url, info.url)
        diff.set(\.mbid, info.mbid)
        diff.set(\.summary, stripReadMoreLink(info.bio?.summary))
        diff.set(\.biography, stripReadMoreLink(info.bio?.content))
        diff.set(\.biographyLicense, ccLicense)
        diff.set(\.externalID, cover.externalID)
        diff.set(\.$cover.id, coverID)
        if let listeners = info.stats?.listeners?.value { diff.set(\.listeners, listeners) }
        if let scrobbleCount = info.stats?.playcount?.value { diff.set(\.scrobbles, scrobbleCount) }

        if diff.changed { try await artist.save(on: db) }
        try await syncTags(
            info.tags?.tag,
            current: { try await artist.$tags.get(on: db) },
            attach: { try await artist.$tags.attach($0, on: db) },
            db: db
        )
        if syncSimilar {
            try await syncSimilarArtists(info.similar?.artist, artist: artist, db: db, lastFM: lastFM)
        }

        var scrobbles: UserScrobbles?
        if let username, trackScrobbles {
            let userPlaycount = username == serviceUsername ? info.stats?.userplaycount?.value : try await userInfo?.stats?.userplaycount?.value
            let target = ScrobbleTarget.artist(try artist.requireID())
            let existingScrobbles = try await findUserScrobbles(username: username, target: target, db: db)
            scrobbles = try await upsertScrobbles(
                existing: existingScrobbles,
                username: username,
                playCount: userPlaycount ?? existingScrobbles?.playCount ?? 0,
                loved: nil,
                target: target,
                db: db
            )
        }

        return SyncedArtist(artist: artist, scrobbles: scrobbles)
    }

    // MARK: - Album

    static func syncAlbum(name: String, artist: Artist, username: String?, db: any Database, lastFM: any LastFMClientProtocol) async throws -> SyncedAlbum {
        let artistID = try artist.requireID()
        let existing = try await Album.query(on: db)
            .filter(\.$name == name)
            .filter(\.$artist.$id == artistID)
            .first()

        if let existing, !isStale(existing.updatedAt, ttl: entityTTL) {
            var scrobbles: UserScrobbles?
            if let username {
                scrobbles = try await findUserScrobbles(username: username, target: .album(try existing.requireID()), db: db)
            }
            if username == nil || !isStale(scrobbles?.updatedAt, ttl: scrobbleTTL) {
                return SyncedAlbum(album: existing, scrobbles: scrobbles)
            }
        }

        async let canonicalInfo = lastFM.albumInfo(name: name, artist: artist.name, username: serviceUsername)
        async let userInfo: LFMAlbum? = {
            guard let username, username != serviceUsername else { return nil }
            return try await lastFM.albumInfo(name: name, artist: artist.name, username: username)
        }()

        let info = try await canonicalInfo
        let cover = try await findOrCreateCover(externalID: coverExternalID(from: info.image) ?? "", db: db)
        let coverID = try cover.requireID()

        let album = existing ?? Album(name: info.name, url: info.url, listeners: 0, scrobbles: 0, artistID: artistID, coverID: coverID)
        var diff = FieldDiff(album, isNew: existing == nil)

        diff.set(\.name, info.name)
        diff.set(\.url, info.url)
        diff.set(\.mbid, info.mbid)
        diff.set(\.summary, stripReadMoreLink(info.wiki?.summary))
        diff.set(\.biography, stripReadMoreLink(info.wiki?.content))
        diff.set(\.biographyLicense, ccLicense)
        diff.set(\.$cover.id, coverID)
        if let listeners = info.listeners?.value { diff.set(\.listeners, listeners) }
        if let scrobbleCount = info.playcount?.value { diff.set(\.scrobbles, scrobbleCount) }

        if diff.changed { try await album.save(on: db) }
        try await syncTags(
            info.tags?.tag,
            current: { try await album.$tags.get(on: db) },
            attach: { try await album.$tags.attach($0, on: db) },
            db: db
        )

        let albumID = try album.requireID()

        // TODO: i dont think we need to fetch every track in the album?
        if let tracks = info.tracks?.track {
            for entry in tracks {
                let existingTrack = try await Track.query(on: db)
                    .filter(\.$name == entry.name)
                    .filter(\.$album.$id == albumID)
                    .first()
                let rank = entry.attr?.rank?.value ?? 0
                if let existingTrack {
                    if existingTrack.rank != rank {
                        existingTrack.rank = rank
                        try await existingTrack.save(on: db)
                    }
                } else {
                    let track = Track(name: entry.name, url: info.url, duration: 0, rank: rank, listeners: 0, scrobbles: 0, artistID: artistID, albumID: albumID, coverID: coverID)
                    try await track.save(on: db)
                }
            }
        }

        var scrobbles: UserScrobbles?
        if let username {
            let userPlaycount = username == serviceUsername ? info.userplaycount?.value : try await userInfo?.userplaycount?.value
            let target = ScrobbleTarget.album(albumID)
            let existingScrobbles = try await findUserScrobbles(username: username, target: target, db: db)
            scrobbles = try await upsertScrobbles(
                existing: existingScrobbles,
                username: username,
                playCount: userPlaycount ?? existingScrobbles?.playCount ?? 0,
                loved: nil,
                target: target,
                db: db
            )
        }

        return SyncedAlbum(album: album, scrobbles: scrobbles)
    }

    // MARK: - Track

    /// - Parameter persistAlbumAssociation: When `false`, `album` was a best-effort guess (discovered,
    ///   not supplied by the caller, etc) and will not be written as the track's album.
    static func syncTrack(name: String, artist: Artist, album: Album?, username: String?, db: any Database, lastFM: any LastFMClientProtocol, persistAlbumAssociation: Bool = true) async throws -> SyncedTrack {
        let artistID = try artist.requireID()

        var existing: Track?
        if let album, persistAlbumAssociation {
            let albumID = try album.requireID()
            existing = try await Track.query(on: db).filter(\.$name == name).filter(\.$album.$id == albumID).first()
        } else {
            existing = try await Track.query(on: db).filter(\.$name == name).filter(\.$artist.$id == artistID).first()
        }

        if let existing, !isStale(existing.updatedAt, ttl: entityTTL) {
            var scrobbles: UserScrobbles?
            if let username {
                scrobbles = try await findUserScrobbles(username: username, target: .track(try existing.requireID()), db: db)
            }
            if username == nil || !isStale(scrobbles?.updatedAt, ttl: scrobbleTTL) {
                return SyncedTrack(track: existing, scrobbles: scrobbles)
            }
        }

        async let canonicalInfo = lastFM.trackInfo(name: name, artist: artist.name, username: serviceUsername)
        async let userInfo: LFMTrack? = {
            guard let username, username != serviceUsername else { return nil }
            return try await lastFM.trackInfo(name: name, artist: artist.name, username: username)
        }()

        let info = try await canonicalInfo
        let canCreateOrAssociate = album != nil && persistAlbumAssociation

        guard existing != nil || canCreateOrAssociate else {
            // since no existing track is found, we dont save anything to the DB
            let track = Track(
                name: info.name,
                mbid: info.mbid,
                url: info.url,
                duration: info.duration?.value ?? 0,
                rank: 0,
                listeners: info.listeners?.value ?? 0,
                scrobbles: info.playcount?.value ?? 0,
                artistID: artistID,
                albumID: artistID, // placeholder id, never persisted
                coverID: album?.$cover.id ?? artist.$cover.id
            )

            var scrobbles: UserScrobbles?
            if let username {
                let resolvedUserInfo = username == serviceUsername ? info : try await userInfo
                if let playCount = resolvedUserInfo?.userplaycount?.value {
                    scrobbles = UserScrobbles(username: username, playCount: playCount, loved: resolvedUserInfo?.userloved?.value.map { $0 == 1 })
                }
            }
            return SyncedTrack(track: track, scrobbles: scrobbles)
        }

        let track = try existing ?? Track(name: info.name, url: info.url, duration: 0, rank: 0, listeners: 0, scrobbles: 0, artistID: artistID, albumID: album!.requireID(), coverID: album!.$cover.id)
        var diff = FieldDiff(track, isNew: existing == nil)

        diff.set(\.name, info.name)
        diff.set(\.url, info.url)
        diff.set(\.mbid, info.mbid)
        if let album, persistAlbumAssociation {
            let albumID = try album.requireID()
            diff.set(\.$album.id, albumID)
            diff.set(\.$cover.id, album.$cover.id)
        }
        if let duration = info.duration?.value { diff.set(\.duration, duration) }
        if let listeners = info.listeners?.value { diff.set(\.listeners, listeners) }
        if let scrobbleCount = info.playcount?.value { diff.set(\.scrobbles, scrobbleCount) }

        if diff.changed { try await track.save(on: db) }
        try await syncTags(
            info.toptags?.tag,
            current: { try await track.$tags.get(on: db) },
            attach: { try await track.$tags.attach($0, on: db) },
            db: db
        )

        var scrobbles: UserScrobbles?
        if let username {
            let resolvedUserInfo = username == serviceUsername ? info : try await userInfo
            let target = ScrobbleTarget.track(try track.requireID())
            let existingScrobbles = try await findUserScrobbles(username: username, target: target, db: db)
            scrobbles = try await upsertScrobbles(
                existing: existingScrobbles,
                username: username,
                playCount: resolvedUserInfo?.userplaycount?.value ?? existingScrobbles?.playCount ?? 0,
                loved: resolvedUserInfo?.userloved?.value.map { $0 == 1 },
                target: target,
                db: db
            )
        }

        return SyncedTrack(track: track, scrobbles: scrobbles)
    }
}
