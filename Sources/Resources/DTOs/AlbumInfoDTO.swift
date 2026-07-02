import Fluent
import Foundation
import Vapor

struct AlbumInfoQuery: Content {
    var id: UUID?
    var name: String?
    var artist: String?
    var username: String?
}

struct AlbumInfoResponseDTO: Content {
    var id: UUID
    var name: String
    var artist: String
    var mbid: String?
    var url: String
    var listeners: Int
    var scrobbles: Int
    var cover: CoverDTO?
    var tags: [String]
    var bio: ArtistBioDTO
    var tracks: [AlbumTrackDTO]
    var userScrobbles: UserScrobbleDTO?
}

extension LastFMSync.SyncedAlbum {
    func toDTO(db: any Database) async throws -> AlbumInfoResponseDTO {
        let artist = try await album.$artist.get(reload: true, on: db)
        let cover = try await album.$cover.get(reload: true, on: db)
        let tags = try await album.$tags.get(reload: true, on: db)
        let albumID = try album.requireID()
        let tracks = try await Track.query(on: db)
            .filter(\.$album.$id == albumID)
            .sort(\.$rank)
            .all()

        return AlbumInfoResponseDTO(
            id: albumID,
            name: album.name,
            artist: artist.name,
            mbid: album.mbid,
            url: album.url,
            listeners: album.listeners,
            scrobbles: album.scrobbles,
            cover: cover.toCoverDTO(),
            tags: tags.map { $0.name },
            bio: ArtistBioDTO(summary: album.summary, content: album.biography, license: album.biographyLicense),
            tracks: tracks.map { AlbumTrackDTO(id: $0.id ?? UUID(), name: $0.name, rank: $0.rank) },
            userScrobbles: scrobbles?.toDTO()
        )
    }
}
