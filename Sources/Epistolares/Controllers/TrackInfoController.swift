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

        let trackName: String
        let albumName: String?
        let artistName: String
        if let id = query.id {
            guard let track = try await Track.find(id, on: req.db) else {
                req.logger.info("track/info: unknown id", metadata: ["id": .string(id.uuidString)])
                throw Abort(.notFound)
            }
            let artist = try await track.$artist.get(on: req.db)
            let album = try await track.$album.get(on: req.db)
            trackName = track.name
            albumName = album.name
            artistName = artist.name
        } else if let track = query.track, let artist = query.artist {
            trackName = track
            albumName = query.album
            artistName = artist
        } else {
            throw Abort(.badRequest, reason: "Provide either id or track and artist")
        }

        do {
            let result = try await TrackInfoResolver.resolve(
                track: trackName,
                album: albumName,
                artist: artistName,
                username: query.username,
                db: req.db,
                lastFM: req.application.lastFM
            )
            return try await result.toDTO(displayName: trackName, db: req.db)
        } catch LastFMError.notFound {
            req.logger.info("track/info: not found", metadata: ["track": .string(trackName), "artist": .string(artistName), "album": .string(albumName ?? "nil")])
            throw Abort(.notFound)
        }
    }
}
