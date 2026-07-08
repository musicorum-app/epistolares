import Fluent
import FluentSQL
import Foundation
import Vapor

enum LastFMSync {
    static let entityTTL: TimeInterval = 24 * 60 * 60
    static let scrobbleTTL: TimeInterval = 5 * 60

    private static let logger = Logger(label: "resources.sync")

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
        record.playCount = playCount
        record.loved = loved
        try await record.save(on: db)
        return record
    }

    private static func syncScrobbles(username: String?, target: ScrobbleTarget, playCount: Int?, loved: Bool?, db: any Database) async throws -> UserScrobbles? {
        guard let username else { return nil }
        let existing = try await findUserScrobbles(username: username, target: target, db: db)
        return try await upsertScrobbles(existing: existing, username: username, playCount: playCount ?? existing?.playCount ?? 0, loved: loved, target: target, db: db)
    }

    // MARK: - Freshness

    fileprivate protocol HasUpdatedAt {
        var updatedAt: Date? { get }
    }

    private enum FreshnessCheck<Entity> {
        case hit(Entity, UserScrobbles?)
        case miss(reason: String)
    }

    private static func checkFreshness<Entity: HasUpdatedAt>(
        _ existing: Entity?,
        username: String?,
        trackScrobbles: Bool = true,
        target: (Entity) throws -> ScrobbleTarget,
        db: any Database
    ) async throws -> FreshnessCheck<Entity> {
        guard let existing, !isStale(existing.updatedAt, ttl: entityTTL) else {
            return .miss(reason: "entity missing or stale")
        }
        var scrobbles: UserScrobbles?
        if let username, trackScrobbles {
            scrobbles = try await findUserScrobbles(username: username, target: try target(existing), db: db)
        }
        if username == nil || !trackScrobbles || !isStale(scrobbles?.updatedAt, ttl: scrobbleTTL) {
            return .hit(existing, scrobbles)
        }
        return .miss(reason: "scrobbles stale")
    }

    private static func fetchCanonicalAndUser<Info>(
        username: String?,
        trackScrobbles: Bool = true,
        _ fetch: @Sendable @escaping (String) async throws -> Info
    ) async throws -> (canonical: Info, user: Info?) {
        async let canonical = fetch(serviceUsername)
        async let user: Info? = {
            guard let username, trackScrobbles, username != serviceUsername else { return nil }
            return try await fetch(username)
        }()
        return (try await canonical, try await user)
    }

    // MARK: - Shared helpers

    private static func createOrFetchExisting<Model: FluentKit.Model>(_ model: Model, db: any Database, fetchExisting: () async throws -> Model?) async throws -> Model {
        do {
            try await model.save(on: db)
            return model
        } catch {
            guard let dbError = error as? any DatabaseError, dbError.isConstraintFailure,
                  let existing = try await fetchExisting() else { throw error }
            logger.debug("createOrFetchExisting: lost a create race, using the row a concurrent sync just inserted", metadata: ["model": .string(String(describing: Model.self))])
            return existing
        }
    }

    private static func attachIgnoringDuplicate(_ attach: () async throws -> Void) async throws {
        do {
            try await attach()
        } catch {
            guard let dbError = error as? any DatabaseError, dbError.isConstraintFailure else { throw error }
            logger.debug("attachIgnoringDuplicate: a concurrent sync already attached this pair")
        }
    }

    private static func findOrCreateCover(externalID: String, db: any Database) async throws -> Cover {
        if let existing = try await Cover.query(on: db)
            .filter(\.$source == .lastfm)
            .filter(\.$externalID == externalID)
            .first() {
            return existing
        }
        let cover = Cover(source: .lastfm, externalID: externalID)
        return try await createOrFetchExisting(cover, db: db) {
            try await Cover.query(on: db).filter(\.$source == .lastfm).filter(\.$externalID == externalID).first()
        }
    }

    private static let placeholderCoverIDs: Set<String> = [
        "4128a6eb29f94943c9d206c08e625904",
        "c6f59c1e5e7240a4c0d427abd71f3dbb",
        "2a96cbd8b46e442fc41c2b86b821562f",
    ]

    static func coverExternalID(from images: [LFMImage]?) -> String? {
        for image in (images ?? []).reversed() {
            guard !image.text.isEmpty, let url = URL(string: image.text) else { continue }
            let id = url.deletingPathExtension().lastPathComponent
            if !placeholderCoverIDs.contains(id) { return id }
        }
        return nil
    }

    static func isMissingCover(_ cover: Cover) -> Bool {
        cover.externalID.isEmpty || placeholderCoverIDs.contains(cover.externalID)
    }

    private static func betterCoverID(album: Album?, artist: Artist, db: any Database) async throws -> Cover.IDValue {
        if let album {
            let albumCover = try await album.$cover.get(reload: true, on: db)
            if !isMissingCover(albumCover) { return try albumCover.requireID() }
        }
        return artist.$cover.id
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
        return try await createOrFetchExisting(tag, db: db) {
            try await Tag.query(on: db).filter(\.$name == name).first()
        }
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
            try await attachIgnoringDuplicate { try await attach(tag) }
        }
    }

    // TODO: syncTags and syncArtists: detach old artist and tags
    static func findArtistByNameOrAlias(_ name: String, db: any Database) async throws -> Artist? {
        if let exact = try await Artist.query(on: db).filter(\.$name == name).first() {
            return exact
        }
        guard let sql = db as? any SQLDatabase else {
            let all = try await Artist.query(on: db).all()
            return all.first { $0.aliases.contains { $0.lowercased() == name.lowercased() } }
        }
        struct IDRow: Decodable { let id: UUID }
        let match = try await sql.raw("""
            SELECT id FROM artists
            WHERE EXISTS (SELECT 1 FROM unnest(aliases) AS alias WHERE lower(alias) = lower(\(bind: name)))
            LIMIT 1
            """).first(decoding: IDRow.self)
        guard let match else { return nil }
        return try await Artist.find(match.id, on: db)
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
                logger.debug("attaching newly-discovered similar artist", metadata: ["artist": .string(artist.name), "similar": .string(other.name)])
                try await attachIgnoringDuplicate { try await artist.$similarArtists.attach(other, on: db) }
            }
        }
    }

    // MARK: - Artist

    /// - Parameter trackScrobbles: When `false`, `username` is only along for the ride to get a real
    ///   (non-placeholder) image out of Last.fm, without writing to `UserScrobbles`.
    static func syncArtist(name: String, username: String?, db: any Database, lastFM: any LastFMClientProtocol, syncSimilar: Bool = true, trackScrobbles: Bool = true) async throws -> SyncedArtist {
        let existing = try await findArtistByNameOrAlias(name, db: db)

        switch try await checkFreshness(existing, username: username, trackScrobbles: trackScrobbles, target: { .artist(try $0.requireID()) }, db: db) {
        case .hit(let artist, let scrobbles):
            logger.debug("syncArtist cache hit", metadata: ["name": .string(name)])
            return SyncedArtist(artist: artist, scrobbles: scrobbles)
        case .miss(let reason):
            logger.debug("syncArtist cache miss: \(reason)", metadata: ["name": .string(name)])
        }

        let (info, userInfo) = try await fetchCanonicalAndUser(username: username, trackScrobbles: trackScrobbles) { username in
            try await lastFM.artistInfo(name: name, username: username)
        }
        let cover = try await findOrCreateCover(externalID: coverExternalID(from: info.image) ?? "", db: db)
        let coverID = try cover.requireID()
        let coverIsReal = !isMissingCover(cover)

        var artist = existing ?? Artist(name: info.name, url: info.url, externalID: cover.externalID, listeners: 0, scrobbles: 0, coverID: coverID)
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
        if existing == nil || coverIsReal {
            diff.set(\.externalID, cover.externalID)
            diff.set(\.$cover.id, coverID)
        }
        if let listeners = info.stats?.listeners?.value { diff.set(\.listeners, listeners) }
        if let scrobbleCount = info.stats?.playcount?.value { diff.set(\.scrobbles, scrobbleCount) }

        if diff.changed {
            if existing == nil {
                artist = try await createOrFetchExisting(artist, db: db) { try await findArtistByNameOrAlias(info.name, db: db) }
            } else {
                try await artist.save(on: db)
            }
        }
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
        if trackScrobbles {
            let userPlaycount = username == serviceUsername ? info.stats?.userplaycount?.value : userInfo?.stats?.userplaycount?.value
            scrobbles = try await syncScrobbles(username: username, target: .artist(try artist.requireID()), playCount: userPlaycount, loved: nil, db: db)
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

        switch try await checkFreshness(existing, username: username, target: { .album(try $0.requireID()) }, db: db) {
        case .hit(let album, let scrobbles):
            logger.debug("syncAlbum cache hit", metadata: ["name": .string(name)])
            return SyncedAlbum(album: album, scrobbles: scrobbles)
        case .miss(let reason):
            logger.debug("syncAlbum cache miss: \(reason)", metadata: ["name": .string(name)])
        }

        let (info, userInfo) = try await fetchCanonicalAndUser(username: username) { username in
            try await lastFM.albumInfo(name: name, artist: artist.name, username: username)
        }
        let cover = try await findOrCreateCover(externalID: coverExternalID(from: info.image) ?? "", db: db)
        let coverID = try cover.requireID()
        let coverIsReal = !isMissingCover(cover)

        var album = existing ?? Album(name: info.name, url: info.url, listeners: 0, scrobbles: 0, artistID: artistID, coverID: coverID)
        var diff = FieldDiff(album, isNew: existing == nil)

        diff.set(\.name, info.name)
        diff.set(\.url, info.url)
        diff.set(\.mbid, info.mbid)
        diff.set(\.summary, stripReadMoreLink(info.wiki?.summary))
        diff.set(\.biography, stripReadMoreLink(info.wiki?.content))
        diff.set(\.biographyLicense, ccLicense)
        if existing == nil || coverIsReal {
            diff.set(\.$cover.id, coverID)
        }
        if let listeners = info.listeners?.value { diff.set(\.listeners, listeners) }
        if let scrobbleCount = info.playcount?.value { diff.set(\.scrobbles, scrobbleCount) }

        if diff.changed {
            if existing == nil {
                album = try await createOrFetchExisting(album, db: db) {
                    try await Album.query(on: db).filter(\.$name == info.name).filter(\.$artist.$id == artistID).first()
                }
            } else {
                try await album.save(on: db)
            }
        }
        try await syncTags(
            info.tags?.tag,
            current: { try await album.$tags.get(on: db) },
            attach: { try await album.$tags.attach($0, on: db) },
            db: db
        )

        let albumID = try album.requireID()

        if let tracks = info.tracks?.track {
            let existingByName = try await Track.query(on: db)
                .filter(\.$album.$id == albumID)
                .all()
                .reduce(into: [String: Track]()) { $0[$1.name] = $1 }

            for entry in tracks {
                let existingTrack = existingByName[entry.name]
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

        let userPlaycount = username == serviceUsername ? info.userplaycount?.value : userInfo?.userplaycount?.value
        let scrobbles = try await syncScrobbles(username: username, target: .album(albumID), playCount: userPlaycount, loved: nil, db: db)

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

        switch try await checkFreshness(existing, username: username, target: { .track(try $0.requireID()) }, db: db) {
        case .hit(let track, let scrobbles):
            logger.debug("syncTrack cache hit", metadata: ["name": .string(name)])
            return SyncedTrack(track: track, scrobbles: scrobbles)
        case .miss(let reason):
            logger.debug("syncTrack cache miss: \(reason)", metadata: ["name": .string(name)])
        }

        let (info, userInfo) = try await fetchCanonicalAndUser(username: username) { username in
            try await lastFM.trackInfo(name: name, artist: artist.name, username: username)
        }
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
                coverID: try await betterCoverID(album: album, artist: artist, db: db)
            )

            var scrobbles: UserScrobbles?
            if let username {
                let resolvedUserInfo = username == serviceUsername ? info : userInfo
                scrobbles = UserScrobbles(
                    username: username,
                    playCount: resolvedUserInfo?.userplaycount?.value ?? 0,
                    loved: resolvedUserInfo?.userloved?.value.map { $0 == 1 }
                )
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
            let albumCover = try await album.$cover.get(reload: true, on: db)
            if existing == nil || !isMissingCover(albumCover) {
                diff.set(\.$cover.id, try albumCover.requireID())
            }
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

        let resolvedUserInfo = username == serviceUsername ? info : userInfo
        let scrobbles = try await syncScrobbles(
            username: username,
            target: .track(try track.requireID()),
            playCount: resolvedUserInfo?.userplaycount?.value,
            loved: resolvedUserInfo?.userloved?.value.map { $0 == 1 },
            db: db
        )

        return SyncedTrack(track: track, scrobbles: scrobbles)
    }
}

extension Artist: LastFMSync.HasUpdatedAt {}
extension Album: LastFMSync.HasUpdatedAt {}
extension Track: LastFMSync.HasUpdatedAt {}
