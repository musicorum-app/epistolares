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
        try await req.validateLastFMUsername(query.username, endpoint: "user/charts")

        do {
            return try await ChartsResolver.resolve(
                type: query.type,
                username: query.username,
                period: query.period,
                limit: clampedLimit(query.limit, default: 50),
                page: clampedPage(query.page),
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
        try await req.validateLastFMUsername(query.username, endpoint: "user/charts/all")

        do {
            return try await ChartsResolver.resolveAll(
                username: query.username,
                period: query.period,
                limit: clampedLimit(query.limit, default: 50),
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
        try await req.validateLastFMUsername(query.username, endpoint: "user/recent-tracks")

        do {
            return try await RecentTracksResolver.resolve(
                username: query.username,
                limit: clampedLimit(query.limit, default: 5),
                page: clampedPage(query.page),
                db: req.db,
                lastFM: req.application.lastFM,
                logger: req.logger
            )
        } catch LastFMError.notFound {
            req.logger.info("user/recent-tracks: not found", metadata: ["username": .string(query.username)])
            throw Abort(.notFound)
        }
    }

    private func clampedLimit(_ limit: Int?, default defaultValue: Int, max maxValue: Int = 100) -> Int {
        min(max(limit ?? defaultValue, 1), maxValue)
    }

    private func clampedPage(_ page: Int?) -> Int {
        max(page ?? 1, 1)
    }
}
