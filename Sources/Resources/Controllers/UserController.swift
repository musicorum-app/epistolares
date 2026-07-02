import Fluent
import Vapor

struct UserController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.group("user") { group in
            group.get("charts", use: charts)
            group.get("charts", "all", use: chartsAll)
            group.get("recent-tracks", use: recentTracks)
        }
    }

    @Sendable
    func charts(req: Request) async throws -> ChartsResponseDTO {
        let query = try req.query.decode(ChartsQuery.self)

        do {
            try await req.application.lastFM.validateUsername(query.username)
        } catch LastFMError.notFound {
            req.logger.warning("user/charts: invalid username", metadata: ["username": .string(query.username)])
            throw Abort(.badRequest, reason: "Invalid Last.fm username")
        }

        let limit = min(max(query.limit ?? 50, 1), 100)
        let page = max(query.page ?? 1, 1)

        do {
            return try await ChartsResolver.resolve(
                type: query.type,
                username: query.username,
                period: query.period,
                limit: limit,
                page: page,
                db: req.db,
                lastFM: req.application.lastFM,
                logger: req.logger
            )
        } catch LastFMError.notFound {
            req.logger.info("user/charts: not found", metadata: ["username": .string(query.username), "type": .string(query.type.rawValue)])
            throw Abort(.notFound)
        }
    }

    @Sendable
    func chartsAll(req: Request) async throws -> ChartsAllResponseDTO {
        let query = try req.query.decode(ChartsAllQuery.self)

        do {
            try await req.application.lastFM.validateUsername(query.username)
        } catch LastFMError.notFound {
            req.logger.warning("user/charts/all: invalid username", metadata: ["username": .string(query.username)])
            throw Abort(.badRequest, reason: "Invalid Last.fm username")
        }

        let limit = min(max(query.limit ?? 50, 1), 100)

        do {
            return try await ChartsResolver.resolveAll(
                username: query.username,
                period: query.period,
                limit: limit,
                db: req.db,
                lastFM: req.application.lastFM,
                logger: req.logger
            )
        } catch LastFMError.notFound {
            req.logger.info("user/charts/all: not found", metadata: ["username": .string(query.username)])
            throw Abort(.notFound)
        }
    }

    @Sendable
    func recentTracks(req: Request) async throws -> RecentTracksResponseDTO {
        let query = try req.query.decode(RecentTracksQuery.self)

        do {
            try await req.application.lastFM.validateUsername(query.username)
        } catch LastFMError.notFound {
            req.logger.warning("user/recent-tracks: invalid username", metadata: ["username": .string(query.username)])
            throw Abort(.badRequest, reason: "Invalid Last.fm username")
        }

        let limit = min(max(query.limit ?? 5, 1), 100)
        let page = max(query.page ?? 1, 1)

        do {
            return try await RecentTracksResolver.resolve(
                username: query.username,
                limit: limit,
                page: page,
                db: req.db,
                lastFM: req.application.lastFM,
                logger: req.logger
            )
        } catch LastFMError.notFound {
            req.logger.info("user/recent-tracks: not found", metadata: ["username": .string(query.username)])
            throw Abort(.notFound)
        }
    }
}
