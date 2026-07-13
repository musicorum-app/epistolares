import Fluent
import NIOWebSocket
import Vapor

struct PresenceController: RouteCollection {
    static let staleAfter: TimeInterval = 120

    func boot(routes: any RoutesBuilder) throws {
        let group = routes.grouped("user", "presence")
        group.post("register", use: register)
        group.get(":username", use: get)
        group.post(":username", use: push)
        group.webSocket(":username", "ws", shouldUpgrade: shouldUpgrade, onUpgrade: subscribe)
    }

    @Sendable
    func register(req: Request) async throws -> PresenceRegisterResponse {
        let body = try decode(PresenceRegisterRequest.self, from: req)

        let username: String
        do {
            username = try await req.application.lastFM.verifySession(sessionKey: body.sessionKey)
        } catch let error as LastFMError {
            req.logger.info("presence/register: session key rejected", metadata: ["error": .string("\(error)")])
            throw Abort(.unauthorized)
        }

        let key = try await UserPresenceKey.getOrCreate(username: username, on: req.db)
        return PresenceRegisterResponse(username: username, pushKey: key.pushKey)
    }

    @Sendable
    func push(req: Request) async throws -> Response {
        let username = try req.parameters.require("username")
        try await authenticate(req: req, username: username)

        let body = try decode(PresenceStateDTO.self, from: req)
        await req.application.presence.push(username: username, state: body)
        return Response(status: .noContent)
    }

    @Sendable
    func get(req: Request) async throws -> PresenceStateDTO {
        let username = try req.parameters.require("username")
        try await authenticate(req: req, username: username)

        guard let state = await req.application.presence.latest(username: username, staleAfter: Self.staleAfter) else {
            throw Abort(.notFound)
        }
        return state
    }

    @Sendable
    private func shouldUpgrade(req: Request) async throws -> HTTPHeaders? {
        let username = try req.parameters.require("username")
        try await authenticate(req: req, username: username)
        return [:]
    }

    @Sendable
    private func subscribe(req: Request, ws: WebSocket) async {
        guard let username = try? req.parameters.require("username") else {
            try? await ws.close(code: .unacceptableData)
            return
        }

        let id = await req.application.presence.subscribe(username: username, socket: ws)
        let app = req.application
        ws.onClose.whenComplete { _ in
            Task { await app.presence.unsubscribe(username: username, id: id) }
        }

        ws.pingInterval = .seconds(30)
    }

    private func authenticate(req: Request, username: String) async throws {
        guard let token = req.headers.bearerAuthorization?.token else { throw Abort(.unauthorized) }
        guard let key = try await UserPresenceKey.query(forUsername: username, on: req.db).first(), key.pushKey == token else {
            throw Abort(.unauthorized)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from req: Request) throws -> T {
        do {
            return try req.content.decode(T.self)
        } catch {
            throw Abort(.badRequest, reason: "Malformed body")
        }
    }
}
