import Fluent
import Vapor

struct TrackInfoController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.group("track") { group in
            group.get("info", use: info)
        }
    }

    @Sendable
    func info(req: Request) async throws -> TrackInfoResponseDTO {
        let query = try req.query.decode(TrackInfoQuery.self)

        if let username = query.username {
            do {
                try await req.application.lastFM.validateUsername(username)
            } catch LastFMError.notFound {
                throw Abort(.badRequest, reason: "Invalid Last.fm username")
            }
        }

        do {
            let result = try await TrackInfoResolver.resolve(
                track: query.track,
                album: query.album,
                artist: query.artist,
                username: query.username,
                db: req.db,
                lastFM: req.application.lastFM
            )
            return try await result.toDTO(db: req.db)
        } catch LastFMError.notFound {
            throw Abort(.notFound)
        }
    }
}
