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

        try await req.validateLastFMUsername(query.username, endpoint: "track/info")

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
            req.logger.info("track/info: not found", metadata: ["track": .string(query.track), "artist": .string(query.artist), "album": .string(query.album ?? "nil")])
            throw Abort(.notFound)
        }
    }
}
