import Fluent
import Vapor
import VaporToOpenAPI

func routes(_ app: Application) throws {
    app.get("ping") { req async -> String in
        "Pong"
    }

    try app.register(collection: TrackInfoController())
    try app.register(collection: ArtistController())

    app.get("Swagger", "swagger.json") { req in
        req.application.routes.openAPI(
            info: InfoObject(
            title: "resources2",
            description: "The resources2 API",
            version: "0.1.0",
            )
        )
    }
    .excludeFromOpenAPI()
}
