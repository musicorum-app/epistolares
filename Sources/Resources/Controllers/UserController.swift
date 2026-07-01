import Fluent
import Vapor

struct UserController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.group("user") { group in
            group.get("charts", use: charts)
        }
    }

    @Sendable
    func charts(req: Request) async throws -> ChartsResponseDTO {
        let query = try req.query.decode(ChartsQuery.self)

        do {
            try await req.application.lastFM.validateUsername(query.username)
        } catch LastFMError.notFound {
            throw Abort(.badRequest, reason: "Invalid Last.fm username")
        }

        let limit = min(max(query.limit ?? 50, 1), 1000)
        let page = max(query.page ?? 1, 1)

        do {
            return try await ChartsResolver.resolve(
                type: query.type,
                username: query.username,
                period: query.period ?? .overall,
                limit: limit,
                page: page,
                db: req.db,
                lastFM: req.application.lastFM
            )
        } catch LastFMError.notFound {
            throw Abort(.notFound)
        }
    }
}
