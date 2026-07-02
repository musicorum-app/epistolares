import Fluent
import Foundation
import Logging

enum ChartsResolver {
    private static let cache = InMemoryCache<String, ChartsResponseDTO>(ttl: 10 * 60)

    static func resolve(
        type: ChartType,
        username: String,
        period: ChartPeriod,
        limit: Int,
        page: Int,
        db: any Database,
        lastFM: any LastFMClientProtocol,
        logger: Logger
    ) async throws -> ChartsResponseDTO {
        let cacheKey = "\(type.rawValue)|\(username.lowercased())|\(period.rawValue)|\(limit)|\(page)"
        if let cached = await cache.get(cacheKey) {
            logger.debug("charts cache hit", metadata: ["key": .string(cacheKey)])
            return cached
        }
        logger.debug("charts cache miss", metadata: ["key": .string(cacheKey)])

        let overallStart = DispatchTime.now()
        var items: [ChartEntryDTO] = []
        let attr: LFMChartAttr
        switch type {
        case .artist:
            let chart = try await lastFM.topArtists(username: username, period: period.rawValue, limit: limit, page: page)
            attr = chart.attr
            for entry in chart.artist ?? [] {
                let synced = try await LastFMSync.syncArtist(name: entry.name, username: username, db: db, lastFM: lastFM, syncSimilar: false)
                items.append(try await entryDTO(artist: nil, playCount: entry.playcount?.value, entity: synced.artist, db: db))
            }

        case .album:
            let chart = try await lastFM.topAlbums(username: username, period: period.rawValue, limit: limit, page: page)
            attr = chart.attr
            for entry in chart.album ?? [] {
                let syncedArtist = try await LastFMSync.syncArtist(name: entry.artist.name, username: username, db: db, lastFM: lastFM, syncSimilar: false)
                let syncedAlbum = try await LastFMSync.syncAlbum(name: entry.name, artist: syncedArtist.artist, username: username, db: db, lastFM: lastFM)
                items.append(try await entryDTO(artist: syncedArtist.artist.name, playCount: entry.playcount?.value, entity: syncedAlbum.album, db: db))
            }

        case .track:
            let chart = try await lastFM.topTracks(username: username, period: period.rawValue, limit: limit, page: page)
            attr = chart.attr
            for entry in chart.track ?? [] {
                let result = try await TrackInfoResolver.resolve(track: entry.name, album: nil, artist: entry.artist.name, username: username, db: db, lastFM: lastFM)
                items.append(try await entryDTO(artist: result.artist.name, playCount: entry.playcount?.value, entity: result.track, db: db))
            }
        }

        // Guarantee "ordered by playCount" regardless of what order Last.fm happened to send.
        items.sort { $0.playCount > $1.playCount }

        let response = ChartsResponseDTO(
            page: attr.page.value ?? page,
            totalPages: attr.totalPages.value ?? 0,
            total: attr.total.value ?? 0,
            items: items
        )

        let overallMs = Double(DispatchTime.now().uptimeNanoseconds - overallStart.uptimeNanoseconds) / 1_000_000
        logger.info("resolved charts", metadata: [
            "type": .string(type.rawValue), "username": .string(username), "count": .stringConvertible(items.count), "ms": .stringConvertible(String(format: "%.1f", overallMs)),
        ])

        await cache.set(cacheKey, response)
        return response
    }

    static func resolveAll(
        username: String,
        period: ChartPeriod,
        limit: Int,
        db: any Database,
        lastFM: any LastFMClientProtocol,
        logger: Logger
    ) async throws -> ChartsAllResponseDTO {
        async let artists = resolve(type: .artist, username: username, period: period, limit: limit, page: 1, db: db, lastFM: lastFM, logger: logger)
        async let albums = resolve(type: .album, username: username, period: period, limit: limit, page: 1, db: db, lastFM: lastFM, logger: logger)
        async let tracks = resolve(type: .track, username: username, period: period, limit: limit, page: 1, db: db, lastFM: lastFM, logger: logger)
        return try await ChartsAllResponseDTO(artists: artists, albums: albums, tracks: tracks)
    }

    private static func entryDTO(artist: String?, playCount: Int?, entity: some ChartResolvable, db: any Database) async throws -> ChartEntryDTO {
        let cover = try await entity.cover(db: db)
        return ChartEntryDTO(
            id: entity.id ?? UUID(),
            name: entity.name,
            artist: artist,
            cover: cover.toCoverDTO(),
            playCount: playCount ?? 0
        )
    }
}

private protocol ChartResolvable {
    var id: UUID? { get }
    var name: String { get }
    func cover(db: any Database) async throws -> Cover
}

extension Artist: ChartResolvable {
    func cover(db: any Database) async throws -> Cover {
        try await $cover.get(reload: true, on: db)
    }
}

extension Album: ChartResolvable {
    func cover(db: any Database) async throws -> Cover {
        try await $cover.get(reload: true, on: db)
    }
}

extension Track: ChartResolvable {
    func cover(db: any Database) async throws -> Cover {
        try await $cover.get(reload: true, on: db)
    }
}
