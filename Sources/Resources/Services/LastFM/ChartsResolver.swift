import Fluent
import Foundation

enum ChartsResolver {
    private static let cache = InMemoryCache<String, ChartsResponseDTO>(ttl: 10 * 60)

    static func resolve(
        type: ChartType,
        username: String,
        period: ChartPeriod,
        limit: Int,
        page: Int,
        db: any Database,
        lastFM: any LastFMClientProtocol
    ) async throws -> ChartsResponseDTO {
        let cacheKey = "\(type.rawValue)|\(username.lowercased())|\(period.rawValue)|\(limit)|\(page)"
        if let cached = await cache.get(cacheKey) {
            return cached
        }

        let response: ChartsResponseDTO
        switch type {
        case .artist:
            let chart = try await lastFM.topArtists(username: username, period: period.rawValue, limit: limit, page: page)
            var items: [ChartEntryDTO] = []
            for entry in chart.artist ?? [] {
                let synced = try await LastFMSync.syncArtist(name: entry.name, username: username, db: db, lastFM: lastFM, syncSimilar: false)
                items.append(try await entryDTO(rank: entry.attr?.rank?.value, artist: nil, playcount: entry.playcount?.value, entity: synced.artist, db: db))
            }
            response = ChartsResponseDTO(type: type, period: period, page: chart.attr.page.value ?? page, totalPages: chart.attr.totalPages.value ?? 0, total: chart.attr.total.value ?? 0, items: items)

        case .album:
            let chart = try await lastFM.topAlbums(username: username, period: period.rawValue, limit: limit, page: page)
            var items: [ChartEntryDTO] = []
            for entry in chart.album ?? [] {
                let syncedArtist = try await LastFMSync.syncArtist(name: entry.artist.name, username: username, db: db, lastFM: lastFM, syncSimilar: false)
                let syncedAlbum = try await LastFMSync.syncAlbum(name: entry.name, artist: syncedArtist.artist, username: username, db: db, lastFM: lastFM)
                items.append(try await entryDTO(rank: entry.attr?.rank?.value, artist: syncedArtist.artist.name, playcount: entry.playcount?.value, entity: syncedAlbum.album, db: db))
            }
            response = ChartsResponseDTO(type: type, period: period, page: chart.attr.page.value ?? page, totalPages: chart.attr.totalPages.value ?? 0, total: chart.attr.total.value ?? 0, items: items)

        case .track:
            let chart = try await lastFM.topTracks(username: username, period: period.rawValue, limit: limit, page: page)
            var items: [ChartEntryDTO] = []
            for entry in chart.track ?? [] {
                let result = try await TrackInfoResolver.resolve(track: entry.name, album: nil, artist: entry.artist.name, username: username, db: db, lastFM: lastFM)
                items.append(try await entryDTO(rank: entry.attr?.rank?.value, artist: result.artist.name, playcount: entry.playcount?.value, entity: result.track, db: db))
            }
            response = ChartsResponseDTO(type: type, period: period, page: chart.attr.page.value ?? page, totalPages: chart.attr.totalPages.value ?? 0, total: chart.attr.total.value ?? 0, items: items)
        }

        await cache.set(cacheKey, response)
        return response
    }

    private static func entryDTO(rank: Int?, artist: String?, playcount: Int?, entity: some ChartResolvable, db: any Database) async throws -> ChartEntryDTO {
        let cover = try await entity.cover(db: db)
        return ChartEntryDTO(
            rank: rank ?? 0,
            id: entity.id ?? UUID(),
            name: entity.name,
            artist: artist,
            coverURL: cover.toCoverURL(dimensions: .large)?.absoluteString,
            playcount: playcount ?? 0
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
