import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor

/// configures your application
func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.middleware.use(RequestTimingMiddleware())

    let databaseName = Environment.get("DATABASE_NAME") ?? "vapor_database"
    
    app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: databaseName,
        tls: .prefer(try .init(configuration: .clientDefault)))
    ), as: .psql)

    let apiKey = Environment.get("LASTFM_API_KEY") ?? ""
    if apiKey.isEmpty {
        fatalError("Missing LASTFM_API_KEY")
    }
    app.lastFM = LastFMClient(client: app.client, apiKey: apiKey)
    app.logger.info("Using Last.fm service account", metadata: ["username": .string(LastFMSync.serviceUsername)])

    app.migrations.add(CreateCover())
    app.migrations.add(CreateTag())
    app.migrations.add(CreateArtist())
    app.migrations.add(CreateAlbum())
    app.migrations.add(CreateTrack())
    app.migrations.add(CreateArtistTag())
    app.migrations.add(CreateAlbumTag())
    app.migrations.add(CreateTrackTag())
    app.migrations.add(CreateSimilarArtists())
    app.migrations.add(CreateUserScrobbles())

    // register routes
    try routes(app)
}
