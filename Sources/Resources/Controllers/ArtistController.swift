import Fluent
import Vapor

struct ArtistController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.group("artist") { group in
            group.get("info", use: info)
        }
    }

    @Sendable
    func info(req: Request) async throws -> ArtistInfoResponseDTO {
        let query = try req.query.decode(ArtistInfoQuery.self)

        if let username = query.username {
            do {
                try await req.application.lastFM.validateUsername(username)
            } catch LastFMError.notFound {
                throw Abort(.badRequest, reason: "Invalid Last.fm username")
            }
        }

        let searchName: String
        if let id = query.id {
            guard let artist = try await Artist.find(id, on: req.db) else {
                throw Abort(.notFound)
            }
            searchName = artist.name
        } else if let name = query.name {
            searchName = name
        } else {
            throw Abort(.badRequest, reason: "Provide either id or name")
        }

        do {
            let result = try await LastFMSync.syncArtist(name: searchName, username: query.username, db: req.db, lastFM: req.application.lastFM)
            return try await result.toDTO(db: req.db)
        } catch LastFMError.notFound {
            throw Abort(.notFound)
        }
    }
}
