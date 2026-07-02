import Fluent
import Foundation
import Vapor

struct ArtistInfoQuery: Content {
    var id: UUID?
    var name: String?
    var username: String?
}

struct ArtistBioDTO: Content {
    var summary: String?
    var content: String?
    var license: String?
}

struct SimilarArtistDTO: Content {
    var id: UUID
    var name: String
    var cover: CoverDTO?
}

struct ArtistInfoResponseDTO: Content {
    var id: UUID
    var name: String
    var aliases: [String]
    var mbid: String?
    var url: String
    var listeners: Int
    var scrobbles: Int
    var cover: CoverDTO?
    var tags: [String]
    var bio: ArtistBioDTO
    var similarArtists: [SimilarArtistDTO]
    var userScrobbles: UserScrobbleDTO?
}

extension LastFMSync.SyncedArtist {
    func toDTO(db: any Database) async throws -> ArtistInfoResponseDTO {
        let cover = try await artist.$cover.get(reload: true, on: db)
        let tags = try await artist.$tags.get(reload: true, on: db)
        let similar = try await artist.$similarArtists.get(reload: true, on: db)

        var similarDTOs: [SimilarArtistDTO] = []
        for similarArtist in similar {
            let similarCover = try await similarArtist.$cover.get(reload: true, on: db)
            similarDTOs.append(SimilarArtistDTO(
                id: try similarArtist.requireID(),
                name: similarArtist.name,
                cover: similarCover.toCoverDTO()
            ))
        }

        return ArtistInfoResponseDTO(
            id: try artist.requireID(),
            name: artist.name,
            aliases: artist.aliases,
            mbid: artist.mbid,
            url: artist.url,
            listeners: artist.listeners,
            scrobbles: artist.scrobbles,
            cover: cover.toCoverDTO(),
            tags: tags.map { $0.name },
            bio: ArtistBioDTO(summary: artist.summary, content: artist.biography, license: artist.biographyLicense),
            similarArtists: similarDTOs,
            userScrobbles: scrobbles?.toDTO()
        )
    }
}
