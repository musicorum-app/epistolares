import Vapor

struct RequestTimingMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let start = DispatchTime.now()
        let response = try await next.respond(to: request)

        request.logger.info(
            "\(request.method) \(request.url.path)",
            metadata: ["status": .stringConvertible(response.status.code), "ms": .stringConvertible(start.elapsedMs)]
        )

        return response
    }
}
