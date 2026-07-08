import Fluent
import Foundation
import Vapor

struct RecentTracksQuery: Content {
    var username: String
    var limit: Int?
    var page: Int?
}

/// A lighter entity reference for `RecentTrackDTO`'s `album`/`artist` -- no tags, no album
/// tracklist. Unlike a full `/track/info` lookup, a scrobble-history feed doesn't need either.
/// `userScrobbles` is never nil here: this endpoint always requires a `username`.
struct RecentEntityRefDTO: Content {
    var id: UUID
    var name: String
    var listeners: Int
    var scrobbles: Int
    var cover: CoverDTO?
    var userScrobbles: UserScrobbleDTO
}

/// Same idea as `RecentEntityRefDTO`, but for the `track` slot -- keeps `tags` (dropped for
/// `album`/`artist`) and carries `loved` via `TrackScrobbleDTO`.
struct RecentTrackEntityDTO: Content {
    var id: UUID
    var name: String
    var listeners: Int
    var scrobbles: Int
    var cover: CoverDTO?
    var tags: [String]
    var userScrobbles: TrackScrobbleDTO
}

struct RecentTrackDTO: Content {
    var track: RecentTrackEntityDTO
    var album: RecentEntityRefDTO?
    var artist: RecentEntityRefDTO
    var nowPlaying: Bool
    var playedAt: Date?
}

struct RecentTracksResponseDTO: Content {
    var page: Int
    var totalPages: Int
    var total: Int
    var items: [RecentTrackDTO]
}

extension TrackInfoResult {
    func toRecentTrackDTO(db: any Database, nowPlaying: Bool, playedAt: Date?) async throws -> RecentTrackDTO {
        let trackCover = try await track.$cover.get(reload: true, on: db)
        let trackTags = track.id != nil ? try await track.$tags.get(reload: true, on: db) : []
        let trackDTO = RecentTrackEntityDTO(
            id: track.id ?? UUID(),
            name: track.name,
            listeners: track.listeners,
            scrobbles: track.scrobbles,
            cover: trackCover.toCoverDTO(),
            tags: trackTags.map { $0.name },
            userScrobbles: trackScrobbles!.toTrackDTO()
        )

        let artistCover = try await artist.$cover.get(reload: true, on: db)
        let artistDTO = RecentEntityRefDTO(
            id: try artist.requireID(),
            name: artist.name,
            listeners: artist.listeners,
            scrobbles: artist.scrobbles,
            cover: artistCover.toCoverDTO(),
            userScrobbles: artistScrobbles!.toDTO()
        )

        var albumDTO: RecentEntityRefDTO?
        if let album {
            let albumCover = try await album.$cover.get(reload: true, on: db)
            albumDTO = RecentEntityRefDTO(
                id: try album.requireID(),
                name: album.name,
                listeners: album.listeners,
                scrobbles: album.scrobbles,
                cover: albumCover.toCoverDTO(),
                userScrobbles: albumScrobbles!.toDTO()
            )
        }

        return RecentTrackDTO(track: trackDTO, album: albumDTO, artist: artistDTO, nowPlaying: nowPlaying, playedAt: playedAt)
    }
}

extension RecentTrackDTO {
    static func unresolved(trackName: String, albumName: String?, artistName: String, cover: CoverDTO?, nowPlaying: Bool, playedAt: Date?) -> RecentTrackDTO {
        let trackDTO = RecentTrackEntityDTO(
            id: UUID(),
            name: trackName,
            listeners: 0,
            scrobbles: 0,
            cover: cover,
            tags: [],
            userScrobbles: TrackScrobbleDTO(playCount: 0, loved: false)
        )

        let artistDTO = RecentEntityRefDTO(
            id: UUID(),
            name: artistName,
            listeners: 0,
            scrobbles: 0,
            cover: nil,
            userScrobbles: UserScrobbleDTO(playCount: 0)
        )

        let albumDTO = albumName.map {
            RecentEntityRefDTO(
                id: UUID(),
                name: $0,
                listeners: 0,
                scrobbles: 0,
                cover: nil,
                userScrobbles: UserScrobbleDTO(playCount: 0)
            )
        }

        return RecentTrackDTO(track: trackDTO, album: albumDTO, artist: artistDTO, nowPlaying: nowPlaying, playedAt: playedAt)
    }
}
