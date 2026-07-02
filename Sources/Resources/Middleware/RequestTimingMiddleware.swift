import Vapor

struct RequestTimingMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let start = DispatchTime.now()
        let response = try await next.respond(to: request)
        let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000

        request.logger.info(
            "\(request.method) \(request.url.path)",
            metadata: ["status": .stringConvertible(response.status.code), "ms": .stringConvertible(String(format: "%.1f", elapsedMs))]
        )

        return response
    }
}
