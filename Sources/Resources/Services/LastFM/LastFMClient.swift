import Foundation
import NIOFoundationCompat
import Vapor

protocol LastFMClientProtocol: Sendable {
    func artistInfo(name: String, username: String?) async throws -> LFMArtist
    func albumInfo(name: String, artist: String, username: String?) async throws -> LFMAlbum
    func trackInfo(name: String, artist: String, username: String?) async throws -> LFMTrack
    /// Throws `LastFMError.notFound` if username is invalid
    func validateUsername(_ username: String) async throws
}

struct LastFMClient: LastFMClientProtocol, Sendable {
    private static let baseURL = "https://ws.audioscrobbler.com/2.0/"

    let client: any Client
    let apiKey: String

    private func call<T: Decodable>(method: String, params: [String: String], as type: T.Type) async throws -> T {
        var query = params
        query["method"] = method
        query["api_key"] = apiKey
        query["format"] = "json"

        let response = try await client.get(URI(string: Self.baseURL)) { req in
            try req.query.encode(query)
        }

        guard let body = response.body else { throw LastFMError.invalidResponse }
        let data = Data(buffer: body)

        if let error = try? JSONDecoder().decode(LFMErrorResponse.self, from: data) {
            throw error.error == 6 ? LastFMError.notFound : LastFMError.apiError(code: error.error, message: error.message)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    func artistInfo(name: String, username: String?) async throws -> LFMArtist {
        var params = ["artist": name, "autocorrect": "1"]
        if let username { params["username"] = username }
        return try await call(method: "artist.getInfo", params: params, as: LFMArtistResponse.self).artist
    }

    func albumInfo(name: String, artist: String, username: String?) async throws -> LFMAlbum {
        var params = ["album": name, "artist": artist, "autocorrect": "1"]
        if let username { params["username"] = username }
        return try await call(method: "album.getInfo", params: params, as: LFMAlbumResponse.self).album
    }

    func trackInfo(name: String, artist: String, username: String?) async throws -> LFMTrack {
        var params = ["track": name, "artist": artist, "autocorrect": "1"]
        if let username { params["username"] = username }
        return try await call(method: "track.getInfo", params: params, as: LFMTrackResponse.self).track
    }

    func validateUsername(_ username: String) async throws {
        _ = try await call(method: "user.getInfo", params: ["user": username], as: LFMUserInfoResponse.self)
    }
}

extension Application {
    private struct LastFMClientKey: StorageKey {
        typealias Value = any LastFMClientProtocol
    }

    var lastFM: any LastFMClientProtocol {
        get {
            guard let client = storage[LastFMClientKey.self] else {
                fatalError("LastFMClient not configured. Set app.lastFM in configure.swift.")
            }
            return client
        }
        set { storage[LastFMClientKey.self] = newValue }
    }
}
