import Fluent
import Vapor

struct AlbumController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.group("album") { group in
            group.get("info", use: info)
        }
    }

    @Sendable
    func info(req: Request) async throws -> AlbumInfoResponseDTO {
        let query = try req.query.decode(AlbumInfoQuery.self)

        try await req.validateLastFMUsername(query.username, endpoint: "album/info")

        let artistName: String
        let albumName: String
        if let id = query.id {
            guard let album = try await Album.find(id, on: req.db) else {
                req.logger.info("album/info: unknown id", metadata: ["id": .string(id.uuidString)])
                throw Abort(.notFound)
            }
            let artist = try await album.$artist.get(on: req.db)
            artistName = artist.name
            albumName = album.name
        } else if let name = query.name, let artist = query.artist {
            artistName = artist
            albumName = name
        } else {
            throw Abort(.badRequest, reason: "Provide either id or name and artist")
        }

        do {
            let syncedArtist = try await LastFMSync.syncArtist(name: artistName, username: query.username, db: req.db, lastFM: req.application.lastFM)
            let result = try await LastFMSync.syncAlbum(name: albumName, artist: syncedArtist.artist, username: query.username, db: req.db, lastFM: req.application.lastFM)
            return try await result.toDTO(db: req.db)
        } catch LastFMError.notFound {
            req.logger.info("album/info: not found", metadata: ["name": .string(albumName), "artist": .string(artistName)])
            throw Abort(.notFound)
        }
    }
}
