import Fluent
import Foundation
import Vapor

struct TrackInfoQuery: Content {
    var track: String
    var album: String?
    var artist: String
    var username: String
}

struct UserScrobbleDTO: Content {
    var playCount: Int
    var loved: Bool?
}

struct AlbumTrackDTO: Content {
    var id: UUID
    var name: String
    var rank: Int
}

struct EntityInfoDTO: Content {
    var id: UUID
    var name: String
    var listeners: Int
    var scrobbles: Int
    var coverURL: String?
    var tags: [String]
    var userScrobbles: UserScrobbleDTO?
    var tracks: [AlbumTrackDTO]?
}

struct TrackInfoResponseDTO: Content {
    var track: EntityInfoDTO
    var album: EntityInfoDTO?
    var artist: EntityInfoDTO
}

extension UserScrobbles {
    func toDTO() -> UserScrobbleDTO {
        UserScrobbleDTO(playCount: playCount, loved: loved)
    }
}

extension TrackInfoResult {
    func toDTO(db: any Database) async throws -> TrackInfoResponseDTO {
        let artistCover = try await artist.$cover.get(reload: true, on: db)
        let artistTags = try await artist.$tags.get(reload: true, on: db)
        let artistDTO = EntityInfoDTO(
            id: try artist.requireID(),
            name: artist.name,
            listeners: artist.listeners,
            scrobbles: artist.scrobbles,
            coverURL: artistCover.toCoverURL(dimensions: .large)?.absoluteString,
            tags: artistTags.map { $0.name },
            userScrobbles: artistScrobbles?.toDTO()
        )

        var albumDTO: EntityInfoDTO?
        if let album {
            let albumCover = try await album.$cover.get(reload: true, on: db)
            let albumTags = try await album.$tags.get(reload: true, on: db)
            let albumID = try album.requireID()
            let albumTracks = try await Track.query(on: db)
                .filter(\.$album.$id == albumID)
                .sort(\.$rank)
                .all()
            albumDTO = EntityInfoDTO(
                id: albumID,
                name: album.name,
                listeners: album.listeners,
                scrobbles: album.scrobbles,
                coverURL: albumCover.toCoverURL(dimensions: .large)?.absoluteString,
                tags: albumTags.map { $0.name },
                userScrobbles: albumScrobbles?.toDTO(),
                tracks: albumTracks.map { AlbumTrackDTO(id: $0.id ?? UUID(), name: $0.name, rank: $0.rank) }
            )
        }

        let trackCover = try await track.$cover.get(reload: true, on: db)
        let trackTags = track.id != nil ? try await track.$tags.get(reload: true, on: db) : []
        let trackDTO = EntityInfoDTO(
            id: track.id ?? UUID(),
            name: track.name,
            listeners: track.listeners,
            scrobbles: track.scrobbles,
            coverURL: trackCover.toCoverURL(dimensions: .large)?.absoluteString,
            tags: trackTags.map { $0.name },
            userScrobbles: trackScrobbles?.toDTO()
        )

        return TrackInfoResponseDTO(track: trackDTO, album: albumDTO, artist: artistDTO)
    }
}
