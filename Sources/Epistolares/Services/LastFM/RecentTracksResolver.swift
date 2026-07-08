import Fluent
import Foundation
import Logging

enum RecentTracksResolver {
    static func resolve(
        username: String,
        limit: Int,
        page: Int,
        db: any Database,
        lastFM: any LastFMClientProtocol,
        logger: Logger
    ) async throws -> RecentTracksResponseDTO {
        let overallStart = ContinuousClock.now
        let recent = try await lastFM.recentTracks(username: username, limit: limit, page: page)

        let items = try await mapConcurrently(recent.track ?? []) { entry in
            let albumName = entry.album?.text.isEmpty == false ? entry.album?.text : nil
            let nowPlaying = entry.attr?.nowplaying == "true"
            let playedAt = entry.date?.uts.value.map { Date(timeIntervalSince1970: TimeInterval($0)) }

            do {
                let result = try await TrackInfoResolver.resolve(
                    track: entry.name,
                    album: albumName,
                    artist: entry.artist.text,
                    username: username,
                    db: db,
                    lastFM: lastFM
                )
                return try await result.toRecentTrackDTO(db: db, nowPlaying: nowPlaying, playedAt: playedAt)
            } catch LastFMError.notFound {
                logger.info("recent-tracks: entry unresolvable, returning raw scrobble data", metadata: [
                    "track": .string(entry.name), "artist": .string(entry.artist.text),
                ])
                return RecentTrackDTO.unresolved(
                    trackName: entry.name,
                    albumName: albumName,
                    artistName: entry.artist.text,
                    cover: Cover.toCoverDTO(externalID: LastFMSync.coverExternalID(from: entry.image)),
                    nowPlaying: nowPlaying,
                    playedAt: playedAt
                )
            }
        }

        logger.info("resolved recent-tracks", metadata: [
            "username": .string(username), "count": .stringConvertible(items.count), "ms": .stringConvertible(overallStart.elapsedMs),
        ])

        return RecentTracksResponseDTO(
            page: recent.attr.page.value ?? page,
            totalPages: recent.attr.totalPages.value ?? 0,
            total: recent.attr.total.value ?? 0,
            items: items
        )
    }
}
